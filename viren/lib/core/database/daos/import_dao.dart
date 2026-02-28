import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/imports_table.dart';

part 'import_dao.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ImportDao — Data lineage for every ingestion session.
// ─────────────────────────────────────────────────────────────────────────────
@DriftAccessor(tables: [Imports])
class ImportDao extends DatabaseAccessor<AppDatabase> with _$ImportDaoMixin {
  ImportDao(super.db);

  /// Record a new import session.
  Future<Import> logImport(ImportsCompanion entry) =>
      into(imports).insertReturning(entry);

  /// Watch all import records, newest first.
  Stream<List<Import>> watchAllImports() =>
      (select(imports)
            ..orderBy([(i) => OrderingTerm.desc(i.createdAt)]))
          .watch();

  /// Total number of trades ever imported from external sources.
  Future<int> totalImportedRows() async {
    final sumExpr = imports.rowsImported.sum();
    final query = selectOnly(imports)..addColumns([sumExpr]);
    final row = await query.getSingle();
    return row.read(sumExpr)?.toInt() ?? 0;
  }
}
