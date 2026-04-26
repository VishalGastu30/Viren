import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart' hide PortfolioSnapshot;
import '../../core/market/nse_price_service.dart';
import 'portfolio_analytics_engine.dart';

class _HoldingMetric {
  final String symbol;
  final double invested;
  final double? currentVal;
  final double? pnl;
  final double? ret;
  final int qty;
  final double avgPrice;
  final double? cmp;

  _HoldingMetric({
    required this.symbol,
    required this.invested,
    required this.qty,
    required this.avgPrice,
    this.currentVal,
    this.pnl,
    this.ret,
    this.cmp,
  });
}

/// Builds an ultra-compact portfolio context matrix for the LLM.
/// This acts as a "Math Matrix", providing pre-sorted leaderboards so the LLM
/// never has to do negative float math.
class PortfolioContextBuilder {
  final AppDatabase db;
  PortfolioContextBuilder(this.db);

  /// Builds the matrix from an existing snapshot to ensure 100% data consistency
  /// and avoid fetching prices twice.
  String buildFromSnapshot(PortfolioSnapshot snap) {
    if (snap.isEmpty && snap.trades.isEmpty) {
      return 'DATE:${snap.today}|PORTFOLIO:EMPTY';
    }

    if (snap.isEmpty) {
      return 'DATE:${snap.today}|PORTFOLIO:NO_ACTIVE_HOLDINGS';
    }

    final pnlSign = snap.totalPnL >= 0 ? '+' : '-';
    final pnlAbs = snap.totalPnL.abs();

    final buf = StringBuffer();
    buf.writeln('=== [PORTFOLIO MATH MATRIX] ===');
    buf.writeln('WARNING: Do NOT recalculate these numbers. Use these exact rankings to answer questions.');
    buf.writeln('Total Invested: ₹${snap.totalInvested.toStringAsFixed(2)}');
    buf.writeln('Current Value: ₹${snap.totalCurrentValue.toStringAsFixed(2)}');
    buf.writeln('Total P&L: $pnlSign₹${pnlAbs.toStringAsFixed(2)} (${snap.totalReturnPct >= 0 ? '+' : ''}${snap.totalReturnPct.toStringAsFixed(2)}%)');
    buf.writeln();

    final withPrices = snap.holdings.where((h) => h.hasPriceData).toList();

    if (withPrices.isNotEmpty) {
      final sortedByRet = List<HoldingAnalysis>.from(withPrices)
        ..sort((a, b) => b.returnPct!.compareTo(a.returnPct!));

      buf.writeln('--- RANKING: BY RETURN PERCENTAGE ---');
      buf.writeln('1. ${sortedByRet.first.symbol} (${sortedByRet.first.returnStr}) [TOP PERFORMER]');
      if (sortedByRet.length > 2) {
        for (int i = 1; i < sortedByRet.length - 1; i++) {
          buf.writeln('${i + 1}. ${sortedByRet[i].symbol} (${sortedByRet[i].returnStr})');
        }
      }
      if (sortedByRet.length > 1) {
        buf.writeln('${sortedByRet.length}. ${sortedByRet.last.symbol} (${sortedByRet.last.returnStr}) [WORST PERFORMER]');
      }
      buf.writeln();

      final sortedByPnl = List<HoldingAnalysis>.from(withPrices)
        ..sort((a, b) => b.unrealisedPnL!.compareTo(a.unrealisedPnL!));

      buf.writeln('--- RANKING: BY ABSOLUTE PROFIT/LOSS (₹) ---');
      buf.writeln('1. ${sortedByPnl.first.symbol} (${sortedByPnl.first.pnlStr}) [HIGHEST PROFIT]');
      if (sortedByPnl.length > 2) {
        for (int i = 1; i < sortedByPnl.length - 1; i++) {
          buf.writeln('${i + 1}. ${sortedByPnl[i].symbol} (${sortedByPnl[i].pnlStr})');
        }
      }
      if (sortedByPnl.length > 1) {
        buf.writeln('${sortedByPnl.length}. ${sortedByPnl.last.symbol} (${sortedByPnl.last.pnlStr}) [BIGGEST LOSS]');
      }
      buf.writeln();
    }

    final sortedByWeight = List<HoldingAnalysis>.from(snap.holdings)
      ..sort((a, b) => b.invested.compareTo(a.invested));

    buf.writeln('--- PORTFOLIO ALLOCATION ---');
    buf.writeln('1. ${sortedByWeight.first.symbol} (₹${sortedByWeight.first.invested.toStringAsFixed(2)} invested) [LARGEST POSITION]');
    for (int i = 1; i < sortedByWeight.length; i++) {
      buf.writeln('${i + 1}. ${sortedByWeight[i].symbol} (₹${sortedByWeight[i].invested.toStringAsFixed(2)})');
    }
    buf.writeln('===============================');

    return buf.toString();
  }

