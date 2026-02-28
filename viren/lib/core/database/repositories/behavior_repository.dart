import 'package:uuid/uuid.dart';
import '../app_database.dart';
import '../daos/behavior_dao.dart';
import '../enums.dart';
import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BehaviorRepository — Behavioral metrics and confidence score wiring.
// ─────────────────────────────────────────────────────────────────────────────
class BehaviorRepository {
  final BehaviorDao _dao;
  final _uuid = const Uuid();

  BehaviorRepository(this._dao);

  /// Store a computed behavioral signal.
  Future<BehaviorMetric> saveMetric({
    required BehaviorMetricType metricType,
    required double value,
    required String timeWindowStart,
    required String timeWindowEnd,
    int confidence = 0,
  }) {
    return _dao.insertBehaviorMetric(
      BehaviorMetricsCompanion.insert(
        id: _uuid.v4(),
        metricType: metricType,
        value: value,
        timeWindowStart: timeWindowStart,
        timeWindowEnd: timeWindowEnd,
        confidence: Value(confidence),
      ),
    );
  }

  /// Store a new confidence score calculation snapshot.
  Future<ConfidenceMeterData> saveConfidenceSnapshot({
    required double score,
    required double strategyAdherence,
    required double consistency,
    required double emotionalStability,
  }) {
    return _dao.insertConfidenceSnapshot(
      ConfidenceMeterCompanion.insert(
        id: _uuid.v4(),
        score: score,
        strategyAdherence: strategyAdherence,
        consistency: consistency,
        emotionalStability: emotionalStability,
      ),
    );
  }

  /// Returns the most recent confidence score row. Null if never computed.
  Future<ConfidenceMeterData?> getLatestConfidenceScore() =>
      _dao.latestConfidenceScore();

  /// Watch the latest confidence score reactively.
  Stream<ConfidenceMeterData?> watchLatestConfidenceScore() =>
      _dao.watchLatestConfidenceScore();

  /// Watch all behavioral metrics, newest first.
  Stream<List<BehaviorMetric>> watchAllMetrics() => _dao.watchAllMetrics();
}
