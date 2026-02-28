import '../../database/enums.dart';
import 'rule_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dip-Buy Pattern Rule
//
// Detects repeated buy actions on instruments that have recently declined
// in average price. Pattern: multiple buys on the same symbol within a
// short window where each buy is at a lower price than the previous.
//
// This is an observation, not advice. It detects a behavioral pattern
// (averaging down) that the user may want to be aware of.
//
// Deterministic: compare sequential buy prices per symbol
// ─────────────────────────────────────────────────────────────────────────────

class DipBuyPatternRule extends IntelligenceRule {
  /// Minimum number of consecutive declining buys to trigger.
  final int minConsecutiveDips;

  /// Rolling window in days to look for the pattern.
  final int windowDays;

  DipBuyPatternRule({
    this.minConsecutiveDips = 3,
    this.windowDays = 30,
  });

  @override
  String get ruleId => 'DIP_BUY_PATTERN';

  @override
  String get displayName => 'Dip-Buy Pattern';

  @override
  List<RuleAlert> evaluate(RuleContext context) {
    if (context.trades.isEmpty) return [];

    final cutoff = DateTime.now().toUtc().subtract(Duration(days: windowDays));

    // Group BUY trades by symbol within the window, sorted by date
    final buysBySymbol = <String, List<_TradePoint>>{};
    for (final trade in context.trades) {
      if (trade.tradeType != TradeType.buy) continue;
      if (trade.tradeTimestamp.isBefore(cutoff)) continue;

      buysBySymbol.putIfAbsent(trade.instrumentSymbol, () => []);
      buysBySymbol[trade.instrumentSymbol]!.add(_TradePoint(
        price: trade.pricePerUnit,
        date: trade.tradeTimestamp,
      ));
    }

    final alerts = <RuleAlert>[];

    for (final entry in buysBySymbol.entries) {
      final symbol = entry.key;
      final buys = entry.value
        ..sort((a, b) => a.date.compareTo(b.date));

      if (buys.length < minConsecutiveDips) continue;

      // Count consecutive declining buys
      int consecutiveDips = 1;
      int maxConsecutive = 1;
      double firstDipPrice = buys.first.price;
      double lastDipPrice = buys.first.price;

      for (int i = 1; i < buys.length; i++) {
        if (buys[i].price < buys[i - 1].price) {
          consecutiveDips++;
          lastDipPrice = buys[i].price;
          if (consecutiveDips > maxConsecutive) {
            maxConsecutive = consecutiveDips;
          }
        } else {
          firstDipPrice = buys[i].price;
          consecutiveDips = 1;
        }
      }

      if (maxConsecutive >= minConsecutiveDips) {
        final totalDecline = ((firstDipPrice - lastDipPrice) / firstDipPrice * 100);
        alerts.add(RuleAlert(
          ruleId: ruleId,
          severity: maxConsecutive >= 5
              ? AlertSeverity.warning
              : AlertSeverity.info,
          title: '$symbol: $maxConsecutive consecutive dip-buys detected',
          description:
              'You made $maxConsecutive consecutive buy orders on $symbol '
              'within $windowDays days, each at a lower price than the '
              'previous. Total price decline across these buys: '
              '${totalDecline.toStringAsFixed(1)}%. This pattern is '
              'known as "averaging down" — it\'s neither good nor bad, '
              'but worth being aware of.',
          triggerData: {
            'symbol': symbol,
            'consecutive_dips': maxConsecutive,
            'first_dip_price': firstDipPrice,
            'last_dip_price': lastDipPrice,
            'total_decline_percent': double.parse(totalDecline.toStringAsFixed(2)),
            'window_days': windowDays,
            'total_buys_in_window': buys.length,
          },
          confidence: 95,
          relatedInstrument: symbol,
        ));
      }
    }

    return alerts;
  }
}

class _TradePoint {
  final double price;
  final DateTime date;
  const _TradePoint({required this.price, required this.date});
}
