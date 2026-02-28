import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────────
// confidence_meter — Non-Monetary Score
//
// Slow-moving aggregate of behavioral health. One row per calculation.
// Never volatile — should not change daily without significant behavioral data.
// ─────────────────────────────────────────────────────────────────────────────
class ConfidenceMeter extends Table {
  /// UUID primary key.
  TextColumn get id => text().named('id')();

  /// Overall composite confidence score (0.0–100.0).
  RealColumn get score => real().named('score')();

  /// Sub-score: how well actions matched stated strategy (0.0–100.0).
  RealColumn get strategyAdherence =>
      real().named('strategy_adherence')();

  /// Sub-score: consistency of decision-making cadence (0.0–100.0).
  RealColumn get consistency => real().named('consistency')();

  /// Sub-score: absence of emotionally-driven decisions (0.0–100.0).
  RealColumn get emotionalStability =>
      real().named('emotional_stability')();

  /// UTC timestamp when this score was calculated.
  DateTimeColumn get calculatedAt =>
      dateTime().named('calculated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
