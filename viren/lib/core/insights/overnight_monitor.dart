import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart';
import 'package:workmanager/workmanager.dart';
import '../database/app_database.dart';
import '../database/enums.dart';
import '../market/symbol_classifier.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'rss_fetcher.dart';
import 'notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OvernightMonitor — Viren never sleeps, just goes quiet.
//
// During quiet hours (default 10 PM – 8 AM):
//   - RSS feeds are still fetched
//   - Global market data is fetched (Gift Nifty, US markets, gold spot)
//   - Qwen reasons about overnight events
//   - Alerts are stored in DB with notified=false
//
// When quiet hours end (8 AM):
//   - Morning briefing fires as a single, curated notification
//   - Summarises everything that happened overnight
//   - "While you slept: ..."
//
// The morning briefing is a separate WorkManager one-off task
// scheduled to fire at exactly the quiet hours end time.
// ─────────────────────────────────────────────────────────────────────────────

const kMorningBriefingTask = 'viren_morning_briefing';

class OvernightMonitor {
  final AppDatabase _db;

  // Overnight data sources — these work 24/7
  static const _overnightFeeds = {
    'Reuters Global':
        'https://feeds.reuters.com/reuters/businessNews',
    'ET Markets':
        'https://economictimes.indiatimes.com/markets/rss.cms',
    'RBI':
        'https://www.rbi.org.in/Scripts/RSSView.aspx',
  };

  // Gold spot via Yahoo Finance (GLD proxy or XAU=X)
  static const _goldSpotUrl =
      'https://query2.finance.yahoo.com/v8/finance/chart/GC%3DF?interval=1d&range=2d';

  // S&P 500 closing
  static const _sp500Url =
      'https://query2.finance.yahoo.com/v8/finance/chart/%5EGSPC?interval=1d&range=2d';

  OvernightMonitor(this._db);

  /// Called by InsightEngine during every overnight run.
  /// Fetches overnight data, stores insights, schedules morning briefing.
  Future<void> run() async {
    final holdings = await _db.select(_db.holdings).get();
    if (holdings.isEmpty) return;

    // Fetch overnight data points
    final overnightData = await _fetchOvernightData(holdings);

    // Store as OVERNIGHT_DATA sentinel for morning briefing
    await _storeOvernightData(overnightData);

    // Schedule morning briefing to fire at quiet hours end
    await _scheduleMorningBriefing();
  }

  Future<Map<String, dynamic>> _fetchOvernightData(
      List<Holding> holdings) async {
    final data = <String, dynamic>{};

    // Fetch US market data
    try {
      final sp500 = await _fetchLastClose(_sp500Url, 'S&P 500');
      if (sp500 != null) data['sp500'] = sp500;
    } catch (_) {}

    // Fetch gold spot
    try {
      final gold = await _fetchLastClose(_goldSpotUrl, 'Gold');
      if (gold != null) data['gold_spot'] = gold;
    } catch (_) {}

    // Fetch RSS overnight news
    try {
      final newsItems = <Map<String, String>>[];
      for (final entry in _overnightFeeds.entries.take(2)) {
        final items = await RssFetcher.fetchFromUrl(
          url: entry.value,
          sourceName: entry.key,
          maxItems: 5,
        );
        newsItems.addAll(items
            .take(3)
            .map((i) => {'title': i.title, 'source': i.source}));
      }
      data['news'] = newsItems;
    } catch (_) {}

    data['holdings_context'] =
        SymbolClassifier.buildPortfolioQwenContext(holdings);
    data['fetched_at'] = DateTime.now().toIso8601String();

    return data;
  }

