import 'package:viren/core/database/app_database.dart';
import 'package:viren/core/database/enums.dart';
import 'package:viren/core/intelligence/ai/ai_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Sanitizer
//
// Converts raw database entities (Trades, Metrics) into a safe format for
// passing to external/local LLMs.
//
// Rules enforced:
//   1. Strip all individual IDs, raw reasons, and emotional states.
//   2. Strip raw quantities and total values (use percentages).
//   3. Strip encryption keys or raw data prior to stats conversion.
// ─────────────────────────────────────────────────────────────────────────────

class DataSanitizer {
  
  /// Sanitizes portfolio state from raw holdings and the current score.
  static SanitizedPortfolioData sanitizePortfolio({
    required List<Holding> holdings,
    required double confidenceScore,
    required String timeRange,
  }) {
    if (holdings.isEmpty) {
      return SanitizedPortfolioData(
        totalHoldings: 0,
        totalInvestedPercent: 0.0,
        allocationPercents: {},
        confidenceScore: confidenceScore,
        timeRange: timeRange,
        aggregateStats: {'total_holdings': 0},
      );
    }

    final totalInvested = holdings.fold(0.0, (acc, h) => acc + h.investedValue);
    
    final allocation = <String, double>{};
    if (totalInvested > 0) {
      for (final h in holdings) {
        allocation[h.instrumentSymbol] = h.investedValue / totalInvested;
      }
    }

    return SanitizedPortfolioData(
      totalHoldings: holdings.length,
      totalInvestedPercent: 1.0, // Assuming 100% of tracked value is deployed
      allocationPercents: allocation,
      confidenceScore: confidenceScore,
      timeRange: timeRange,
      aggregateStats: {
        'total_holdings': holdings.length,
      },
    );
  }

  /// Extracts the relevant safe metrics from a list of BehaviorMetrics.
  static SanitizedBehaviorData sanitizeBehavior(
    List<BehaviorMetric> metrics, 
    ConfidenceMeterData? latestConfidence,
    List<Trade> trades,
  ) {
    int buys = 0, sells = 0;
    for (final t in trades) {
      if (t.tradeType == TradeType.buy) {
        buys++;
      } else {
        sells++;
      }
    }
    double buyToSellRatio = sells == 0 ? buys.toDouble() : buys / sells;
    int inactivityDays = 0;
    double tradesPerMonth = 0;

    for (final m in metrics) {
      if (m.metricType == BehaviorMetricType.overtrading) {
         tradesPerMonth = m.value; // Represented as trades/month in overtrading context
      } else if (m.metricType == BehaviorMetricType.inactivity) {
         inactivityDays = m.value.toInt();
      }
    }

    return SanitizedBehaviorData(
      tradesPerMonth: tradesPerMonth,
      buyToSellRatio: buyToSellRatio,
      consistencyScore: latestConfidence?.consistency ?? 50.0,
      strategyAdherenceScore: latestConfidence?.strategyAdherence ?? 50.0,
      emotionalStabilityScore: latestConfidence?.emotionalStability ?? 50.0,
      inactivityDays: inactivityDays,
    );
  }

  /// Sanitizes an alert into a safe insight explanation format.
  static SanitizedInsightData sanitizeInsight(Alert alert) {
    // Decodes the triggerData JSON map.
    // Removes any keys that might contain raw text reasons.
    return SanitizedInsightData(
      ruleId: alert.alertType,
      alertTitle: alert.title,
      triggerData: {"action": "auto_triggered_by_rule"}, 
      confidence: alert.confidence,
    );
  }
}
