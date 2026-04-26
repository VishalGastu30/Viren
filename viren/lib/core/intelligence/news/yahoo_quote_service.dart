import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

class YahooQuoteService {
  /// Fuzzy searches for a symbol name using Yahoo Autocomplete API.
  /// Example: "Idea" -> "IDEA.NS"
  static Future<String?> searchSymbol(String query) async {
    if (query.trim().isEmpty) return null;
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://query2.finance.yahoo.com/v1/finance/search?q=$encodedQuery&quotesCount=1&newsCount=0';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      
      if (response.statusCode != 200) return null;
      
      final json = jsonDecode(response.body);
      final quotes = json['quotes'] as List?;
      if (quotes != null && quotes.isNotEmpty) {
        // Prefer Indian equities (.NS or .BO) if available, else take the first
        final nseQuote = quotes.firstWhere((q) => q['symbol'].toString().endsWith('.NS'), orElse: () => quotes.first);
        return nseQuote['symbol']?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches real-time price snapshot for a given Yahoo symbol.
  /// Returns null if fetching fails.
  static Future<({double cmp, double dayChangePct, double dayChangeAbs, String name})?> fetchQuote(String symbol) async {
    final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=1d&interval=1d';
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final result = json['chart']['result'] as List?;
      if (result == null || result.isEmpty) return null;

      final meta = result[0]['meta'];
      if (meta == null) return null;

      final cmp = (meta['regularMarketPrice'] as num).toDouble();
      final prevClose = (meta['chartPreviousClose'] as num).toDouble();
      final name = meta['shortName'] ?? meta['symbol'] ?? symbol;
      
      final dayChangeAbs = cmp - prevClose;
      final dayChangePct = prevClose > 0 ? (dayChangeAbs / prevClose) * 100 : 0.0;

      return (
        cmp: cmp,
        dayChangePct: dayChangePct,
        dayChangeAbs: dayChangeAbs,
        name: name.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetches 1-month historical data for charting.
  /// Returns a map of timestamps (seconds since epoch) to close prices.
  static Future<Map<int, double>?> fetchHistoricalData(String symbol, {String range = '1mo'}) async {
    final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=$range&interval=1d';
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final result = json['chart']['result'] as List?;
      if (result == null || result.isEmpty) return null;

      final timestamps = List<int>.from(result[0]['timestamp'] ?? []);
      final closes = List<num?>.from(result[0]['indicators']['quote'][0]['close'] ?? []);
      
      if (timestamps.isEmpty || closes.isEmpty) return null;

      final map = <int, double>{};
      for (int i = 0; i < math.min(timestamps.length, closes.length); i++) {
        if (closes[i] != null) {
          map[timestamps[i]] = closes[i]!.toDouble();
        }
      }
      return map;
    } catch (_) {
      return null;
    }
  }

  /// Maps common classification asset classes to their primary Yahoo ticker.
  static String mapAssetClassToSymbol(String assetClass) {
    switch (assetClass) {
      case 'nifty': return '^NSEI';
      case 'sensex': return '^BSESN';
      case 'gold': return 'GC=F';
      case 'silver': return 'SI=F';
      case 'copper': return 'HG=F';
      case 'banking': return '^NSEBANK'; // Bank Nifty
      case 'us_markets': return '^IXIC'; // NASDAQ
      default: return '^NSEI';
    }
  }
}
