import 'dart:math';
import '../../database/app_database.dart';
import '../../database/enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StatsService — Pure Statistical Computations
//
// No prediction. No forecasting. No advice. Facts only.
//
// All computations are pure functions over trade data:
//   • Rolling Min/Max/Average per holding
//   • Percentile positioning
//   • Realized volatility (std dev of trade prices)
//   • Trade frequency statistics
// ─────────────────────────────────────────────────────────────────────────────

/// Statistical summary for a single holding.
class HoldingStats {
  final String symbol;
  final double minTradePrice;
  final double maxTradePrice;
  final double avgTradePrice;
  final double currentAvgPrice; // from holdings cache
  final double percentilePosition; // 0–100, where current sits vs history
  final double realizedVolatility; // standard deviation of trade prices
  final int totalTrades;
  final int buyCount;
  final int sellCount;

  const HoldingStats({
    required this.symbol,
    required this.minTradePrice,
    required this.maxTradePrice,
    required this.avgTradePrice,
    required this.currentAvgPrice,
    required this.percentilePosition,
    required this.realizedVolatility,
    required this.totalTrades,
    required this.buyCount,
    required this.sellCount,
  });
}

/// Portfolio-wide frequency statistics.
class FrequencyStats {
  final double tradesPerWeek;
  final double tradesPerMonth;
  final double buyToSellRatio;
  final int totalTrades;
  final int totalBuys;
  final int totalSells;
  final int uniqueInstruments;

  const FrequencyStats({
    required this.tradesPerWeek,
    required this.tradesPerMonth,
    required this.buyToSellRatio,
    required this.totalTrades,
    required this.totalBuys,
    required this.totalSells,
    required this.uniqueInstruments,
  });
}

class StatsService {
  /// Computes statistics for a specific holding.
  ///
  /// [trades] — all trades for this symbol, any order.
  /// [holding] — current holding from cache (for currentAvgPrice).
  /// [windowDays] — rolling window for stats (null = all time).
  HoldingStats computeHoldingStats({
    required String symbol,
    required List<Trade> trades,
    required Holding? holding,
    int? windowDays,
  }) {
    // Filter to relevant trades
    var filtered = trades
        .where((t) => t.instrumentSymbol == symbol)
        .toList();

    if (windowDays != null) {
      final cutoff = DateTime.now().toUtc().subtract(Duration(days: windowDays));
      filtered = filtered.where((t) => t.tradeTimestamp.isAfter(cutoff)).toList();
    }

    if (filtered.isEmpty) {
      return HoldingStats(
        symbol: symbol,
        minTradePrice: 0,
        maxTradePrice: 0,
        avgTradePrice: 0,
        currentAvgPrice: holding?.averagePrice ?? 0,
        percentilePosition: 50,
        realizedVolatility: 0,
        totalTrades: 0,
        buyCount: 0,
        sellCount: 0,
      );
    }

    final prices = filtered.map((t) => t.pricePerUnit).toList();
    final minPrice = prices.reduce(min);
    final maxPrice = prices.reduce(max);
    final avgPrice = prices.reduce((a, b) => a + b) / prices.length;

    final currentAvg = holding?.averagePrice ?? avgPrice;

    // Percentile: where does current avg sit in the range of all trade prices?
    final sortedPrices = List<double>.from(prices)..sort();
    final percentile = _computePercentile(sortedPrices, currentAvg);

    // Realized volatility: standard deviation of trade prices
    final vol = _standardDeviation(prices);

    final buys = filtered.where((t) => t.tradeType == TradeType.buy).length;
    final sells = filtered.where((t) => t.tradeType == TradeType.sell).length;

    return HoldingStats(
      symbol: symbol,
      minTradePrice: minPrice,
      maxTradePrice: maxPrice,
      avgTradePrice: avgPrice,
      currentAvgPrice: currentAvg,
      percentilePosition: percentile,
      realizedVolatility: vol,
      totalTrades: filtered.length,
      buyCount: buys,
      sellCount: sells,
    );
  }

  /// Computes portfolio-wide trade frequency statistics.
  FrequencyStats computeFrequencyStats(List<Trade> trades) {
    if (trades.isEmpty) {
      return const FrequencyStats(
        tradesPerWeek: 0,
        tradesPerMonth: 0,
        buyToSellRatio: 0,
        totalTrades: 0,
        totalBuys: 0,
        totalSells: 0,
        uniqueInstruments: 0,
      );
    }

    final sorted = List.of(trades)
      ..sort((a, b) => a.tradeTimestamp.compareTo(b.tradeTimestamp));

    final firstDate = sorted.first.tradeTimestamp;
    final lastDate = sorted.last.tradeTimestamp;
    final spanDays = max(1, lastDate.difference(firstDate).inDays);

    final buys = trades.where((t) => t.tradeType == TradeType.buy).length;
    final sells = trades.where((t) => t.tradeType == TradeType.sell).length;
    final uniqueSymbols = trades.map((t) => t.instrumentSymbol).toSet().length;

    return FrequencyStats(
      tradesPerWeek: (trades.length / (spanDays / 7)).clamp(0, double.infinity),
      tradesPerMonth: (trades.length / (spanDays / 30)).clamp(0, double.infinity),
      buyToSellRatio: sells > 0 ? buys / sells : buys.toDouble(),
      totalTrades: trades.length,
      totalBuys: buys,
      totalSells: sells,
      uniqueInstruments: uniqueSymbols,
    );
  }

  /// Computes stats for ALL holdings at once.
  List<HoldingStats> computeAllHoldingStats({
    required List<Trade> trades,
    required List<Holding> holdings,
    int? windowDays,
  }) {
    return holdings.map((h) => computeHoldingStats(
      symbol: h.instrumentSymbol,
      trades: trades,
      holding: h,
      windowDays: windowDays,
    )).toList();
  }

  // ── Math helpers ──────────────────────────────────────────────────────────

  /// Computes the percentile rank of [value] within [sortedData].
  double _computePercentile(List<double> sortedData, double value) {
    if (sortedData.isEmpty) return 50;
    if (sortedData.length == 1) return 50;

    int below = 0;
    for (final d in sortedData) {
      if (d < value) below++;
    }

    return (below / sortedData.length * 100).clamp(0, 100);
  }

  /// Standard deviation of a list of values.
  double _standardDeviation(List<double> values) {
    if (values.length < 2) return 0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSquaredDiffs = values.fold<double>(
      0, (sum, v) => sum + pow(v - mean, 2),
    );
    return sqrt(sumSquaredDiffs / values.length);
  }
}
