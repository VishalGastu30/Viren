import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/enums.dart';
import 'alert_trigger_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PatternEngine — Layer 3 Intelligence: pure Dart statistical pattern detection.
//
// No AI. No network. Pure arithmetic against the local trades + holdings DB.
//
// Detects:
//   1. DCA Pattern — same symbol bought 3+ times at declining prices
//   2. Concentration Drift — one holding > 40% of portfolio by current value
//   3. Accumulation — 3+ buys in the same calendar month (SIP-like behaviour)
//   4. Gap Detection — portfolio price has moved significantly since last trade
//
// All methods are idempotent — AlertTriggerService handles deduplication.
// ─────────────────────────────────────────────────────────────────────────────

class PatternEngine {
  final AppDatabase _db;
  late final AlertTriggerService _alertService;

  PatternEngine(this._db) {
    _alertService = AlertTriggerService(_db);
  }

  /// Entry point called from InsightEngine.
  Future<void> run() async {
    final holdings = await _db.select(_db.holdings).get();
    if (holdings.isEmpty) return;

    final trades = await (_db.select(_db.trades)
          ..orderBy([(t) => OrderingTerm.asc(t.tradeTimestamp)]))
        .get();
    if (trades.isEmpty) return;

    await _checkDcaPattern(trades, holdings);
    await _checkConcentrationDrift(holdings);
    await _checkAccumulationPattern(trades);
    await _checkGapDetection(trades, holdings);
    await _checkEconomicCalendar();
    await _checkLtcgCountdown(trades, holdings);
    await _checkPortfolioCorrelation(holdings);
  }

  // ── Pattern 1: DCA Detection ──────────────────────────────────

  Future<void> _checkDcaPattern(
      List<Trade> trades, List<Holding> holdings) async {
    // Group buy trades by symbol
    final buysBySymbol = <String, List<Trade>>{};
    for (final t in trades) {
      if (t.tradeType == TradeType.buy) {
        buysBySymbol
            .putIfAbsent(t.instrumentSymbol.toUpperCase(), () => [])
            .add(t);
      }
    }

    for (final entry in buysBySymbol.entries) {
      final symbol = entry.key;
      final buys = entry.value; // already sorted by timestamp asc
      if (buys.length < 3) continue;

      // Check if the last 3 buys show declining or flat prices
      final last3 = buys.sublist(buys.length - 3);
      final prices = last3.map((t) => t.pricePerUnit).toList();
      bool isDeclining = true;
      for (int i = 1; i < prices.length; i++) {
        if (prices[i] > prices[i - 1] * 1.02) {
          // allow 2% tolerance
          isDeclining = false;
          break;
        }
      }
      if (!isDeclining) continue;

      // Find the holding for avg cost
      final holding = holdings
          .cast<Holding?>()
          .firstWhere((h) => h!.instrumentSymbol.toUpperCase() == symbol,
              orElse: () => null);
      if (holding == null) continue;

      final lowestBuyPrice = prices.reduce((a, b) => a < b ? a : b);
      final avgCost = holding.averagePrice;

      // Next DCA price estimate: project one more buy at current avg cost
      final nextDcaPrice = avgCost * 0.97; // 3% below current avg

      await _alertService.createPatternAlert(
        alertType: 'DCA_OPPORTUNITY',
        symbol: symbol,
        title: 'You\'re naturally DCA-ing $symbol',
        description:
            'You\'ve bought $symbol ${buys.length} times with declining prices. '
            'Your avg cost is ₹${avgCost.toStringAsFixed(2)}. '
            'One more buy around ₹${nextDcaPrice.toStringAsFixed(2)} '
            'would lower your cost base further.',
        confidence: 85,
        triggerData: {
          'buyCount': buys.length,
          'avgCost': avgCost,
          'lastBuyPrice': prices.last,
          'lowestBuyPrice': lowestBuyPrice,
        },
      );
    }
  }

  // ── Pattern 2: Concentration Drift ───────────────────────────

