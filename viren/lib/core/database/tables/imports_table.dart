import 'package:drift/drift.dart';
import '../enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// imports — Data Lineage
//
// Every ingestion event is recorded here. This table enables audit trails,
// duplicate detection, and importation debugging.
// ─────────────────────────────────────────────────────────────────────────────
class Imports extends Table {
  /// UUID primary key.
  TextColumn get id => text().named('id')();

  /// Whether this was an email or CSV import.
  IntColumn get importType =>
      intEnum<ImportType>().named('import_type')();

  /// Human-readable source (e.g. "Zerodha CSV", "HDFC Securities Email").
  TextColumn get sourceName => text().named('source_name')();

  /// Number of trade rows imported in this session.
  IntColumn get rowsImported =>
      integer().named('rows_imported').withDefault(const Constant(0))();

  /// Percentage of rows that were successfully parsed (0–100).
  IntColumn get successRate =>
      integer().named('success_rate').withDefault(const Constant(0))();

  /// UTC timestamp of ingestion.
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
