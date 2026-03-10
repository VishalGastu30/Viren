import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NsePriceService {
  static final Map<String, _CachedPrice> _cache = {};
  static const _cacheDuration = Duration(minutes: 5);

  // NSE public API — no auth required, but needs browser-like headers
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/91.0.4472.120',
    'Accept': 'application/json',
    'Referer': 'https://www.nseindia.com',
  };

  /// Returns current market price for a symbol, or null if unavailable.
  static Future<double?> getPrice(String symbol) async {
    final upper = symbol.toUpperCase().trim();

    // Return cached price if fresh
    final cached = _cache[upper];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return cached.price;
    }

    try {
      final uri = Uri.parse(
          'https://www.nseindia.com/api/quote-equity?symbol=${Uri.encodeComponent(upper)}');
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final priceData = json['priceInfo'] as Map<String, dynamic>?;
        final price = (priceData?['lastPrice'] as num?)?.toDouble();
        if (price != null && price > 0) {
          _cache[upper] = _CachedPrice(price, DateTime.now());
          return price;
        }
      }
    } catch (e) {
      debugPrint('NSE price fetch failed for $upper: $e');
    }

    // Fallback: try BSE via alternative endpoint
    try {
      final uri = Uri.parse(
          'https://www.nseindia.com/api/quote-equity?symbol=${Uri.encodeComponent(upper)}&series=EQ');
      final response = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final price =
            (json['priceInfo']?['lastPrice'] as num?)?.toDouble();
        if (price != null && price > 0) {
          _cache[upper] = _CachedPrice(price, DateTime.now());
          return price;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Fetch prices for multiple symbols concurrently.
  static Future<Map<String, double?>> getPrices(
      List<String> symbols) async {
    final results = await Future.wait(
      symbols.map((s) async => MapEntry(s.toUpperCase(), await getPrice(s))),
    );
    return Map.fromEntries(results);
  }

  static void clearCache() => _cache.clear();
}

class _CachedPrice {
  final double price;
  final DateTime fetchedAt;
  const _CachedPrice(this.price, this.fetchedAt);
}
