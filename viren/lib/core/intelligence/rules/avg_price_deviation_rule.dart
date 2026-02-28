import '../../database/enums.dart';
import 'rule_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Average Price Deviation Rule
//
// Fires when the latest trade's price deviates significantly from the
// volume-weighted average price (VWAP) of that holding.
//
// Deterministic: deviation = |tradePrice - avgPrice| / avgPrice × 100
// ─────────────────────────────────────────────────────────────────────────────

class AvgPriceDeviationRule extends IntelligenceRule {
  /// Minimum deviation percentage to trigger alert.
  final double deviationThresholdPercent;

  AvgPriceDeviationRule({this.deviationThresholdPercent = 15.0});

  @override
  String get ruleId => 'AVG_PRICE_DEVIATION';

  @override
  String get displayName => 'Average Price Deviation';

  @override
  List<RuleAlert> evaluate(RuleContext context) {
    final alerts = <RuleAlert>[];
    if (context.trades.isEmpty || context.holdings.isEmpty) return alerts;

    // Build a map of symbol → average price from holdings
    final avgPrices = <String, double>{};
    for (final h in context.holdings) {
      if (h.averagePrice > 0) {
        avgPrices[h.instrumentSymbol] = h.averagePrice;
      }
    }

    // Check the most recent trade per symbol
    final checkedSymbols = <String>{};
    for (final trade in context.trades) {
      final symbol = trade.instrumentSymbol;
      if (checkedSymbols.contains(symbol)) continue;
      checkedSymbols.add(symbol);

      final avg = avgPrices[symbol];
      if (avg == null || avg <= 0) continue;

      final deviation = ((trade.pricePerUnit - avg) / avg) * 100;
      final absDeviation = deviation.abs();

      if (absDeviation > deviationThresholdPercent) {
        final direction = deviation > 0 ? 'above' : 'below';
        alerts.add(RuleAlert(
          ruleId: ruleId,
          severity: absDeviation > 30
              ? AlertSeverity.critical
              : AlertSeverity.warning,
          title: '$symbol: Last trade ${absDeviation.toStringAsFixed(1)}% $direction average',
          description:
              'Your latest $symbol trade was at ₹${trade.pricePerUnit.toStringAsFixed(2)}, '
              'which is ${absDeviation.toStringAsFixed(1)}% $direction your '
              'average price of ₹${avg.toStringAsFixed(2)}.',
          triggerData: {
            'symbol': symbol,
            'trade_price': trade.pricePerUnit,
            'average_price': avg,
            'deviation_percent': double.parse(deviation.toStringAsFixed(2)),
            'threshold_percent': deviationThresholdPercent,
            'trade_date': trade.tradeTimestamp.toIso8601String(),
          },
          confidence: 100,
          relatedInstrument: symbol,
        ));
      }
    }

    return alerts;
  }
}
