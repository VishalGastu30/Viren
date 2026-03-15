import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../database/app_database.dart';
import '../../market/nse_price_service.dart';

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

    // Fetch live prices for accurate snapshot
    final symbols = holdings
        .map((h) => h.instrumentSymbol.toUpperCase())
        .toList();
    double currentValue = 0;
    try {
      final prices = await NsePriceService.getPrices(symbols);
      for (final h in holdings) {
        final sym = h.instrumentSymbol.toUpperCase();
        final cmp = prices[sym];
        currentValue += cmp != null
            ? cmp * h.totalQuantity
            : h.investedValue; // fallback to invested if no price
      }
    } catch (e) {
      debugPrint('PortfolioSnapshotService: price fetch failed: $e');
      currentValue = totalInvested; // fallback entirely
    }

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