  Future<String> build() async {
    try {
      final holdings = await db.select(db.holdings).get();
      final trades = await (db.select(db.trades)
            ..orderBy([(t) => OrderingTerm.desc(t.tradeTimestamp)]))
          .get();

      final now = DateTime.now();
      final todayStr = DateFormat('dd MMM yyyy').format(now);

      if (holdings.isEmpty && trades.isEmpty) {
        return 'DATE:$todayStr|PORTFOLIO:EMPTY';
      }

      final activeHoldings = holdings
          .where((h) => h.totalQuantity > 0.001)
          .toList();

      if (activeHoldings.isEmpty) {
        return 'DATE:$todayStr|PORTFOLIO:NO_ACTIVE_HOLDINGS';
      }

      final symbols = activeHoldings.map((h) => h.instrumentSymbol).toList();
      final prices = symbols.isNotEmpty
          ? await NsePriceService.getPrices(symbols)
          : <String, double?>{};

      double totalInvested = 0;
      double totalCurrentValue = 0;
      final metrics = <_HoldingMetric>[];

      for (final h in activeHoldings) {
        final symbol = h.instrumentSymbol.toUpperCase();
        final qty = h.totalQuantity;
        final invested = h.investedValue;
        final cmp = prices[symbol];

        totalInvested += invested;

        double? cv, pnl, ret;
        if (cmp != null) {
          cv = cmp * qty;
          totalCurrentValue += cv;
          pnl = cv - invested;
          ret = invested > 0 ? (pnl / invested) * 100 : null;
        } else {
          totalCurrentValue += invested;
        }

        metrics.add(_HoldingMetric(
          symbol: symbol,
          invested: invested,
          qty: qty.round(),
          avgPrice: h.averagePrice,
          currentVal: cv,
          pnl: pnl,
          ret: ret,
          cmp: cmp,
        ));
      }

      final overallPnl = totalCurrentValue - totalInvested;
      final overallPct = totalInvested > 0 ? (overallPnl / totalInvested) * 100 : 0;
      final pnlSign = overallPnl >= 0 ? '+' : '-';
      final pnlAbs = overallPnl.abs();

      // Sort logic
      final sortedByRet = List.of(metrics)
        ..removeWhere((m) => m.ret == null)
        ..sort((a, b) => b.ret!.compareTo(a.ret!));

      final sortedByPnl = List.of(metrics)
        ..removeWhere((m) => m.pnl == null)
        ..sort((a, b) => b.pnl!.compareTo(a.pnl!));

      final sortedByWeight = List.of(metrics)
        ..sort((a, b) => b.invested.compareTo(a.invested));

      final buf = StringBuffer();
      buf.writeln('=== [PM.v3] ===');
      buf.writeln('WARNING: Do NOT recalculate these numbers. Use these exact rankings to answer questions.');
      buf.writeln('Total Invested: ₹${totalInvested.toStringAsFixed(2)}');
      buf.writeln('Current Value: ₹${totalCurrentValue.toStringAsFixed(2)}');
      buf.writeln('Total P&L: $pnlSign₹${pnlAbs.toStringAsFixed(2)} (${overallPct >= 0 ? '+' : ''}${overallPct.toStringAsFixed(2)}%) [OVERALL since purchase, NOT today]');
      buf.writeln();

      if (sortedByRet.isNotEmpty) {
        buf.writeln('--- RANKING: BY RETURN PERCENTAGE ---');
        buf.writeln('1. ${sortedByRet.first.symbol} (${sortedByRet.first.ret! >= 0 ? '+' : ''}${sortedByRet.first.ret!.toStringAsFixed(2)}%) [TOP PERFORMER]');
        if (sortedByRet.length > 2) {
          for (int i = 1; i < sortedByRet.length - 1; i++) {
            buf.writeln('${i + 1}. ${sortedByRet[i].symbol} (${sortedByRet[i].ret! >= 0 ? '+' : ''}${sortedByRet[i].ret!.toStringAsFixed(2)}%)');
          }
        }
        if (sortedByRet.length > 1) {
          buf.writeln('${sortedByRet.length}. ${sortedByRet.last.symbol} (${sortedByRet.last.ret! >= 0 ? '+' : ''}${sortedByRet.last.ret!.toStringAsFixed(2)}%) [WORST PERFORMER]');
        }
        buf.writeln();
      }

      if (sortedByPnl.isNotEmpty) {
        buf.writeln('--- RANKING: BY ABSOLUTE PROFIT/LOSS (₹) ---');
        buf.writeln('1. ${sortedByPnl.first.symbol} (${sortedByPnl.first.pnl! >= 0 ? '+' : '-'}₹${sortedByPnl.first.pnl!.abs().toStringAsFixed(2)}) [HIGHEST PROFIT]');
        if (sortedByPnl.length > 2) {
          for (int i = 1; i < sortedByPnl.length - 1; i++) {
            buf.writeln('${i + 1}. ${sortedByPnl[i].symbol} (${sortedByPnl[i].pnl! >= 0 ? '+' : '-'}₹${sortedByPnl[i].pnl!.abs().toStringAsFixed(2)})');
          }
        }
        if (sortedByPnl.length > 1) {
          buf.writeln('${sortedByPnl.length}. ${sortedByPnl.last.symbol} (${sortedByPnl.last.pnl! >= 0 ? '+' : '-'}₹${sortedByPnl.last.pnl!.abs().toStringAsFixed(2)}) [BIGGEST LOSS]');
        }
        buf.writeln();
      }

      if (sortedByWeight.isNotEmpty) {
        buf.writeln('--- RANKING: BY CAPITAL DEPLOYED (WEIGHT) ---');
        buf.writeln('1. ${sortedByWeight.first.symbol} (₹${sortedByWeight.first.invested.toStringAsFixed(2)}) [LARGEST HOLDING]');
        if (sortedByWeight.length > 2) {
          for (int i = 1; i < sortedByWeight.length - 1; i++) {
            buf.writeln('${i + 1}. ${sortedByWeight[i].symbol} (₹${sortedByWeight[i].invested.toStringAsFixed(2)})');
          }
        }
        if (sortedByWeight.length > 1) {
          buf.writeln('${sortedByWeight.length}. ${sortedByWeight.last.symbol} (₹${sortedByWeight.last.invested.toStringAsFixed(2)}) [SMALLEST HOLDING]');
        }
        buf.writeln();
      }

      buf.writeln('--- RAW HOLDINGS DATA ---');
      for (final m in metrics) {
        final retStr = m.ret != null ? '${m.ret! >= 0 ? '+' : ''}${m.ret!.toStringAsFixed(2)}%' : 'no price';
        final pnlStr = m.pnl != null ? '${m.pnl! >= 0 ? '+' : '-'}₹${m.pnl!.abs().toStringAsFixed(2)}' : '';
        buf.writeln('${m.symbol}: ${m.qty}u @₹${m.avgPrice.toStringAsFixed(2)} | CMP ₹${m.cmp?.toStringAsFixed(2) ?? 'NA'} | $pnlStr $retStr [OVERALL]');
      }
      buf.writeln('===================================');

      return buf.toString().trim();
    } catch (e) {
      return 'PORTFOLIO:ERROR';
    }
  }
}
