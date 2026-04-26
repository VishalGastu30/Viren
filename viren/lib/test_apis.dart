// ignore_for_file: avoid_print
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:viren/core/intelligence/news/tavily_service.dart';
import 'package:viren/core/intelligence/news/newsdata_service.dart';

void main() async {
  await dotenv.load(fileName: ".env");

  print('=== Testing Tavily API (Primary) ===');
  final tavilyResult = await TavilyService.search('nifty', 'nifty news');
  if (tavilyResult.isNotEmpty) {
    print('✅ SUCCESS - Tavily returned:\n$tavilyResult');
  } else {
    print('❌ FAILED - Tavily returned empty');
  }

  print('\n=== Testing Newsdata.io API (Fallback) ===');
  final newsdataResult = await NewsdataService.fetchLatest('nifty');
  if (newsdataResult.isNotEmpty) {
    print('✅ SUCCESS - Newsdata returned:\n$newsdataResult');
  } else {
    print('❌ FAILED - Newsdata returned empty');
  }
}
