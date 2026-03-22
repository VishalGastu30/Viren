import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../market/nse_price_service.dart';
import 'rss_fetcher.dart';
import 'alert_trigger_service.dart';
import 'notification_service.dart';
import 'macro_engine.dart';
import 'pattern_engine.dart';
import 'behaviour_engine.dart';
import 'price_alert_watcher.dart';
import 'storage_cleaner.dart';
import '../database/enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// InsightEngine — Orchestrates all intelligence layers.
//
// Called by InsightWorker (background) and by the app on foreground resume.
// Safe to call multiple times — all operations are idempotent.
// ─────────────────────────────────────────────────────────────────────────────

class InsightEngine {
  final AppDatabase _db;
  late final AlertTriggerService _alertService;

  // Cached prices from the last price intelligence run.
  // Shared with BehaviourEngine so it can do mirror warnings
  // without a second price fetch.
  Map<String, double> _lastFetchedPrices = {};

  static const _llmChannel =
      MethodChannel('com.viren.viren/pdf_crypto');

  InsightEngine(this._db) {
    _alertService = AlertTriggerService(_db);
  }

  /// Market hours check: IST 9:00 AM – 3:45 PM, Monday–Friday.
  static bool isMarketHours() {
    final now = DateTime.now().toUtc().add(
        const Duration(hours: 5, minutes: 30)); // Convert to IST
    final weekday = now.weekday; // 1=Mon, 7=Sun
    if (weekday == 6 || weekday == 7) return false; // Weekend
    final hour = now.hour;
    final minute = now.minute;
    final timeInMinutes = hour * 60 + minute;
    return timeInMinutes >= (9 * 60) &&
        timeInMinutes <= (15 * 60 + 45);
  }

  /// Main entry point — runs all intelligence layers.
  /// Called from WorkManager background task and manual refresh.
  /// Each layer is wrapped independently — one failure never
  /// cascades to another.
  Future<void> run() async {
    // Record when this run started — used by _sendPendingNotifications
    // so it finds ALL alerts created during this run, not just the
    // last 5 minutes (engines can take longer than 5 minutes).
    final runStartedAt = DateTime.now();

    // Flush any notifications that were queued during quiet hours
    try { await _flushQueuedNotifications(); } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final monitoringEnabled =
        prefs.getBool('alerts_monitoring_enabled') ?? true;
    if (!monitoringEnabled) return; // user disabled everything

    final priceEnabled = prefs.getBool('alerts_price_enabled') ?? true;
    final newsEnabled = prefs.getBool('alerts_news_enabled') ?? true;
    final macroEnabled = prefs.getBool('alerts_macro_enabled') ?? true;
    final patternEnabled =
        prefs.getBool('alerts_pattern_enabled') ?? true;
    final behaviourEnabled =
        prefs.getBool('alerts_behaviour_enabled') ?? true;

    if (priceEnabled) {
      try {
        await _runPriceIntelligence();
      } catch (_) {}
    }

    if (newsEnabled) {
      try {
        await _runNewsIntelligence();
      } catch (_) {}
    }

    if (macroEnabled) {
      try {
        // Layer 4: Macro intelligence (daily, gated internally)
        final macroEngine = MacroEngine(_db);
        await macroEngine.run();
      } catch (_) {}
    }

    if (patternEnabled) {
      try {
        // Layer 3: Pattern detection (pure Dart, no AI)
        final patternEngine = PatternEngine(_db);
        await patternEngine.run();
      } catch (_) {}
    }

    if (behaviourEnabled) {
      try {
        // Layer 5: Behaviour intelligence
        final behaviourEngine = BehaviourEngine(_db);
        await behaviourEngine.run(
          currentPrices: _lastFetchedPrices,
        );
      } catch (_) {}

      try {
        await _runBehaviourIntelligence(); // keep existing inactivity check
      } catch (_) {}
    }

    // Fire notifications for any new HIGH/CRITICAL alerts
    try {
      await _sendPendingNotifications(since: runStartedAt);
    } catch (_) {}

    // Daily maintenance
    try {
      final cleaner = StorageCleaner(_db);
      await cleaner.run();
    } catch (_) {}
  }

