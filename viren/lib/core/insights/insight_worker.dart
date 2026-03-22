import 'package:workmanager/workmanager.dart';
import '../database/app_database.dart';
import 'insight_engine.dart';
import 'weekly_digest_service.dart';
import 'overnight_monitor.dart';
import 'auto_email_sync_service.dart';
import 'package:flutter/widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InsightWorker — WorkManager background task dispatcher.
//
// Runs every 15 minutes (WorkManager minimum interval).
// The InsightEngine checks market hours internally — safe to run always.
// Also handles the weekly digest one-off task.
// ─────────────────────────────────────────────────────────────────────────────

const _taskName = 'viren_insight_worker';
const _taskTag = 'viren_insights';

/// Top-level function — required by WorkManager.
/// Must be a top-level function, NOT a method.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    // ── Morning briefing ──────────────────────────────────────
    if (taskName == kMorningBriefingTask) {
      try {
        final db = AppDatabase();
        await OvernightMonitor.runMorningBriefing(db);
        await db.close();
      } catch (_) {}
      return Future.value(true);
    }

    // ── Weekly digest ──────────────────────────────────────────
    if (taskName == 'WEEKLY_DIGEST' || taskName == weeklyDigestTaskName) {
      try {
        final db = AppDatabase();
        await WeeklyDigestService.run(db);
        await db.close();
        await WeeklyDigestService.scheduleNextWeek();
      } catch (_) {}
      return Future.value(true);
    }

    // ── Sunday evening report ─────────────────────────────────────
    if (taskName == sundayReportTaskName) {
      try {
        final db = AppDatabase();
        await WeeklyDigestService.runSundayReport(db);
        await db.close();
        await WeeklyDigestService.scheduleWeekendReports();
      } catch (_) {}
      return Future.value(true);
    }

    // ── Auto Gmail sync ────────────────────────────────────────
    if (taskName == kAutoEmailSyncTask) {
      try {
        await AutoEmailSyncService.runSync();
      } catch (_) {}
      return Future.value(true);
    }

    // ── Regular insight scan ───────────────────────────────────
    if (taskName != _taskName) return Future.value(true);

    try {
      final db = AppDatabase();
      final engine = InsightEngine(db);
      await engine.run();
      await db.close();
      return Future.value(true);
    } catch (_) {
      return Future.value(false);
    }
  });
}

/// Registers the periodic background task and weekly digest.
/// Call once at app startup after Workmanager().initialize().
Future<void> registerInsightWorker() async {
  // Insight scan — every 15 min
  await Workmanager().registerPeriodicTask(
    _taskName, _taskName,
    tag: _taskTag,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 5),
  );

  // Auto email sync — adaptive timing
  await AutoEmailSyncService.registerAdaptiveSync();

  // Weekly digest
  await WeeklyDigestService.scheduleNextWeek();
  await WeeklyDigestService.scheduleWeekendReports();
}

/// Cancels the background task (e.g. when user disables insights).
Future<void> cancelInsightWorker() async {
  await Workmanager().cancelByTag(_taskTag);
}
