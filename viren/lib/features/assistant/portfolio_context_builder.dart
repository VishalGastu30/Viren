import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/database/enums.dart' as db_enums;

class PortfolioContextBuilder {
  final AppDatabase db;
  PortfolioContextBuilder(this.db);

  Future<String> build() async {
    try {
      // Fetch all holdings
      final holdings = await db.select(db.holdings).get();

      // Fetch all trades
      final trades = await (db.select(db.trades)
            ..orderBy([(t) => OrderingTerm.desc(t.tradeTimestamp)]))
          .get();

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (holdings.isEmpty && trades.isEmpty) {
        return '''PORTFOLIO CONTEXT (today: $today):
Holdings: None yet.
Summary: No trades recorded yet.
Recent trades: None.''';
      }

      // ── Holdings lines ──
      final holdingLines = StringBuffer();
      double totalInvested = 0;
      for (final h in holdings) {
        final daysHeld = DateTime.now().difference(h.lastUpdated).inDays;
        holdingLines.writeln(
            '- ${h.instrumentSymbol}: ${h.totalQuantity.toStringAsFixed(0)} units, avg cost ₹${h.averagePrice.toStringAsFixed(2)}, invested ₹${h.investedValue.toStringAsFixed(2)}, held ~$daysHeld days');
        totalInvested += h.investedValue;
      }

      // ── Charges ──
      double totalCharges = 0;
      for (final t in trades) {
        totalCharges +=
            (t.brokerage ?? 0) + (t.stt ?? 0) + (t.gst ?? 0) + (t.otherLevies ?? 0);
      }

      // ── Trade count ──
      final tradeCount = trades.length;

      // ── First / last trade dates ──
      String firstTradeDate = 'N/A';
      String daysSinceLastTrade = 'N/A';
      if (trades.isNotEmpty) {
        final sorted = List<Trade>.from(trades)
          ..sort((a, b) => a.tradeTimestamp.compareTo(b.tradeTimestamp));
        firstTradeDate =
            DateFormat('dd-MMM-yyyy').format(sorted.first.tradeTimestamp);
        daysSinceLastTrade =
            DateTime.now().difference(sorted.last.tradeTimestamp).inDays.toString();
      }

      // ── Recent trades (last 5) ──
      final recentTradeLines = StringBuffer();
      final recent = trades.take(5);
      for (final t in recent) {
        final typeStr =
            t.tradeType == db_enums.TradeType.buy ? 'BUY' : 'SELL';
        final date = DateFormat('dd-MMM-yyyy').format(t.tradeTimestamp);
        recentTradeLines.writeln(
            '- $date: $typeStr ${t.instrumentSymbol} ${t.quantity.toStringAsFixed(0)} @ ₹${t.pricePerUnit.toStringAsFixed(2)}');
      }

      return '''PORTFOLIO CONTEXT (today: $today):

Holdings:
$holdingLines
Summary:
- Total invested: ₹${totalInvested.toStringAsFixed(2)}
- Total charges paid: ₹${totalCharges.toStringAsFixed(2)}
- Total trades: $tradeCount
- First trade: $firstTradeDate
- Days since last trade: $daysSinceLastTrade

Recent trades (last 5):
$recentTradeLines''';
    } catch (e) {
      return '''
PORTFOLIO CONTEXT:
No portfolio data available yet. The user has not scanned any emails or entered trades.
''';
    }
  }
}
