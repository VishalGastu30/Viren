import '../../database/enums.dart';
import 'rule_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Overtrading Rule
//
// Fires when trade frequency in a rolling window exceeds a threshold.
// Detects hyperactive trading that may indicate emotional decision-making.
//
// Deterministic: count trades in each rolling N-day window
// ─────────────────────────────────────────────────────────────────────────────

class OvertradingRule extends IntelligenceRule {
  /// Rolling window size in days.
  final int windowDays;

  /// Maximum trades allowed in the window before alerting.
  final int maxTradesInWindow;

  OvertradingRule({
    this.windowDays = 7,
    this.maxTradesInWindow = 10,
  });

  @override
  String get ruleId => 'OVERTRADING';

  @override
  String get displayName => 'Overtrading Detection';

  @override
  List<RuleAlert> evaluate(RuleContext context) {
    if (context.trades.isEmpty) return [];

    // Sort trades by timestamp ascending
    final sorted = List.of(context.trades)
      ..sort((a, b) => a.tradeTimestamp.compareTo(b.tradeTimestamp));

    // Sliding window: find any window of `windowDays` where trade count
    // exceeds the threshold
    final alerts = <RuleAlert>[];
    final windowDuration = Duration(days: windowDays);

    int windowStart = 0;
    for (int windowEnd = 0; windowEnd < sorted.length; windowEnd++) {
      // Move start forward until within window
      while (windowStart < windowEnd &&
          sorted[windowEnd].tradeTimestamp
              .difference(sorted[windowStart].tradeTimestamp) > windowDuration) {
        windowStart++;
      }

      final count = windowEnd - windowStart + 1;
      if (count > maxTradesInWindow) {
        final startDate = sorted[windowStart].tradeTimestamp;
        final endDate = sorted[windowEnd].tradeTimestamp;

        // Only alert once per peak
        alerts.add(RuleAlert(
          ruleId: ruleId,
          severity: count > maxTradesInWindow * 2
              ? AlertSeverity.critical
              : AlertSeverity.warning,
          title: '$count trades in $windowDays days',
          description:
              'You made $count trades between '
              '${_formatDate(startDate)} and ${_formatDate(endDate)}, '
              'exceeding the $maxTradesInWindow-trade threshold for a '
              '$windowDays-day window. High-frequency trading may '
              'indicate emotional decision-making.',
          triggerData: {
            'trade_count': count,
            'window_days': windowDays,
            'threshold': maxTradesInWindow,
            'window_start': startDate.toIso8601String(),
            'window_end': endDate.toIso8601String(),
          },
          confidence: 100,
        ));

        // Don't generate duplicate alerts for overlapping windows
        break;
      }
    }

    return alerts;
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
