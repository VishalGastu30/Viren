import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_database.dart';
import 'database_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Journal providers — starred insights feed.
//
// An insight is "starred" when snoozedUntil == DateTime(9999, 1, 1).
// This sentinel value was chosen because:
//  1. The column already exists — no migration needed.
//  2. A year-9999 datetime is impossible to collide with real snooze logic.
//  3. The activeAlertsProvider is not affected — it only filters dismissedAt.
// ─────────────────────────────────────────────────────────────────────────────

/// Sentinel datetime value for starred alerts.
final kStarredSentinel = DateTime(9999, 1, 1);

/// Streams all starred (journalled) alerts, newest first.
/// Starred = snoozedUntil == DateTime(9999, 1, 1) AND not dismissed.
final journalAlertsProvider = StreamProvider<List<Alert>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.alerts)
        ..where((a) =>
            a.snoozedUntil.isBiggerOrEqualValue(DateTime(9998)) &
            a.dismissedAt.isNull())
        ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
      .watch();
});

/// Checks if a specific alert is starred.
/// Used by InsightCard to show the correct star icon state.
final isAlertStarredProvider =
    Provider.family<bool, String>((ref, alertId) {
  final journalAsync = ref.watch(journalAlertsProvider);
  return journalAsync.maybeWhen(
    data: (alerts) => alerts.any((a) => a.id == alertId),
    orElse: () => false,
  );
});
