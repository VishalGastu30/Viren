import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../database/app_database.dart';
import 'package:drift/drift.dart';

/// Service responsible for computing and verifying cryptographic hash chains
/// to detect database tampering.
class IntegrityService {
  final AppDatabase _db;

  IntegrityService(this._db);

  /// Computes the next hash in a rolling chain.
  /// [chainId] is typically the table name.
  /// [rowData] should be a deterministic string representation of the row.
  Future<String> computeNextHash(String chainId, Map<String, dynamic> rowData) async {
    // 1. Get the current tail hash
    final metadata = await (_db.select(_db.integrityMetadata)
          ..where((t) => t.chainId.equals(chainId)))
        .getSingleOrNull();

    final prevHash = metadata?.tailHash ?? 'GENESIS_BLOCK';

    // 2. Normalize and hash the row data
    final normalized = _normalizeData(rowData);
    final contentToHash = '$normalized|$prevHash';
    final newHash = sha256.convert(utf8.encode(contentToHash)).toString();

    // 3. Update the metadata tail
    await _db.into(_db.integrityMetadata).insertOnConflictUpdate(
          IntegrityMetadataCompanion.insert(
            chainId: chainId,
            tailHash: newHash,
            rowCount: Value((metadata?.rowCount ?? 0) + 1),
            lastVerifiedAt: Value(DateTime.now()),
          ),
        );

    return newHash;
  }

  /// Verifies the integrity of an entire chain.
  /// [allRows] should be a list of `Map<String, dynamic>` from drift models.
  Future<bool> verifyChain(String chainId, List<Map<String, dynamic>> allRows) async {
    String currentPrevHash = 'GENESIS_BLOCK';
    
    for (final row in allRows) {
      final storedHash = row['tamperHash']; // toJson() uses camelCase by default
      if (storedHash == null) return false; 

      final normalized = _normalizeData(row);
      final expectedHash = sha256.convert(utf8.encode('$normalized|$currentPrevHash')).toString();

      if (storedHash != expectedHash) {
        return false;
      }
      currentPrevHash = storedHash;
    }

    final metadata = await (_db.select(_db.integrityMetadata)
          ..where((t) => t.chainId.equals(chainId)))
        .getSingleOrNull();
    
    return metadata?.tailHash == currentPrevHash;
  }

  // --- Testable Core Math ---

  /// Computes a deterministic SHA-256 hash for a table row + previous hash.
  /// Exposed statically for pure unit testing without DB access.
  static String computeStaticHash(Map<String, dynamic> data, String prevHash) {
    // 1. Remove volatile fields that shouldn't affect the hash
    final cleanData = Map<String, dynamic>.from(data)
      ..remove('tamperHash')
      ..remove('tamper_hash') // For database column names
      ..remove('updatedAt')
      ..remove('updated_at') // For database column names
      ..remove('lastUpdated'); // As per the provided snippet

    // 2. Sort keys to ensure deterministic JSON ordering
    final sortedKeys = cleanData.keys.toList()..sort();
    final sortedData = <String, dynamic>{};
    for (final key in sortedKeys) {
      final value = cleanData[key];
      // Normalize values to strings, handling dates and nulls for consistent hashing
      if (value == null) {
        sortedData[key] = 'NULL';
      } else if (value is DateTime) {
        sortedData[key] = value.toUtc().toIso8601String();
      } else {
        sortedData[key] = value;
      }
    }

    // 3. Serialize and hash
    final jsonString = jsonEncode(sortedData);
    final combined = '$prevHash|$jsonString';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  // --- Core Integrity Math ---

  /// Deterministically normalizes data for hashing.
  /// Handles both database-column-style and toJson-style maps.
  /// This method is no longer used directly for hashing after refactoring.
  String _normalizeData(Map<String, dynamic> data) {
    // Exclude fields that are NOT part of the integrity-guaranteed state.
    // tamperHash is excluded because it's the result of the hash.
    // Internal metadata might be excluded if it's derived.
    final Map<String, dynamic> copy = Map.from(data)
      ..remove('tamperHash')
      ..remove('tamper_hash')
      ..remove('updatedAt')
      ..remove('updated_at');

    final sortedKeys = copy.keys.toList()..sort();
    return sortedKeys.map((k) {
      final v = copy[k];
      // Normalize values to strings, handling dates and nulls
      if (v == null) return '$k:NULL';
      if (v is DateTime) return '$k:${v.toUtc().toIso8601String()}';
      return '$k:$v';
    }).join('|');
  }
}
