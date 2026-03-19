import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../database/enums.dart';
import 'notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PriceAlertWatcher — Checks user-set stop-loss and price targets
// against the latest live prices every time InsightEngine runs.
//
// Works by reading all active USER_STOP_LOSS and USER_PRICE_TARGET
// rows from the alerts table (these are set by PriceAlertSheet),
// comparing them to the current prices map, and:
//   1. Firing a notification if the threshold is crossed
//   2. Creating a STOP_LOSS_HIT or PRICE_TARGET_HIT alert row
//   3. Dismissing the standing order (sets dismissedAt) so it
//      does not fire again
//
// The standing order is separate from the triggered alert.
// The user sees a STOP_LOSS_HIT card in the feed.
// The USER_STOP_LOSS row disappears (dismissed) after firing.
// ─────────────────────────────────────────────────────────────────────────────

class PriceAlertWatcher {
  final AppDatabase _db;

  PriceAlertWatcher(this._db);

  /// Called from InsightEngine._runPriceIntelligence()
  /// after prices have been fetched.
  Future<void> check(Map<String, double> prices) async {
    if (prices.isEmpty) return;

    // Fetch all active user-set standing orders
    final standingOrders = await (db.select(_db.alerts)
          ..where((a) =>
              (a.alertType.equals('USER_STOP_LOSS') |
               a.alertType.equals('USER_PRICE_TARGET')) &
              a.dismissedAt.isNull()))
        .get();

    if (standingOrders.isEmpty) return;

    for (final order in standingOrders) {
      final symbol = order.relatedInstrument?.toUpperCase();
      if (symbol == null) continue;

      final currentPrice = prices[symbol];
      if (currentPrice == null) continue;

      double? targetPrice;
      try {
        final data = jsonDecode(order.triggerData) as Map<String, dynamic>;
        targetPrice = (data['targetPrice'] as num?)?.toDouble();
      } catch (_) {
        continue;
      }
      if (targetPrice == null) continue;

      bool triggered = false;
      String triggeredType = '';
      String triggeredTitle = '';
      String triggeredDescription = '';
      AlertSeverity triggeredSeverity = AlertSeverity.warning;

      if (order.alertType == 'USER_STOP_LOSS' &&
          currentPrice <= targetPrice) {
        triggered = true;
        triggeredType = 'STOP_LOSS_HIT';
        triggeredSeverity = AlertSeverity.critical;
        triggeredTitle = '$symbol hit your stop loss — ₹${currentPrice.toStringAsFixed(2)}';
        triggeredDescription =
            '$symbol has fallen to ₹${currentPrice.toStringAsFixed(2)}, '
            'reaching your stop loss of ₹${targetPrice.toStringAsFixed(2)}. '
            'Review your position.';
      } else if (order.alertType == 'USER_PRICE_TARGET' &&
          currentPrice >= targetPrice) {
        triggered = true;
        triggeredType = 'PRICE_TARGET_HIT';
        triggeredSeverity = AlertSeverity.warning;
        triggeredTitle = '$symbol reached your target — ₹${currentPrice.toStringAsFixed(2)}';
        triggeredDescription =
            '$symbol has reached ₹${currentPrice.toStringAsFixed(2)}, '
            'hitting your price target of ₹${targetPrice.toStringAsFixed(2)}. '
            'Consider reviewing your exit strategy.';
      }

      if (!triggered) continue;

      // 1. Dismiss the standing order so it doesn't fire again
      await (_db.update(_db.alerts)
            ..where((a) => a.id.equals(order.id)))
          .write(AlertsCompanion(
        dismissedAt: Value(DateTime.now()),
      ));

      // 2. Create the triggered alert row (shows in feed)
      await _db.into(_db.alerts).insert(
        AlertsCompanion.insert(
          id: _uuid(),
          alertType: triggeredType,
          severity: triggeredSeverity,
          title: triggeredTitle,
          description: triggeredDescription,
          confidence: const Value(100),
          relatedInstrument: Value(symbol),
          triggerData: Value(jsonEncode({
            'triggeredPrice': currentPrice,
            'targetPrice': targetPrice,
            'originalOrderId': order.id,
          })),
        ),
      );

      // 3. Fire immediate notification
      await NotificationService.showAlertNotification(
        id: currentPrice.hashCode ^ symbol.hashCode,
        title: triggeredTitle,
        body: triggeredDescription,
        severity: triggeredSeverity,
        payload: '/holdings/$symbol',
      );
    }
  }

  // Simple UUID-like id using timestamp + hashCode
  String _uuid() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = ts.hashCode ^ identityHashCode(this);
    return '$ts-$rand';
  }
}

// Expose _db getter workaround for the select call above
extension on PriceAlertWatcher {
  AppDatabase get db => _db;
}
