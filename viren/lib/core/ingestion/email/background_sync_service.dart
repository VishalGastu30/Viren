import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import '../../security/key_manager.dart';
import '../../database/app_database.dart';
import '../../database/repositories/trade_repository.dart';
import '../../auth/auth_service.dart';
import 'email_import_service.dart';
import '../../integrity/integrity_service.dart';
import '../../security/field_encryptor.dart';
import '../../database/repositories/behavior_repository.dart';
import '../../intelligence/confidence_calculator.dart';
import '../../intelligence/stats/portfolio_snapshot_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BackgroundSyncService — Headless Email Polling via Workmanager
//
// Periodically scans for new NSE/SBI broker emails in the background.
// If valid cached OAuth tokens exist, executes the full ingestion pipeline:
// discovery -> decrypt -> classify -> parse -> ledger update.
// Emits local notifications to inform the user.
// ─────────────────────────────────────────────────────────────────────────────

const String virenSyncTaskName = 'viren_gmail_sync_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    developer.log('Workmanager task started: $task', name: 'BackgroundSyncService');

    try {
      // 1. Headless Initialization
      WidgetsFlutterBinding.ensureInitialized();
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
      final importDao = database.importDao;
      final behaviorRepo = BehaviorRepository(database.behaviorDao);
      final confidenceCalculator = ConfidenceCalculator(behaviorRepo);

      // Initialize notifications
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
      );

      // 2. Auth (Relies on cached tokens in TokenVault)
      final authService = await AuthService.create(scopes: [gmail.GmailApi.gmailReadonlyScope]);
      
      // Attempt headless auth. This will throw if interactive consent is required via browser.
      await authService.authenticate(); 

      // Retrieve PAN from secure storage to decrypt PDFs
      const secureStorage = FlutterSecureStorage();
      final pan = await secureStorage.read(key: 'user_pan_uppercase');
      if (pan == null || pan.isEmpty) {
         developer.log('Missing PAN in background task. Aborting sync.', name: 'BackgroundSyncService');
         return true; // Return true so Workmanager doesn't retry a known error
      }

      // 3. Pipeline Execution
      final importService = EmailImportService(
        tradeRepository: tradeRepo, 
        importDao: importDao,
        db: database,
        confidenceCalculator: confidenceCalculator,
      );
      
      // Scan for the last 7 days to catch any recent offline broker emails
      final since = DateTime.now().subtract(const Duration(days: 7));
      
      final discovery = await importService.discover(
        authService: authService,
        since: since,
      );

      if (discovery.isEmpty) {
        developer.log('Background sync: No new broker emails found.', name: 'BackgroundSyncService');
        return true;
      }

      final preview = await importService.process(
        discovery: discovery,
        pan: pan,
        authService: authService,
      );

      // Only commit if we actually found usable data (trades or snapshots) to avoid empty commits
      if (preview.totalTradesFound > 0 || preview.totalSnapshotsFound > 0) {
        await importService.commit(preview);
        
        // Let the user know the portfolio changed behind the scenes
        if (preview.totalTradesFound > 0) {
            _showNotification(
                flutterLocalNotificationsPlugin, 
                'Portfolio Updated', 
                'Ingested ${preview.totalTradesFound} trades from NSE Direct in the background.'
            );
        } else if (preview.totalSnapshotsFound > 0) {
            _showNotification(
                flutterLocalNotificationsPlugin, 
                'Statements Synced', 
                'Processed regular statements for reconciliation.'
            );
        }
      }

      return true;
    } catch (e) {
      developer.log('Background sync task failed: $e', name: 'BackgroundSyncService', error: e);
      return false; // False triggers Workmanager retry rules if configured
    }
  });
}

Future<void> _showNotification(FlutterLocalNotificationsPlugin plugin, String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'viren_sync_channel', 
    'Background Sync',
    channelDescription: 'Notifications for automated background portfolio updates',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
  
  await plugin.show(
    id: DateTime.now().millisecond,
    title: title,
    body: body,
    notificationDetails: platformChannelSpecifics,
  );
}

class BackgroundSyncService {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  /// Registers a periodic weekly task to scan the inbox.
  static Future<void> registerWeeklySync() async {
    await Workmanager().registerPeriodicTask(
      virenSyncTaskName,
      virenSyncTaskName,
      frequency: const Duration(days: 7),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep, // Don't override existing timer
    );
  }
}
