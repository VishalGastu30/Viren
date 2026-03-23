import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/trades_table.dart';
import '../tables/trade_reasons_table.dart';

part 'trades_dao.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TradesDao — Write and read the canonical trade truth.
//
// NOTE: This DAO works with raw DB types. Encryption/decryption of sensitive
// fields happens at the Repository layer, NOT here. The DAO is encryption-agnostic.
// ─────────────────────────────────────────────────────────────────────────────
@DriftAccessor(tables: [Trades, TradeReasons])
class TradesDao extends DatabaseAccessor<AppDatabase> with _$TradesDaoMixin {
  TradesDao(super.db);

  // ── Trades ──────────────────────────────────────────────────────────────────

  /// Insert a new trade and return the inserted row.
  Future<Trade> insertTrade(TradesCompanion entry) =>
      into(trades).insertReturning(entry);

  /// Update the updatedAt timestamp and any mutable trade fields.
  Future<bool> updateTrade(TradesCompanion entry) =>
      update(trades).replace(entry);

  /// Watch all trades, newest first. Used by the main trade history screen.
  Stream<List<Trade>> watchAllTrades() =>
      (select(trades)..orderBy([(t) => OrderingTerm.desc(t.tradeTimestamp)]))
          .watch();

  /// One-time fetch of all trades for a given symbol.
  Future<List<Trade>> getTradesBySymbol(String symbol) =>
      (select(trades)
            ..where((t) => t.instrumentSymbol.equals(symbol))
            ..orderBy([(t) => OrderingTerm.desc(t.tradeTimestamp)]))
          .get();

  /// Fetch a single trade by ID. Returns null if not found.
  Future<Trade?> getTradeById(String id) =>
      (select(trades)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Count of all trade records.
  Future<int> tradeCount() async {
    final countExpr = trades.id.count();
    final query = selectOnly(trades)..addColumns([countExpr]);
    final row = await query.getSingle();
    return row.read(countExpr) ?? 0;
  }

  /// Stream of the total trade count. Used to trigger lightweight analytics recomputation.
  Stream<int> watchTradeCount() {
    return (select(trades)..orderBy([])).watch().map((rows) => rows.length);
  }

  // ── Trade Reasons ────────────────────────────────────────────────────────────

  /// Insert or replace the reason for a trade.
  Future<TradeReason> upsertTradeReason(TradeReasonsCompanion entry) async {
    await into(tradeReasons).insertOnConflictUpdate(entry);
    return (select(tradeReasons)
          ..where((r) => r.tradeId.equals(entry.tradeId.value)))
        .getSingle();
  }

  /// Fetch the reason linked to a trade. Returns null if not yet recorded.
  Future<TradeReason?> getReasonForTrade(String tradeId) =>
      (select(tradeReasons)..where((r) => r.tradeId.equals(tradeId)))
          .getSingleOrNull();

  /// Watch the reason for a specific trade.
  Stream<TradeReason?> watchReasonForTrade(String tradeId) =>
      (select(tradeReasons)..where((r) => r.tradeId.equals(tradeId)))
          .watchSingleOrNull();

  /// Fetch ALL trades in chronological order for integrity verification.
  Future<List<Trade>> getAllTrades() =>
      (select(trades)..orderBy([(t) => OrderingTerm.asc(t.tradeTimestamp)]))
          .get();

  /// Fetch ALL trade reasons for integrity verification.
  Future<List<TradeReason>> getAllTradeReasons() =>
      (select(tradeReasons)..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
          .get();
}
