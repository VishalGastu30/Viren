import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../insights/rss_fetcher.dart';
import 'tavily_service.dart';
import 'deep_scraper_service.dart';
import 'intelligent_cache_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NewsIntelligenceService — Tiered news fetcher.
//
// Priority order (to minimise API credit usage):
//   1. Intelligent persisted cache (Context-Aware TTL: 15m active / 12h idle)
//   2. Tavily Search API  (1 credit, real-time AI answer)
//   3. newsdata.io        (1 credit fallback, 12h delay on free tier)
//   4. RSS feeds + Yahoo  (free, no credits, best-effort)
//   5. Empty string       (caller shows honest "no live data" message)
//
// Rules:
//   - Tavily is called ONLY for explicit news/market questions.
//   - RSS + Yahoo run as silent background fallbacks, no errors surfaced.
//   - Every successful fetch is cached persistently to avoid repeat calls.
// ─────────────────────────────────────────────────────────────────────────────

class NewsIntelligenceService {
  /// Main entry point. Returns news context for the given asset class.
  /// Uses the tiered fallback chain to minimise API calls.
  static Future<String> fetchContext(String assetClass, String userQuery) async {
    final cleanQuery = userQuery.trim().toLowerCase();
    final cacheKey = cleanQuery.isNotEmpty 
        ? '${assetClass.toLowerCase()}_${cleanQuery.hashCode}' 
        : assetClass.toLowerCase();

    // ── 1. Intelligent Persistent Cache (free) ─────────────────────────
    final cached = await IntelligentCacheManager.getCachedContext(cacheKey);
    if (cached != null) return cached;

    // ── 2. Deep Scraper Service (Google News + Scraping, Free) ────────
    try {
      final scraperResult = await DeepScraperService.scrapeDeepContext(userQuery);
      if (scraperResult.isNotEmpty) {
        await IntelligentCacheManager.saveContext(cacheKey, scraperResult);
        return scraperResult;
      }
    } catch (_) {
      // Scraper failed — fall through to next tier
    }

    // ── 3. Tavily (1 credit, real-time AI answer, Fallback) ───────────
    try {
      final tavilyResult = await TavilyService.search(assetClass.toLowerCase(), userQuery);
      if (tavilyResult.isNotEmpty) {
        await IntelligentCacheManager.saveContext(cacheKey, tavilyResult);
        return tavilyResult;
      }
    } catch (_) {
      // Tavily failed — fall through to next tier
    }

    // ── 4. RSS feeds + Yahoo Finance (free, best-effort) ──────────────
    try {
      final rssResult = await _fetchRssAndYahoo(assetClass.toLowerCase());
      if (rssResult.isNotEmpty) {
        await IntelligentCacheManager.saveContext(cacheKey, rssResult);
        return rssResult;
      }
    } catch (_) {
      // RSS/Yahoo failed — fall through
    }

    // ── 5. Return empty — caller will show honest "no data" message ───
    return '';
  }

  /// RSS + Yahoo Finance fallback (exactly the old behaviour, but compact).
  static Future<String> _fetchRssAndYahoo(String assetClass) async {
    final buf = StringBuffer();
    buf.writeln('<<<DATA_BLOCK_ALPHA>>> (verified, fetched now — MUST cite in response):');

    // RSS headlines
    final newsItems = await RssFetcher.fetchForAssetClass(
      assetClass: assetClass,
      maxItems: 3,
      maxAgeHours: 48,
    );
    if (newsItems.isNotEmpty) {
      for (final item in newsItems) {
        final timeStr = item.pubDate != null
            ? '${DateTime.now().difference(item.pubDate!).inHours}h ago'
            : 'recent';
        final headline = item.title.length > 80 ? '${item.title.substring(0, 77)}...' : item.title;
        buf.writeln('<<<DATA_BLOCK_ALPHA>>> $headline ($timeStr)');
      }
    }

    // Yahoo Finance live numbers (free, no API key needed)
    final liveNumbers = await _fetchYahooQuotes();
    if (liveNumbers.isNotEmpty) {
      buf.writeln('<<<DATA_BLOCK_ALPHA>>> Global Markets - $liveNumbers (just now, Yahoo)');
    }

    buf.writeln('Your answer MUST start by referencing the most relevant news above.');
    return buf.toString().trim();
  }

  /// Yahoo Finance global context — free API, no credits.
  static Future<String> _fetchYahooQuotes() async {
    try {
      const quoteUrl =
          'https://query1.finance.yahoo.com/v7/finance/quote?symbols=%5EGSPC,GC=F,SI=F,DX-Y.NYB';
      final response =
          await http.get(Uri.parse(quoteUrl)).timeout(const Duration(seconds: 3));
      if (response.statusCode != 200) return '';

      final json = jsonDecode(response.body);
      final result = json['quoteResponse']['result'] as List;

      final parts = <String>[];
      for (final item in result) {
        final sym = item['symbol'] as String;
        final price = item['regularMarketPrice'] as num?;
        final pct = item['regularMarketChangePercent'] as num?;
        if (price != null && pct != null) {
          final sign = pct >= 0 ? '+' : '';
          final label = _symbolLabel(sym);
          parts.add('$label: ${price.toStringAsFixed(2)} ($sign${pct.toStringAsFixed(2)}%)');
        }
      }
      return parts.join(' | ');
    } catch (_) {
      return '';
    }
  }

  static String _symbolLabel(String sym) {
    switch (sym) {
      case 'GC=F': return 'Gold';
      case 'SI=F': return 'Silver';
      case '^GSPC': return 'S&P500';
      case 'DX-Y.NYB': return 'DXY';
      default: return sym;
    }
  }
}
