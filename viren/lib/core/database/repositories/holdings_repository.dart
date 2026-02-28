import '../app_database.dart';
import '../daos/holdings_dao.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HoldingsRepository
// ─────────────────────────────────────────────────────────────────────────────
class HoldingsRepository {
  final HoldingsDao _dao;
  HoldingsRepository(this._dao);

  /// Returns a reactive stream of current holdings, ordered by invested value.
  Stream<List<Holding>> watchHoldings() => _dao.watchAllHoldings();

  /// One-time fetch of current holdings.
  Future<List<Holding>> getHoldings() => _dao.getAllHoldings();

  /// Forces a full rebuild of the holdings cache from the trades table.
  /// Call this after bulk imports or data corrections.
  Future<void> rebuildCache() => _dao.rebuildHoldingsCache();
}
