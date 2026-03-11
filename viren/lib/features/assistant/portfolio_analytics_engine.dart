import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/database/enums.dart' as db_enums;
import '../../core/market/nse_price_service.dart';

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
  });

  bool get hasPriceData => cmp != null;
  bool get isProfitable => (unrealisedPnL ?? 0) >= 0;

  String get pnlStr {
    if (unrealisedPnL == null) return 'N/A';
    final sign = unrealisedPnL! >= 0 ? '+' : '';
    return '$sign₹${unrealisedPnL!.toStringAsFixed(0)}';
  }

  String get returnStr {
    if (returnPct == null) return 'N/A';
    final sign = returnPct! >= 0 ? '+' : '';
    return '$sign${returnPct!.toStringAsFixed(1)}%';
  }

  String get weightStr => '${portfolioWeight.toStringAsFixed(1)}%';
}

class PortfolioSnapshot {
  final List<HoldingAnalysis> holdings;
  final double totalInvested;
  final double totalCurrentValue;
  final double totalPnL;
  final double totalReturnPct;
  final double totalCharges;
  final int totalTrades;
  final String firstTradeDate;
  final bool hasPriceData;
  final String today;

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
  });

  bool get isEmpty => holdings.isEmpty;

  String get pnlStr {
    final sign = totalPnL >= 0 ? '+' : '';
    return '$sign₹${totalPnL.toStringAsFixed(0)}';
  }

  String get returnStr {
    final sign = totalReturnPct >= 0 ? '+' : '';
    return '$sign${totalReturnPct.toStringAsFixed(1)}%';
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
  general, // not portfolio-specific — let model answer freely
}

// ─── Analytics Engine ─────────────────────────────────────────────────────────

class PortfolioAnalyticsEngine {
  final AppDatabase db;
  PortfolioAnalyticsEngine(this.db);

  // ── Detect intent from user message ────────────────────────────────────────
  static QuestionIntent detectIntent(String message) {
    final m = message.toLowerCase();

    // What can you do — check before portfolio questions
    if (_has(m, ['what can you do', 'what do you do', 'help me', 'capabilities',
        'what are you', 'who are you', 'how can you help'])) {
      return QuestionIntent.whatCanYouDo;
    }

    // Best performer
    if (_has(m, ['best', 'top', 'highest', 'most profit', 'performing best',
        'best return', 'highest return', 'leading'])) {
      return QuestionIntent.bestPerformer;
    }

    // Worst performer
    if (_has(m, ['worst', 'lowest', 'underperform', 'losing', 'most loss',
        'bad', 'negative', 'drag', 'weakest'])) {
      return QuestionIntent.worstPerformer;
    }

    // Absolute profit (rupee gain, not percentage)
    if (_has(m, ['most money', 'absolute', 'rupee gain', 'highest profit',
        'largest gain', 'maximum profit', 'most rupee'])) {
      return QuestionIntent.absoluteProfit;
    }

    // Total return / overall portfolio
    if (_has(m, ['total return', 'overall', 'portfolio return', 'how am i doing',
        'total profit', 'total gain', 'net profit', 'portfolio value'])) {
      return QuestionIntent.totalReturn;
    }

    // Portfolio summary
    if (_has(m, ['summary', 'overview', 'all holdings', 'full portfolio',
        'everything', 'show all', 'list all'])) {
      return QuestionIntent.portfolioSummary;
    }

    // Biggest position
    if (_has(m, ['biggest', 'largest', 'most invested', 'highest allocation',
        'most capital', 'biggest position', 'largest position'])) {
      return QuestionIntent.biggestPosition;
    }

    // Concentration / risk
    if (_has(m, ['concentrated', 'concentration', 'too much', 'overweight',
        'risk', 'dependent', 'exposure'])) {
      return QuestionIntent.concentration;
    }

    // Diversification
    if (_has(m, ['diversif', 'spread', 'sector', 'allocation', 'balanced',
        'distribution'])) {
      return QuestionIntent.diversification;
    }

    // Charges
    if (_has(m, ['charge', 'brokerage', 'stt', 'fee', 'cost', 'tax',
        'expense', 'paid'])) {
      return QuestionIntent.charges;
    }

    // Trade history
    if (_has(m, ['trade', 'history', 'when did', 'first trade', 'bought',
        'purchased', 'sold'])) {
      return QuestionIntent.tradeHistory;
    }

    // Days held
    if (_has(m, ['how long', 'days', 'held', 'since when', 'duration',
        'holding period'])) {
      return QuestionIntent.daysHeld;
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
        totalCharges: 0,
        totalTrades: trades.length,
        firstTradeDate: 'N/A',
        hasPriceData: false,
        today: today,
        profitableCount: 0,
      );
    }