  /// Bypass de-duplication for manual refreshes (pull down on Insights Screen).
  Future<void> runForceCheck() async {
    final runStartedAt = DateTime.now();

    try { await _runPriceIntelligence(force: true); } catch (_) {}
    try { await _runNewsIntelligence(); } catch (_) {}
    try { await PatternEngine(_db).run(); } catch (_) {}
    try { await MacroEngine(_db).run(); } catch (_) {}
    try { await BehaviourEngine(_db).run(currentPrices: _lastFetchedPrices); } catch (_) {}
    try { await _runBehaviourIntelligence(); } catch (_) {}

    // Fire notifications for alerts created during this run
    try {
      await _sendPendingNotifications(since: runStartedAt);
    } catch (_) {}
  }

  // ── Layer 1: Price Intelligence ───────────────────────────────

  Future<void> _runPriceIntelligence({bool force = false}) async {
    if (!force && !isMarketHours()) return;

    final holdings = await _db.select(_db.holdings).get();
    if (holdings.isEmpty) return;

    final symbols =
        holdings.map((h) => h.instrumentSymbol.toUpperCase()).toList();
    final rawPrices = await NsePriceService.getPrices(symbols);
    // Filter nulls and cache for BehaviourEngine
    final prices = <String, double>{};
    rawPrices.forEach((k, v) { if (v != null) prices[k] = v; });
    _lastFetchedPrices = prices;

    // Track previous portfolio value for milestone check
    double totalCurrent = 0;
    double totalInvested = 0;

    for (final h in holdings) {
      final symbol = h.instrumentSymbol.toUpperCase();
      final cmp = prices[symbol];
      if (cmp == null) continue;

      final avgCost = h.averagePrice;
      totalCurrent += cmp * h.totalQuantity;
      totalInvested += h.investedValue;

      // Drawdown check: alert if down 5%+ from avg cost
      await _alertService.checkDrawdown(
        symbol: symbol,
        avgCost: avgCost,
        currentPrice: cmp,
        drawdownPct: 5.0,
      );

      // Recovery check: alert if recovering near avg cost
      await _alertService.checkRecovery(
        symbol: symbol,
        avgCost: avgCost,
        currentPrice: cmp,
      );

      // Momentum check: alert if price moved 3%+ since last run
      await _alertService.checkMomentum(
        symbol: symbol,
        currentPrice: cmp,
      );

      // Circuit breaker: need day change % — fetch from MarketDataService
      // Skip for now if not available from NsePriceService
      // TODO: integrate day change into NsePriceService response
    }

    // Portfolio milestone check
    await _alertService.checkPortfolioMilestone(
      previousValue: totalInvested, // use invested as proxy for previous
      currentValue: totalCurrent,
    );

    // Phase 4: check user-set price alerts
    final watcher = PriceAlertWatcher(_db);
    await watcher.check(_lastFetchedPrices);
  }

  // ── Layer 2: News Intelligence ────────────────────────────────

  Future<void> _runNewsIntelligence() async {
    final holdings = await _db.select(_db.holdings).get();
    if (holdings.isEmpty) return;

    final symbols =
        holdings.map((h) => h.instrumentSymbol.toUpperCase()).toList();

    // Fetch RSS items
    final newsItems = await RssFetcher.fetchRecent(
      maxFeedsPerRun: 2,
      maxItemsPerFeed: 8,
    );

    if (newsItems.isEmpty) return;

    // Get model path for Qwen
    String? modelPath;
    try {
      modelPath = await _llmChannel.invokeMethod<String>('getModelPath');
    } catch (_) {
      return; // Model not available — skip news intelligence
    }

    // Build holding names for context
    // Map NSE symbols to common names for better Qwen matching
    final holdingContext = _buildHoldingContext(symbols, holdings);

    for (final item in newsItems.take(5)) {
      // Rate limit: max 5 Qwen calls per background run
      try {
        final insight = await _scoreNewsRelevance(
          newsItem: item,
          holdingContext: holdingContext,
          modelPath: '$modelPath/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
        );

        if (insight != null) {
          await _alertService.createNewsAlert(
            symbol: insight['symbol'] as String,
            newsTitle: item.title,
            qwenInsight: insight['insight'] as String,
            newsSource: item.source,
            relevanceScore: insight['score'] as int,
          );
        }
      } catch (_) {
        continue;
      }
    }
  }

