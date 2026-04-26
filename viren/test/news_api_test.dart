// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:viren/core/intelligence/news/tavily_service.dart';
import 'package:viren/core/intelligence/news/newsdata_service.dart';

void main() {
  setUpAll(() async {
    // Load .env explicitly for tests
    await dotenv.load(fileName: ".env");
  });

  group('News API Tests', () {
    test('Tavily API should return data for "nifty"', () async {
      print('\\n--- Testing Tavily API (Primary) ---');
      final result = await TavilyService.search('nifty', 'nifty news');
      
      expect(result, isNotEmpty, reason: 'Tavily API returned an empty string. Check your API key or network.');
      
      print('✅ SUCCESS - Tavily returned:\\n\$result');
      // Ensure it has the structure we built
      expect(result.contains('NEWS SUMMARY:'), isTrue, reason: 'Tavily result missing NEWS SUMMARY');
      expect(result.contains('SOURCES:'), isTrue, reason: 'Tavily result missing SOURCES');
    });

    test('Newsdata.io API should return data for "nifty"', () async {
      print('\\n--- Testing Newsdata.io API (Fallback) ---');
      final result = await NewsdataService.fetchLatest('nifty');
      
      expect(result, isNotEmpty, reason: 'Newsdata API returned an empty string. Check your API key or network.');
      
      print('✅ SUCCESS - Newsdata returned:\\n\$result');
      // Ensure it has the structure we built
      expect(result.contains('RECENT NEWS:'), isTrue, reason: 'Newsdata result missing RECENT NEWS flag');
    });
  });
}
