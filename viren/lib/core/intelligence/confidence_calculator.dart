import 'dart:math';
import '../database/app_database.dart';
import '../database/repositories/behavior_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ConfidenceCalculator — Real Behavioral Scoring
//
// Computes the composite confidence score from three sub-scores:
//   • Strategy Adherence — do actions match stated intentions?
//   • Consistency — regularity of trading cadence
//   • Emotional Stability — absence of emotionally-flagged trades
//
// All computations are deterministic. No AI, no prediction, no judgment.
// The score is a mirror — it reflects behavior, not quality.
// ─────────────────────────────────────────────────────────────────────────────

class ConfidenceScoreResult {
  final double compositeScore;     // 0–100
  final double strategyAdherence;  // 0–100
  final double consistency;        // 0–100
  final double emotionalStability; // 0–100

  const ConfidenceScoreResult({
    required this.compositeScore,
    required this.strategyAdherence,
    required this.consistency,
    required this.emotionalStability,
  });
}

class ConfidenceCalculator {
  final BehaviorRepository _behaviorRepo;

  // Weights for composite score (must sum to 1.0)
  static const _strategyWeight = 0.35;
  static const _consistencyWeight = 0.35;
  static const _emotionalWeight = 0.30;

  ConfidenceCalculator(this._behaviorRepo);

  /// Computes the confidence score from trade history and reasons.
  ///
  /// Parameters:
  ///   [trades] — All trades, any order
  ///   [reasons] — Trade reasons (decrypted), keyed by trade ID
  ///   [emotionalStates] — Decoded emotional states, keyed by trade ID
  ///
  /// Returns the computed score AND persists it to the ConfidenceMeter table.
  Future<ConfidenceScoreResult> compute({
    required List<Trade> trades,
    required Map<String, String?> reasons,      // tradeId → reason text
    required Map<String, String?> emotionalStates, // tradeId → emotion label
  }) async {
    if (trades.isEmpty) {
      return const ConfidenceScoreResult(
        compositeScore: 50,
        strategyAdherence: 50,
        consistency: 50,
        emotionalStability: 50,
      );
    }

    final strategy = _computeStrategyAdherence(trades, reasons);
    final consistency = _computeConsistency(trades);
    final emotional = _computeEmotionalStability(trades, emotionalStates);

    final composite = (strategy * _strategyWeight +
                      consistency * _consistencyWeight +
                      emotional * _emotionalWeight)
        .clamp(0, 100)
        .roundToDouble();

    // Persist to DB
    await _behaviorRepo.saveConfidenceSnapshot(
      score: composite,
      strategyAdherence: strategy,
      consistency: consistency,
      emotionalStability: emotional,
    );

    return ConfidenceScoreResult(
      compositeScore: composite,
      strategyAdherence: strategy,
      consistency: consistency,
      emotionalStability: emotional,
    );
  }

  /// Strategy Adherence: What percentage of trades have recorded reasons?
  /// Trades with documented reasoning score higher.
  double _computeStrategyAdherence(
    List<Trade> trades,
    Map<String, String?> reasons,
  ) {
    if (trades.isEmpty) return 50;

    int withReason = 0;
    int withSubstantialReason = 0;

    for (final trade in trades) {
      final reason = reasons[trade.id];
      if (reason != null && reason.isNotEmpty) {
        withReason++;
        // A "substantial" reason is one with more than 10 characters
        if (reason.length > 10) {
          withSubstantialReason++;
        }
      }
    }

    // Base: % of trades with any reason
    final baseScore = (withReason / trades.length) * 70;
    // Bonus: % of reasons that are substantial
    final bonusScore = withReason > 0
        ? (withSubstantialReason / withReason) * 30
        : 0.0;

    return (baseScore + bonusScore).clamp(0, 100);
  }

  /// Consistency: How regular is the trading cadence?
  /// Measures standard deviation of inter-trade gaps.
  /// Lower variance = higher score.
  double _computeConsistency(List<Trade> trades) {
    if (trades.length < 2) return 50;

    // Sort by date
    final sorted = List.of(trades)
      ..sort((a, b) => a.tradeTimestamp.compareTo(b.tradeTimestamp));

    // Compute gaps between consecutive trades
    final gaps = <int>[];
    for (int i = 1; i < sorted.length; i++) {
      gaps.add(
        sorted[i].tradeTimestamp.difference(sorted[i - 1].tradeTimestamp).inDays,
      );
    }

    if (gaps.isEmpty) return 50;

    // Compute coefficient of variation (CV)
    final mean = gaps.reduce((a, b) => a + b) / gaps.length;
    if (mean <= 0) return 100;

    final variance = gaps.fold<double>(
      0, (sum, gap) => sum + pow(gap - mean, 2),
    ) / gaps.length;
    final stdDev = sqrt(variance);
    final cv = stdDev / mean; // coefficient of variation

    // Lower CV → more consistent → higher score
    // CV = 0 → perfect consistency → 100
    // CV >= 2 → very inconsistent → ~20
    final score = (100 * (1 - (cv / 2).clamp(0, 0.8))).clamp(0, 100);
    return score.roundToDouble();
  }

  /// Emotional Stability: What percentage of trades were made in calm/
  /// disciplined emotional states (vs fearful/excited/panic)?
  double _computeEmotionalStability(
    List<Trade> trades,
    Map<String, String?> emotionalStates,
  ) {
    if (trades.isEmpty) return 50;

    int total = 0;
    int stable = 0;

    const stableStates = {'calm', 'disciplined', 'cautious'};

    for (final trade in trades) {
      final state = emotionalStates[trade.id];
      if (state != null) {
        total++;
        if (stableStates.contains(state.toLowerCase())) {
          stable++;
        }
      }
    }

    if (total == 0) {
      // No emotional data recorded → neutral score
      return 60;
    }

    return ((stable / total) * 100).clamp(0, 100).roundToDouble();
  }
}
