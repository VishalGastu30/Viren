import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/behavior_metrics_table.dart';
import '../tables/confidence_meter_table.dart';

part 'behavior_dao.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BehaviorDao — Behavioral metrics and confidence score storage.
// ─────────────────────────────────────────────────────────────────────────────
@DriftAccessor(tables: [BehaviorMetrics, ConfidenceMeter])
class BehaviorDao extends DatabaseAccessor<AppDatabase>
    with _$BehaviorDaoMixin {
  BehaviorDao(super.db);

  // ── Behavior Metrics ────────────────────────────────────────────────────────

  /// Insert a computed behavioral metric.
  Future<BehaviorMetric> insertBehaviorMetric(BehaviorMetricsCompanion entry) =>
      into(behaviorMetrics).insertReturning(entry);

  /// Watch all metrics, newest first.
  Stream<List<BehaviorMetric>> watchAllMetrics() =>
      (select(behaviorMetrics)
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
          .watch();

  /// One-time fetch of metrics within a date window [startDate, endDate]
  /// where dates are ISO-8601 strings (e.g. "2024-01-01").
  Future<List<BehaviorMetric>> getMetricsInWindow(
    String startDate,
    String endDate,
  ) =>
      (select(behaviorMetrics)
            ..where(
              (m) =>
                  m.timeWindowStart.isBiggerOrEqualValue(startDate) &
                  m.timeWindowEnd.isSmallerOrEqualValue(endDate),
            ))
          .get();

  // ── Confidence Meter ────────────────────────────────────────────────────────

  /// Insert a new confidence score snapshot.
  Future<ConfidenceMeterData> insertConfidenceSnapshot(
    ConfidenceMeterCompanion entry,
  ) =>
      into(confidenceMeter).insertReturning(entry);

  /// Returns the single most recent confidence score. Null if none exists yet.
  Future<ConfidenceMeterData?> latestConfidenceScore() =>
      (select(confidenceMeter)
            ..orderBy([(c) => OrderingTerm.desc(c.calculatedAt)])
            ..limit(1))
          .getSingleOrNull();

  /// Watch the latest confidence score reactively.
  Stream<ConfidenceMeterData?> watchLatestConfidenceScore() =>
      (select(confidenceMeter)
            ..orderBy([(c) => OrderingTerm.desc(c.calculatedAt)])
            ..limit(1))
          .watchSingleOrNull();
}
