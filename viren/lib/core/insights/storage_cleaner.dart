import 'package:drift/drift.dart' as drift;
import 'dart:developer' as developer;
import '../database/app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StorageCleaner — Smart Vault Cleanup.
//
// Prunes stale data to keep SQLite fast and manageable.
// - Keeps ALL USER DATA (holdings, trades, journals, emotion notes).
// - Deletes PRICE_SNAPSHOT > 7 days old.
// - Deletes OVERNIGHT_DATA > 7 days old.
// - Deletes MACRO_STATE > 30 days old.
// - Deletes MORNING_BRIEFING > 14 days old.
// ─────────────────────────────────────────────────────────────────────────────

class StorageCleaner {
  final AppDatabase _db;

  StorageCleaner(this._db);

  Future<void> run() async {
    developer.log('StorageCleaner: Starting silent cleanup...', name: 'StorageCleaner');
    try {
      final now = DateTime.now();

      // Price snapshots > 7 days
      final priceCutoff = now.subtract(const Duration(days: 7));
      final priceDeleted = await (_db.delete(_db.alerts)
            ..where((a) => a.alertType.equals('PRICE_SNAPSHOT') & a.createdAt.isSmallerThanValue(priceCutoff)))
          .go();

      // Overnight data > 7 days
      final overnightCutoff = now.subtract(const Duration(days: 7));
      final overnightDeleted = await (_db.delete(_db.alerts)
            ..where((a) => a.alertType.equals('OVERNIGHT_DATA') & a.createdAt.isSmallerThanValue(overnightCutoff)))
          .go();

      // Macro state > 30 days
      final macroCutoff = now.subtract(const Duration(days: 30));
      final macroDeleted = await (_db.delete(_db.alerts)
            ..where((a) => a.alertType.equals('MACRO_STATE') & a.createdAt.isSmallerThanValue(macroCutoff)))
          .go();

      // Morning briefings > 14 days
      final briefingCutoff = now.subtract(const Duration(days: 14));
      final briefingDeleted = await (_db.delete(_db.alerts)
            ..where((a) => a.alertType.equals('MORNING_BRIEFING') & a.createdAt.isSmallerThanValue(briefingCutoff)))
          .go();

      final total = priceDeleted + overnightDeleted + macroDeleted + briefingDeleted;
      developer.log('StorageCleaner: Done. Removed $total stale records.', name: 'StorageCleaner');
    } catch (e) {
      developer.log('StorageCleaner: Failed to clean up: $e', name: 'StorageCleaner');
      rethrow;
    }
  }
}
