import '../../database/enums.dart';
import 'rule_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Allocation Drift Rule
//
// Fires when any single holding exceeds a configurable percentage of total
// portfolio invested value. This is a concentration risk signal.
//
// Deterministic: weight = holding.investedValue / sum(all investedValues)
// ─────────────────────────────────────────────────────────────────────────────

class AllocationDriftRule extends IntelligenceRule {
  /// Maximum allowed allocation percentage for a single holding.
  final double maxAllocationPercent;

  AllocationDriftRule({this.maxAllocationPercent = 25.0});

  @override
  String get ruleId => 'ALLOCATION_DRIFT';

  @override
  String get displayName => 'Allocation Drift';

  @override
  List<RuleAlert> evaluate(RuleContext context) {
    final holdings = context.holdings;
    if (holdings.isEmpty) return [];

    final totalInvested = holdings.fold<double>(
      0, (sum, h) => sum + h.investedValue,
    );
    if (totalInvested <= 0) return [];

    final alerts = <RuleAlert>[];
    for (final holding in holdings) {
      final weight = (holding.investedValue / totalInvested) * 100;
      if (weight > maxAllocationPercent) {
        alerts.add(RuleAlert(
          ruleId: ruleId,
          severity: weight > 40
              ? AlertSeverity.critical
              : AlertSeverity.warning,
          title: '${holding.instrumentSymbol} is ${weight.toStringAsFixed(1)}% of your portfolio',
          description:
              '${holding.instrumentSymbol} has an allocation of '
              '${weight.toStringAsFixed(1)}%, which exceeds the '
              '${maxAllocationPercent.toStringAsFixed(0)}% threshold. '
              'High concentration in a single holding increases risk.',
          triggerData: {
            'symbol': holding.instrumentSymbol,
            'allocation_percent': double.parse(weight.toStringAsFixed(2)),
            'invested_value': holding.investedValue,
            'total_portfolio_value': totalInvested,
            'threshold_percent': maxAllocationPercent,
          },
          confidence: 100, // fully deterministic
          relatedInstrument: holding.instrumentSymbol,
        ));
      }
    }

    return alerts;
  }
}
