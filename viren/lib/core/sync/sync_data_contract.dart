// ─────────────────────────────────────────────────────────────────────────────
// Sync Data Contract — Defines What Syncs and What NEVER Syncs
//
// This is the boundary between local and cloud. Cloud operates on this
// contract, never on raw tables.
//
// ✅ Syncs: trades (sans reasons), holdings, alerts, snapshots
// ❌ Never syncs: encryption keys, raw reasons, emotions, email bodies
// ─────────────────────────────────────────────────────────────────────────────

/// Defines the sync policy for each data type.
enum SyncPolicy {
  /// Syncs in both directions.
  bidirectional,

  /// Syncs only from local to cloud (backup).
  localToCloud,

  /// Never syncs. Ever.
  never,
}

/// Sync contract for all data types.
class SyncDataContract {
  /// Defines what syncs and how.
  static const Map<String, SyncPolicy> policies = {
    // ── Syncable (encrypted blobs only) ──────────────────────
    'trades':              SyncPolicy.bidirectional,
    'holdings':            SyncPolicy.localToCloud,
    'alerts':              SyncPolicy.bidirectional,
    'portfolio_snapshots': SyncPolicy.localToCloud,
    'behavior_metrics':    SyncPolicy.localToCloud,
    'confidence_meter':    SyncPolicy.localToCloud,
    'imports':             SyncPolicy.localToCloud,
    'price_history':       SyncPolicy.localToCloud,

    // ── NEVER syncs ──────────────────────────────────────────
    'trade_reasons':       SyncPolicy.never,  // encrypted emotions/reasons
    'email_credentials':   SyncPolicy.never,  // OAuth tokens
    'column_mappings':     SyncPolicy.never,  // local preference
    'integrity_metadata':  SyncPolicy.never,  // local chain state
  };

  /// Checks if a table is allowed to sync.
  static bool canSync(String tableName) {
    final policy = policies[tableName];
    return policy != null && policy != SyncPolicy.never;
  }

  /// Returns the sync policy for a table.
  static SyncPolicy policyFor(String tableName) {
    return policies[tableName] ?? SyncPolicy.never;
  }

  /// Returns all table names that are allowed to sync.
  static List<String> get syncableTables {
    return policies.entries
        .where((e) => e.value != SyncPolicy.never)
        .map((e) => e.key)
        .toList();
  }

  /// Returns all table names that NEVER sync.
  static List<String> get neverSyncTables {
    return policies.entries
        .where((e) => e.value == SyncPolicy.never)
        .map((e) => e.key)
        .toList();
  }
}
