import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/database/enums.dart' as db_enums;
import '../../core/market/market_data_service.dart';
import '../../core/market/nse_price_service.dart';
import '../../core/intelligence/news/yahoo_quote_service.dart';

class _CompareItem {
  final String symbol;
  final double? invested;
  final double? currentValue;
  final double? cmp;
  final double? qty;
  final double? avgCost;
  final String pnlStr;
  final String returnStr;
  final String weightStr;
  final int? daysHeld;
  final bool isExternal;
  final String yahooSymbolForChart;

  _CompareItem({
    required this.symbol,
    required this.invested,
    required this.currentValue,
    required this.cmp,
    required this.qty,
    required this.avgCost,
    required this.pnlStr,
    required this.returnStr,
    required this.weightStr,
    required this.daysHeld,
    required this.isExternal,
    required this.yahooSymbolForChart,
  });
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class HoldingAnalysis {
  final String symbol;
  final double qty;
  final double avgCost;
  final double invested;
  final double? cmp;
  final double? currentValue;
  final double? unrealisedPnL;
  final double? returnPct;
  final int daysHeld;
  final double portfolioWeight; // % of total portfolio value
  final double? dayChangePercent;

  const HoldingAnalysis({
    required this.symbol,
    required this.qty,
    required this.avgCost,
    required this.invested,
    required this.daysHeld,
    required this.portfolioWeight,
    this.cmp,
    this.currentValue,
    this.unrealisedPnL,
    this.returnPct,
    this.dayChangePercent,
  });

  bool get hasPriceData => cmp != null;
  bool get isProfitable => (unrealisedPnL ?? 0) >= 0;

  String get pnlStr {
    if (unrealisedPnL == null) return 'N/A';
    final sign = unrealisedPnL! >= 0 ? '+' : '-';
    return '$sign₹${unrealisedPnL!.abs().toStringAsFixed(2)}';
  }

  String get returnStr {
    if (returnPct == null) return 'N/A';
    final sign = returnPct! >= 0 ? '+' : '';
    return '$sign${returnPct!.toStringAsFixed(2)}%';
  }

  String get weightStr => '${portfolioWeight.toStringAsFixed(2)}%';
}

class PortfolioSnapshot {
  final List<HoldingAnalysis> holdings;
  final double totalInvested;
  final double totalCurrentValue;
  final double totalPnL;
  final double totalReturnPct;
  final double totalBrokerage;
  final double totalStt;
  final double totalGst;
  final double totalOtherLevies;
  final double totalCharges;
  final int totalTrades;
  final String firstTradeDate;
  final bool hasPriceData;
  final String today;
  final double? xirr;
  final List<Trade> trades;

  // Pre-computed rankings — guaranteed correct math
  final HoldingAnalysis? bestByReturn;
  final HoldingAnalysis? worstByReturn;
  final HoldingAnalysis? bestByAbsoluteProfit;
  final HoldingAnalysis? largestByWeight;
  final int profitableCount;

  const PortfolioSnapshot({
    required this.holdings,
    required this.totalInvested,
    required this.totalCurrentValue,
    required this.totalPnL,
    required this.totalReturnPct,
    required this.totalBrokerage,
    required this.totalStt,
    required this.totalGst,
    required this.totalOtherLevies,
    required this.totalCharges,
    required this.totalTrades,
    required this.firstTradeDate,
    required this.hasPriceData,
    required this.today,
    required this.profitableCount,
    this.bestByReturn,
    this.worstByReturn,
    this.bestByAbsoluteProfit,
    this.largestByWeight,
    this.xirr,
    this.trades = const [],
  });

  bool get isEmpty => holdings.isEmpty;

  String get pnlStr {
    final sign = totalPnL >= 0 ? '+' : '-';
    return '$sign₹${totalPnL.abs().toStringAsFixed(2)}';
  }