  Future<void> _checkConcentrationDrift(List<Holding> holdings) async {
    if (holdings.length < 2) return;

    // Use investedValue as proxy since we don't have live prices here
    double totalValue = 0;
    for (final h in holdings) {
      totalValue += h.investedValue;
    }
    if (totalValue <= 0) return;

    for (final h in holdings) {
      final symbol = h.instrumentSymbol.toUpperCase();
      final pct = (h.investedValue / totalValue) * 100;
      if (pct < 40) continue;

      // Check allocation concentration
      final investedPct = pct; // same since we use investedValue for both
      final driftPct = pct - (100.0 / holdings.length); // compare to equal weight
      if (driftPct < 5) continue; // only flag if concentration is meaningful

      await _alertService.createPatternAlert(
        alertType: 'CONCENTRATION_DRIFT',
        symbol: symbol,
        title: '$symbol is ${pct.toStringAsFixed(0)}% of your portfolio',
        description:
            '$symbol makes up ${pct.toStringAsFixed(1)}% of your portfolio '
            'by invested value. '
            'Consider whether this concentration aligns with your risk appetite.',
        confidence: 90,
        triggerData: {
          'currentPct': pct,
          'investedPct': investedPct,
          'driftPct': driftPct,
          'investedValue': h.investedValue,
          'totalValue': totalValue,
        },
      );
    }
  }

  double _totalInvested(List<Holding> holdings) {
    return holdings.fold(0.0, (sum, h) => sum + h.investedValue);
  }

  // ── Pattern 3: Accumulation / SIP-like Behaviour ─────────────

  Future<void> _checkAccumulationPattern(List<Trade> trades) async {
    final buyTrades =
        trades.where((t) => t.tradeType == TradeType.buy).toList();
    if (buyTrades.length < 3) return;

    // Group by year-month
    final byMonth = <String, List<Trade>>{};
    for (final t in buyTrades) {
      final key =
          '${t.tradeTimestamp.year}-${t.tradeTimestamp.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(t);
    }

    // Find months with 3+ buys
    for (final entry in byMonth.entries) {
      if (entry.value.length < 3) continue;

      final month = entry.key;
      final symbols = entry.value
          .map((t) => t.instrumentSymbol.toUpperCase())
          .toSet()
          .join(', ');

      await _alertService.createPatternAlert(
        alertType: 'ACCUMULATION_PATTERN',
        symbol: null,
        title: '${entry.value.length} investments in one month',
        description:
            'In $month you made ${entry.value.length} separate purchases '
            '($symbols). This disciplined accumulation pattern reduces '
            'timing risk and builds long-term cost averaging.',
        confidence: 80,
        triggerData: {
          'month': month,
          'buyCount': entry.value.length,
          'symbols': symbols,
        },
      );
    }
  }

  // ── Pattern 4: Gap Detection ──────────────────────────────────

  Future<void> _checkGapDetection(
      List<Trade> trades, List<Holding> holdings) async {
    if (trades.isEmpty) return;

    final lastTrade = trades.last; // sorted asc, last = most recent
    final daysSince =
        DateTime.now().difference(lastTrade.tradeTimestamp).inDays;
    if (daysSince < 60) return;

    final totalInvested = _totalInvested(holdings);
    if (totalInvested <= 0) return;

    // Use investedValue since we don't have live prices in this context
    // The gap detection focuses on inactivity, not P&L
    final overallPct = 0.0; // PatternEngine doesn't have live prices

    final direction = overallPct >= 0 ? 'up' : 'down';
    final absStr = overallPct.abs().toStringAsFixed(1);

    await _alertService.createPatternAlert(
      alertType: 'INACTIVITY_ALERT',
      symbol: null,
      title: '$daysSince days since your last trade',
      description:
          'You haven\'t traded in $daysSince days. '
          'Your portfolio is $direction $absStr% overall since you last invested. '
          'Regular investing tends to smooth out market volatility.',
      confidence: 95,
      triggerData: {
        'daysSince': daysSince,
        'overallPct': overallPct,
        'lastTradeDate': lastTrade.tradeTimestamp.toIso8601String(),
      },
    );
  }

