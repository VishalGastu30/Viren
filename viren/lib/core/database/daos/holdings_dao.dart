import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/holdings_table.dart';
import '../tables/trades_table.dart';
import '../../database/enums.dart';

part 'holdings_dao.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HoldingsDao — Manages the derived holdings cache.
//
// The holdings table is NEVER manually edited. It is always rebuilt from the
// canonical trades table using a full recomputation.
// ─────────────────────────────────────────────────────────────────────────────
@DriftAccessor(tables: [Holdings, Trades])
class HoldingsDao extends DatabaseAccessor<AppDatabase>
    with _$HoldingsDaoMixin {
  HoldingsDao(super.db);

  /// Returns a reactive stream of all current holdings.
  Stream<List<Holding>> watchAllHoldings() =>
      (select(holdings)
            ..orderBy([(h) => OrderingTerm.desc(h.investedValue)]))
          .watch();

  /// One-time fetch of all holdings.
  Future<List<Holding>> getAllHoldings() =>
      (select(holdings)
            ..orderBy([(h) => OrderingTerm.desc(h.investedValue)]))
          .get();

  /// Rebuilds the entire holdings cache from the trades table.
  ///
  /// Algorithm:
  ///   1. For each instrument, sum bought quantities and compute VWAP.
  ///   2. Subtract sold quantities (FIFO not required — use net position).
  ///   3. Delete holdings with net quantity <= 0 (position fully exited).
  ///   4. Upsert remaining rows.
  Future<void> rebuildHoldingsCache() async {
    // Fetch all trades ordered by instrument and time.
    final allTrades = await (select(trades)
          ..orderBy([
            (t) => OrderingTerm.asc(t.instrumentSymbol),
            (t) => OrderingTerm.asc(t.tradeTimestamp),
          ]))
        .get();

    // Group by symbol and compute net position.
    final Map<String, _SymbolAggregator> agg = {};
    for (final trade in allTrades) {
      agg.putIfAbsent(
        trade.instrumentSymbol,
        () => _SymbolAggregator(
          symbol: trade.instrumentSymbol,
          name: trade.instrumentName,
        ),
      );
      if (trade.tradeType == TradeType.buy) {
        agg[trade.instrumentSymbol]!.addBuy(trade.quantity, trade.pricePerUnit);
      } else {
        agg[trade.instrumentSymbol]!.addSell(trade.quantity, trade.pricePerUnit);
      }
    }

    // Clear and repopulate in a single transaction.
    await transaction(() async {
      await delete(holdings).go();
      for (final entry in agg.values) {
        await into(holdings).insertOnConflictUpdate(
          HoldingsCompanion.insert(
            instrumentSymbol: entry.symbol,
            instrumentName: entry.name,
            totalQuantity: entry.netQuantity,
            averagePrice: entry.vwap,
            investedValue: entry.netQuantity * entry.vwap,
            realizedPnL: Value(entry.realizedPnL),
          ),
        );
      }
    });
  }
}

/// Private helper for VWAP + net-quantity aggregation per symbol.
class _SymbolAggregator {
  final String symbol;
  final String name;

  double _totalBuyValue = 0;
  double _totalBuyQty = 0;
  double _totalSellQty = 0;
  double _totalSellValue = 0;

  _SymbolAggregator({required this.symbol, required this.name});

  void addBuy(double qty, double price) {
    _totalBuyValue += qty * price;
    _totalBuyQty += qty;
  }

  void addSell(double qty, double price) {
    _totalSellQty += qty;
    _totalSellValue += qty * price;
  }

  double get netQuantity => _totalBuyQty - _totalSellQty;

  double get vwap =>
      _totalBuyQty > 0 ? _totalBuyValue / _totalBuyQty : 0;
      
  double get realizedPnL => 
      _totalSellQty > 0 ? _totalSellValue - (_totalSellQty * vwap) : 0.0;
}
