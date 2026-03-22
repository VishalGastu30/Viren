import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import '../database/app_database.dart';
import 'notification_service.dart';
import '../database/enums.dart';
import 'rss_fetcher.dart';
import '../market/nse_price_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WeeklyDigestService — Saturday summary notification.
//
// Reads the past 7 days of alerts and sends one notification
// summarising what Viren noticed this week.
//
// Scheduled as a one-time WorkManager task that re-schedules itself
// each time it runs, so it fires every Saturday regardless of whether
// the app is open.
//
// Privacy: all data is local. No network calls.
// ─────────────────────────────────────────────────────────────────────────────

const weeklyDigestTaskName = 'viren_weekly_digest';
const sundayReportTaskName = 'viren_sunday_report';

class WeeklyDigestService {
  static Future<void> run(AppDatabase db) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));

    // ── Fetch this week's alerts ──────────────────────────────────
    final weekAlerts = await (db.select(db.alerts)
          ..where((a) =>
              a.createdAt.isBiggerOrEqualValue(cutoff) &
              a.alertType.isNotValue('MACRO_STATE') &
              a.alertType.isNotValue('PRICE_SNAPSHOT') &
              a.alertType.isNotValue('EMOTION_NOTE') &
              a.alertType.isNotValue('OVERNIGHT_DATA')))
        .get();

    // ── Fetch holdings for portfolio context ──────────────────────
    final holdings = await db.select(db.holdings).get();

    // ── Fetch trades for behaviour analysis ───────────────────────
    final trades = await (db.select(db.trades)
          ..where((a) => a.tradeTimestamp.isBiggerOrEqualValue(cutoff))
          ..orderBy([(t) => OrderingTerm.asc(t.tradeTimestamp)]))
        .get();

    // ── Fetch live prices for week-end valuation ──────────────────
    final symbols = holdings.map((h) => h.instrumentSymbol.toUpperCase()).toList();
    final prices = symbols.isNotEmpty
        ? await NsePriceService.getPrices(symbols)
        : <String, double?>{};

    // ── Build portfolio performance context ───────────────────────
    double totalInvested = 0;
    double totalCurrent = 0;
    final holdingLines = <String>[];

    for (final h in holdings) {
      final sym = h.instrumentSymbol.toUpperCase();
      totalInvested += h.investedValue;
      final cmp = prices[sym];
      if (cmp != null) {
        final cv = cmp * h.totalQuantity;
        totalCurrent += cv;
        final pnl = cv - h.investedValue;
        final pct = h.investedValue > 0 ? (pnl / h.investedValue) * 100 : 0.0;
        final sign = pct >= 0 ? '+' : '';
        holdingLines.add(
          '$sym: CMP ₹${cmp.toStringAsFixed(2)}, '
          'P&L $sign₹${pnl.toStringAsFixed(0)} ($sign${pct.toStringAsFixed(1)}%)',
        );
      } else {
        holdingLines.add('$sym: price unavailable');
      }
    }

    final totalPnL = totalCurrent - totalInvested;
    final totalPct = totalInvested > 0 ? (totalPnL / totalInvested) * 100 : 0.0;

    // ── Categorise alerts ─────────────────────────────────────────
    final drawdowns = weekAlerts.where((a) =>
        a.alertType == 'DRAWDOWN_ALERT').length;
    final opportunities = weekAlerts.where((a) =>
        a.alertType == 'DCA_OPPORTUNITY' ||
        a.alertType == 'ACCUMULATION_PATTERN').length;
    final newsAlerts = weekAlerts.where((a) =>
        a.alertType == 'NEWS_RELEVANT' ||
        a.alertType == 'MACRO_EVENT').length;
    final patterns = weekAlerts.where((a) =>
        a.alertType == 'CONSISTENCY_STREAK' ||
        a.alertType == 'BEHAVIOUR_WARNING').length;

    // ── Fetch weekend news for Qwen context ───────────────────────
    List<RssItem> weekendNews = [];
    try {
      weekendNews = await RssFetcher.fetchRecent(
          maxFeedsPerRun: 2, maxItemsPerFeed: 5);
    } catch (_) {}

    // ── Build Qwen prompt for weekly synthesis ────────────────────
    const channel = MethodChannel('com.viren.viren/pdf_crypto');
    String? modelPath;
    try {
      final base = await channel.invokeMethod<String>('getModelPath');
      modelPath =
          '$base/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';
    } catch (_) {}

    String weeklyBody;

    if (modelPath != null) {
      final newsHeadlines = weekendNews.isEmpty
          ? 'No recent news fetched.'
          : weekendNews.take(4)
              .map((n) => '- ${n.title} (${n.source})')
              .join('\n');

      final portfolioSummary = holdingLines.isEmpty
          ? 'No holdings data.'
          : holdingLines.join('\n');

      final pnlSign = totalPct >= 0 ? '+' : '';
      final prompt =
          '''You are Viren, a personal investment advisor. Write a concise Saturday weekly digest for a retail investor.

Portfolio this week:
$portfolioSummary
Total P&L: $pnlSign₹${totalPnL.toStringAsFixed(0)} ($pnlSign${totalPct.toStringAsFixed(1)}%)

Alerts this week: $drawdowns drawdowns, $opportunities opportunities, $newsAlerts news signals, $patterns behaviour patterns
Trades this week: ${trades.length} trades

Weekend news:
$newsHeadlines

Write a 3-4 sentence weekly summary starting with "This week:". Include:
1. Portfolio performance in plain numbers
2. The most important thing that happened this week
3. One thing to watch next week based on the news
Be specific and use actual numbers. Plain text only. No bullet points. No markdown.''';

      try {
        final response = await channel.invokeMethod<String>('chat', {
          'prompt': prompt,
          'modelPath': modelPath,
        });

        if (response != null && response.trim().isNotEmpty) {
          weeklyBody = response.trim()
              .replaceAllMapped(
                  RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '')
              .replaceAll(r'$1', '');
        } else {
          weeklyBody = _buildFallbackBody(
              weekAlerts.length, drawdowns, opportunities, newsAlerts,
              totalPct, holdingLines);
        }
      } catch (_) {
        weeklyBody = _buildFallbackBody(
            weekAlerts.length, drawdowns, opportunities, newsAlerts,
            totalPct, holdingLines);
      }
    } else {
      weeklyBody = _buildFallbackBody(
          weekAlerts.length, drawdowns, opportunities, newsAlerts,
          totalPct, holdingLines);
    }

    await NotificationService.showAlertNotification(
      id: 9999,
      title: '📊 Viren Weekly Review — ${_weekDateRange()}',
      body: weeklyBody,
      severity: AlertSeverity.info,
      payload: '/insights',
    );

    // Also store as an insight card
    await db.into(db.alerts).insert(
      AlertsCompanion.insert(
        id: 'weekly_${DateTime.now().millisecondsSinceEpoch}',
        alertType: 'WEEKLY_DIGEST',
        severity: AlertSeverity.info,
        title: '📊 Weekly Review — ${_weekDateRange()}',
        description: weeklyBody,
        triggerData: Value(jsonEncode({'notified': true})),
      ),
    );
  }

  static String _buildFallbackBody(
      int total, int drawdowns, int opportunities,
      int newsAlerts, double totalPct, List<String> holdingLines) {
    final pnlSign = totalPct >= 0 ? '+' : '';
    final parts = <String>[];
    if (drawdowns > 0) parts.add('$drawdowns drawdowns');
    if (opportunities > 0) parts.add('$opportunities opportunities');
    if (newsAlerts > 0) parts.add('$newsAlerts news signals');
    final summary = parts.isEmpty ? 'A quiet week.' : parts.join(', ');
    return 'This week: Portfolio at $pnlSign${totalPct.toStringAsFixed(1)}% overall. '
        '$summary across $total insights. '
        '${holdingLines.isNotEmpty ? holdingLines.first : ''} Tap to review.';
  }

  static String _weekDateRange() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${weekAgo.day} ${months[weekAgo.month-1]} – '
        '${now.day} ${months[now.month-1]}';
  }

  /// Schedules the weekly digest to fire next Saturday at 9 AM IST.
  /// Uses a one-time WorkManager task with an initial delay calculated
  /// from the current time to next Saturday 9 AM.
  static Future<void> scheduleNextWeek() async {
    final delay = _delayUntilNextSaturday9AM();
    await Workmanager().registerOneOffTask(
      weeklyDigestTaskName,
      weeklyDigestTaskName,
      initialDelay: delay,
      constraints: Constraints(
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Calculates the Duration from now until next Saturday at 9:00 AM IST.
  static Duration _delayUntilNextSaturday9AM() {
    final now = DateTime.now().toUtc().add(
        const Duration(hours: 5, minutes: 30)); // IST
    var next = DateTime(now.year, now.month, now.day, 9, 0); // 9 AM today

    // Find next Saturday (weekday 6)
    int daysUntilSaturday = (6 - now.weekday + 7) % 7;
    if (daysUntilSaturday == 0 && now.hour >= 9) {
      // Already past 9 AM Saturday — schedule for next Saturday
      daysUntilSaturday = 7;
    }

    next = next.add(Duration(days: daysUntilSaturday));
    final delay = next.difference(now);
    // Minimum 1 minute delay to avoid WorkManager complaints
    return delay.isNegative || delay.inMinutes < 1
        ? const Duration(minutes: 1)
        : delay;
  }

  /// Sunday / Monday Report — fires at 3 distinct scheduled times.
  /// Monitors weekend news + US market open + gives Monday watchlist.
  static Future<void> runSundayReport(AppDatabase db) async {
    // Gate: only run once per 6-hour window
    // Prevents duplicate cards from manual refreshes
    final alreadyRan = await _sundayReportRanRecently(db);
    if (alreadyRan) return;

    final now = DateTime.now().toUtc().add(
        const Duration(hours: 5, minutes: 30)); // IST
    final isMonday = now.weekday == DateTime.monday;
    final isEvening = now.hour >= 20; // 8 PM+ = evening slot

    // Customize notification title based on time
    final String notifTitle;
    final String qwenFocus;

    if (isMonday) {
      notifTitle = '✧ Monday Pre-Market — Viren';
      qwenFocus = 'Markets open in about 1 hour. '
          'Write a 2-sentence final pre-market note. '
          'What is the single most important thing to watch at market open? '
          'Be specific about which holding and why.';
    } else if (isEvening) {
      notifTitle = '☾ Sunday Evening — Monday Watchlist';
      qwenFocus = 'US markets just opened. Write a 3-sentence Sunday evening briefing. '
          'Include: what the weekend data says, US market direction, '
          'and one specific prediction for Indian markets Monday morning.';
    } else {
      notifTitle = '☼ Sunday Morning — Weekly Preview';
      qwenFocus = 'Write a 2-sentence Sunday morning note. '
          'What happened last week in markets that matters for their holdings, '
          'and what should they keep an eye on this week?';
    }

    final holdings = await db.select(db.holdings).get();
    if (holdings.isEmpty) return;

    // ── Fetch weekend news (wider 72h window for weekend) ──────────
    List<RssItem> weekendNews = [];
    List<RssItem> goldNews = [];
    try {
      weekendNews = await RssFetcher.fetchRecent(
          maxFeedsPerRun: 2, maxItemsPerFeed: 5);
      // Fetch gold/commodity news specifically — key for weekend moves
      goldNews = await RssFetcher.fetchForAssetClass(
          assetClass: 'gold', maxItems: 3, maxAgeHours: 72);
    } catch (_) {}

    // ── Fetch US market data (S&P 500 — opens Sunday evening IST) ──
    double? sp500Change;
    try {
      final resp = await http.get(
        Uri.parse(
          'https://query2.finance.yahoo.com/v8/finance/chart/%5EGSPC'
          '?interval=1d&range=2d',
        ),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final meta = json['chart']?['result']?[0]?['meta'];
        if (meta != null) {
          final price = (meta['regularMarketPrice'] as num?)?.toDouble();
          final prev = (meta['chartPreviousClose'] as num?)?.toDouble();
          if (price != null && prev != null && prev > 0) {
            sp500Change = ((price - prev) / prev) * 100;
          }
        }
      }
    } catch (_) {}

    // ── Fetch gold spot change ─────────────────────────────────────
    double? goldChange;
    try {
      final resp = await http.get(
        Uri.parse(
          'https://query2.finance.yahoo.com/v8/finance/chart/GC%3DF'
          '?interval=1d&range=2d',
        ),
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final meta = json['chart']?['result']?[0]?['meta'];
        if (meta != null) {
          final price = (meta['regularMarketPrice'] as num?)?.toDouble();
          final prev = (meta['chartPreviousClose'] as num?)?.toDouble();
          if (price != null && prev != null && prev > 0) {
            goldChange = ((price - prev) / prev) * 100;
          }
        }
      }
    } catch (_) {}

    // ── Build Qwen prompt ──────────────────────────────────────────
    const channel = MethodChannel('com.viren.viren/pdf_crypto');
    String? modelPath;
    try {
      final base = await channel.invokeMethod<String>('getModelPath');
      modelPath =
          '$base/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';
    } catch (_) {}

    // Build holdings context
    final holdingsSummary = holdings.map((h) {
      return '${h.instrumentSymbol.toUpperCase()}: '
          'avg cost ₹${h.averagePrice.toStringAsFixed(2)}, '
          '${h.totalQuantity.toStringAsFixed(0)} units';
    }).join('; ');

    // Build market data context
    final marketLines = <String>[];
    if (sp500Change != null) {
      final s = sp500Change >= 0 ? '+' : '';
      marketLines.add('S&P 500: $s${sp500Change.toStringAsFixed(2)}% this session');
    }
    if (goldChange != null) {
      final s = goldChange >= 0 ? '+' : '';
      marketLines.add('Gold spot: $s${goldChange.toStringAsFixed(2)}% weekend move');
    }

    final newsHeadlines = [
      ...weekendNews.take(3),
      ...goldNews.take(2),
    ].map((n) => '- ${n.title} (${n.source})').join('\n');

    String reportBody;

    if (modelPath != null) {
      final prompt =
          '''You are Viren, a personal investment advisor. The Indian market opens Monday at 9:15 AM IST.
Write a weekend briefing for a retail investor.

Their holdings: $holdingsSummary

Weekend market data:
${marketLines.isEmpty ? 'US market data unavailable.' : marketLines.join('\n')}

Weekend news headlines:
${newsHeadlines.isEmpty ? 'No news fetched.' : newsHeadlines}

$qwenFocus Plain text only. No markdown. No bullet points.''';

      try {
        final response = await channel.invokeMethod<String>('chat', {
          'prompt': prompt,
          'modelPath': modelPath,
        });

        if (response != null && response.trim().isNotEmpty) {
          reportBody = response.trim()
              .replaceAllMapped(
                  RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '')
              .replaceAll(r'$1', '');
          if (!reportBody.startsWith('Markets open')) {
            reportBody = 'Markets open in ~14 hours. $reportBody';
          }
        } else {
          reportBody = _buildFallbackSundayReport(
              sp500Change, goldChange, holdingsSummary);
        }
      } catch (_) {
        reportBody = _buildFallbackSundayReport(
            sp500Change, goldChange, holdingsSummary);
      }
    } else {
      reportBody = _buildFallbackSundayReport(
          sp500Change, goldChange, holdingsSummary);
    }

    // Fire notification
    await NotificationService.showAlertNotification(
      id: 9998,
      title: notifTitle,
      body: reportBody,
      severity: AlertSeverity.info,
      payload: '/insights',
    );

    // Store as insight card
    await db.into(db.alerts).insert(
      AlertsCompanion.insert(
        id: 'weekend_report_${DateTime.now().millisecondsSinceEpoch}',
        alertType: 'MORNING_BRIEFING',
        severity: AlertSeverity.info,
        title: notifTitle,
        description: reportBody,
        triggerData: Value(jsonEncode({'notified': true})),
      ),
    );

    // Reschedule the NEXT occurrence of the same report
    // Just reschedule all three to be safe
    await scheduleWeekendReports();
  }

  static String _buildFallbackSundayReport(
      double? sp500Change, double? goldChange, String holdings) {
    final parts = <String>['Markets open in ~14 hours.'];
    if (sp500Change != null) {
      final s = sp500Change >= 0 ? '+' : '';
      parts.add('S&P 500 is $s${sp500Change.toStringAsFixed(1)}% — '
          '${sp500Change >= 0 ? 'positive signal for Monday open' : 'may pressure Indian markets Monday'}.');
    }
    if (goldChange != null) {
      final s = goldChange >= 0 ? '+' : '';
      parts.add(
          'Gold moved $s${goldChange.toStringAsFixed(1)}% over the weekend.');
    }
    return parts.join(' ');
  }

  /// Returns true if a Sunday report was already generated
  /// in the last 6 hours — prevents duplicates from manual refreshes.
  static Future<bool> _sundayReportRanRecently(AppDatabase db) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 6));
    final existing = await (db.select(db.alerts)
          ..where((a) =>
              a.alertType.equals('MORNING_BRIEFING') &
              (a.title.like('%Sunday Evening%') | 
               a.title.like('%Sunday Morning%') | 
               a.title.like('%Monday Pre-Market%')) &
              a.createdAt.isBiggerOrEqualValue(cutoff))
          ..limit(1))
        .getSingleOrNull();
    return existing != null;
  }

  /// Schedule all three Sunday/Monday report windows.
  /// Call once at app startup — each task reschedules itself after running.
  static Future<void> scheduleWeekendReports() async {
    await _scheduleSundayMorning();
    await _scheduleSundayEvening();
    await _scheduleMondayMorning();
  }

  // Sunday 7 AM IST — morning preview
  static Future<void> _scheduleSundayMorning() async {
    final delay = _delayUntilNextSundayAt(7, 0);
    await Workmanager().registerOneOffTask(
      'viren_sunday_morning',
      sundayReportTaskName,
      initialDelay: delay,
      constraints: Constraints(requiresBatteryNotLow: false),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      // keep — don't reset if already scheduled
    );
  }

  // Sunday 10 PM IST — evening watchlist (US markets just opened)
  static Future<void> _scheduleSundayEvening() async {
    final delay = _delayUntilNextSundayAt(22, 0);
    await Workmanager().registerOneOffTask(
      'viren_sunday_evening',
      sundayReportTaskName,
      initialDelay: delay,
      constraints: Constraints(requiresBatteryNotLow: false),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  // Monday 8 AM IST — pre-market final briefing
  static Future<void> _scheduleMondayMorning() async {
    final delay = _delayUntilNextMondayAt(8, 0);
    await Workmanager().registerOneOffTask(
      'viren_monday_morning',
      sundayReportTaskName,
      initialDelay: delay,
      constraints: Constraints(requiresBatteryNotLow: false),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  static Duration _delayUntilNextSundayAt(int hour, int minute) {
    final now = DateTime.now().toUtc().add(
        const Duration(hours: 5, minutes: 30)); // IST
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    // Find next Sunday
    int daysUntil = (7 - now.weekday + 7) % 7;
    if (daysUntil == 0 && now.hour >= hour) {
      daysUntil = 7; // already past this time today — next week
    }
    target = target.add(Duration(days: daysUntil));
    final delay = target.difference(now);
    return delay.isNegative || delay.inMinutes < 1
        ? const Duration(hours: 24) // safety fallback
        : delay;
  }

  static Duration _delayUntilNextMondayAt(int hour, int minute) {
    final now = DateTime.now().toUtc().add(
        const Duration(hours: 5, minutes: 30)); // IST
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    // Find next Monday (weekday 1)
    int daysUntil = (1 - now.weekday + 7) % 7;
    if (daysUntil == 0 && now.hour >= hour) {
      daysUntil = 7;
    }
    target = target.add(Duration(days: daysUntil));
    final delay = target.difference(now);
    return delay.isNegative || delay.inMinutes < 1
        ? const Duration(hours: 24)
        : delay;
  }
}
