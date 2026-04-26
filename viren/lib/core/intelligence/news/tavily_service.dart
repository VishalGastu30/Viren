import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Tavily Search API — used ONLY for live news/market questions.
/// Returns an AI-generated answer + source headlines.
///
/// Cost: 1 credit per basic search. Free tier: 1,000 credits/month.
/// This service is invoked ONLY when the user asks a news/market question
/// that cannot be answered from the knowledge base or portfolio data.
class TavilyService {
  static const _baseUrl = 'https://api.tavily.com/search';
  static const _timeout = Duration(seconds: 5);

  /// Map asset class → search query optimised for Indian market context.
  static const Map<String, String> _assetClassQueries = {
    'gold': 'gold price India today',
    'silver': 'silver price India today',
    'nifty': 'Nifty 50 India stock market today',
    'banking': 'Indian banking sector RBI news today',
    'commodity': 'commodity prices India today',
    'us_markets': 'US stock market S&P 500 Federal Reserve today',
    'macro_india': 'India economy GDP inflation RBI today',
  };

  /// Searches Tavily for the given asset class using the exact user query.
  /// Returns a compact string with the AI answer + top headlines.
  /// Returns empty string on failure — caller handles fallback.
  static Future<String> search(String assetClass, String userQuery) async {
    final apiKey = dotenv.env['tavily_api']?.replaceAll('"', '');
    if (apiKey == null || apiKey.isEmpty) return '';

    // Trust the exact user query if provided, otherwise fallback to asset class defaults
    final query = userQuery.trim().isNotEmpty
        ? userQuery.trim()
        : _assetClassQueries[assetClass.toLowerCase()] ?? 'Indian stock market news today';

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'api_key': apiKey,
              'query': query,
              'topic': 'news',
              'search_depth': 'basic', // 1 credit
              'max_results': 3,
              'include_answer': true, // AI-generated summary
              'include_raw_content': false,
              'include_images': false,
              'time_range': 'day', // last 24h only
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return '';

      final json = jsonDecode(response.body);

      final buf = StringBuffer();
      buf.writeln('<<<DATA_BLOCK_ALPHA>>> (verified, fetched now — MUST cite in response):');

      // 1. AI-generated answer (the gold mine)
      final answer = json['answer'] as String?;
      if (answer != null && answer.isNotEmpty) {
        // Trim to ~500 chars to save tokens
        final trimmed = answer.length > 500 ? answer.substring(0, 500) : answer;
        buf.writeln('<<<DATA_BLOCK_ALPHA>>> $trimmed (just now, AI Summary)');
      }

      // 2. Top headlines with sources
      final results = json['results'] as List? ?? [];
      if (results.isNotEmpty) {
        for (int i = 0; i < results.length && i < 3; i++) {
          final title = results[i]['title'] as String? ?? '';
          final url = results[i]['url'] as String? ?? '';
          // Extract domain name for citation
          final domain = Uri.tryParse(url)?.host.replaceAll('www.', '') ?? '';
          if (title.isNotEmpty) {
            final headline = title.length > 80 ? '${title.substring(0, 77)}...' : title;
            buf.writeln('<<<DATA_BLOCK_ALPHA>>> $headline (just now, $domain)');
          }
        }
      }

      buf.writeln('Your answer MUST start by referencing the most relevant news above.');
      return buf.toString().trim();
    } catch (_) {
      return '';
    }
  }
}