  String get returnStr {
    final sign = totalReturnPct >= 0 ? '+' : '';
    return '$sign${totalReturnPct.toStringAsFixed(2)}%';
  }
}

// ─── Question Intent ──────────────────────────────────────────────────────────

enum QuestionIntent {
  bestPerformer,
  worstPerformer,
  absoluteProfit,
  totalReturn,
  portfolioSummary,
  biggestPosition,
  concentration,
  diversification,
  charges,
  tradeHistory,
  daysHeld,
  whatCanYouDo,
  comparison,
  specificHolding,  // "how is ITC" — per-stock query
  general, // not portfolio-specific — let model answer freely
}

// ─── XIRR Calculator ──────────────────────────────────────────────────────────

class XirrCalc {
  static double? calculate(
      List<({double amount, DateTime date})> cashflows) {
    if (cashflows.length < 2) return null;
    try {
      double rate = 0.1;
      const maxIter = 100;
      const tol = 1e-6;
      final t0 = cashflows.first.date;
      for (int i = 0; i < maxIter; i++) {
        double f = 0;
        double df = 0;
        for (final cf in cashflows) {
          final t = cf.date.difference(t0).inDays / 365.0;
          final pow = math.pow(1 + rate, t);
          f += cf.amount / pow;
          df += -t * cf.amount / (pow * (1 + rate));
        }
        if (df.abs() < tol) break;
        final newRate = rate - f / df;
        if ((newRate - rate).abs() < tol) return newRate * 100;
        rate = newRate;
        if (rate <= -1) return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// ─── Analytics Engine ─────────────────────────────────────────────────────────

class PortfolioAnalyticsEngine {
  final AppDatabase db;
  PortfolioAnalyticsEngine(this.db);

  // ── Detect intent from user message ────────────────────────────────────────
  static QuestionIntent detectIntent(String message, {List<HoldingAnalysis>? holdings}) {
    final m = message.toLowerCase();

    // What can you do — check before portfolio questions
    if (_has(m, ['what can you do', 'what do you do', 'help me', 'capabilities',
        'what are you', 'who are you', 'how can you help'])) {
      return QuestionIntent.whatCanYouDo;
    }

    // Specific holding query — "how is ITC", "tell me about GOLDBEES"
    if (holdings != null && holdings.isNotEmpty) {
      for (final h in holdings) {
        if (m.contains(h.symbol.toLowerCase())) {
          return QuestionIntent.specificHolding;
        }
      }
    }

    // Best performer
    if (_has(m, ['best', 'top', 'highest return', 'most profit', 'performing best',
        'best return', 'leading']) && !_has(m, ['compare', 'vs', 'versus'])) {
      return QuestionIntent.bestPerformer;
    }

    // Worst performer
    if (_has(m, ['worst', 'lowest', 'underperform', 'losing', 'most loss',
        'drag', 'weakest'])) {
      return QuestionIntent.worstPerformer;
    }

    // Absolute profit
    if (_has(m, ['most money', 'absolute', 'rupee gain', 'highest profit',
        'largest gain', 'maximum profit', 'most rupee'])) {
      return QuestionIntent.absoluteProfit;
    }

    // Total return / overall portfolio
    if (_has(m, ['total return', 'overall', 'portfolio return', 'how am i doing',
        'total profit', 'total gain', 'net profit', 'portfolio value'])) {
      return QuestionIntent.totalReturn;
    }

    // Portfolio summary / granular breakdown
    if (_has(m, ['summary', 'overview', 'all holdings', 'full portfolio',
        'everything', 'show all', 'list all', 'granular', 'breakdown',
        'total invested'])) {
      return QuestionIntent.portfolioSummary;
    }

    // Biggest position
    if (_has(m, ['biggest', 'largest position', 'most invested', 'highest allocation',
        'most capital', 'biggest position'])) {
      return QuestionIntent.biggestPosition;
    }

    // Concentration (but NOT generic 'risk' — that goes to general for concept questions)
    if (_has(m, ['concentrated', 'concentration', 'overweight',
        'dependent', 'exposure'])) {
      return QuestionIntent.concentration;
    }

    // Diversification
    if (_has(m, ['diversif', 'spread', 'sector', 'allocation', 'balanced',
        'distribution'])) {
      return QuestionIntent.diversification;
    }

    // Charges
    if (_has(m, ['charge', 'brokerage', 'stt', 'fee', 'expense',
        'paid in charges'])) {
      return QuestionIntent.charges;
    }

    // Trade history
    if (_has(m, ['trade history', 'when did', 'first trade', 'bought',
        'purchased', 'sold'])) {
      return QuestionIntent.tradeHistory;
    }

    // Days held
    if (_has(m, ['how long', 'days held', 'since when',
        'holding period'])) {
      return QuestionIntent.daysHeld;
    }

    // Comparison
    if (_has(m, ['compare', 'vs', 'versus'])) {
      return QuestionIntent.comparison;
    }

    return QuestionIntent.general;
  }

  static bool _has(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  // ── Build full portfolio snapshot ───────────────────────────────────────────
  Future<PortfolioSnapshot> buildSnapshot() async {
    final holdings = await db.select(db.holdings).get();
    final trades = await (db.select(db.trades)
          ..orderBy([(t) => OrderingTerm.asc(t.tradeTimestamp)]))
        .get();

    final today = _fmt(DateTime.now(), 'yyyy-MM-dd');

    if (holdings.isEmpty) {
      return PortfolioSnapshot(
        holdings: [],
        totalInvested: 0,
        totalCurrentValue: 0,
        totalPnL: 0,
        totalReturnPct: 0,
        totalBrokerage: 0,
        totalStt: 0,
        totalGst: 0,
        totalOtherLevies: 0,
        totalCharges: 0,
        totalTrades: trades.length,
        firstTradeDate: 'N/A',
        hasPriceData: false,
        today: today,
        profitableCount: 0,
        trades: trades,
      );
    }

    // Live prices
    final symbols = holdings.map((h) => h.instrumentSymbol.toUpperCase()).toList();
    final prices = await NsePriceService.getPrices(symbols);

    // Fetch day change data via MarketDataService
    final marketService = MarketDataService();
    final Map<String, double> dayChangePctMap = {};
    try {
      final quoteFutures = symbols.map((s) => marketService.fetchQuote(s));
      final quotes = await Future.wait(quoteFutures);
      for (int i = 0; i < symbols.length; i++) {
        final q = quotes[i];
        if (q != null) {
          dayChangePctMap[symbols[i]] = q.dayChangePercent;
        }
      }
    } catch (e) {
      debugPrint('Day change fetch failed: $e');
    }

    // First buy date per symbol for accurate daysHeld
    final Map<String, DateTime> firstBuyDate = {};
    for (final t in trades) {
      if (t.tradeType == db_enums.TradeType.buy) {
        final sym = t.instrumentSymbol.toUpperCase();
        if (!firstBuyDate.containsKey(sym) ||
            t.tradeTimestamp.isBefore(firstBuyDate[sym]!)) {
          firstBuyDate[sym] = t.tradeTimestamp;
        }
      }
    }

    double totalInvested = 0;
    double totalCurrentValue = 0;
    bool hasPriceData = false;
    final analysed = <HoldingAnalysis>[];

    // First pass — calculate totals for weight calculation
    for (final h in holdings) {
      if (h.totalQuantity <= 0) continue; // PHASE 3A: GLOBAL ZERO-UNIT PURGE
      
      final symbol = h.instrumentSymbol.toUpperCase();
      final invested = h.investedValue;
      final cmp = prices[symbol];
      totalInvested += invested;
      if (cmp != null) {
        totalCurrentValue += cmp * h.totalQuantity;
        hasPriceData = true;
      } else {
        totalCurrentValue += invested;
      }
    }

    // Second pass — build full analysis with weights
    for (final h in holdings) {
      if (h.totalQuantity <= 0) continue; // PHASE 3A: GLOBAL ZERO-UNIT PURGE
      
      final symbol = h.instrumentSymbol.toUpperCase();
      final qty = h.totalQuantity;
      final avgCost = h.averagePrice;
      final invested = h.investedValue;
      final cmp = prices[symbol];

      // Use first buy date for accurate days held
      final buyDate = firstBuyDate[symbol];
      final daysHeld = buyDate != null
          ? DateTime.now().difference(buyDate).inDays
          : DateTime.now().difference(h.lastUpdated).inDays;

      double? currentValue;
      double? unrealisedPnL;
      double? returnPct;

      if (cmp != null) {
        currentValue = cmp * qty;
        unrealisedPnL = currentValue - invested;
        returnPct = invested > 0 ? (unrealisedPnL / invested) * 100 : 0;
      }

      final weight = totalCurrentValue > 0
          ? ((cmp != null ? (cmp * qty) : invested) / totalCurrentValue) * 100
          : 0.0;

      analysed.add(HoldingAnalysis(
        symbol: symbol,
        qty: qty,
        avgCost: avgCost,
        invested: invested,
        cmp: cmp,
        currentValue: currentValue,
        unrealisedPnL: unrealisedPnL,
        returnPct: returnPct,
        daysHeld: daysHeld,
        portfolioWeight: weight,
        dayChangePercent: dayChangePctMap[symbol],
      ));
    }

    // Charges
    double totalCharges = 0;
    double totalB = 0;
    double totalSttV = 0;
    double totalGstV = 0;
    double totalOtherV = 0;

    for (final t in trades) {
      totalB += t.brokerage ?? 0;
      totalSttV += t.stt ?? 0;
      totalGstV += t.gst ?? 0;
      totalOtherV += t.otherLevies ?? 0;
      totalCharges += (t.brokerage ?? 0) +
          (t.stt ?? 0) +
          (t.gst ?? 0) +
          (t.otherLevies ?? 0);
    }

    // First trade date
    String firstTradeDate = 'N/A';
    if (trades.isNotEmpty) {
      firstTradeDate = _fmt(trades.first.tradeTimestamp, 'dd-MMM-yyyy');
    }

    // Rankings — only holdings with price data
    final withPrices =
        analysed.where((h) => h.hasPriceData).toList();

    HoldingAnalysis? bestByReturn;
    HoldingAnalysis? worstByReturn;
    HoldingAnalysis? bestByAbsoluteProfit;

    if (withPrices.isNotEmpty) {
      bestByReturn = withPrices.reduce((a, b) =>
          (a.returnPct ?? double.negativeInfinity) >
                  (b.returnPct ?? double.negativeInfinity)
              ? a
              : b);
      worstByReturn = withPrices.reduce((a, b) =>
          (a.returnPct ?? double.infinity) <
                  (b.returnPct ?? double.infinity)
              ? a
              : b);
      bestByAbsoluteProfit = withPrices.reduce((a, b) =>
          (a.unrealisedPnL ?? double.negativeInfinity) >
                  (b.unrealisedPnL ?? double.negativeInfinity)
              ? a
              : b);
    }

    final largestByWeight = analysed.isNotEmpty
        ? analysed.reduce((a, b) =>
            a.portfolioWeight > b.portfolioWeight ? a : b)
        : null;

    final profitableCount =
        withPrices.where((h) => h.isProfitable).length;

    final totalPnL = totalCurrentValue - totalInvested;
    final totalReturnPct =
        totalInvested > 0 ? (totalPnL / totalInvested) * 100 : 0.0;

    // Compute portfolio-level XIRR
    double? portfolioXirr;
    try {
      final cashflows = <({double amount, DateTime date})>[];
      for (final t in trades) {
        if (t.tradeType == db_enums.TradeType.buy) {
          cashflows.add((
            amount: -(t.pricePerUnit * t.quantity),
            date: t.tradeTimestamp,
          ));
        } else {
          cashflows.add((
            amount: t.pricePerUnit * t.quantity,
            date: t.tradeTimestamp,
          ));
        }
      }
      if (totalCurrentValue > 0) {
        cashflows.add((
          amount: totalCurrentValue,
          date: DateTime.now(),
        ));
      }
      portfolioXirr = XirrCalc.calculate(cashflows);
    } catch (_) {}

    return PortfolioSnapshot(
      holdings: analysed,
      totalInvested: totalInvested,
      totalCurrentValue: totalCurrentValue,
      totalPnL: totalPnL,
      totalReturnPct: totalReturnPct,
      totalBrokerage: totalB,
      totalStt: totalSttV,
      totalGst: totalGstV,
      totalOtherLevies: totalOtherV,
      totalCharges: totalCharges,
      totalTrades: trades.length,
      firstTradeDate: firstTradeDate,
      hasPriceData: hasPriceData,
      today: today,
      profitableCount: profitableCount,
      bestByReturn: bestByReturn,
      worstByReturn: worstByReturn,
      bestByAbsoluteProfit: bestByAbsoluteProfit,
      largestByWeight: largestByWeight,
      xirr: portfolioXirr,
      trades: trades,
    );
  }

  // ── Build guided prompt for a specific intent ───────────────────────────────
  // Architecture: Dart computes everything, LLM only paraphrases the draft.
  // Every prompt contains a DRAFT RESPONSE that the model lightly rephrases.
  static Future<String> buildGuidedPrompt({
    required QuestionIntent intent,
    required PortfolioSnapshot snap,
    required String userMessage,
    List<String> externalSymbols = const [],
  }) async {
    switch (intent) {
      case QuestionIntent.whatCanYouDo:
        return 'DRAFT: I can help you understand your portfolio in depth. '
            'I track your exact P&L across all ${snap.holdings.length} holdings with live prices, '
            'break down your charges (brokerage, STT, GST), compare which holdings are performing best or worst, '
            'and answer questions about your investments. Ask me anything about your portfolio.';

      case QuestionIntent.bestPerformer:
        if (!snap.hasPriceData) return _noPriceDraft();
        if (snap.bestByReturn == null) return _noDataDraft();
        
        final best = snap.bestByReturn!;
        
        final buf = StringBuffer();
        buf.writeln('DRAFT: «${best.symbol}» is your top-performing holding with a return of «${best.returnStr}».');
        buf.writeln('You bought «${best.qty.toStringAsFixed(2)}» units at an average of ₹«${best.avgCost.toStringAsFixed(2)}» per unit.');
        buf.writeln('Current market price is ₹«${best.cmp?.toStringAsFixed(2) ?? "N/A"}», bringing your invested ₹«${best.invested.toStringAsFixed(2)}» to a current value of ₹«${best.currentValue?.toStringAsFixed(2) ?? "N/A"}».');
        buf.writeln('Unrealised P&L stands at «${best.pnlStr}» over «${best.daysHeld}» days of holding.');
        
        if (snap.holdings.length > 1) {
          final others = snap.holdings.where((h) => h.symbol != best.symbol && h.hasPriceData).toList();
          if (others.isNotEmpty) {
            final secondBest = others.reduce((a, b) => (a.returnPct ?? double.negativeInfinity) > (b.returnPct ?? double.negativeInfinity) ? a : b);
            buf.writeln('For context, the next best is ${secondBest.symbol} at ${secondBest.returnStr}.');
          }
        }
        return buf.toString();

      case QuestionIntent.worstPerformer:
        if (!snap.hasPriceData) return _noPriceDraft();
        if (snap.worstByReturn == null) return _noDataDraft();
        
        final worst = snap.worstByReturn!;
        
        final buf = StringBuffer();
        buf.writeln('DRAFT: «${worst.symbol}» is your weakest holding right now, standing at «${worst.returnStr}».');
        buf.writeln('You bought «${worst.qty.toStringAsFixed(2)}» units at an average of ₹«${worst.avgCost.toStringAsFixed(2)}» per unit.');
        buf.writeln('Current market price is ₹«${worst.cmp?.toStringAsFixed(2) ?? "N/A"}», bringing your invested ₹«${worst.invested.toStringAsFixed(2)}» to a current value of ₹«${worst.currentValue?.toStringAsFixed(2) ?? "N/A"}».');
        buf.writeln('You are down «${worst.pnlStr}» over «${worst.daysHeld}» days of holding.');
        return buf.toString();

      case QuestionIntent.absoluteProfit:
        if (!snap.hasPriceData) return _noPriceDraft();
        if (snap.bestByAbsoluteProfit == null) return _noDataDraft();

        final buf = StringBuffer();
        buf.writeln('DRAFT: Your highest absolute profit generator is ${snap.bestByAbsoluteProfit!.symbol} with «${snap.bestByAbsoluteProfit!.pnlStr}».');
        return buf.toString();

      case QuestionIntent.totalReturn:
        final pnlWord = snap.totalPnL >= 0 ? 'in profit' : 'at a loss';
        return 'DRAFT: Your portfolio is currently $pnlWord. '
            'Total invested: ₹${snap.totalInvested.toStringAsFixed(2)}. '
            'Current value: ₹${snap.totalCurrentValue.toStringAsFixed(2)}. '
            'Overall P&L: ${snap.pnlStr} (${snap.returnStr}). '
            '${snap.profitableCount} of ${snap.holdings.length} holdings are in profit.';

      case QuestionIntent.portfolioSummary:
        final buf = StringBuffer();
        buf.writeln('CARD:Portfolio Health');
        buf.writeln('Total Invested: ₹${snap.totalInvested.toStringAsFixed(2)}');
        buf.writeln('Current Value: ₹${snap.totalCurrentValue.toStringAsFixed(2)}');
        buf.writeln('Overall P&L: ${snap.pnlStr} (${snap.returnStr})');
        buf.writeln('END_CARD\n');
        buf.writeln('DRAFT: Here is your detailed breakdown across **${snap.holdings.length}** holdings.');
        buf.writeln('• Total invested: **₹${snap.totalInvested.toStringAsFixed(2)}** → Current value: **₹${snap.totalCurrentValue.toStringAsFixed(2)}**');
        buf.writeln('• Overall P&L: **${snap.pnlStr}** (**${snap.returnStr}**)');
        buf.writeln('• **${snap.profitableCount}** of **${snap.holdings.length}** holdings are in profit.');
        buf.writeln('\nTABLE:');
        buf.writeln('Asset | Invested | Current | P&L | Return | Weight');
        for (final h in snap.holdings) {
          if (h.hasPriceData) {
            buf.writeln('${h.symbol} | ₹${h.invested.toStringAsFixed(2)} | ₹${h.currentValue!.toStringAsFixed(2)} | ${h.pnlStr} | ${h.returnStr} | ${h.weightStr}');
          } else {
            buf.writeln('${h.symbol} | ₹${h.invested.toStringAsFixed(2)} | N/A | N/A | N/A | ${h.weightStr}');
          }
        }
        buf.writeln('END_TABLE');
        buf.writeln('\nCHART:donut');
        for (final h in snap.holdings.where((h) => h.hasPriceData).take(5)) {
            buf.writeln('${h.symbol} | ${h.portfolioWeight.toStringAsFixed(2)}%');
        }
        buf.writeln('END_CHART');
        return buf.toString();

      case QuestionIntent.biggestPosition:
        if (snap.largestByWeight == null) return _noDataDraft();
        final largest = snap.largestByWeight!;
        return 'CARD:Largest Holding\n'
            'Your largest position is ${largest.symbol} '
            'with ₹${largest.invested.toStringAsFixed(2)} invested, '
            'making up ${largest.weightStr} of your portfolio.\n'
            'END_CARD\n'
            'DRAFT: ${largest.symbol} is your largest allocation.';

      case QuestionIntent.concentration:
        if (snap.largestByWeight == null) return _noDataDraft();
        final largest = snap.largestByWeight!;
        final isConcentrated = largest.portfolioWeight > 30;
        final buf = StringBuffer();
        if (isConcentrated) {
            buf.writeln('WARNING:\nYour portfolio is highly concentrated in ${largest.symbol} (${largest.weightStr}). This increases risk if the stock underperforms.\nEND_WARNING\n');
        }
        buf.writeln('DRAFT: Your largest holding is ${largest.symbol} at «${largest.weightStr}» of total portfolio value. '
            '${isConcentrated ? "This is considered concentrated since it exceeds 30%." : "Your portfolio is reasonably spread."}');
        buf.writeln('\nCHART:donut');
        for (final h in snap.holdings.where((h) => h.hasPriceData).take(5)) {
            buf.writeln('${h.symbol} | ${h.portfolioWeight.toStringAsFixed(2)}%');
        }
        buf.writeln('END_CHART');
        return buf.toString();

      case QuestionIntent.diversification:
        final allWeights = snap.holdings
            .map((h) => '${h.symbol} ${h.weightStr}')
            .join(', ');
        return 'DRAFT: You hold ${snap.holdings.length} positions. '
            'Allocation: $allWeights.';

      case QuestionIntent.charges:
        final pctOfInvested = snap.totalInvested > 0
            ? (snap.totalCharges / snap.totalInvested * 100).toStringAsFixed(2)
            : '0';
        final buf = StringBuffer();
        buf.writeln('DRAFT: Across «${snap.totalTrades}» trades since ${snap.firstTradeDate}, you paid **₹${snap.totalCharges.toStringAsFixed(2)}** in charges (**$pctOfInvested%** of invested value).');
        buf.writeln('• Brokerage alone accounts for **₹${snap.totalBrokerage.toStringAsFixed(2)}**');
        buf.writeln('• STT adds **₹${snap.totalStt.toStringAsFixed(2)}**');
        buf.writeln('• GST adds **₹${snap.totalGst.toStringAsFixed(2)}**');
        
        buf.writeln('\nTABLE:');
        buf.writeln('Category | Amount Paid');
        buf.writeln('Brokerage | ₹${snap.totalBrokerage.toStringAsFixed(2)}');
        buf.writeln('STT | ₹${snap.totalStt.toStringAsFixed(2)}');
        buf.writeln('GST | ₹${snap.totalGst.toStringAsFixed(2)}');
        buf.writeln('Other | ₹${snap.totalOtherLevies.toStringAsFixed(2)}');
        buf.writeln('**Total** | **₹${snap.totalCharges.toStringAsFixed(2)}**');
        buf.writeln('END_TABLE');

        // Only include charges for active holdings (qty > 0)
        final activeSymbols = snap.holdings.map((h) => h.symbol.toUpperCase()).toSet();
        
        buf.writeln('\nTABLE:');
        buf.writeln('Stock | Brokerage | STT | GST | Total');
        final chargesBySymbol = <String, Map<String, double>>{};
        for (final t in snap.trades) {
          // Filter: only include trades for active holdings
          if (!activeSymbols.contains(t.instrumentSymbol.toUpperCase())) continue;
          
          chargesBySymbol.putIfAbsent(t.instrumentSymbol, () => {'brokerage': 0, 'stt': 0, 'gst': 0, 'total': 0});
          final b = t.brokerage ?? 0.0;
          final s = t.stt ?? 0.0;
          final g = t.gst ?? 0.0;
          final total = t.charges ?? (b + s + g + (t.otherLevies ?? 0.0));
          chargesBySymbol[t.instrumentSymbol]!['brokerage'] = (chargesBySymbol[t.instrumentSymbol]!['brokerage']! + b);
          chargesBySymbol[t.instrumentSymbol]!['stt'] = (chargesBySymbol[t.instrumentSymbol]!['stt']! + s);
          chargesBySymbol[t.instrumentSymbol]!['gst'] = (chargesBySymbol[t.instrumentSymbol]!['gst']! + g);
          chargesBySymbol[t.instrumentSymbol]!['total'] = (chargesBySymbol[t.instrumentSymbol]!['total']! + total);
        }
        
        // Sort by total charges descending
        final sortedSymbols = chargesBySymbol.keys.toList()
          ..sort((a, b) => chargesBySymbol[b]!['total']!.compareTo(chargesBySymbol[a]!['total']!));
          
        for (final sym in sortedSymbols) {
          final c = chargesBySymbol[sym]!;
          buf.writeln('$sym | ₹${c['brokerage']!.toStringAsFixed(2)} | ₹${c['stt']!.toStringAsFixed(2)} | ₹${c['gst']!.toStringAsFixed(2)} | ₹${c['total']!.toStringAsFixed(2)}');
        }
        buf.writeln('END_TABLE');
        
        return buf.toString();

      case QuestionIntent.tradeHistory:
        final buf = StringBuffer();
        buf.writeln('DRAFT: You have executed ${snap.totalTrades} trades since ${snap.firstTradeDate}. Your recent holdings distribution:');
        buf.writeln('\nTIMELINE:');
        for (final h in snap.holdings) {
          buf.writeln('${h.symbol} | ${h.qty.toStringAsFixed(2)} units | avg ₹${h.avgCost.toStringAsFixed(2)} | Held ${h.daysHeld} days');
        }
        buf.writeln('END_TIMELINE');
        return buf.toString();

      case QuestionIntent.daysHeld:
        final daysInfo = snap.holdings
            .map((h) => '${h.symbol}: ${h.daysHeld} days')
            .join(', ');
        return 'DRAFT: Holding durations (since first buy): $daysInfo.';

      case QuestionIntent.specificHolding:
        return _buildSpecificHoldingDraft(userMessage, snap);

      case QuestionIntent.comparison:
        return await buildComparisonDraft(userMessage, snap, externalSymbols: externalSymbols);

      case QuestionIntent.general:
        return '';
    }
  }

  /// Finds the specific holding mentioned in the user's message and builds a draft.
  static String _buildSpecificHoldingDraft(String userMessage, PortfolioSnapshot snap) {
    final m = userMessage.toLowerCase();
    HoldingAnalysis? match;
    for (final h in snap.holdings) {
      if (m.contains(h.symbol.toLowerCase())) {
        match = h;
        break;
      }
    }
    if (match == null) return _noDataDraft();

    final buf = StringBuffer();
    buf.write('DRAFT: ');
    // Find the full name from trades if available
    final tradeName = snap.trades
        .where((t) => t.instrumentSymbol.toUpperCase() == match!.symbol)
        .map((t) => t.instrumentName)
        .firstOrNull;
    final displayName = tradeName ?? match.symbol;

    buf.write('$displayName (${match.symbol}) ');
    if (match.symbol.toUpperCase().contains('GOLD')) {
      buf.write('is a Gold ETF tracking gold prices. It ');
    } else if (match.symbol.toUpperCase().contains('SILVER')) {
      buf.write('is a Silver ETF tracking silver prices. It ');
    } else if (match.symbol.toUpperCase().contains('NIFTY')) {
      buf.write('is an equity index fund tracking the Nifty 50. It ');
    }
    
    if (match.hasPriceData) {
      buf.write('is currently at ₹${match.cmp!.toStringAsFixed(2)}. ');
      buf.write('You hold ${match.qty.toStringAsFixed(2)} units ');
      buf.write('at an average cost of ₹${match.avgCost.toStringAsFixed(2)}. ');
      buf.write('Current value: ₹${match.currentValue!.toStringAsFixed(2)}, ');
      buf.write('invested: ₹${match.invested.toStringAsFixed(2)}. ');
      buf.write('Unrealised P&L: ${match.pnlStr} (${match.returnStr}). ');
      buf.write('[NOTE: The return shown is OVERALL since purchase, not today.] ');
      buf.write('Held for ${match.daysHeld} days. ');
      buf.write('Portfolio weight: ${match.weightStr}.');
    } else {
      buf.write('You hold ${match.qty.toStringAsFixed(2)} units ');
      buf.write('with ₹${match.invested.toStringAsFixed(2)} invested. ');
      buf.write('Live price is currently unavailable.');
    }
    return buf.toString();
  }

  /// Maps common names / aliases to actual portfolio symbols
  static HoldingAnalysis? _resolveHolding(String alias, List<HoldingAnalysis> holdings) {
    final a = alias.toLowerCase().trim();
    
    // Alias map: common name → possible symbol prefixes
    const aliasMap = <String, List<String>>{
      'gold': ['GOLDBEES', 'SETFGOLD', 'GOLD'],
      'silver': ['SILVERIETF', 'SILVERBEES', 'SILVER'],
      'nifty': ['NIFTYBEES', 'NIFTY'],
      'yes bank': ['YESBANK'],
      'yesbank': ['YESBANK'],
      'bank': ['YESBANK', 'HDFCBANK', 'ICICIBANK', 'KOTAKBANK', 'SBIN', 'AXISBANK'],
    };
    
    // 1. Exact symbol match
    for (final h in holdings) {
      if (h.symbol.toLowerCase() == a) return h;
    }
    
    // 2. Alias map match
    for (final entry in aliasMap.entries) {
      if (a.contains(entry.key)) {
        for (final prefix in entry.value) {
          final match = holdings.where((h) => h.symbol.toUpperCase() == prefix).firstOrNull;
          if (match != null) return match;
        }
      }
    }
    
    // 3. Partial match: symbol contains the alias OR alias contains the symbol
    for (final h in holdings) {
      if (h.symbol.toLowerCase().contains(a) || a.contains(h.symbol.toLowerCase())) {
        return h;
      }
    }
    
    return null;
  }
  /// Builds a comparison draft involving a TABLE and CHART:line blocks.
  /// Supports 2 to 4 items and external Yahoo tickers.
  static Future<String> buildComparisonDraft(String userMessage, PortfolioSnapshot snap, {List<String> externalSymbols = const []}) async {
    if (!snap.hasPriceData && externalSymbols.isEmpty) return _noPriceDraft();
    final m = userMessage.toLowerCase();
    
    final targets = <_CompareItem>[];
    final seen = <String>{};
    
    // 1. Exact match from portfolio
    for (final h in snap.holdings) {
      if (m.contains(h.symbol.toLowerCase()) && !seen.contains(h.symbol)) {
        targets.add(_CompareItem(
          symbol: h.symbol, invested: h.invested, currentValue: h.currentValue, cmp: h.cmp,
          qty: h.qty, avgCost: h.avgCost, pnlStr: h.pnlStr, returnStr: h.returnStr,
          weightStr: h.weightStr, daysHeld: h.daysHeld, isExternal: false, yahooSymbolForChart: h.symbol
        ));
        seen.add(h.symbol);
      }
    }
    
    // 2. Alias resolution for portfolio
    final candidateAliases = ['gold', 'silver', 'nifty', 'yes bank', 'yesbank', 'bank'];
    for (final alias in candidateAliases) {
      if (m.contains(alias)) {
        final resolved = _resolveHolding(alias, snap.holdings);
        if (resolved != null && !seen.contains(resolved.symbol)) {
          targets.add(_CompareItem(
            symbol: resolved.symbol, invested: resolved.invested, currentValue: resolved.currentValue, cmp: resolved.cmp,
            qty: resolved.qty, avgCost: resolved.avgCost, pnlStr: resolved.pnlStr, returnStr: resolved.returnStr,
            weightStr: resolved.weightStr, daysHeld: resolved.daysHeld, isExternal: false, yahooSymbolForChart: resolved.symbol
          ));
          seen.add(resolved.symbol);
        }
      }
    }
    
    // 3. Clean external symbols
    final cleanExternal = <String>[];
    String resolveExtToAlias(String e) {
      if (e == 'GC=F') return 'gold';
      if (e == 'SI=F') return 'silver';
      if (e == 'HG=F') return 'copper';
      if (e == '^NSEI') return 'nifty';
      if (e == '^NSEBANK') return 'bank';
      return e.toLowerCase().replaceAll('.ns', '').replaceAll('=f', '');
    }

    for (var ext in externalSymbols) {
       final raw = ext.replaceAll('.NS', '').replaceAll('.BO', '').replaceAll('=F', '').toUpperCase();
       final alias = resolveExtToAlias(ext);
       
       bool alreadyResolved = false;
       for (final t in targets) {
           if (t.symbol.toUpperCase() == raw || t.symbol.toLowerCase().contains(alias)) {
               alreadyResolved = true;
               break;
           }
       }
       
       if (!seen.contains(raw) && !alreadyResolved) {
          cleanExternal.add(ext);
          seen.add(raw);
       }
    }
    if (targets.length + cleanExternal.length < 2 && targets.length + cleanExternal.length > 0) {
        return 'DRAFT: Please specify at least two assets to compare. You only mentioned one.';
    }
    if (targets.length + cleanExternal.length < 2) {
      return 'DRAFT: Please specify at least two holdings or assets to compare.';
    }

    // 4. Fetch external data
    for (final ext in cleanExternal.take(4)) { 
       final quote = await YahooQuoteService.fetchQuote(ext);
       if (quote != null) {
          String shortName = quote.name;
          if (shortName.length > 15) shortName = shortName.substring(0, 15);
          final sign = quote.dayChangePct >= 0 ? '+' : '';
          
          targets.add(_CompareItem(
             symbol: shortName,
             invested: null, currentValue: null, cmp: quote.cmp, qty: null, avgCost: null,
             pnlStr: 'N/A', returnStr: '$sign${quote.dayChangePct.toStringAsFixed(2)}% (1D)',
             weightStr: 'N/A', daysHeld: null, isExternal: true, yahooSymbolForChart: ext
          ));
       }
    }

    final compareList = targets.take(4).toList();
    if (compareList.length < 2) {
       return 'DRAFT: I could not retrieve enough data for the requested assets to perform a comparison.';
    }

    final buf = StringBuffer();
    final symbolList = compareList.map((h) => h.symbol).join(' and ');
    buf.writeln('DRAFT: Comparing $symbolList:');
    
    final portfolioItems = compareList.where((c) => !c.isExternal).toList();
    if (portfolioItems.isNotEmpty) {
       final best = [...portfolioItems]..sort((a,b) {
           final aRet = a.returnStr == 'N/A' ? -999.0 : double.tryParse(a.returnStr.replaceAll('%', '').replaceAll('+','')) ?? -999.0;
           final bRet = b.returnStr == 'N/A' ? -999.0 : double.tryParse(b.returnStr.replaceAll('%', '').replaceAll('+','')) ?? -999.0;
           return bRet.compareTo(aRet);
       });
       buf.writeln('• **${best.first.symbol}** leads your owned portfolio with an overall return of **${best.first.returnStr}** and P&L of **${best.first.pnlStr}**.');
    }
    final externalItems = compareList.where((c) => c.isExternal).toList();
    if (externalItems.isNotEmpty) {
       for (final ext in externalItems) {
           buf.writeln('• **${ext.symbol}** is currently trading at **₹${ext.cmp?.toStringAsFixed(2) ?? "N/A"}** (Day Change: **${ext.returnStr}**).');
       }
    }

    buf.writeln('\nTABLE:');
    final headerCells = ['Metric', ...compareList.map((h) => h.symbol)];
    buf.writeln(headerCells.join(' | '));
    
    String formatNum(double? val, {String prefix = ''}) => val == null ? '–' : '$prefix${val.toStringAsFixed(2)}';
    String formatStr(String val) => val == 'N/A' ? '–' : val;

    buf.writeln(['Invested', ...compareList.map((h) => formatNum(h.invested, prefix: '₹'))].join(' | '));
    buf.writeln(['Current Value', ...compareList.map((h) => formatNum(h.currentValue, prefix: '₹'))].join(' | '));
    buf.writeln(['CMP', ...compareList.map((h) => formatNum(h.cmp, prefix: '₹'))].join(' | '));
    buf.writeln(['Qty', ...compareList.map((h) => formatNum(h.qty))].join(' | '));
    buf.writeln(['Avg Cost', ...compareList.map((h) => formatNum(h.avgCost, prefix: '₹'))].join(' | '));
    buf.writeln(['P&L', ...compareList.map((h) => formatStr(h.pnlStr))].join(' | '));
    buf.writeln(['Return', ...compareList.map((h) => formatStr(h.returnStr))].join(' | '));
    buf.writeln(['Days Held', ...compareList.map((h) => h.daysHeld?.toString() ?? '–')].join(' | '));
    buf.writeln('END_TABLE');
    
    final chartSymbols = compareList.map((h) => '${h.yahooSymbolForChart}::${h.symbol.replaceAll(',', '')}').join(',');
    
    int computedScenario = 3;
    if (portfolioItems.isEmpty && externalItems.isNotEmpty) {
      computedScenario = 1;
    } else if (portfolioItems.isNotEmpty && externalItems.isNotEmpty) {
      computedScenario = 2;
    }

    if (computedScenario == 1) {
        // Scenario 1: All external. 4 line charts.
        buf.writeln('\nCHART:line\n$chartSymbols|max|All Time Performance\nEND_CHART');
        buf.writeln('\nCHART:line\n$chartSymbols|1y|Last 1 Year\nEND_CHART');
        buf.writeln('\nCHART:line\n$chartSymbols|30d|Last 30 Days\nEND_CHART');
        buf.writeln('\nCHART:line\n$chartSymbols|1d|Today\'s Movement\nEND_CHART');
    } else {
        // Scenario 2 / 3: Mixed or All Portfolio
        int minDays = 30;
        if (portfolioItems.isNotEmpty) {
           minDays = portfolioItems.map((h) => h.daysHeld ?? 30).reduce((a, b) => a < b ? a : b);
        }
        if (minDays < 7) minDays = 7; 
        if (minDays > 365) minDays = 365;
        buf.writeln('\nCHART:line\n$chartSymbols|${minDays}d|Owned Window ($minDays Days)\nEND_CHART');
    }

    return buf.toString();
  }

    static String _noPriceDraft() =>
      'DRAFT: Live market prices are not available right now. '
      'I can still show your invested amounts and quantities, '
      'but current P&L and return percentages require a live connection.';

  static String _noDataDraft() =>
      'DRAFT: Portfolio data is not available yet. '
      'If you have imported trades, please wait a moment and ask again. '
      'The data may still be loading from the database.';

  static String _fmt(DateTime dt, String pattern) =>
      DateFormat(pattern).format(dt);
}