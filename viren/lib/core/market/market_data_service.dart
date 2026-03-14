import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Models ───────────────────────────────────────────────────────────────────

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

// ─── Market Data Service ──────────────────────────────────────────────────────

class MarketDataService {
  // query2 is more reliable and less rate-limited than query1
  static const _base2 = 'https://query2.finance.yahoo.com/v8/finance/chart';
  static const _base1 = 'https://query1.finance.yahoo.com/v8/finance/chart';

  // Yahoo crumb endpoint — needed to avoid empty responses during market hours
  static const _crumbUrl =
      'https://query2.finance.yahoo.com/v1/test/getcrumb';
  static const _cookieInitUrl = 'https://finance.yahoo.com';

  // Crumb + cookie cache
  String? _crumb;
  String? _cookie;
  DateTime? _crumbFetchedAt;
  static const _crumbTtl = Duration(hours: 4);

  // Data caches
  final Map<String, (List<OhlcvCandle>, DateTime)> _candleCache = {};
  final Map<String, (StockQuote, DateTime)> _quoteCache = {};
  static const _quoteCacheDuration = Duration(minutes: 3);
  static const _candleCacheDuration = Duration(minutes: 5);

  // Timeframe → (interval, range)
  static const _timeframeConfig = {
    '1D': ('5m', '1d'),
    '1W': ('15m', '5d'),
    '1M': ('1d', '1mo'),
    '1Y': ('1wk', '1y'),
    '3Y': ('1mo', '3y'),
    '5Y': ('1mo', '5y'),
    'ALL': ('3mo', 'max'),
  };

  // ── Full browser headers — required for Yahoo to respond correctly ─────────
  // These mimic a real Chrome browser on Android. Without proper headers
  // Yahoo returns 401 or empty chart data silently during market hours.
  Map<String, String> get _headers => {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-IN,en;q=0.9,hi;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Origin': 'https://finance.yahoo.com',
        'Referer': 'https://finance.yahoo.com/',
        'Sec-Fetch-Dest': 'empty',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'same-site',
        'Connection': 'keep-alive',
        if (_cookie != null) 'Cookie': _cookie!,
      };

  // ── Cookie + crumb initialisation ─────────────────────────────────────────
  // Yahoo Finance requires a session cookie obtained by visiting the homepage
  // and a crumb token. Without these, chart requests return empty during
  // peak hours even if the symbol is valid.
  Future<void> _ensureCrumb() async {
    // Return early if crumb is fresh
    if (_crumb != null &&
        _crumbFetchedAt != null &&
        DateTime.now().difference(_crumbFetchedAt!) < _crumbTtl) {
      return;
    }

    try {
      // Step 1 — visit Yahoo Finance to get session cookies
      final cookieResponse = await http
          .get(Uri.parse(_cookieInitUrl), headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-IN,en;q=0.9',
          })
          .timeout(const Duration(seconds: 8));

      // Extract Set-Cookie header
      final rawCookie = cookieResponse.headers['set-cookie'];
      if (rawCookie != null) {
        // Parse out just the cookie values, strip expiry/domain/path/flags
        final cookieParts = rawCookie
            .split(',')
            .map((part) => part.split(';').first.trim())
            .where((part) => part.contains('='))
            .join('; ');
        _cookie = cookieParts;
      }

      // Step 2 — get crumb using the cookie
      final crumbResponse = await http
          .get(Uri.parse(_crumbUrl), headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (crumbResponse.statusCode == 200) {
        final crumb = crumbResponse.body.trim();
        if (crumb.isNotEmpty && !crumb.startsWith('{')) {
          _crumb = crumb;
          _crumbFetchedAt = DateTime.now();
        }
      }
    } catch (_) {
      // Non-fatal — proceed without crumb. Many requests work without it
      // during off-peak hours. Crumb mainly helps during market hours.
    }
  }

  // ── Build URL with crumb if available ─────────────────────────────────────
  Uri _buildUrl(String base, String symbol, String suffix, String interval,
      String range) {
    final ticker = '$symbol.$suffix';
    final crumbParam = _crumb != null ? '&crumb=${Uri.encodeComponent(_crumb!)}' : '';
    return Uri.parse(
        '$base/$ticker?interval=$interval&range=$range$crumbParam');
  }

