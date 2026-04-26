import 'dart:convert';
import 'package:http/http.dart' as http;

class YahooHistoricalService {
  /// Fetches historical close prices for a given symbol.
  /// Converts internal symbols (e.g. GOLDBEES) to Yahoo format (GOLDBEES.NS).
  static Future<List<({DateTime date, double close})>> fetchHistorical(String symbol, String rangeTag) async {
    final String yRange;
    final String yInterval;

    if (rangeTag == 'max') {
       yRange = 'max'; yInterval = '1wk';
    } else if (rangeTag == '1y' || rangeTag == '365') {
       yRange = '1y'; yInterval = '1d';
    } else if (rangeTag == '1d' || rangeTag == '1') {
       yRange = '1d'; yInterval = '5m';
    } else {
       final intDays = int.tryParse(rangeTag.replaceAll('d', '')) ?? 30;
       final safeDays = intDays.clamp(7, 365 * 3);
       yRange = '${safeDays}d';
       yInterval = '1d';
    }
    
    final yahooSymbol = _mapToYahooSymbol(symbol);
    final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?range=$yRange&interval=$yInterval';
    
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body);
      final result = json['chart']['result'] as List?;
      if (result == null || result.isEmpty) return [];

      final timestamps = result[0]['timestamp'] as List?;
      final indicators = result[0]['indicators']['quote'][0];
      final closes = indicators['close'] as List?;

      if (timestamps == null || closes == null) return [];

      final data = <({DateTime date, double close})>[];
      for (int i = 0; i < timestamps.length; i++) {
        if (closes[i] != null) {
          final timestampStr = timestamps[i].toString();
          double timestampDouble;
          if (timestampStr.contains('.')) {
              timestampDouble = double.tryParse(timestampStr) ?? 0.0;
          } else {
              timestampDouble = int.tryParse(timestampStr)?.toDouble() ?? 0.0;
          }
          final date = DateTime.fromMillisecondsSinceEpoch((timestampDouble * 1000).toInt());
          
          final closeStr = closes[i].toString();
          final close = double.tryParse(closeStr) ?? 0.0;
          
          if (close > 0) {
            data.add((date: date, close: close));
          }
        }
      }
      return data;
    } catch (_) {
      return [];
    }
  }

  static String _mapToYahooSymbol(String symbol) {
    if (symbol.endsWith('.NS') || symbol.endsWith('.BO') || symbol.contains('=')) return symbol;
    // For Viren's specific tracking
    if (symbol == 'GOLDBEES' || symbol == 'SILVERIETF' || symbol == 'NIFTYBEES' || 
        symbol == 'YESBANK' || symbol == 'HDFCBANK' || symbol == 'ICICIBANK' ||
        symbol == 'KOTAKBANK' || symbol == 'SBIN' || symbol == 'AXISBANK') {
      return '$symbol.NS';
    }
    return '$symbol.NS'; // default guess
  }
}
