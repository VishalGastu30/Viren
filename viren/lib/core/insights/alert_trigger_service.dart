import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AlertTriggerService — Creates Alert rows from detected conditions.
//
// All methods are idempotent — they check for recent duplicates
// before inserting to prevent the same alert from firing repeatedly.
// ─────────────────────────────────────────────────────────────────────────────

class AlertTriggerService {
  final AppDatabase _db;
  final _uuid = const Uuid();

  AlertTriggerService(this._db);

  // ── Dedup window: don't fire same alert type for same symbol twice
  // within this many hours
  static const _dedupHoursDefault  = 4;
  static const _dedupHoursSlow     = 168; // 7 days

  static int _dedupWindowFor(String alertType) {
    const slowTypes = {
      'CONCENTRATION_DRIFT',
      'DCA_OPPORTUNITY',
      'ACCUMULATION_PATTERN',
      'CONSISTENCY_STREAK',
      'BEHAVIOUR_WARNING',
      'INACTIVITY_ALERT',
      'PORTFOLIO_MILESTONE',
      'CALENDAR_EVENT',
      'LTCG_COUNTDOWN',
      'CORRELATION_RISK',
    };
    return slowTypes.contains(alertType)
        ? _dedupHoursSlow
        : _dedupHoursDefault;
  }

  /// Checks if an alert of the same type for the same symbol
  /// was already fired within the dedup window.
  Future<bool> _isDuplicate(String alertType, String? symbol) async {
    final hours = _dedupWindowFor(alertType);
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    final existing = await (_db.select(_db.alerts)
          ..where((a) =>
              a.alertType.equals(alertType) &
              (symbol != null
                  ? a.relatedInstrument.equals(symbol)
                  : a.relatedInstrument.isNull()) &
              a.createdAt.isBiggerOrEqualValue(cutoff)))
        .getSingleOrNull();
    return existing != null;
  }

  Future<void> _insert({
    required String alertType,
    required AlertSeverity severity,
    required String title,
    required String description,
    String? relatedInstrument,
    int confidence = 80,
    Map<String, dynamic> triggerData = const {},
  }) async {
    if (await _isDuplicate(alertType, relatedInstrument)) return;

    await _db.into(_db.alerts).insert(
      AlertsCompanion.insert(
        id: _uuid.v4(),
        alertType: alertType,
        severity: severity,
        title: title,
        description: description,
        confidence: Value(confidence),
        relatedInstrument: Value(relatedInstrument),
        triggerData: Value(jsonEncode({
          ...triggerData,
          'notified': false, // will be set to true after notification fires
        })),
      ),
    );
  }

  // ── Price-based triggers ──────────────────────────────────────

