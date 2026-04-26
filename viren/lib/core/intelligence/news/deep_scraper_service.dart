import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:html/parser.dart' as html_parser;
import '../../ai/groq_service.dart';

/// A completely free, real-time intelligence engine.
/// It uses Google News RSS to find the latest articles for a specific query,
/// then visits those articles and scrapes their paragraph content for deep context.
class DeepScraperService {
  static const _timeout = Duration(seconds: 4);
  static const int _maxArticles = 3;
  static const int _maxParagraphsPerArticle = 4;

  static Future<String> _extractKeywords(String query) async {
    final prompt = '''[SYSTEM]
Extract 2-4 core search keywords from this query. Remove stop words, question words, and fluff.
Return ONLY the keywords separated by spaces. Do not return JSON.
Example: "What is the US - Iran war latest news" -> "US Iran war"
Example: "Why did ITC stock fall today?" -> "ITC stock fall"
[USER]
$query''';
    try {
      final response = await GroqService.chat(prompt: prompt, model: GroqService.lightModel, temperature: 0.1);
      if (response.isNotEmpty && response.length < 50) {
        return response.replaceAll('"', '').trim();
      }
    } catch (_) {}
    return query; // fallback
  }

  /// Fetches raw paragraph data from the web for a given query.
  /// Returns a compact string with the scraped content.
  static Future<String> scrapeDeepContext(String query) async {
    if (query.trim().isEmpty) return '';

    try {
      final searchTerms = await _extractKeywords(query);
      
      // 1. Fetch RSS Links
      final encodedQuery = Uri.encodeComponent('$searchTerms news');
      final rssUrl = 'https://news.google.com/rss/search?q=$encodedQuery&hl=en-IN&gl=IN&ceid=IN:en';
      
      final rssResponse = await http.get(Uri.parse(rssUrl)).timeout(_timeout);
      if (rssResponse.statusCode != 200) return '';

      final xmlDoc = XmlDocument.parse(rssResponse.body);
      final items = xmlDoc.findAllElements('item').take(_maxArticles).toList();
      
      if (items.isEmpty) return '';

      final buf = StringBuffer();
      buf.writeln('<<<DATA_BLOCK_BETA>>> (Deep Scraped Web Content — MUST cite sources):');

      // 2. Concurrently scrape the actual web pages
      final scrapeTasks = items.map((item) async {
        final title = item.findElements('title').firstOrNull?.innerText ?? 'Unknown Title';
        final link = item.findElements('link').firstOrNull?.innerText;
        final source = item.findElements('source').firstOrNull?.innerText ?? 'Web Source';
        final pubDate = item.findElements('pubDate').firstOrNull?.innerText ?? 'Recent';

        if (link == null || link.isEmpty) return null;

        // Fetch the HTML content
        try {
          // Google News RSS links often redirect. We follow redirects.
          final request = http.Request('GET', Uri.parse(link))..followRedirects = true;
          final htmlResponse = await http.Client().send(request).timeout(_timeout);
          final responseBody = await htmlResponse.stream.bytesToString();

          if (htmlResponse.statusCode != 200) return null;

          final document = html_parser.parse(responseBody);
          final paragraphs = document.querySelectorAll('p');
          
          final pTexts = <String>[];
          for (final p in paragraphs) {
            final text = p.text.trim();
            // Filter out short navigational/cookie paragraphs
            if (text.length > 50) {
              pTexts.add(text);
              if (pTexts.length >= _maxParagraphsPerArticle) break;
            }
          }

          if (pTexts.isEmpty) return null;

          return 'Source: $source | Headline: $title | Date: $pubDate\nContext: ${pTexts.join(' ')}\n';
        } catch (_) {
          return null; // Ignore individual scraping errors
        }
      });

      final results = await Future.wait(scrapeTasks);
      
      bool hasData = false;
      for (final result in results) {
        if (result != null) {
          buf.writeln(result);
          hasData = true;
        }
      }

      if (!hasData) return '';

      buf.writeln('Use the above scraped content to write a highly informational summary.');
      return buf.toString().trim();
    } catch (_) {
      // Return empty if the whole process fails
      return '';
    }
  }
}
