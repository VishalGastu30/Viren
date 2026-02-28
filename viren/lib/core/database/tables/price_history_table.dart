import 'package:drift/drift.dart';
import '../enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// price_history — Cached Market Memory
//
// Stores historical price snapshots per instrument.
// Composite index on (instrument_symbol, timestamp) for efficient range queries.
// Retention window is enforced by the DAO (default: 90 days rolling).
// ─────────────────────────────────────────────────────────────────────────────
class PriceHistory extends Table {
  /// UUID primary key.
  TextColumn get id => text().named('id')();

  /// Ticker / symbol.
  TextColumn get instrumentSymbol =>
      text().named('instrument_symbol').withLength(min: 1, max: 50)();

  /// Price at this point in time.
  RealColumn get price => real().named('price')();

  /// UTC timestamp of this price reading.
  DateTimeColumn get timestamp => dateTime().named('timestamp')();

  /// Origin of this price data point.
  IntColumn get source =>
      intEnum<PriceSource>().named('source')();

  @override
  Set<Column> get primaryKey => {id};
}