  /// Returns how many times this alert type has fired for this symbol
  /// in the last 30 days, and when it first appeared.
  Future<({int count, DateTime? firstFired})> _getAlertHistory(
      String alertType, String? symbol) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final history = await (_db.select(_db.alerts)
          ..where((a) =>
              a.alertType.equals(alertType) &
              (symbol != null
                  ? a.relatedInstrument.equals(symbol)
                  : a.relatedInstrument.isNull()) &
              a.createdAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
        .get();

    return (
      count: history.length,
      firstFired: history.isNotEmpty ? history.first.createdAt : null,
    );
  }

  /// Fires if holding is down drawdownPct% or more from avg cost.
  Future<void> checkDrawdown({
    required String symbol,
    required double avgCost,
    required double currentPrice,
    double drawdownPct = 5.0,
  }) async {
    final changePct = ((currentPrice - avgCost) / avgCost) * 100;
    if (changePct > -drawdownPct) return; // not in drawdown

    // Check staleness — how many times has this fired before?
    final history = await _getAlertHistory('DRAWDOWN_ALERT', symbol);
    final weeksSinceFirst = history.firstFired != null
        ? DateTime.now().difference(history.firstFired!).inDays ~/ 7
        : 0;

    // Escalating messages based on how long the drawdown has persisted
    String title;
    String description;
    AlertSeverity severity;

    if (weeksSinceFirst == 0) {
      // Week 1: informational
      title = '$symbol is down ${changePct.abs().toStringAsFixed(1)}%';
      description =
          'Your $symbol is now ₹${currentPrice.toStringAsFixed(2)}, '
          '${changePct.abs().toStringAsFixed(1)}% below your avg cost '
          'of ₹${avgCost.toStringAsFixed(2)}. '
          'This may be a DCA opportunity — prices at this level '
          'historically recover within your holding horizon.';
      severity = AlertSeverity.warning;
    } else if (weeksSinceFirst == 1) {
      // Week 2: draw attention to persistence
      title = '$symbol has been in drawdown for 2 weeks';
      description =
          '$symbol has been below your avg cost '
          '(₹${avgCost.toStringAsFixed(2)}) for 2 weeks now. '
          'Current price ₹${currentPrice.toStringAsFixed(2)} '
          '(${changePct.abs().toStringAsFixed(1)}% below avg). '
          'Consider: is this a broad market move, or $symbol-specific? '
          'If broad market, your ETFs typically recover. '
          'If stock-specific, review your thesis.';
      severity = AlertSeverity.warning;
    } else if (weeksSinceFirst == 2) {
      // Week 3: position review prompt
      title = '$symbol drawdown — week 3. Time to review.';
      description =
          '$symbol has been below your avg cost for 3 weeks. '
          'Current: ₹${currentPrice.toStringAsFixed(2)} '
          '(${changePct.abs().toStringAsFixed(1)}% below ₹${avgCost.toStringAsFixed(2)}). '
          'Three weeks is a meaningful signal. '
          'Ask yourself: has anything fundamental changed? '
          'Is your original thesis still intact? '
          'Tap "Ask Viren" for a position-specific analysis.';
      severity = AlertSeverity.warning;
    } else {
      // Week 4+: critical review
      title = '$symbol has been in drawdown for ${weeksSinceFirst + 1}+ weeks';
      description =
          '$symbol has been ${changePct.abs().toStringAsFixed(1)}% below your '
          'avg cost for over a month (₹${currentPrice.toStringAsFixed(2)} vs '
          '₹${avgCost.toStringAsFixed(2)}). '
          'This is a long-term drawdown. '
          'An extended review of this position is warranted. '
          'Consider your original investment thesis carefully.';
      severity = AlertSeverity.critical;
    }

    await _insert(
      alertType: 'DRAWDOWN_ALERT',
      severity: severity,
      title: title,
      description: description,
      relatedInstrument: symbol,
      confidence: 95,
      triggerData: {
        'avgCost': avgCost,
        'currentPrice': currentPrice,
        'changePct': changePct,
        'weeksSinceFirst': weeksSinceFirst,
        'occurrenceCount': history.count,
      },
    );
  }

  /// Fires if holding recovers to within 2% of avg cost after a drawdown.
  Future<void> checkRecovery({
    required String symbol,
    required double avgCost,
    required double currentPrice,
  }) async {
    final changePct =
        ((currentPrice - avgCost) / avgCost) * 100;
    if (changePct >= -2.0 && changePct < 0) {
      await _insert(
        alertType: 'RECOVERY_ALERT',
        severity: AlertSeverity.info,
        title: '$symbol is recovering — near your avg cost',
        description:
            '$symbol is at ₹${currentPrice.toStringAsFixed(2)}, '
            'just ${changePct.abs().toStringAsFixed(1)}% below your '
            'avg cost of ₹${avgCost.toStringAsFixed(2)}. '
            'You are close to breaking even on this position.',
        relatedInstrument: symbol,
        confidence: 90,
        triggerData: {
          'avgCost': avgCost,
          'currentPrice': currentPrice,
          'changePct': changePct,
        },
      );
    }
  }

  /// Fires if holding moves 5%+ in a single session (circuit breaker zone).
  Future<void> checkCircuitBreaker({
    required String symbol,
    required double dayChangePct,
    required double currentPrice,
  }) async {
    if (dayChangePct.abs() >= 5.0) {
      final dir = dayChangePct > 0 ? 'up' : 'down';
      await _insert(
        alertType: 'CIRCUIT_BREAKER',
        severity: AlertSeverity.critical,
        title:
            '$symbol is $dir ${dayChangePct.abs().toStringAsFixed(1)}% today',
        description:
            'Large single-session move detected for $symbol. '
            'Current price: ₹${currentPrice.toStringAsFixed(2)}. '
            'Moves of this size can indicate institutional activity or '
            'major news. Review before making any decisions.',
        relatedInstrument: symbol,
        confidence: 99,
        triggerData: {
          'dayChangePct': dayChangePct,
          'currentPrice': currentPrice,
        },
      );
    }
  }

  /// Fires when portfolio total value crosses a round milestone.
  Future<void> checkPortfolioMilestone({
    required double previousValue,
    required double currentValue,
  }) async {
    // Round milestones: every ₹1000 up to ₹10K, every ₹5000 after
    final milestones = [
      1000, 2000, 3000, 4000, 5000, 7500,
      10000, 15000, 20000, 25000, 50000, 100000
    ];
    for (final m in milestones) {
      if (previousValue < m && currentValue >= m) {
        await _insert(
          alertType: 'PORTFOLIO_MILESTONE',
          severity: AlertSeverity.success,
          title:
              '🎯 Portfolio crossed ₹${_formatAmount(m.toDouble())}',
          description:
              'Your portfolio value has reached ₹${_formatAmount(currentValue)}. '
              'Keep investing consistently.',
          confidence: 100,
          triggerData: {
            'milestone': m,
            'currentValue': currentValue,
          },
        );
        break; // only one milestone per run
      }
    }
  }

  // ── News-based triggers ───────────────────────────────────────

  /// Creates a NEWS_RELEVANT alert from Qwen's reasoning output.
  Future<void> createNewsAlert({
    required String symbol,
    required String newsTitle,
    required String qwenInsight,
    required String newsSource,
    required int relevanceScore, // 1-10 from Qwen
  }) async {
    if (relevanceScore < 6) return; // below threshold

    final severity =
        relevanceScore >= 8 ? AlertSeverity.warning : AlertSeverity.info;

    await _insert(
      alertType: 'NEWS_RELEVANT',
      severity: severity,
      title: newsTitle.length > 60
          ? '${newsTitle.substring(0, 57)}...'
          : newsTitle,
      description: qwenInsight,
      relatedInstrument: symbol,
      confidence: relevanceScore * 10,
      triggerData: {
        'newsTitle': newsTitle,
        'source': newsSource,
        'relevanceScore': relevanceScore,
      },
    );
  }

  // ── Behaviour triggers ────────────────────────────────────────

  /// Fires if user hasn't traded in 60+ days.
  Future<void> checkInactivity({
    required DateTime lastTradeDate,
  }) async {
    final daysSince =
        DateTime.now().difference(lastTradeDate).inDays;
    if (daysSince >= 60) {
      await _insert(
        alertType: 'INACTIVITY_ALERT',
        severity: AlertSeverity.info,
        title: '$daysSince days since your last trade',
        description:
            'You haven\'t added to your portfolio in $daysSince days. '
            'Regular investing tends to smooth out market volatility over time.',
        confidence: 100,
        triggerData: {
          'daysSince': daysSince,
          'lastTradeDate': lastTradeDate.toIso8601String(),
        },
      );
    }
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  // ── Macro triggers ────────────────────────────────────────────

  /// Creates a MACRO_EVENT alert from Qwen's macro reasoning output.
  Future<void> createMacroAlert({
    required String eventTitle,
    required String qwenInsight,
    String? affectedSymbol,
    required String source,
    required int relevanceScore,
  }) async {
    if (relevanceScore < 5) return;

    final severity =
        relevanceScore >= 8 ? AlertSeverity.warning : AlertSeverity.info;

    await _insert(
      alertType: 'MACRO_EVENT',
      severity: severity,
      title: eventTitle.length > 60
          ? '${eventTitle.substring(0, 57)}...'
          : eventTitle,
      description: qwenInsight,
      relatedInstrument: affectedSymbol,
      confidence: relevanceScore * 10,
      triggerData: {
        'eventTitle': eventTitle,
        'source': source,
        'relevanceScore': relevanceScore,
      },
    );
  }

  // ── Pattern triggers ──────────────────────────────────────────

  /// Creates a pattern-based alert (DCA, concentration drift, etc.)
  /// from PatternEngine's pure Dart analysis.
  Future<void> createPatternAlert({
    required String alertType,
    required String title,
    required String description,
    String? symbol,
    int confidence = 80,
    Map<String, dynamic> triggerData = const {},
  }) async {
    // Pattern alerts use INFO severity by default — they are nudges
    // CONCENTRATION_DRIFT is elevated to WARNING since it's a risk signal
    final severity = alertType == 'CONCENTRATION_DRIFT'
        ? AlertSeverity.warning
        : AlertSeverity.info;

    await _insert(
      alertType: alertType,
      severity: severity,
      title: title,
      description: description,
      relatedInstrument: symbol,
      confidence: confidence,
      triggerData: triggerData,
    );
  }

  // ── Momentum triggers ─────────────────────────────────────────

  /// Stores the last seen price for a symbol (for momentum detection).
  /// Uses a PRICE_SNAPSHOT sentinel row — never shown in feed.
  Future<void> updatePriceSnapshot({
    required String symbol,
    required double price,
  }) async {
    final existing = await (_db.select(_db.alerts)
          ..where((a) =>
              a.alertType.equals('PRICE_SNAPSHOT') &
              a.relatedInstrument.equals(symbol))
          ..limit(1))
        .getSingleOrNull();

    final data = jsonEncode({
      'price': price,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (existing != null) {
      await (_db.update(_db.alerts)
            ..where((a) => a.id.equals(existing.id)))
          .write(AlertsCompanion(
        triggerData: Value(data),
        // Keep dismissedAt set so it never appears in the feed
      ));
    } else {
      await _db.into(_db.alerts).insert(
        AlertsCompanion.insert(
          id: _uuid.v4(),
          alertType: 'PRICE_SNAPSHOT',
          severity: AlertSeverity.info,
          title: '_price_snapshot_$symbol',
          description: '_internal',
          relatedInstrument: Value(symbol),
          triggerData: Value(data),
          // Immediately dismiss so it never appears in feed
          dismissedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Checks if price has moved 3%+ since last snapshot.
  /// Returns null if no snapshot exists yet (first run).
  Future<void> checkMomentum({
    required String symbol,
    required double currentPrice,
    double thresholdPct = 3.0,
  }) async {
    final snapshot = await (_db.select(_db.alerts)
          ..where((a) =>
              a.alertType.equals('PRICE_SNAPSHOT') &
              a.relatedInstrument.equals(symbol))
          ..limit(1))
        .getSingleOrNull();

    if (snapshot == null) {
      // No previous price — store and return
      await updatePriceSnapshot(
          symbol: symbol, price: currentPrice);
      return;
    }

    double? previousPrice;
    DateTime? snapshotTime;
    try {
      final data =
          jsonDecode(snapshot.triggerData) as Map<String, dynamic>;
      previousPrice = (data['price'] as num?)?.toDouble();
      final tsStr = data['timestamp'] as String?;
      if (tsStr != null) snapshotTime = DateTime.parse(tsStr);
    } catch (_) {
      await updatePriceSnapshot(
          symbol: symbol, price: currentPrice);
      return;
    }

    if (previousPrice == null || previousPrice <= 0) {
      await updatePriceSnapshot(
          symbol: symbol, price: currentPrice);
      return;
    }

    // Only compare if snapshot is between 10 and 60 minutes old
    // (avoids stale overnight comparisons firing at market open)
    if (snapshotTime != null) {
      final age = DateTime.now().difference(snapshotTime).inMinutes;
      if (age > 60) {
        // Snapshot is too old — reset without firing
        await updatePriceSnapshot(
            symbol: symbol, price: currentPrice);
        return;
      }
    }

    final changePct =
        ((currentPrice - previousPrice) / previousPrice) * 100;

    if (changePct.abs() >= thresholdPct) {
      final dir = changePct > 0 ? 'up' : 'down';
      final sign = changePct > 0 ? '+' : '';
      await _insert(
        alertType: 'MOMENTUM_ALERT',
        severity: AlertSeverity.warning,
        title:
            '$symbol moved $dir ${changePct.abs().toStringAsFixed(1)}% in 15 min',
        description:
            '$symbol has moved $sign${changePct.toStringAsFixed(1)}% '
            'from ₹${previousPrice.toStringAsFixed(2)} to '
            '₹${currentPrice.toStringAsFixed(2)} in the last 15 minutes. '
            'This is a fast intraday move — check for news.',
        relatedInstrument: symbol,
        confidence: 92,
        triggerData: {
          'previousPrice': previousPrice,
          'currentPrice': currentPrice,
          'changePct': changePct,
        },
      );
    }

    // Always update snapshot to current price after comparison
    await updatePriceSnapshot(symbol: symbol, price: currentPrice);
  }
}
