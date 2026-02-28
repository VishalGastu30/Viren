import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────────
// column_mappings — Import Memory
//
// Stores successful CSV column-to-field mappings so the user never has to
// re-map the same file format twice. One row per unique source name.
// ─────────────────────────────────────────────────────────────────────────────
class ColumnMappings extends Table {
  /// UUID primary key.
  TextColumn get id => text().named('id')();

  /// Broker/source label (e.g. "Zerodha Tradebook", "Groww Equity").
  TextColumn get sourceName => text().named('source_name')();

  /// Serialized column→field mapping as JSON.
  TextColumn get mappingJson => text().named('mapping_json')();

  /// UTC row creation time.
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
