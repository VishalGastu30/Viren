import '../../database/enums.dart';
import 'rule_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Inactivity Rule
//
// Fires when no trades have been recorded for N consecutive days.
// Simple date arithmetic on the latest trade timestamp.
//
// Deterministic: gap = now - latestTradeDate
// ─────────────────────────────────────────────────────────────────────────────

class InactivityRule extends IntelligenceRule {
  /// Number of days without trades before alerting.
  final int inactivityDaysThreshold;

  InactivityRule({this.inactivityDaysThreshold = 90});

  @override
  String get ruleId => 'INACTIVITY_GAP';

  @override
  String get displayName => 'Inactivity Gap';

  @override
  List<RuleAlert> evaluate(RuleContext context) {
    if (context.trades.isEmpty) return [];

    // Find the most recent trade timestamp
    DateTime latest = context.trades.first.tradeTimestamp;
    for (final trade in context.trades) {
      if (trade.tradeTimestamp.isAfter(latest)) {
        latest = trade.tradeTimestamp;
      }
    }

    final now = context.now.toUtc();
    final gap = now.difference(latest).inDays;

    if (gap >= inactivityDaysThreshold) {
      return [
        RuleAlert(
          ruleId: ruleId,
          severity: gap > 180
              ? AlertSeverity.critical
              : AlertSeverity.info,
          title: 'No trades in $gap days',
          description:
              'Your last trade was on ${_formatDate(latest)}, '
              '$gap days ago. Long inactivity gaps may indicate '
              'disengagement or missed opportunities. This is a '
              'neutral observation, not advice.',
          triggerData: {
            'last_trade_date': latest.toIso8601String(),
            'gap_days': gap,
            'threshold_days': inactivityDaysThreshold,
          },
          confidence: 100,
        ),
      ];
    }

    return [];
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
