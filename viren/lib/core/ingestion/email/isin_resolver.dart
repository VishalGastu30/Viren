import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


import '../../market/nse_price_service.dart';

/// Resolves ISINs to actual NSE trading symbols using persistent local caching
/// and the NSE Autocomplete API as a fallback.
class IsinResolver {
  static const _prefKey = 'dynamic_isin_to_symbol_map';
  final Map<String, String> _cache = {};
  bool _initialized = false;

  /// Ensure SharedPreferences cache is loaded into memory
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString(_prefKey);
      if (storedJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(storedJson);
        _cache.addAll(decoded.map((k, v) => MapEntry(k, v.toString())));
      }
    } catch (e) {
      debugPrint('[IsinResolver] Failed to load persistent cache: $e');
    }
    _initialized = true;
  }

  /// Resolve an ISIN.
  /// 1. Checks memory cache
  /// 2. If not found, calls NSE autocomplete search
  /// 3. Validates symbol by hitting price API
  /// 4. Falls back to description-based mapping if network fails
  Future<String> resolve(String isin, String description,
      {required String Function(String) fallbackDeriver}) async {
    await init();

    if (_cache.containsKey(isin)) {
      return _cache[isin]!;
    }

    try {
      debugPrint('[IsinResolver] Querying NSE for unknown ISIN: $isin');

      final uri = Uri.parse(
          'https://www.nseindia.com/api/search/autocomplete?q=$isin');
      final response = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'application/json',
        'Referer': 'https://www.nseindia.com/',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final symbols = json['symbols'] as List<dynamic>?;

        if (symbols != null && symbols.isNotEmpty) {
          // Find the precise equity symbol map
          for (final rawItem in symbols) {
            final item = rawItem as Map<String, dynamic>;
            if (item['symbol'] != null) {
              final symbol = item['symbol'] as String;

              // Validate it can be fetched
              final testPrice = await NsePriceService.getPrice(symbol);
              if (testPrice != null && testPrice > 0) {
                await _persistMapping(isin, symbol);
                debugPrint(
                    '[IsinResolver] Successfully mapped $isin → $symbol via API');
                return symbol;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[IsinResolver] Network resolution failed for $isin: $e');
    }

    // Network completely failed or NSE changed API → structural fallback
    debugPrint(
        '[IsinResolver] Failing back to description parser for $isin...');
    final derived = fallbackDeriver(description);
    return derived;
  }

  Future<void> _persistMapping(String isin, String symbol) async {
    _cache[isin] = symbol;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_cache));
    } catch (_) {}
  }
}
