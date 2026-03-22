import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/app_database.dart';
import '../security/key_manager.dart';
import '../security/field_encryptor.dart';
import '../integrity/integrity_service.dart';
import '../intelligence/stats/portfolio_snapshot_service.dart';
import '../database/repositories/trade_repository.dart';
import '../intelligence/confidence_calculator.dart';
import '../database/repositories/behavior_repository.dart';
import '../auth/auth_service.dart';
import '../ingestion/email/email_import_service.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

// ─────────────────────────────────────────────────────────────────────────────
// AutoEmailSyncService — Adaptive automatic email scanning.
//
// Replaces BackgroundSyncService.registerWeeklySync() (which was weekly
// and had a callbackDispatcher conflict).
//
// Adaptive timing:
//   Market hours + 2h (9AM-5:30PM): every 30 minutes
//   Evening (5:30PM-10PM): every 2 hours
//   Night (10PM-8AM): once at 10PM, once at 7:45AM
//
// This means contract notes (which arrive after trade execution during
// market hours) are imported within 30 minutes automatically.
// The user never needs to tap "Scan Email" again.
// ─────────────────────────────────────────────────────────────────────────────

const kAutoEmailSyncTask = 'viren_auto_email_sync';

class AutoEmailSyncService {
  /// Register adaptive periodic task.
  static Future<void> registerAdaptiveSync() async {
    final interval = _currentInterval();
    await Workmanager().registerPeriodicTask(
      kAutoEmailSyncTask,
      kAutoEmailSyncTask,
      frequency: interval,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false, // email scan must work even at low battery
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      // Replace so interval updates when app is reopened
    );
    developer.log(
      'AutoEmailSync registered: ${interval.inMinutes}min interval',
      name: 'AutoEmailSyncService',
    );
  }

  /// Determines polling interval based on current time (IST).
  static Duration _currentInterval() {
    final now = DateTime.now().toUtc().add(
        const Duration(hours: 5, minutes: 30)); // IST
    final minutes = now.hour * 60 + now.minute;

    // 9 AM – 5:30 PM: every 30 minutes (market hours + post-market window)
    if (minutes >= 9 * 60 && minutes <= 17 * 60 + 30) {
      return const Duration(minutes: 30);
    }
    // 5:30 PM – 10 PM: every 2 hours
    if (minutes > 17 * 60 + 30 && minutes <= 22 * 60) {
      return const Duration(hours: 2);
    }
    // Night: every 4 hours (minimum useful check)
    return const Duration(hours: 4);
  }

  /// Runs the email sync — called from callbackDispatcher.
  static Future<void> runSync() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      final keyManager = await KeyManager.initialize();
      final database = AppDatabase();
      final encryptor = FieldEncryptor(keyManager);
      final integrityService = IntegrityService(database);
      final snapshotService = PortfolioSnapshotService(database);

      final tradeRepo = TradeRepository(
        tradesDao: database.tradesDao,
        holdingsDao: database.holdingsDao,
        encryptor: encryptor,
        integrityService: integrityService,
        snapshotService: snapshotService,
      );
      final behaviorRepo = BehaviorRepository(database.behaviorDao);
      final confidenceCalc = ConfidenceCalculator(behaviorRepo);

      final importService = EmailImportService(
        tradeRepository: tradeRepo,
        importDao: database.importDao,
        db: database,
        confidenceCalculator: confidenceCalc,
      );

      // Authenticate silently using cached OAuth tokens
      final authService = await AuthService.create(
          scopes: [gmail.GmailApi.gmailReadonlyScope]);
      await authService.authenticate();

      // Get PAN for PDF decryption
      const secureStorage = FlutterSecureStorage();
      final pan = await secureStorage.read(key: 'user_pan_uppercase');
      if (pan == null || pan.isEmpty) {
        developer.log('AutoEmailSync: No PAN cached, skipping.',
            name: 'AutoEmailSyncService');
        await database.close();
        return;
      }

      // Scan last 2 days only (not 7 — avoids re-processing old emails)
      // Deduplication in insertTrade handles the rare duplicate case
      final since = DateTime.now().subtract(const Duration(days: 2));

      final discovery = await importService.discover(
        authService: authService,
        since: since,
      );

      if (discovery.isEmpty) {
        developer.log('AutoEmailSync: No new broker emails.',
            name: 'AutoEmailSyncService');
        await database.close();
        return;
      }

      final preview = await importService.process(
        discovery: discovery,
        pan: pan,
        authService: authService,
      );

      if (preview.totalTradesFound > 0) {
        await importService.commit(preview);

        // Notify user — trades were auto-imported
        // Use a low-priority notification so it doesn't interrupt
        final tradesText = preview.totalTradesFound == 1
            ? '1 new trade imported'
            : '${preview.totalTradesFound} new trades imported';
        developer.log(
          'AutoEmailSync: $tradesText from ${preview.totalBrokerEmailsFound} emails.',
          name: 'AutoEmailSyncService',
        );
        // The notification is fired by InsightEngine's next run
        // which will detect the new trades and surface them.
      }

      await database.close();
    } catch (e) {
      developer.log('AutoEmailSync failed: $e',
          name: 'AutoEmailSyncService', error: e);
    }
  }
}
