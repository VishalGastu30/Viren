import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/enums.dart';
import '../market/symbol_classifier.dart';
import 'rss_fetcher.dart';
import 'alert_trigger_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MacroEngine — Layer 4 Intelligence: macro-level event reasoning.
//
// Runs once per day (gated by timestamp stored in DB sentinel row).
// Fetches macro RSS feeds (RBI, SEBI, ET macro-level news).
// Asks Qwen to reason about the event against the user's portfolio
// composition — not generic commentary, but position-specific analysis.
//
// Privacy: no portfolio data leaves the device.
// All Qwen calls use the existing MethodChannel.
// ─────────────────────────────────────────────────────────────────────────────

class MacroEngine {
  final AppDatabase _db;
  late final AlertTriggerService _alertService;

  static const _llmChannel = MethodChannel('com.viren.viren/pdf_crypto');

  // Macro-level RSS feeds — different from news feeds in RssFetcher
  // These are slower-moving, policy-level sources
  static const Map<String, String> _macroFeeds = {
    'RBI Press Releases':
        'https://www.rbi.org.in/Scripts/RSSView.aspx',
    'SEBI Circulars':
        'https://www.sebi.gov.in/sebiweb/rss/RssServlet?type=circulars',
    'ET Markets Macro':
        'https://economictimes.indiatimes.com/markets/rss.cms',
  };



  MacroEngine(this._db) {
    _alertService = AlertTriggerService(_db);
  }

  /// Entry point called from InsightEngine.
  /// Checks if 24 hours have passed since last macro run.
  /// If yes, runs macro intelligence. If no, skips silently.
  Future<void> run() async {
    if (!await _shouldRunToday()) return;

    final holdings = await _db.select(_db.holdings).get();
    if (holdings.isEmpty) return;

    final portfolioContext = _buildPortfolioContext(holdings);
    final dynamicKeywords = _buildDynamicKeywords(holdings);

    String? modelPath;
    try {
      final basePath =
          await _llmChannel.invokeMethod<String>('getModelPath');
      modelPath =
          '$basePath/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';
    } catch (_) {
      return; // Model not available — skip silently
    }

    // Fetch macro items from up to 2 feeds per run
    final macroItems = await _fetchMacroItems();
    if (macroItems.isEmpty) return;

    // Run Qwen reasoning on macro items — max 3 per day to preserve
    // battery and avoid thermal buildup
    int qwenCallCount = 0;
    for (final item in macroItems) {
      if (qwenCallCount >= 3) break;
      if (!_isMacroRelevant(item, dynamicKeywords)) continue;

      try {
        final insight = await _reasonAboutMacroEvent(
          newsItem: item,
          portfolioContext: portfolioContext,
          modelPath: modelPath,
        );
        if (insight != null) {
          await _alertService.createMacroAlert(
            eventTitle: item.title,
            qwenInsight: insight['insight'] as String,
            affectedSymbol: insight['symbol'] as String?,
            source: item.source,
            relevanceScore: insight['score'] as int,
            // You may update createMacroAlert locally to accept signal if needed.
          );
          qwenCallCount++;
        }
      } catch (_) {
        continue;
      }
    }

    await _markRanToday();
  }

  /// Checks if macro engine ran today already.
  /// Uses a sentinel alert row in DB for background-isolate safety.
  Future<bool> _shouldRunToday() async {
    try {
      final prefs = await _getPrefs();
      final lastRun = prefs['macro_last_run'] as String?;
      final today =
          DateTime.now().toIso8601String().substring(0, 10); // yyyy-MM-dd
      return lastRun != today;
    } catch (_) {
      return true; // If we can't read, run anyway
    }
  }

