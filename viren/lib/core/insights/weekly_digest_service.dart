import 'package:drift/drift.dart';
import 'package:workmanager/workmanager.dart';
import '../database/app_database.dart';
import 'notification_service.dart';
import '../database/enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WeeklyDigestService — Saturday summary notification.
//
// Reads the past 7 days of alerts and sends one notification
// summarising what Viren noticed this week.
//
// Scheduled as a one-time WorkManager task that re-schedules itself
// each time it runs, so it fires every Saturday regardless of whether
// the app is open.
//
// Privacy: all data is local. No network calls.
// ─────────────────────────────────────────────────────────────────────────────

const weeklyDigestTaskName = 'viren_weekly_digest';

class WeeklyDigestService {
  /// Builds and sends the weekly digest notification.
  static Future<void> run(AppDatabase db) async {
    final cutoff =
        DateTime.now().subtract(const Duration(days: 7));

    // Fetch all non-dismissed alerts from the past 7 days
    final weekAlerts = await (db.select(db.alerts)
          ..where((a) =>
              a.createdAt.isBiggerOrEqualValue(cutoff) &
              a.dismissedAt.isNull() &
              // Exclude sentinels
              a.alertType.isNotValue('MACRO_STATE')))
        .get();

    if (weekAlerts.isEmpty) {
      // Nothing this week — skip the notification
      return;
    }

    // Count by category
    final priceAlerts = weekAlerts
        .where((a) => [
              'DRAWDOWN_ALERT',
              'RECOVERY_ALERT',
              'CIRCUIT_BREAKER',
              'STOP_LOSS_HIT',
              'PRICE_TARGET_HIT',
            ].contains(a.alertType))
        .length;

    final newsAlerts = weekAlerts
        .where((a) =>
            a.alertType == 'NEWS_RELEVANT' ||
            a.alertType == 'MACRO_EVENT')
        .length;

    final patternAlerts = weekAlerts
        .where((a) => [
              'DCA_OPPORTUNITY',
              'CONCENTRATION_DRIFT',
              'ACCUMULATION_PATTERN',
              'CONSISTENCY_STREAK',
              'BEHAVIOUR_WARNING',
              'INACTIVITY_ALERT',
            ].contains(a.alertType))
        .length;

    // Find the most significant alert of the week for the headline
    final warningAlerts = weekAlerts
        .where((a) =>
            a.severity == AlertSeverity.critical ||
            a.severity == AlertSeverity.warning)
        .toList();

    final headline = warningAlerts.isNotEmpty
        ? 'Top signal: ${warningAlerts.first.title}'
        : 'Your portfolio had a quiet week.';

    // Build the summary body
    final parts = <String>[];
    if (priceAlerts > 0) parts.add('$priceAlerts price alerts');
    if (newsAlerts > 0) parts.add('$newsAlerts news signals');
    if (patternAlerts > 0) parts.add('$patternAlerts pattern insights');

    final summary = parts.isEmpty
        ? 'Nothing significant this week.'
        : parts.join(' · ');

    await NotificationService.showAlertNotification(
      id: 9999, // fixed ID for weekly digest
      title: '📊 Viren Weekly — ${weekAlerts.length} insights this week',
      body: '$headline\n\n$summary\n\nTap to review.',
      severity: AlertSeverity.info, // mapped from prompt's "low"
      payload: '/insights',
    );
  }

  /// Schedules the weekly digest to fire next Saturday at 9 AM IST.
  /// Uses a one-time WorkManager task with an initial delay calculated
  /// from the current time to next Saturday 9 AM.
  static Future<void> scheduleNextWeek() async {
    final delay = _delayUntilNextSaturday9AM();
    await Workmanager().registerOneOffTask(
      weeklyDigestTaskName,
      weeklyDigestTaskName,
      initialDelay: delay,
      constraints: Constraints(
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Calculates the Duration from now until next Saturday at 9:00 AM IST.
  static Duration _delayUntilNextSaturday9AM() {
    final now = DateTime.now().toUtc().add(
        const Duration(hours: 5, minutes: 30)); // IST
    var next = DateTime(now.year, now.month, now.day, 9, 0); // 9 AM today

    // Find next Saturday (weekday 6)
    int daysUntilSaturday = (6 - now.weekday + 7) % 7;
    if (daysUntilSaturday == 0 && now.hour >= 9) {
      // Already past 9 AM Saturday — schedule for next Saturday
      daysUntilSaturday = 7;
    }

    next = next.add(Duration(days: daysUntilSaturday));
    final delay = next.difference(now);
    // Minimum 1 minute delay to avoid WorkManager complaints
    return delay.isNegative || delay.inMinutes < 1
        ? const Duration(minutes: 1)
        : delay;
  }
}