    // Live prices
    final symbols = holdings.map((h) => h.instrumentSymbol.toUpperCase()).toList();
    final prices = await NsePriceService.getPrices(symbols);

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
      ));
    }

    // Charges
    double totalCharges = 0;
    for (final t in trades) {
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

    return PortfolioSnapshot(
      holdings: analysed,
      totalInvested: totalInvested,
      totalCurrentValue: totalCurrentValue,
      totalPnL: totalPnL,
      totalReturnPct: totalReturnPct,
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
    );
  }

  // ── Build guided prompt for a specific intent ───────────────────────────────
  // This is the key method — Flutter calculates everything, model just narrates.
  static String buildGuidedPrompt({
    required QuestionIntent intent,
    required PortfolioSnapshot snap,
    required String userMessage,
  }) {
    switch (intent) {
      case QuestionIntent.whatCanYouDo:
        return '''The user asked: "$userMessage"

Tell them in 3-4 sentences what you can help with. Include: analysing portfolio performance, tracking P&L, comparing holdings, showing charges, answering questions about their investments. Keep it warm and specific. Do not use bullet points.''';

      case QuestionIntent.bestPerformer:
        if (!snap.hasPriceData) {
          return _noPricePrompt(userMessage);
        }
        if (snap.bestByReturn == null) return _noDataPrompt(userMessage);
        final best = snap.bestByReturn!;
        final others = snap.holdings
            .where((h) => h.symbol != best.symbol && h.hasPriceData)
            .map((h) => '${h.symbol} ${h.returnStr}')
            .join(', ');
        return '''The user asked: "$userMessage"

VERIFIED DATA — trust these numbers exactly:
Best performing holding: ${best.symbol}
Return: ${best.returnStr}
Qty: ${best.qty.toStringAsFixed(0)} units
Avg cost: ₹${best.avgCost.toStringAsFixed(2)}
CMP: ₹${best.cmp!.toStringAsFixed(2)}
Unrealised gain: ${best.pnlStr}
Held for: ${best.daysHeld} days
Other holdings for comparison: $others

Write a confident, direct response. Start with the conclusion. Show the position details. Compare briefly with other holdings. End with one optional follow-up offer. Use plain text only, no markdown.''';

      case QuestionIntent.worstPerformer:
        if (!snap.hasPriceData) return _noPricePrompt(userMessage);
        if (snap.worstByReturn == null) return _noDataPrompt(userMessage);
        final worst = snap.worstByReturn!;
        final others = snap.holdings
            .where((h) => h.symbol != worst.symbol && h.hasPriceData)
            .map((h) => '${h.symbol} ${h.returnStr}')
            .join(', ');
        return '''The user asked: "$userMessage"

VERIFIED DATA:
Worst performing holding: ${worst.symbol}
Return: ${worst.returnStr}
Qty: ${worst.qty.toStringAsFixed(0)} units
Avg cost: ₹${worst.avgCost.toStringAsFixed(2)}
CMP: ₹${worst.cmp!.toStringAsFixed(2)}
Unrealised P&L: ${worst.pnlStr}
Held for: ${worst.daysHeld} days
Other holdings: $others
Profitable holdings: ${snap.profitableCount} out of ${snap.holdings.length}

Write a direct response. State the weakest holding first. Show the numbers. Give context about the rest of the portfolio. Plain text only.''';

      case QuestionIntent.absoluteProfit:
        if (!snap.hasPriceData) return _noPricePrompt(userMessage);
        if (snap.bestByAbsoluteProfit == null) return _noDataPrompt(userMessage);
        final best = snap.bestByAbsoluteProfit!;
        return '''The user asked: "$userMessage"

VERIFIED DATA:
Highest absolute rupee profit: ${best.symbol}
Unrealised profit: ${best.pnlStr}
Return percentage: ${best.returnStr}
Qty: ${best.qty.toStringAsFixed(0)} units
Avg cost: ₹${best.avgCost.toStringAsFixed(2)}
CMP: ₹${best.cmp!.toStringAsFixed(2)}

Note: highest rupee profit and highest percentage return may be different holdings.

Write a direct response explaining the difference between absolute profit and percentage return if relevant. Plain text only.''';

      case QuestionIntent.totalReturn:
        return '''The user asked: "$userMessage"

VERIFIED DATA:
Total invested: ₹${snap.totalInvested.toStringAsFixed(0)}
Total current value: ₹${snap.totalCurrentValue.toStringAsFixed(0)}
Total unrealised P&L: ${snap.pnlStr} (${snap.returnStr})
Profitable holdings: ${snap.profitableCount} out of ${snap.holdings.length}
${snap.hasPriceData ? 'Live prices used.' : 'Note: some prices unavailable.'}

Write a confident summary of portfolio performance. Show the key numbers. Mention which holdings are driving the gains. Plain text only.''';

      case QuestionIntent.portfolioSummary:
        final holdingsSummary = snap.holdings
            .map((h) => h.hasPriceData
                ? '${h.symbol}: ${h.returnStr} | P&L ${h.pnlStr} | weight ${h.weightStr}'
                : '${h.symbol}: no live price')
            .join('\n');
        return '''The user asked: "$userMessage"

VERIFIED DATA:
$holdingsSummary

Total invested: ₹${snap.totalInvested.toStringAsFixed(0)}
Total value: ₹${snap.totalCurrentValue.toStringAsFixed(0)}
Total P&L: ${snap.pnlStr} (${snap.returnStr})

For the table, use this exact format:
TABLE:
Symbol|Invested|CMP|P&L|Return
Then one row per holding with exact numbers above.
END_TABLE

Then add one sentence summary after the table. Plain text only, no markdown.''';

      case QuestionIntent.biggestPosition:
        if (snap.largestByWeight == null) return _noDataPrompt(userMessage);
        final largest = snap.largestByWeight!;
        final others = snap.holdings
            .where((h) => h.symbol != largest.symbol)
            .map((h) => '${h.symbol} ${h.weightStr}')
            .join(', ');
        return '''The user asked: "$userMessage"

VERIFIED DATA:
Largest position: ${largest.symbol}
Capital allocated: ₹${largest.invested.toStringAsFixed(0)}
Portfolio weight: ${largest.weightStr}
Other positions: $others

Write a direct response. State the largest position and its weight. Compare with others. Plain text only.''';

      case QuestionIntent.concentration:
        if (snap.largestByWeight == null) return _noDataPrompt(userMessage);
        final largest = snap.largestByWeight!;
        final isConcentrated = largest.portfolioWeight > 30;
        return '''The user asked: "$userMessage"

VERIFIED DATA:
Largest single holding: ${largest.symbol} at ${largest.weightStr} of portfolio
Total holdings: ${snap.holdings.length}
Is concentrated (>30% in one stock): $isConcentrated

Write a factual analysis of concentration risk. If concentrated, mention it clearly but without alarm. State the facts. The decision is theirs. Plain text only.''';

      case QuestionIntent.diversification:
        final allWeights = snap.holdings
            .map((h) => '${h.symbol}: ${h.weightStr}')
            .join(', ');
        return '''The user asked: "$userMessage"

VERIFIED DATA:
Number of holdings: ${snap.holdings.length}
Allocation breakdown: $allWeights

Write a brief diversification analysis. Mention number of holdings and how spread the capital is. Plain text only.''';

      case QuestionIntent.charges:
        return '''The user asked: "$userMessage"

VERIFIED DATA:
Total charges paid: ₹${snap.totalCharges.toStringAsFixed(2)}
Total trades executed: ${snap.totalTrades}
Investing since: ${snap.firstTradeDate}

Write a direct response with the exact charges figure. If charges are low relative to portfolio size, note that briefly. Plain text only.''';

      case QuestionIntent.tradeHistory:
        return '''The user asked: "$userMessage"

VERIFIED DATA:
Total trades: ${snap.totalTrades}
First trade: ${snap.firstTradeDate}
Current holdings: ${snap.holdings.map((h) => h.symbol).join(', ')}

Write a brief response about their trading history. Plain text only.''';

      case QuestionIntent.daysHeld:
        final daysInfo = snap.holdings
            .map((h) => '${h.symbol}: ${h.daysHeld} days')
            .join(', ');
        return '''The user asked: "$userMessage"

VERIFIED DATA (days held = days since first buy):
$daysInfo

Write a direct response with the holding durations. Plain text only.''';

      case QuestionIntent.general:
        // For general questions, return empty — let assistant_service
        // use normal prompt building with portfolio context
        return '';
    }
  }

  static String _noPricePrompt(String userMessage) =>
      '''The user asked: "$userMessage"
Live prices are currently unavailable. Tell the user you cannot give accurate performance data without current prices, and suggest they check back when online. Be brief and direct.''';

  static String _noDataPrompt(String userMessage) =>
      '''The user asked: "$userMessage"
No holdings data is available. Tell the user their portfolio appears empty and suggest importing trades first. Be brief.''';

  static String _fmt(DateTime dt, String pattern) =>
      DateFormat(pattern).format(dt);
}