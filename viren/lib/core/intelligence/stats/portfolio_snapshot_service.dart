import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../../database/app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PortfolioSnapshotService — Point-in-Time Portfolio State
//
// On-demand snapshot generator that captures current portfolio state
// for historical comparison. Called after trade inserts or manually
// from the UI.
// ─────────────────────────────────────────────────────────────────────────────

class PortfolioSnapshotService {
  final AppDatabase _db;
  final _uuid = const Uuid();

  PortfolioSnapshotService(this._db);

  /// Takes a snapshot of current portfolio state and persists it.
  ///
  /// [confidenceScore] — latest confidence score, if available.
  Future<PortfolioSnapshot> takeSnapshot({
    double? confidenceScore,
  }) async {
    // 1. Get current holdings
    final holdings = await (_db.select(_db.holdings)
          ..orderBy([(h) => OrderingTerm.desc(h.investedValue)]))
        .get();

    if (holdings.isEmpty) {
      throw StateError('Cannot take snapshot — no holdings exist');
    }

    // 2. Compute totals
    final totalInvested = holdings.fold<double>(
      0, (sum, h) => sum + h.investedValue,
    );

    // Current market value is not available without live prices —
    // use invested value as placeholder. Price history integration
    // will improve this later.
    final currentValue = totalInvested;
    final unrealizedPnl = currentValue - totalInvested;

    // 3. Compute realized P&L (simplified: from sell trades)
    final sellTrades = await (_db.select(_db.trades)
          ..where((t) => t.tradeType.equals(1))) // sell = index 1
        .get();

    double realizedPnl = 0;
    // Simplified realized P&L: sum of (sellPrice - avgBuyPrice) * qty
    // This is approximate without FIFO/LIFO matching
    for (final sell in sellTrades) {
      final holding = holdings.firstWhere(
        (h) => h.instrumentSymbol == sell.instrumentSymbol,
        orElse: () => holdings.first, // shouldn't happen, but safety
      );
      realizedPnl += (sell.pricePerUnit - holding.averagePrice) * sell.quantity;
    }

    // 4. Persist snapshot
    final today = DateTime.now().toUtc();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final entry = PortfolioSnapshotsCompanion.insert(
      id: _uuid.v4(),
      snapshotDate: dateStr,
      totalInvested: totalInvested,
      currentValue: currentValue,
      unrealizedPnl: unrealizedPnl,
      realizedPnl: realizedPnl,
      confidenceScore: Value(confidenceScore ?? 0),
      createdAt: Value(today),
    );

    final result = await _db.into(_db.portfolioSnapshots).insertReturning(entry);
    return result;
  }

  /// Fetches all snapshots ordered by date (newest first).
  Future<List<PortfolioSnapshot>> getAllSnapshots() {
    return (_db.select(_db.portfolioSnapshots)
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .get();
  }

  /// Fetches the most recent snapshot.
  Future<PortfolioSnapshot?> getLatestSnapshot() {
    return (_db.select(_db.portfolioSnapshots)
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }
}