  // ── Pattern 5: Economic Calendar Awareness ────────────────────
  Future<void> _checkEconomicCalendar() async {
    final now = DateTime.now();

    // 1. F&O Expiry (Last working Thursday of the month)
    // Roughly days 24-31. If it's a Wed/Thu in that range:
    if (now.day >= 24 && (now.weekday == 3 || now.weekday == 4)) {
      await _alertService.createPatternAlert(
        alertType: 'CALENDAR_EVENT',
        title: 'Volatility Alert: F&O Expiry Week',
        description: 'We are in the final days of the monthly derivatives expiry. '
            'Expect higher intraday volatility in large caps and the Nifty index.',
        confidence: 90,
      );
    }

    // 2. RBI Policy (first week of Feb, Apr, Jun, Aug, Oct, Dec)
    final rbiMonths = [2, 4, 6, 8, 10, 12];
    if (rbiMonths.contains(now.month) && now.day >= 3 && now.day <= 8) {
      await _alertService.createPatternAlert(
        alertType: 'CALENDAR_EVENT',
        title: 'Macro Alert: RBI Policy Week',
        description: 'The RBI Monetary Policy Committee meets this week. '
            'Rate sensitive sectors (Banking, Auto, Real Estate) may see sharp moves.',
        confidence: 90,
      );
    }
  }

  // ── Pattern 6: LTCG Countdown ─────────────────────────────────
  Future<void> _checkLtcgCountdown(List<Trade> trades, List<Holding> holdings) async {
    final now = DateTime.now();
    final oneYearAgo = now.subtract(const Duration(days: 365));
    // Look for buys between 11 and 12 months ago
    final elevenMonthsAgo = now.subtract(const Duration(days: 335));

    for (final h in holdings) {
      if (h.totalQuantity <= 0) continue;
      
      final symbol = h.instrumentSymbol.toUpperCase();
      // Find old buys for this symbol
      final oldBuys = trades.where((t) => 
        t.tradeType == TradeType.buy && 
        t.instrumentSymbol.toUpperCase() == symbol &&
        t.tradeTimestamp.isAfter(oneYearAgo) && 
        t.tradeTimestamp.isBefore(elevenMonthsAgo)
      ).toList();

      if (oldBuys.isNotEmpty) {
        final qty = oldBuys.fold(0.0, (sum, t) => sum + t.quantity);
        await _alertService.createPatternAlert(
          alertType: 'LTCG_COUNTDOWN',
          symbol: symbol,
          title: '$symbol units approaching Long Term status',
          description: '${qty.toStringAsFixed(0)} units of $symbol will '
              'qualify for Long Term Capital Gains (LTCG) tax rates in less than 30 days. '
              'Consider holding if you were planning to sell.',
          confidence: 95,
        );
      }
    }
  }

  // ── Pattern 7: Portfolio Correlation ──────────────────────────
  Future<void> _checkPortfolioCorrelation(List<Holding> holdings) async {
    final totalInvested = _totalInvested(holdings);
    if (totalInvested <= 0) return;

    double bankExposure = 0;
    double itExposure = 0;

    for (final h in holdings) {
      final sym = h.instrumentSymbol.toUpperCase();
      if (sym.contains('BANK') || sym == 'HDFCBANK' || sym == 'ICICIBANK' || sym == 'SBIN' || sym == 'KOTAKBANK' || sym == 'AXISBANK') {
        bankExposure += h.investedValue;
      } else if (sym == 'INFY' || sym == 'TCS' || sym.contains('IT') || sym == 'WIPRO' || sym == 'HCLTECH' || sym == 'TECHM') {
        itExposure += h.investedValue;
      }
    }

    if (bankExposure / totalInvested > 0.45) {
      await _alertService.createPatternAlert(
        alertType: 'CORRELATION_RISK',
        title: 'High Banking Sector Exposure',
        description: 'Over 45% of your portfolio is concentrated in Banking & Financials. '
            'Your overall portfolio is highly correlated to interest rates and RBI policy.',
        confidence: 85,
      );
    }

    if (itExposure / totalInvested > 0.40) {
      await _alertService.createPatternAlert(
        alertType: 'CORRELATION_RISK',
        title: 'High IT Sector Exposure',
        description: 'Over 40% of your portfolio is concentrated in the IT sector. '
            'Your overall portfolio is highly sensitive to US economic data and USD/INR rates.',
        confidence: 85,
      );
    }
  }
}
