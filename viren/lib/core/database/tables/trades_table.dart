import 'package:drift/drift.dart';
import '../enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// trades — The Atomic Truth
//
// Every row is one executed action. Never mutated destructively.
// All higher-level views derive from here.
// ─────────────────────────────────────────────────────────────────────────────
class Trades extends Table {
  /// UUID primary key.
  TextColumn get id => text().named('id')();

  /// Ticker / symbol (e.g. RELIANCE, TCS).
  TextColumn get instrumentSymbol =>
      text().named('instrument_symbol').withLength(min: 1, max: 50)();

  /// Human-readable name of the instrument.
  TextColumn get instrumentName => text().named('instrument_name')();

  /// Exchange (e.g. NSE, BSE). Nullable — not always available.
  TextColumn get exchange =>
      text().named('exchange').nullable()();

  /// Direction: BUY or SELL.
  IntColumn get tradeType =>
      intEnum<TradeType>().named('trade_type')();

  /// Number of shares/units.
  RealColumn get quantity => real().named('quantity')();

  /// Price per unit at execution time.
  RealColumn get pricePerUnit => real().named('price_per_unit')();

  /// Stored total (quantity × pricePerUnit). Derived but persisted to avoid
  /// floating point recomputation drift across schema versions.
  RealColumn get totalValue => real().named('total_value')();

  /// UTC timestamp of trade execution.
  DateTimeColumn get tradeTimestamp =>
      dateTime().named('trade_timestamp')();

  /// Broker name (e.g. Zerodha, Groww).
  TextColumn get broker => text().named('broker').withDefault(const Constant('Unknown'))();

  /// Brokerage + STT + other charges. Nullable when unknown.
  RealColumn get charges => real().named('charges').nullable()();

  /// Real column for brokerage charges.
  RealColumn get brokerage => real().named('brokerage').nullable()();

  /// Real column for securities transaction tax (STT).
  RealColumn get stt => real().named('stt').nullable()();

  /// Real column for goods and services tax (GST).
  RealColumn get gst => real().named('gst').nullable()();

  /// Real column for other levies and stamp duty.
  RealColumn get otherLevies => real().named('other_levies').nullable()();

  /// The net amount computed after applying all levies to the gross amount.
  RealColumn get netAmountAfterLevies => real().named('net_amount_after_levies').nullable()();

  /// The true cost basis calculated including all charges.
  RealColumn get trueCostBasis => real().named('true_cost_basis').nullable()();

  /// Reconciliation status.
  IntColumn get status => intEnum<TradeStatus>().named('status').withDefault(const Constant(0))();

  /// ISO 4217 currency code.
  TextColumn get currency =>
      text().named('currency').withDefault(const Constant('INR'))();

  /// How the trade entered the system.
  IntColumn get source => intEnum<TradeSource>().named('source')();

  /// Reference to the originating import (email message ID, file hash, etc.).
  TextColumn get sourceReference =>
      text().named('source_reference').nullable()();

  /// Reference to the originating import session.
  TextColumn get importId => text().named('import_id').nullable()();

  /// The raw execution number/ID precisely as it appeared on the statement.
  TextColumn get rawTradeNo => text().named('raw_trade_no').nullable()();

  /// ISIN — permanent NSE/BSE instrument identifier.
  /// e.g. INF204KB17I5 for GOLDBEES. Never changes unlike symbol.
  TextColumn get isin => text().named('isin').nullable()();

  /// Settlement date — T+1 from the contract note.
  /// Distinct from trade date. Useful for cash flow tracking.
  DateTimeColumn get settlementDate =>
      dateTime().named('settlement_date').nullable()();

  /// Trade execution time — HH:MM:SS from Annexure A.
  /// e.g. "10:14:48". Stored as text to avoid timezone issues.
  TextColumn get tradeTime => text().named('trade_time').nullable()();

  /// NSE Order Number from Annexure A (16 digits).
  /// Different from Trade No. Stored for audit trail.
  TextColumn get orderNo => text().named('order_no').nullable()();

  /// Parser confidence for auto-imported trades (0–100). 100 = manual entry.
  IntColumn get parseConfidence =>
      integer().named('parse_confidence').withDefault(const Constant(100))();

  /// Row creation time in UTC.
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  /// Last update time in UTC.
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  /// Cryptographic hash for tamper detection (Rolling chain).
  /// sha256(row_data + prev_hash)
  TextColumn get tamperHash => text().named('tamper_hash').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
