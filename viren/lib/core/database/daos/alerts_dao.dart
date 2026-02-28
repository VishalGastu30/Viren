import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/alerts_table.dart';

part 'alerts_dao.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlertsDao — Immutable alert records.
//
// Alerts are written once and never deleted.
// Dismissal and snoozing are soft-state flags on the record.
// ─────────────────────────────────────────────────────────────────────────────
@DriftAccessor(tables: [Alerts])
class AlertsDao extends DatabaseAccessor<AppDatabase> with _$AlertsDaoMixin {
  AlertsDao(super.db);

  /// Insert a new, immutable alert record.
  Future<Alert> insertAlert(AlertsCompanion entry) =>
      into(alerts).insertReturning(entry);

  /// Watch active (non-dismissed, non-snoozed) alerts, newest first.
  Stream<List<Alert>> watchActiveAlerts() {
    final now = DateTime.now().toUtc();
    return (select(alerts)
          ..where(
            (a) =>
                a.dismissedAt.isNull() &
                (a.snoozedUntil.isNull() |
                    a.snoozedUntil.isSmallerThanValue(now)),
          )
          ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
        .watch();
  }

  /// Watch ALL alerts including dismissed ones (for audit/history).
  Stream<List<Alert>> watchAllAlerts() =>
      (select(alerts)
            ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
          .watch();

  /// Soft-dismiss an alert. Sets dismissed_at to now.
  Future<void> dismissAlert(String id) async {
    await (update(alerts)..where((a) => a.id.equals(id))).write(
      AlertsCompanion(dismissedAt: Value(DateTime.now().toUtc())),
    );
  }

  /// Snooze an alert until a future UTC time.
  Future<void> snoozeAlert(String id, DateTime until) async {
    await (update(alerts)..where((a) => a.id.equals(id))).write(
      AlertsCompanion(snoozedUntil: Value(until.toUtc())),
    );
  }

  /// Fetch a single alert by ID.
  Future<Alert?> getAlertById(String id) =>
      (select(alerts)..where((a) => a.id.equals(id))).getSingleOrNull();

  /// Fetch ALL alerts in chronological order for integrity verification.
  Future<List<Alert>> getAllAlerts() =>
      (select(alerts)..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .get();
}
