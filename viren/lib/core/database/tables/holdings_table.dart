import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────────
// holdings — Current State Cache
//
// Derived from the trades table. Rebuilt on demand. Never manually edited.
// PK is instrument_symbol — only one row per holding.
// ─────────────────────────────────────────────────────────────────────────────
class Holdings extends Table {
  /// Instrument symbol acts as the natural primary key for holdings.
  TextColumn get instrumentSymbol =>
      text().named('instrument_symbol').withLength(min: 1, max: 50)();

  /// Human-readable instrument name.
  TextColumn get instrumentName => text().named('instrument_name')();

  /// Net quantity currently held (BUYs - SELLs).
  RealColumn get totalQuantity => real().named('total_quantity')();

  /// Volume-weighted average purchase price.
  RealColumn get averagePrice => real().named('average_price')();

  /// Total capital deployed (averagePrice × totalQuantity).
  RealColumn get investedValue => real().named('invested_value')();

  /// Realized Profit & Loss calculated.
  RealColumn get realizedPnL => real().named('realized_pnl').withDefault(const Constant(0.0))();

  /// UTC timestamp of the last cache rebuild.
  DateTimeColumn get lastUpdated =>
      dateTime().named('last_updated').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {instrumentSymbol};
}