  Future<Map<String, double>?> _fetchLastClose(
      String url, String label) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14) Chrome/124.0.0.0',
            'Accept': 'application/json',
          })
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body);
      final result = json['chart']?['result'];
      if (result == null || (result as List).isEmpty) return null;

      final meta = result[0]['meta'];
      final price = (meta['regularMarketPrice'] as num?)?.toDouble();
      final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble();

      if (price == null) return null;

      final changePct = prevClose != null && prevClose > 0
          ? ((price - prevClose) / prevClose) * 100
          : 0.0;

      return {'price': price, 'changePct': changePct};
    } catch (_) {
      return null;
    }
  }

  Future<void> _storeOvernightData(Map<String, dynamic> data) async {
    // Store as OVERNIGHT_DATA sentinel — same pattern as MACRO_STATE
    final existing = await (_db.select(_db.alerts)
          ..where((a) => a.alertType.equals('OVERNIGHT_DATA'))
          ..limit(1))
        .getSingleOrNull();

    final encoded = jsonEncode(data);
    if (existing != null) {
      await (_db.update(_db.alerts)
            ..where((a) => a.id.equals(existing.id)))
          .write(AlertsCompanion(triggerData: Value(encoded)));
    } else {
      await _db.into(_db.alerts).insert(
        AlertsCompanion.insert(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          alertType: 'OVERNIGHT_DATA',
          severity: AlertSeverity.info,
          title: '_overnight_data_sentinel',
          description: '_internal',
          triggerData: Value(encoded),
          dismissedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Schedules the morning briefing one-off task to fire at quiet hours end.
  static Future<void> _scheduleMorningBriefing() async {
    // Read quiet hours end time from SharedPreferences
    // Default: 8 AM
    final prefs = await SharedPreferences.getInstance();
    final quietTo = prefs.getInt('alerts_quiet_to') ?? 8;

    final delay = _delayUntilHour(quietTo);
    if (delay.isNegative || delay.inMinutes < 5) return;
    // Already past the hour or too close — skip scheduling

    await Workmanager().registerOneOffTask(
      kMorningBriefingTask,
      kMorningBriefingTask,
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  static Duration _delayUntilHour(int targetHour) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, targetHour, 0);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target.difference(now);
  }

  /// Runs the morning briefing — called from callbackDispatcher.
  static Future<void> runMorningBriefing(AppDatabase db) async {
    try {
      // Load overnight data from sentinel
      final sentinel = await (db.select(db.alerts)
            ..where((a) => a.alertType.equals('OVERNIGHT_DATA'))
            ..limit(1))
          .getSingleOrNull();

      if (sentinel == null) return;

      Map<String, dynamic> overnightData;
      try {
        overnightData = jsonDecode(sentinel.triggerData) as Map<String, dynamic>;
      } catch (_) {
        return;
      }

      // Get model path
      const channel = MethodChannel('com.viren.viren/pdf_crypto');
      final basePath = await channel.invokeMethod<String>('getModelPath');
      final modelPath =
          '$basePath/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';

      // Build Qwen prompt for morning briefing
      final newsItems = (overnightData['news'] as List?)
              ?.map((n) => '- ${n['title']} (${n['source']})')
              .join('\n') ??
          'No overnight news captured.';

      final sp500Data = overnightData['sp500'] as Map?;
      final goldData = overnightData['gold_spot'] as Map?;
      final holdingsContext =
          overnightData['holdings_context'] as String? ?? '';

      final sp500Line = sp500Data != null
          ? 'S&P 500: ${_pctStr(sp500Data['changePct'] as double)}'
          : '';
      final goldLine = goldData != null
          ? 'Gold spot: ${_pctStr(goldData['changePct'] as double)}'
          : '';

      final prompt = '''You are a personal investment advisor giving a morning market briefing.
The investor is waking up. Be warm, concise, and actionable. 2-3 sentences max.

Their portfolio:
$holdingsContext

Overnight data:
$sp500Line
$goldLine
Key overnight news:
$newsItems

Write a morning briefing starting with "While you slept: ". 
Mention the most relevant overnight event for their specific holdings.
If there is a buying opportunity or risk, say it clearly but without alarm.
Plain text only. 2-3 sentences maximum.''';

      final response = await channel.invokeMethod<String>('chat', {
        'prompt': prompt,
        'modelPath': modelPath,
      });

      if (response == null || response.trim().isEmpty) return;

      // Clean the response
      var briefing = response.trim()
          .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '')
          .replaceAll(r'$1', '');

      if (!briefing.startsWith('While you slept')) {
        briefing = 'While you slept: $briefing';
      }

      // Fire the morning briefing notification
      await NotificationService.showAlertNotification(
        id: 7777,
        title: '☀️ Viren Morning Briefing',
        body: briefing,
        severity: AlertSeverity.info,
        payload: '/insights',
      );

      // Also store as an insight card in the feed
      await db.into(db.alerts).insert(
        AlertsCompanion.insert(
          id: 'morning_${DateTime.now().millisecondsSinceEpoch}',
          alertType: 'MORNING_BRIEFING',
          severity: AlertSeverity.info,
          title: '☀️ Morning Briefing',
          description: briefing,
          triggerData: Value(jsonEncode({'notified': true})),
        ),
      );
    } catch (_) {}
  }

  static String _pctStr(double pct) {
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(2)}%';
  }
}