  /// Asks Qwen: is this news relevant to any of my holdings?
  /// Returns null if not relevant, or a map with symbol + insight + score.
  Future<Map<String, dynamic>?> _scoreNewsRelevance({
    required RssItem newsItem,
    required String holdingContext,
    required String modelPath,
  }) async {
    final prompt = '''You are analyzing financial news for a retail investor.

Their holdings: $holdingContext

News headline: "${newsItem.title}"
News summary: "${newsItem.description}"

Answer in this exact JSON format only, no other text:
{"relevant": true/false, "symbol": "SYMBOL_OR_NULL", "score": 1-10, "insight": "one sentence max"}

Rules:
- relevant: true only if this news directly affects one of their holdings
- symbol: the exact holding symbol affected (e.g. NIFTYBEES, GOLDBEES)
- score: 1-10 relevance (8+ = highly relevant, send notification)
- insight: explain impact on their specific position in one sentence

If not relevant to any holding, return: {"relevant": false, "symbol": null, "score": 0, "insight": ""}''';

    try {
      final response = await _llmChannel.invokeMethod<String>('chat', {
        'prompt': prompt,
        'modelPath': modelPath,
      });

      if (response == null || response.isEmpty) return null;

      // Parse JSON response
      final cleaned =
          response.replaceAll('```json', '').replaceAll('```', '').trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      if (json['relevant'] != true) return null;
      if ((json['score'] as int? ?? 0) < 6) return null;

      return {
        'symbol': json['symbol'] as String? ?? 'PORTFOLIO',
        'insight': json['insight'] as String? ?? newsItem.title,
        'score': json['score'] as int? ?? 6,
      };
    } catch (_) {
      return null;
    }
  }

  String _buildHoldingContext(
      List<String> symbols, List<Holding> holdings) {
    // Map symbols to human-readable names for better Qwen understanding
    const nameMap = {
      'NIFTYBEES': 'NIFTYBEES (Nifty 50 index ETF)',
      'GOLDBEES': 'GOLDBEES (Gold ETF)',
      'SILVERIETF': 'SILVERIETF (Silver ETF)',
      'YESBANK': 'YESBANK (Yes Bank equity)',
    };

    return holdings.map((h) {
      final sym = h.instrumentSymbol.toUpperCase();
      final name = nameMap[sym] ?? sym;
      final invested =
          '₹${h.investedValue.toStringAsFixed(0)} invested';
      return '$name ($invested)';
    }).join(', ');
  }

  // ── Layer 3: Behaviour Intelligence ──────────────────────────

  Future<void> _runBehaviourIntelligence() async {
    final trades = await (_db.select(_db.trades)
          ..orderBy(
              [(t) => drift.OrderingTerm.desc(t.tradeTimestamp)]))
        .get();

    if (trades.isEmpty) return;

    final lastTrade = trades.first;
    await _alertService.checkInactivity(
        lastTradeDate: lastTrade.tradeTimestamp);
  }

  // ── Notification dispatch ─────────────────────────────────────

