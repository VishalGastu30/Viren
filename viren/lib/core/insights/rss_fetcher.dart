import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// RssFetcher — Fetches and parses public RSS feeds.
//
// No library needed — parses XML with simple string operations.
// Privacy: only public RSS URLs are fetched. No user data is sent.
// ─────────────────────────────────────────────────────────────────────────────

class RssItem {
  final String title;
  final String description;
  final String link;
  final DateTime? pubDate;
  final String source;

  const RssItem({
    required this.title,
    required this.description,
    required this.link,
    required this.source,
    this.pubDate,
  });

  /// Combined text for AI relevance scoring.
  String get fullText => '$title. $description'.trim();
}

class RssFetcher {
  // Public RSS feeds — all Indian market relevant
  static const Map<String, String> _feeds = {
    'ET Markets':
        'https://economictimes.indiatimes.com/markets/rss.cms',
    'Moneycontrol':
        'https://www.moneycontrol.com/rss/marketsindia.xml',
    'Reuters India':
        'https://feeds.reuters.com/reuters/INbusinessNews',
    'RBI':
        'https://www.rbi.org.in/Scripts/RSSView.aspx',
  };

  /// Fetches all feeds and returns deduplicated items from last 24 hours.
  /// Rotates through 2 feeds per call to save battery and avoid rate limits.
  static Future<List<RssItem>> fetchRecent({
    int maxFeedsPerRun = 2,
    int maxItemsPerFeed = 10,
  }) async {
    final items = <RssItem>[];
    final feedEntries = _feeds.entries.toList();

    // Rotate feeds: use hour of day to pick which 2 feeds to fetch
    final hour = DateTime.now().hour;
    final startIdx = (hour ~/ 2) % feedEntries.length;

    for (int i = 0; i < maxFeedsPerRun; i++) {
      final entry = feedEntries[(startIdx + i) % feedEntries.length];
      try {
        final fetched = await _fetchFeed(
          url: entry.value,
          sourceName: entry.key,
          maxItems: maxItemsPerFeed,
        );
        items.addAll(fetched);
      } catch (_) {
        // Individual feed failure is non-fatal
        continue;
      }
    }

    // Deduplicate by title
    final seen = <String>{};
    return items.where((item) => seen.add(item.title)).toList();
  }

  /// Fetches a specific RSS URL directly.
  /// Used by MacroEngine to fetch its own feed list.
  static Future<List<RssItem>> fetchFromUrl({
    required String url,
    required String sourceName,
    int maxItems = 5,
  }) async {
    try {
      return await _fetchFeed(
        url: url,
        sourceName: sourceName,
        maxItems: maxItems,
      );
    } catch (_) {
      return [];
    }
  }

  static Future<List<RssItem>> _fetchFeed({
    required String url,
    required String sourceName,
    required int maxItems,
  }) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return [];

    return _parseRss(response.body, sourceName, maxItems);
  }

  static List<RssItem> _parseRss(
      String xml, String source, int maxItems) {
    final items = <RssItem>[];

    // Extract all <item> blocks
    final itemRegex = RegExp(r'<item>([\s\S]*?)</item>');
    final matches = itemRegex.allMatches(xml).take(maxItems);

    for (final match in matches) {
      final block = match.group(1) ?? '';

      final title = _extractTag(block, 'title');
      final desc = _extractTag(block, 'description');
      final link = _extractTag(block, 'link');
      final pubDateStr = _extractTag(block, 'pubDate');

      if (title.isEmpty) continue;

      // Only include recent items (last 24 hours)
      DateTime? pubDate;
      try {
        pubDate = DateTime.parse(pubDateStr);
      } catch (_) {
        // pubDate parsing failed — include anyway, can't filter by time
      }

      if (pubDate != null &&
          DateTime.now().difference(pubDate).inHours > 24) {
        continue;
      }

      items.add(RssItem(
        title: _stripHtml(title),
        description: _stripHtml(desc).substring(
            0, _stripHtml(desc).length.clamp(0, 200)),
        link: link,
        source: source,
        pubDate: pubDate,
      ));
    }

    return items;
  }

  static String _extractTag(String xml, String tag) {
    final pattern = RegExp('<$tag[^>]*>([\\s\\S]*?)</$tag>');
    final match = pattern.firstMatch(xml);
    return match?.group(1)?.trim() ?? '';
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}
