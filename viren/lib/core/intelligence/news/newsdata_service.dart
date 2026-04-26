import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// newsdata.io API — used as FALLBACK when Tavily fails.
/// Uses the "Latest" endpoint with business category and India country.
///
/// Free tier: 200 credits/day, 12h delay. 1 credit = 10 articles.
/// This service is invoked ONLY when Tavily fails or is unavailable.
class NewsdataService {
  static const _baseUrl = 'https://newsdata.io/api/1/latest';
  static const _timeout = Duration(seconds: 5);

  /// Map asset class → search keywords for newsdata.io.
  static const Map<String, String> _assetClassKeywords = {
    'gold': 'gold price',
    'silver': 'silver price',
    'nifty': 'Nifty stock market',
    'banking': 'banking RBI',
    'commodity': 'commodity prices',
    'us_markets': 'US stock market Federal Reserve',
    'macro_india': 'India economy GDP inflation',
  };

  /// Fetches latest news from newsdata.io for the given asset class.
  /// Returns compact string with headlines.
  /// Returns empty string on failure — caller handles fallback.
  static Future<String> fetchLatest(String assetClass, {String? userQuery}) async {
    final apiKey = dotenv.env['newsdata_api']?.replaceAll('"', '');
    if (apiKey == null || apiKey.isEmpty) return '';

    final keywords = (userQuery != null && userQuery.trim().isNotEmpty)
        ? userQuery.trim()
        : _assetClassKeywords[assetClass.toLowerCase()] ?? 'Indian stock market';

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'apikey': apiKey,
        'q': keywords,
        'category': 'business',
        'country': 'in',
        'language': 'en',
        'size': '5', // 5 articles, costs 1 credit
      });

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) return '';

      final json = jsonDecode(response.body);
      final results = json['results'] as List? ?? [];

      if (results.isEmpty) return '';

      final buf = StringBuffer();
      buf.writeln('<<<DATA_BLOCK_ALPHA>>> (verified, fetched now — MUST cite in response):');
      for (int i = 0; i < results.length && i < 5; i++) {
        final title = results[i]['title'] as String? ?? '';
        final source = results[i]['source_name'] as String? ?? '';
        final pubDate = results[i]['pubDate'] as String? ?? '';
        if (title.isNotEmpty) {
          final headline = title.length > 80 ? '${title.substring(0, 77)}...' : title;
          buf.writeln('<<<DATA_BLOCK_ALPHA>>> $headline ($pubDate, $source)');
        }
      }

      buf.writeln('Your answer MUST start by referencing the most relevant news above.');
      return buf.toString().trim();
    } catch (_) {
      return '';
    }
  }
}
