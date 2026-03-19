import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/enums.dart';
import 'alert_trigger_service.dart';
import 'emotion_recall_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BehaviourEngine — Layer 5 Intelligence: behavioural pattern recognition.
//
// Uses trade history to build a behavioural mirror for the user.
// Shows them their own patterns in a non-judgmental way.
//
// Phase 2 implements:
//   1. Consistency Nudge — "you've invested N months in a row"
//   2. Mirror Warning — "last time this symbol was near this price, you bought X"
//
// No AI. No network. Pure Dart arithmetic.
// ─────────────────────────────────────────────────────────────────────────────

class BehaviourEngine {
  final AppDatabase _db;
  late final AlertTriggerService _alertService;

  BehaviourEngine(this._db) {
    _alertService = AlertTriggerService(_db);
  }

  /// Entry point called from InsightEngine.
  /// Receives current prices map so Mirror Warning can compare.
  Future<void> run({Map<String, double> currentPrices = const {}}) async {
    final trades = await (_db.select(_db.trades)
          ..orderBy([(t) => OrderingTerm.asc(t.tradeTimestamp)]))
        .get();
    if (trades.isEmpty) return;

    await _checkConsistencyStreak(trades);
    if (currentPrices.isNotEmpty) {
      await _checkMirrorWarning(trades, currentPrices);
    }
  }

  // ── Behaviour 1: Consistency Streak ──────────────────────────

  Future<void> _checkConsistencyStreak(List<Trade> trades) async {
    final buyTrades =
        trades.where((t) => t.tradeType == TradeType.buy).toList();
    if (buyTrades.length < 2) return;

    // Get unique months (yyyy-MM) sorted ascending
    final months = buyTrades
        .map((t) =>
            '${t.tradeTimestamp.year}-${t.tradeTimestamp.month.toString().padLeft(2, '0')}')
        .toSet()
        .toList()
      ..sort();

    if (months.length < 2) return;

    // Count consecutive months ending at the most recent
    int streak = 1;
    for (int i = months.length - 1; i > 0; i--) {
      final current = _parseYearMonth(months[i]);
      final previous = _parseYearMonth(months[i - 1]);
      final diff = (current.year - previous.year) * 12 +
          (current.month - previous.month);
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }

    if (streak < 3) return; // Only surface if streak is meaningful

    await _alertService.createPatternAlert(
      alertType: 'CONSISTENCY_STREAK',
      symbol: null,
      title: '$streak months of consistent investing 🎯',
      description:
          'You\'ve made at least one investment every month for the last '
          '$streak months. Consistency like this is the most reliable '
          'predictor of long-term wealth building.',
      confidence: 100,
      triggerData: {
        'streak': streak,
        'months': months,
      },
    );
  }

  DateTime _parseYearMonth(String ym) {
    final parts = ym.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  // ── Behaviour 2: Mirror Warning ───────────────────────────────

  Future<void> _checkMirrorWarning(
      List<Trade> trades, Map<String, double> currentPrices) async {
    // Group buy trades by symbol
    final buysBySymbol = <String, List<Trade>>{};
    for (final t in trades) {
      if (t.tradeType == TradeType.buy) {
        buysBySymbol
            .putIfAbsent(t.instrumentSymbol.toUpperCase(), () => [])
            .add(t);
      }
    }

    for (final entry in buysBySymbol.entries) {
      final symbol = entry.key;
      final currentPrice = currentPrices[symbol];
      if (currentPrice == null) continue;

      final buys = entry.value;
      if (buys.length < 2) continue;

      // Find a historical buy where the price is within 3% of current price
      // Exclude the most recent buy
      for (final historicalBuy in buys.sublist(0, buys.length - 1)) {
        final priceDiff =
            ((currentPrice - historicalBuy.pricePerUnit) / historicalBuy.pricePerUnit).abs();
        if (priceDiff > 0.03) continue;

        // Check if subsequent trades show the price eventually fell
        final buysAfterThis = buys
            .where(
                (b) => b.tradeTimestamp.isAfter(historicalBuy.tradeTimestamp))
            .toList();

        final hadSubsequentDip = buysAfterThis.isNotEmpty &&
            buysAfterThis.any((b) => b.pricePerUnit < historicalBuy.pricePerUnit * 0.95);

        if (!hadSubsequentDip) continue;

        final buyDate =
            '${_monthName(historicalBuy.tradeTimestamp.month)} ${historicalBuy.tradeTimestamp.year}';

        // Check if user wrote a note when they made that historical buy
        final recallService = EmotionRecallService(_db);
        final noteText = await recallService.getNoteText(
            historicalBuy.id);

        // Enrich the description with the user's original thesis if available
        final enrichedDescription = noteText != null && noteText.isNotEmpty
            ? 'In $buyDate you bought $symbol near '
              '₹${historicalBuy.pricePerUnit.toStringAsFixed(2)}. '
              'You noted: "$noteText". '
              'The price then fell further before recovering. '
              'Current price is ₹${currentPrice.toStringAsFixed(2)}. '
              'Has your original thesis changed?'
            : 'In $buyDate you bought $symbol near '
              '₹${historicalBuy.pricePerUnit.toStringAsFixed(2)}. '
              'The price then fell further before recovering. '
              'Current price is ₹${currentPrice.toStringAsFixed(2)}. '
              'This is a data point — not a prediction.';

        await _alertService.createPatternAlert(
          alertType: 'BEHAVIOUR_WARNING',
          symbol: symbol,
          title: 'You\'ve been here before with $symbol',
          description: enrichedDescription,
          confidence: 70,
          triggerData: {
            'historicalBuyPrice': historicalBuy.pricePerUnit,
            'historicalBuyDate':
                historicalBuy.tradeTimestamp.toIso8601String(),
            'currentPrice': currentPrice,
            'priceDiffPct': priceDiff * 100,
          },
        );
        break; // only one mirror warning per symbol per run
      }
    }
  }

  String _monthName(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month];
  }
}
