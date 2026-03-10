import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/database/enums.dart' as db_enums;
import '../../core/market/nse_price_service.dart';

class PortfolioContextBuilder {
  final AppDatabase db;
  PortfolioContextBuilder(this.db);

  Future<String> build() async {
    try {
      final holdings = await db.select(db.holdings).get();
      final trades = await (db.select(db.trades)
            ..orderBy([(t) => OrderingTerm.desc(t.tradeTimestamp)]))
          .get();

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      if (holdings.isEmpty && trades.isEmpty) {
        return 'PORTFOLIO (today: $today): No holdings or trades recorded yet.';
      }

      // Fetch live prices for all holdings concurrently
      final symbols = holdings.map((h) => h.instrumentSymbol).toList();
      final prices = symbols.isNotEmpty
          ? await NsePriceService.getPrices(symbols)
          : <String, double?>{};

      // Build holdings lines with live data
      final holdingLines = StringBuffer();
      double totalInvested = 0;
      double totalCurrentValue = 0;
      bool hasPrices = false;

      for (final h in holdings) {
        final symbol = h.instrumentSymbol.toUpperCase();
        final qty = h.totalQuantity;
        final avgCost = h.averagePrice;
        final invested = h.investedValue;
        final cmp = prices[symbol];
        final daysHeld =
            DateTime.now().difference(h.lastUpdated).inDays;

        totalInvested += invested;

        if (cmp != null) {
          hasPrices = true;
          final currentValue = cmp * qty;
          final unrealisedGain = currentValue - invested;
          final returnPct = (unrealisedGain / invested) * 100;
          final gainSign = unrealisedGain >= 0 ? '+' : '';
          totalCurrentValue += currentValue;

          holdingLines.writeln(
            '- $symbol: ${qty.toStringAsFixed(0)} units | '
            'avg cost ₹${avgCost.toStringAsFixed(2)} | '
            'CMP ₹${cmp.toStringAsFixed(2)} | '
            'invested ₹${invested.toStringAsFixed(0)} | '
            'current ₹${currentValue.toStringAsFixed(0)} | '
            'P&L $gainSign₹${unrealisedGain.toStringAsFixed(0)} ($gainSign${returnPct.toStringAsFixed(1)}%) | '
            'held $daysHeld days',
          );
        } else {
          // No live price available — show what we have, be explicit
          holdingLines.writeln(
            '- $symbol: ${qty.toStringAsFixed(0)} units | '
            'avg cost ₹${avgCost.toStringAsFixed(2)} | '
            'CMP: unavailable (offline?) | '
            'invested ₹${invested.toStringAsFixed(0)} | '
            'held $daysHeld days',
          );
          totalCurrentValue += invested; // fallback
        }
      }

      // Charges
      double totalCharges = 0;
      for (final t in trades) {
        totalCharges += (t.brokerage ?? 0) +
            (t.stt ?? 0) +
            (t.gst ?? 0) +
            (t.otherLevies ?? 0);
      }

      // Trade summary
      final tradeCount = trades.length;
      String firstTradeDate = 'N/A';
      if (trades.isNotEmpty) {
        final sorted = List<Trade>.from(trades)
          ..sort((a, b) =>
              a.tradeTimestamp.compareTo(b.tradeTimestamp));
        firstTradeDate =
            DateFormat('dd-MMM-yyyy').format(sorted.first.tradeTimestamp);
      }

      // Recent trades (last 3 only to save tokens)
      final recentTradeLines = StringBuffer();
      for (final t in trades.take(3)) {
        final typeStr =
            t.tradeType == db_enums.TradeType.buy ? 'BUY' : 'SELL';
        final date =
            DateFormat('dd-MMM-yy').format(t.tradeTimestamp);
        recentTradeLines.writeln(
          '- $date $typeStr ${t.instrumentSymbol} '
          '${t.quantity.toStringAsFixed(0)}@₹${t.pricePerUnit.toStringAsFixed(2)}',
        );
      }

      // Portfolio summary
      final totalPnL = totalCurrentValue - totalInvested;
      final totalReturnPct =
          totalInvested > 0 ? (totalPnL / totalInvested) * 100 : 0.0;
      final pnlSign = totalPnL >= 0 ? '+' : '';

      final priceNote = hasPrices
          ? '(live prices as of $today)'
          : '(current prices unavailable — offline)';

      return '''PORTFOLIO $priceNote:

Holdings:
$holdingLines
Summary:
- Total invested: ₹${totalInvested.toStringAsFixed(0)}
- Total current value: ₹${totalCurrentValue.toStringAsFixed(0)}
- Total unrealised P&L: $pnlSign₹${totalPnL.toStringAsFixed(0)} ($pnlSign${totalReturnPct.toStringAsFixed(1)}%)
- Total charges paid: ₹${totalCharges.toStringAsFixed(0)}
- Total trades: $tradeCount (since $firstTradeDate)

Recent trades:
$recentTradeLines''';
    } catch (e) {
      return 'PORTFOLIO: Data unavailable. Error: $e';
    }
  }
}
