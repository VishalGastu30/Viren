import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EncryptedDbOpener — Hook for SQLCipher integration
//
// Current state: Opens a standard drift_flutter (SQLite) database.
// Future intent: Switch to drift/sqlcipher once the project requires
// full database-at-rest encryption (on top of field-level encryption).
//
// This isolation ensures that switching from standard SQLite to SQLCipher
// only requires changing this single file.
// ─────────────────────────────────────────────────────────────────────────────
class EncryptedDbOpener {
  /// Opens the local database.
  /// 
  /// In the future, this will use the MEK from KeyManager to unlock
  /// the SQLCipher container.
  static QueryExecutor open(String dbName) {
    return driftDatabase(name: dbName);
  }
}
