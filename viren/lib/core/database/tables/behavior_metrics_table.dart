import 'package:drift/drift.dart';
import '../enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// behavior_metrics — Self-Awareness Engine
//
// Computed behavioral signals stored for trend analysis.
// These are facts, not judgments. No language of fault.
// ─────────────────────────────────────────────────────────────────────────────
class BehaviorMetrics extends Table {
  /// UUID primary key.
  TextColumn get id => text().named('id')();

  /// The class of behavioral signal detected.
  IntColumn get metricType =>
      intEnum<BehaviorMetricType>().named('metric_type')();

  /// Numeric value of this metric (interpretation depends on metricType).
  RealColumn get value => real().named('value')();

  /// Start of the analysis window (ISO-8601 date string, e.g. "2024-01-01").
  TextColumn get timeWindowStart => text().named('time_window_start')();

  /// End of the analysis window (ISO-8601 date string, e.g. "2024-01-31").
  TextColumn get timeWindowEnd => text().named('time_window_end')();

  /// Detection confidence (0–100).
  IntColumn get confidence =>
      integer().named('confidence').withDefault(const Constant(0))();

  /// UTC row creation time.
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
