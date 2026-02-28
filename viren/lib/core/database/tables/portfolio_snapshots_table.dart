import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────────
// portfolio_snapshots — Time Travel
//
// Periodic portfolio state snapshots (daily / weekly).
// Enables time-based performance views without recomputing from raw trades.
// One row per snapshot_date — if you need intraday, a full datetime column
// can be added in a future migration.
// ─────────────────────────────────────────────────────────────────────────────
class PortfolioSnapshots extends Table {
  /// UUID primary key.
  TextColumn get id => text().named('id')();

  /// The date this snapshot represents (stored as ISO-8601 date string).
  TextColumn get snapshotDate => text().named('snapshot_date')();

  /// Total capital deployed on this date.
  RealColumn get totalInvested => real().named('total_invested')();

  /// Estimated portfolio market value on this date.
  RealColumn get currentValue => real().named('current_value')();

  /// Unrealized P&L (currentValue - totalInvested) at snapshot time.
  RealColumn get unrealizedPnl => real().named('unrealized_pnl')();

  /// Cumulative realized P&L from closed positions up to this date.
  RealColumn get realizedPnl => real().named('realized_pnl')();

  /// Confidence score at snapshot time (0.0–100.0).
  RealColumn get confidenceScore =>
      real().named('confidence_score').withDefault(const Constant(0.0))();

  /// UTC row creation time.
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