  /// Flushes notifications that were generated during quiet hours.
  /// Runs at the start of every engine cycle.
  /// If quiet hours just ended, finds all alerts with notified=false
  /// and delivers them as a batch.
  Future<void> _flushQueuedNotifications() async {
    // Still in quiet hours — do nothing
    if (await NotificationService.isQuietHours()) return;

    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    final candidates = await (_db.select(_db.alerts)
          ..where((a) =>
              a.dismissedAt.isNull() &
              a.createdAt.isBiggerOrEqualValue(cutoff) &
              a.alertType.isNotValue('MACRO_STATE') &
              a.alertType.isNotValue('EMOTION_NOTE') &
              a.alertType.isNotValue('USER_STOP_LOSS') &
              a.alertType.isNotValue('USER_PRICE_TARGET') &
              a.alertType.isNotValue('PRICE_SNAPSHOT')))
        .get();

    final unnotified = candidates.where((a) {
      try {
        final data = jsonDecode(a.triggerData) as Map<String, dynamic>;
        return data['notified'] == false;
      } catch (_) {
        return false;
      }
    }).toList();

    if (unnotified.isEmpty) return;

    if (unnotified.length == 1) {
      final a = unnotified.first;
      await NotificationService.showAlertNotification(
        id: a.id.hashCode.abs(),
        title: a.title,
        body: a.description,
        severity: a.severity,
        payload: a.relatedInstrument != null
            ? '/holdings/${a.relatedInstrument}'
            : '/insights',
        alertId: a.id,
        db: _db,
      );
    } else {
      // Send each queued notification individually
      for (int i = 0; i < unnotified.length; i++) {
        final a = unnotified[i];
        await NotificationService.showAlertNotification(
          id: 3000 + i,
          title: a.title,
          body: a.description,
          severity: a.severity,
          payload: a.relatedInstrument != null
              ? '/holdings/${a.relatedInstrument}'
              : '/insights',
          alertId: a.id,
          db: _db,
        );
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }
  }

  Future<void> _sendPendingNotifications({DateTime? since}) async {
    // Only send notifications for alerts that haven't been notified yet.
    // The 'notified' flag in triggerData is set to false by _insert()
    // and to true after a notification is sent.
    // This prevents re-sending the same alerts on every refresh.

    // Use the provided start time, or fall back to 5 minutes ago.
    // When called from run() or runForceCheck(), 'since' is the exact
    // moment the run started — capturing ALL alerts from this cycle.
    final cutoff = since ?? DateTime.now().subtract(const Duration(minutes: 5));

    final recentAlerts = await (_db.select(_db.alerts)
          ..where((a) =>
              a.createdAt.isBiggerOrEqualValue(cutoff) &
              a.dismissedAt.isNull() &
              a.alertType.isNotValue('MACRO_STATE') &
              a.alertType.isNotValue('PRICE_SNAPSHOT') &
              a.alertType.isNotValue('EMOTION_NOTE') &
              a.alertType.isNotValue('OVERNIGHT_DATA') &
              a.alertType.isNotValue('USER_STOP_LOSS') &
              a.alertType.isNotValue('USER_PRICE_TARGET')))
        .get();

    // Filter to only unnotified alerts in Dart (triggerData is JSON)
    final newAlerts = recentAlerts.where((a) {
      try {
        final data = jsonDecode(a.triggerData) as Map<String, dynamic>;
        return data['notified'] == false;
      } catch (_) {
        return true; // treat as unnotified if flag missing
      }
    }).toList();

    if (newAlerts.isEmpty) return;

    // Check quiet hours once for the batch
    final quietHours = await NotificationService.isQuietHours();

    // Send INDIVIDUAL notification for each alert.
    // Do NOT batch/group — user wants to see each one separately.
    // Use a unique notification ID per alert (hash of alert ID).
    for (int i = 0; i < newAlerts.length; i++) {
      final alert = newAlerts[i];

      // During quiet hours, only send critical alerts
      if (quietHours && alert.severity != AlertSeverity.critical) {
        // Leave notified=false so _flushQueuedNotifications handles it later
        continue;
      }

      // Unique notification ID: use index offset from 2000 to avoid conflicts
      final notifId = 2000 + i;

      await NotificationService.showAlertNotification(
        id: notifId,
        title: alert.title,
        body: alert.description,
        severity: alert.severity,
        payload: alert.relatedInstrument != null
            ? '/holdings/${alert.relatedInstrument}'
            : '/insights',
        alertId: alert.id,
        db: _db,
      );

      // Small delay between notifications so they stack properly
      // in the notification tray instead of collapsing
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }
}