  Future<void> _markRanToday() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await _savePrefs({'macro_last_run': today});
    } catch (_) {}
  }

  // Use drift's underlying SQLite for simple key-value storage
  // to avoid SharedPreferences plugin compatibility issues in background
  Future<Map<String, dynamic>> _getPrefs() async {
    final existing = await (_db.select(_db.alerts)
          ..where((a) => a.alertType.equals('MACRO_STATE'))
          ..limit(1))
        .getSingleOrNull();
    if (existing == null) return {};
    try {
      return jsonDecode(existing.triggerData) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _savePrefs(Map<String, dynamic> data) async {
    final existing = await (_db.select(_db.alerts)
          ..where((a) => a.alertType.equals('MACRO_STATE'))
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      final merged = {
        ...jsonDecode(existing.triggerData) as Map<String, dynamic>,
        ...data,
      };
      await (_db.update(_db.alerts)
            ..where((a) => a.id.equals(existing.id)))
          .write(AlertsCompanion(
        triggerData: Value(jsonEncode(merged)),
      ));
    } else {
      await _db.into(_db.alerts).insert(
        AlertsCompanion.insert(
          id: const Uuid().v4(),
          alertType: 'MACRO_STATE',
          severity: AlertSeverity.info,
          title: '_macro_state_sentinel',
          description: '_internal',
          triggerData: Value(jsonEncode(data)),
          dismissedAt: Value(DateTime.now()), // immediately dismiss so it never shows in feed
        ),
      );
    }
  }

  Future<List<RssItem>> _fetchMacroItems() async {
    final items = <RssItem>[];
    for (final entry in _macroFeeds.entries.take(2)) {
      try {
        final fetched = await RssFetcher.fetchFromUrl(
          url: entry.value,
          sourceName: entry.key,
          maxItems: 5,
        );
        items.addAll(fetched);
      } catch (_) {
        continue;
      }
    }
    return items;
  }

  /// Quick keyword filter — only send macro-relevant items to Qwen.
  bool _isMacroRelevant(RssItem item, List<String> keywords) {
    final text = item.fullText.toLowerCase();
    return keywords.any((kw) => text.contains(kw));
  }

  /// Asks Qwen to reason about a macro event against the user's
  /// specific portfolio composition.
  Future<Map<String, dynamic>?> _reasonAboutMacroEvent({
    required RssItem newsItem,
    required String portfolioContext,
    required String modelPath,
  }) async {
    final prompt =
        '''You are an experienced Indian stock market investor with 20 years of experience.
A retail investor's portfolio and a news event are shown below.
Your job: reason like a seasoned investor — not a robot.

Portfolio:
$portfolioContext

News: "${newsItem.title}"
Details: "${newsItem.description}"

Answer in this exact JSON format only, no other text:
{"relevant": true/false, "symbol": "MOST_AFFECTED_SYMBOL_OR_null", "score": 1-10, "signal": "BUY_OPPORTUNITY/RISK/HOLD/NEUTRAL", "insight": "one sentence max"}

Rules:
- relevant: true if this news has a clear, direct impact channel to any holding
- symbol: the most affected holding symbol from the portfolio
- score: 1-10 significance (8+ means notify immediately)
- signal: BUY_OPPORTUNITY if this creates a good entry, RISK if it threatens the position, HOLD if it reinforces holding, NEUTRAL if informational only
- insight: write like a trusted advisor — mention the holding by name, the price context, and what an experienced investor would think about it. Be specific, not generic.

If not relevant to any holding: {"relevant": false, "symbol": null, "score": 0, "signal": "NEUTRAL", "insight": ""}''';

    try {
      final response = await _llmChannel.invokeMethod<String>('chat', {
        'prompt': prompt,
        'modelPath': modelPath,
      });
      if (response == null || response.isEmpty) return null;
      final cleaned = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      if (parsed['relevant'] != true) return null;
      if ((parsed['score'] as int? ?? 0) < 5) return null;
      return {
        'symbol': parsed['symbol'] as String?,
        'insight': parsed['insight'] as String? ?? newsItem.title,
        'score': parsed['score'] as int? ?? 5,
        'signal': parsed['signal'] as String? ?? 'NEUTRAL',
      };
    } catch (_) {
      return null;
    }
  }

  String _buildPortfolioContext(List<Holding> holdings) {
    return SymbolClassifier.buildPortfolioQwenContext(holdings);
  }

  List<String> _buildDynamicKeywords(List<Holding> holdings) {
    final keywords = <String>{
      // Always watch these macro fundamentals
      'repo rate', 'rbi', 'sebi', 'inflation', 'cpi', 'gdp',
      'fed', 'federal reserve', 'rate cut', 'rate hike',
      'monetary policy', 'fiscal', 'budget', 'iip',
      'rupee', 'dollar', 'nifty', 'sensex',
      'gift nifty', 'sgx nifty',  // overnight indicator
      // US markets — relevant for NIFTYBEES and IT stocks
      's&p 500', 'nasdaq', 'dow jones', 'wall street',
    };

    // Add asset-class-specific keywords based on actual holdings
    for (final h in holdings) {
      final info = SymbolClassifier.classify(h.instrumentSymbol);
      for (final driver in info.macroDrIvers) {
        // Extract key nouns from the driver description
        keywords.addAll(driver.toLowerCase().split(' ')
            .where((w) => w.length > 4));
      }
      keywords.addAll(info.correlations.map((c) => c.toLowerCase()));
    }

    return keywords.toList();
  }
}
