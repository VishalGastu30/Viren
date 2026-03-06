import 'dart:convert';
import 'package:http/http.dart' as http;

class MarketDataService {
  static const _baseUrl = 'https://query1.finance.yahoo.com/v8/finance/chart';

  // Cache: symbol+timeframe → (data, fetchedAt)
  final Map<String, (List<OhlcvCandle>, DateTime)> _candleCache = {};
  final Map<String, (StockQuote, DateTime)> _quoteCache = {};
  static const _cacheDuration = Duration(minutes: 5);

  // Timeframe config: timeframe → (interval, range)
  static const _timeframeConfig = {
    '1D': ('5m', '1d'),
    '1W': ('15m', '5d'),
    '1M': ('1d', '1mo'),
    '1Y': ('1wk', '1y'),
    '3Y': ('1mo', '3y'),
    '5Y': ('1mo', '5y'),
    'ALL': ('3mo', 'max'),
  };

  /// Fetch current quote for a symbol. Tries .NS (NSE) first, then .BO (BSE).
  Future<StockQuote?> fetchQuote(String symbol) async {
    // Check cache
    final cached = _quoteCache[symbol];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _cacheDuration) {
      return cached.$1;
    }

    // Try NSE first, fallback to BSE
    var quote = await _fetchQuoteForSuffix(symbol, 'NS');
    quote ??= await _fetchQuoteForSuffix(symbol, 'BO');

    if (quote != null) {
      _quoteCache[symbol] = (quote, DateTime.now());
    }
    return quote;
  }

  Future<StockQuote?> _fetchQuoteForSuffix(
      String symbol, String suffix) async {
    try {
      final url = Uri.parse('$_baseUrl/$symbol.$suffix?interval=1d&range=5d');
      final response = await http
          .get(url, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final result = json['chart']?['result'];
      if (result == null || (result as List).isEmpty) return null;

      final meta = result[0]['meta'];
      if (meta == null) return null;

      final double currentPrice =
          (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
      if (currentPrice == 0.0) return null;

      final double previousClose =
          (meta['chartPreviousClose'] as num?)?.toDouble() ?? currentPrice;
      final double dayChange = currentPrice - previousClose;
      final double dayChangePercent =
          previousClose != 0 ? (dayChange / previousClose) * 100 : 0.0;

      final double fiftyTwoWeekHigh =
          (meta['fiftyTwoWeekHigh'] as num?)?.toDouble() ?? currentPrice;
      final double fiftyTwoWeekLow =
          (meta['fiftyTwoWeekLow'] as num?)?.toDouble() ?? currentPrice;
      final int volume =
          (meta['regularMarketVolume'] as num?)?.toInt() ?? 0;
      final int avgVolume =
          (meta['averageDailyVolume3Month'] as num?)?.toInt() ?? 0;

      // Derive day high/low from intraday candles if available
      double dayHigh = currentPrice;
      double dayLow = currentPrice;
      final indicators = result[0]['indicators']?['quote'];
      if (indicators != null && (indicators as List).isNotEmpty) {
        final highs = indicators[0]['high'] as List?;
        final lows = indicators[0]['low'] as List?;
        if (highs != null) {
          final validHighs = highs.whereType<num>().map((e) => e.toDouble());
          if (validHighs.isNotEmpty) {
            dayHigh = validHighs.reduce((a, b) => a > b ? a : b);
          }
        }
        if (lows != null) {
          final validLows = lows.whereType<num>().map((e) => e.toDouble());
          if (validLows.isNotEmpty) {
            dayLow = validLows.reduce((a, b) => a < b ? a : b);
          }
        }
      }

      // Override with meta values if available
      dayHigh = (meta['regularMarketDayHigh'] as num?)?.toDouble() ?? dayHigh;
      dayLow = (meta['regularMarketDayLow'] as num?)?.toDouble() ?? dayLow;

      return StockQuote(
        symbol: symbol,
        currentPrice: currentPrice,
        dayChange: dayChange,
        dayChangePercent: dayChangePercent,
        dayHigh: dayHigh,
        dayLow: dayLow,
        fiftyTwoWeekHigh: fiftyTwoWeekHigh,
        fiftyTwoWeekLow: fiftyTwoWeekLow,
        volume: volume,
        avgVolume: avgVolume,
        fetchedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetch OHLCV candles for a symbol and timeframe.
  Future<List<OhlcvCandle>> fetchCandles(
      String symbol, String timeframe) async {
    final cacheKey = '$symbol-$timeframe';
    final cached = _candleCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _cacheDuration) {
      return cached.$1;
    }

    final config = _timeframeConfig[timeframe];
    if (config == null) return [];
    final (interval, range) = config;

    // Try NSE first, then BSE
    var candles = await _fetchCandlesForSuffix(symbol, 'NS', interval, range);
    if (candles.isEmpty) {
      candles = await _fetchCandlesForSuffix(symbol, 'BO', interval, range);
    }

    if (candles.isNotEmpty) {
      _candleCache[cacheKey] = (candles, DateTime.now());
    }
    return candles;
  }

  Future<List<OhlcvCandle>> _fetchCandlesForSuffix(
      String symbol, String suffix, String interval, String range) async {
    try {
      final url = Uri.parse(
          '$_baseUrl/$symbol.$suffix?interval=$interval&range=$range');
      final response = await http
          .get(url, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body);
      final result = json['chart']?['result'];
      if (result == null || (result as List).isEmpty) return [];

      final timestamps = result[0]['timestamp'] as List?;
      final indicators = result[0]['indicators']?['quote'];
      if (timestamps == null ||
          indicators == null ||
          (indicators as List).isEmpty) {
        return [];
      }

      final quote = indicators[0];
      final opens = quote['open'] as List?;
      final highs = quote['high'] as List?;
      final lows = quote['low'] as List?;
      final closes = quote['close'] as List?;
      final volumes = quote['volume'] as List?;

      if (opens == null || highs == null || lows == null || closes == null) {
        return [];
      }

      final candles = <OhlcvCandle>[];
      for (int i = 0; i < timestamps.length; i++) {
        final o = opens[i];
        final h = highs[i];
        final l = lows[i];
        final c = closes[i];
        final v = volumes?[i];
        // Skip null candles
        if (o == null || h == null || l == null || c == null) continue;

        candles.add(OhlcvCandle(
          time: DateTime.fromMillisecondsSinceEpoch(
              (timestamps[i] as num).toInt() * 1000),
          open: (o as num).toDouble(),
          high: (h as num).toDouble(),
          low: (l as num).toDouble(),
          close: (c as num).toDouble(),
          volume: (v as num?)?.toInt() ?? 0,
        ));
      }
      return candles;
    } catch (_) {
      return [];
    }
  }

  /// Invalidate all caches.
  void clearCache() {
    _candleCache.clear();
    _quoteCache.clear();
  }
}

class StockQuote {
  final String symbol;
  final double currentPrice;
  final double dayChange;
  final double dayChangePercent;
  final double dayHigh;
  final double dayLow;
  final double fiftyTwoWeekHigh;
  final double fiftyTwoWeekLow;
  final int volume;
  final int avgVolume;
  final DateTime fetchedAt;

  const StockQuote({
    required this.symbol,
    required this.currentPrice,
    required this.dayChange,
    required this.dayChangePercent,
    required this.dayHigh,
    required this.dayLow,
    required this.fiftyTwoWeekHigh,
    required this.fiftyTwoWeekLow,
    required this.volume,
    required this.avgVolume,
    required this.fetchedAt,
  });
}

class OhlcvCandle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  const OhlcvCandle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });
}
