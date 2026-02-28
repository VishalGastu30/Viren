import 'package:drift/drift.dart';

/// Tracks the current tail hash for rolling chains across different tables.
class IntegrityMetadata extends Table {
  /// The table name or chain identifier (e.g., 'trades', 'alerts').
  TextColumn get chainId => text().named('chain_id')();

  /// The SHA-256 hash of the last successfully committed row in this chain.
  TextColumn get tailHash => text().named('tail_hash')();

  /// Total number of rows verified in this chain.
  IntColumn get rowCount => integer().named('row_count').withDefault(const Constant(0))();

  /// Last verification timestamp.
  DateTimeColumn get lastVerifiedAt => 
      dateTime().named('last_verified_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {chainId};
}
