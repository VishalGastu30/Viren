import 'package:workmanager/workmanager.dart';
import '../database/app_database.dart';
import 'insight_engine.dart';
import 'weekly_digest_service.dart';

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
    // ── Weekly digest task ────────────────────────────────────
    if (taskName == weeklyDigestTaskName) {
      try {
        final db = AppDatabase();
        await WeeklyDigestService.run(db);
        await db.close();
        await WeeklyDigestService.scheduleNextWeek();
      } catch (_) {}
      return Future.value(true);
    }

    // ── Regular insight worker task ───────────────────────────
    if (taskName != _taskName) return Future.value(true);

    try {
      // Open a fresh DB connection for the background isolate
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
  // Register the periodic insight scanning task
  await Workmanager().registerPeriodicTask(
    _taskName,
    _taskName,
    tag: _taskTag,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true, // don't run on low battery
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 5),
  );

  // Schedule the weekly digest (Saturday 9 AM IST)
  await WeeklyDigestService.scheduleNextWeek();
}

/// Cancels the background task (e.g. when user disables insights).
Future<void> cancelInsightWorker() async {
  await Workmanager().cancelByTag(_taskTag);
}