  // ── Fetch quote ────────────────────────────────────────────────────────────
  Future<StockQuote?> fetchQuote(String symbol) async {
    final sym = symbol.toUpperCase();

    // Check cache
    final cached = _quoteCache[sym];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _quoteCacheDuration) {
      return cached.$1;
    }

    await _ensureCrumb();

    // Try NSE first (.NS), then BSE (.BO)
    // Use 2d range to get both current price and previous close reliably
    StockQuote? quote;
    quote ??= await _fetchQuoteForSuffix(sym, 'NS');
    quote ??= await _fetchQuoteForSuffix(sym, 'BO');

    if (quote != null) {
      _quoteCache[sym] = (quote, DateTime.now());
    }
    return quote;
  }

  Future<StockQuote?> _fetchQuoteForSuffix(
      String symbol, String suffix) async {
    // Try query2 first (more reliable), fall back to query1
    StockQuote? result;
    result ??= await _tryFetchQuote(_base2, symbol, suffix);
    result ??= await _tryFetchQuote(_base1, symbol, suffix);
    return result;
  }

  Future<StockQuote?> _tryFetchQuote(
      String base, String symbol, String suffix) async {
    try {
      final url = _buildUrl(base, symbol, suffix, '1d', '2d');
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 401 || response.statusCode == 403) {
        // Cookie/crumb expired — reset so next call refreshes
        _crumb = null;
        _cookie = null;
        _crumbFetchedAt = null;
        return null;
      }

      if (response.statusCode != 200) { return null; }

      final json = jsonDecode(response.body);
      final result = json['chart']?['result'];
      if (result == null || (result as List).isEmpty) { return null; }

      final meta = result[0]['meta'];
      if (meta == null) { return null; }

      final double currentPrice =
          (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
      if (currentPrice == 0.0) { return null; }

      // Previous close — prefer chartPreviousClose over previousClose
      final double previousClose =
          (meta['chartPreviousClose'] as num?)?.toDouble() ??
              (meta['previousClose'] as num?)?.toDouble() ??
              currentPrice;

      final double dayChange = currentPrice - previousClose;
      final double dayChangePercent =
          previousClose != 0 ? (dayChange / previousClose) * 100 : 0.0;

      // 52-week range
      final double fiftyTwoWeekHigh =
          (meta['fiftyTwoWeekHigh'] as num?)?.toDouble() ?? currentPrice;
      final double fiftyTwoWeekLow =
          (meta['fiftyTwoWeekLow'] as num?)?.toDouble() ?? currentPrice;

      // Volume
      final int volume =
          (meta['regularMarketVolume'] as num?)?.toInt() ?? 0;
      final int avgVolume =
          (meta['averageDailyVolume3Month'] as num?)?.toInt() ?? 0;

      // Day high/low — prefer meta values, derive from candles as fallback
      double dayHigh =
          (meta['regularMarketDayHigh'] as num?)?.toDouble() ?? 0.0;
      double dayLow =
          (meta['regularMarketDayLow'] as num?)?.toDouble() ?? 0.0;

      // Derive from intraday candles if meta values missing
      if (dayHigh == 0.0 || dayLow == 0.0) {
        final indicators = result[0]['indicators']?['quote'];
        if (indicators != null && (indicators as List).isNotEmpty) {
          final highs = indicators[0]['high'] as List?;
          final lows = indicators[0]['low'] as List?;
          if (highs != null) {
            final validHighs =
                highs.whereType<num>().map((e) => e.toDouble()).toList();
            if (validHighs.isNotEmpty) {
              dayHigh = validHighs.reduce((a, b) => a > b ? a : b);
            }
          }
          if (lows != null) {
            final validLows =
                lows.whereType<num>().map((e) => e.toDouble()).toList();
            if (validLows.isNotEmpty) {
              dayLow = validLows.reduce((a, b) => a < b ? a : b);
            }
          }
        }
      }

      // Final fallback
      if (dayHigh == 0.0) { dayHigh = currentPrice; }
      if (dayLow == 0.0) { dayLow = currentPrice; }

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

  // ── Fetch candles ──────────────────────────────────────────────────────────
  Future<List<OhlcvCandle>> fetchCandles(
      String symbol, String timeframe) async {
    final sym = symbol.toUpperCase();
    final cacheKey = '$sym-$timeframe';

    final cached = _candleCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _candleCacheDuration) {
      return cached.$1;
    }

    final config = _timeframeConfig[timeframe];
    if (config == null) { return []; }
    final (interval, range) = config;

    await _ensureCrumb();

    // Try NSE first, then BSE
    var candles = await _fetchCandlesForSuffix(sym, 'NS', interval, range);
    if (candles.isEmpty) {
      candles = await _fetchCandlesForSuffix(sym, 'BO', interval, range);
    }

    if (candles.isNotEmpty) {
      _candleCache[cacheKey] = (candles, DateTime.now());
    }
    return candles;
  }

  Future<List<OhlcvCandle>> _fetchCandlesForSuffix(
      String symbol, String suffix, String interval, String range) async {
    // Try query2 first, then query1
    var candles = await _tryFetchCandles(_base2, symbol, suffix, interval, range);
    if (candles.isEmpty) {
      candles = await _tryFetchCandles(_base1, symbol, suffix, interval, range);
    }
    return candles;
  }

  Future<List<OhlcvCandle>> _tryFetchCandles(String base, String symbol,
      String suffix, String interval, String range) async {
    try {
      final url = _buildUrl(base, symbol, suffix, interval, range);
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        _crumb = null;
        _cookie = null;
        _crumbFetchedAt = null;
        return [];
      }

      if (response.statusCode != 200) { return []; }

      final json = jsonDecode(response.body);
      final result = json['chart']?['result'];
      if (result == null || (result as List).isEmpty) { return []; }

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
        if (i >= opens.length ||
            i >= highs.length ||
            i >= lows.length ||
            i >= closes.length) { break; }

        final o = opens[i];
        final h = highs[i];
        final l = lows[i];
        final c = closes[i];
        final v = volumes != null && i < volumes.length ? volumes[i] : null;

        // Skip null candles (market closed periods, pre/post market gaps)
        if (o == null || h == null || l == null || c == null) continue;

        // All prices are in INR from Yahoo for .NS/.BO symbols
        candles.add(OhlcvCandle(
          time: DateTime.fromMillisecondsSinceEpoch(
              (timestamps[i] as num).toInt() * 1000,
              isUtc: false),
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

  // ── Tooltip date format — dynamic based on timeframe ──────────────────────
  // Used by stock_detail_screen.dart to format candle timestamps correctly.
  // 1D → "10:35 AM"  |  1W → "Mon 10:35"  |  1M → "14 Jan"
  // 1Y → "Jan 2024"  |  3Y/5Y/ALL → "Jan 2024"
  static String formatCandleDate(DateTime time, String timeframe) {
    switch (timeframe) {
      case '1D':
        // Show time only — user knows it's today
        final h = time.hour;
        final m = time.minute.toString().padLeft(2, '0');
        final period = h >= 12 ? 'PM' : 'AM';
        final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        return '$hour:$m $period';

      case '1W':
        // Show day name + time
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final day = days[time.weekday - 1];
        final h = time.hour;
        final m = time.minute.toString().padLeft(2, '0');
        final period = h >= 12 ? 'PM' : 'AM';
        final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        return '$day $hour:$m $period';

      case '1M':
        // Show date + month
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return '${time.day} ${months[time.month - 1]}';

      case '1Y':
      case '3Y':
      case '5Y':
      case 'ALL':
        // Show month + year
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return '${months[time.month - 1]} ${time.year}';

      default:
        return '${time.day}/${time.month}/${time.year}';
    }
  }

  // ── X-axis label positions — evenly spaced for the chart ──────────────────
  // Returns indices of candles that should show a label on the x-axis.
  // Keeps it to 4-5 labels regardless of candle count.
  static List<int> xAxisLabelIndices(int totalCandles) {
    if (totalCandles <= 1) return [0];
    const targetLabels = 4;
    final step = (totalCandles / targetLabels).floor();
    if (step <= 0) return [0];
    final indices = <int>[];
    for (int i = 0; i < totalCandles; i += step) {
      indices.add(i);
    }
    // Always include last candle
    if (indices.last != totalCandles - 1) {
      indices.add(totalCandles - 1);
    }
    return indices;
  }

  /// Invalidate all caches — call on app resume or manual refresh
  void clearCache() {
    _candleCache.clear();
    _quoteCache.clear();
  }

  /// Clear crumb only — forces re-authentication on next request
  void clearCrumb() {
    _crumb = null;
    _cookie = null;
    _crumbFetchedAt = null;
  }
}