import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../security/field_encryptor.dart';
import 'sync_data_contract.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Encrypted Backup Service — Local Export/Import
//
// Exports selected tables as an encrypted JSON blob using the sync key.
// Imports with conflict resolution: local always wins.
// File-based — no cloud required.
//
// Security:
//   • Export blob is encrypted with AES-256-GCM (sync key)
//   • Only syncable tables are exported (per SyncDataContract)
//   • Keys never leave the device
// ─────────────────────────────────────────────────────────────────────────────

/// Metadata about an exported backup.
class BackupMetadata {
  final String version;
  final DateTime createdAt;
  final int tableCount;
  final int totalRows;
  final String checksum;

  const BackupMetadata({
    required this.version,
    required this.createdAt,
    required this.tableCount,
    required this.totalRows,
    required this.checksum,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'created_at': createdAt.toIso8601String(),
    'table_count': tableCount,
    'total_rows': totalRows,
    'checksum': checksum,
  };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) => BackupMetadata(
    version: json['version'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    tableCount: json['table_count'] as int,
    totalRows: json['total_rows'] as int,
    checksum: json['checksum'] as String,
  );
}

class EncryptedBackupService {
  final AppDatabase _db;
  final FieldEncryptor _encryptor;

  EncryptedBackupService(this._db, this._encryptor);

  /// Exports all syncable data as an encrypted JSON string.
  ///
  /// The returned string can be written to a file for backup.
  /// It is encrypted — cannot be read without the sync key.
  Future<String> exportBackup() async {
    final payload = <String, dynamic>{};
    int totalRows = 0;

    // Export each syncable table
    if (SyncDataContract.canSync('trades')) {
      final trades = await _db.select(_db.trades).get();
      payload['trades'] = trades.map((t) => t.toJson()).toList();
      totalRows += trades.length;
    }

    if (SyncDataContract.canSync('holdings')) {
      final holdings = await _db.select(_db.holdings).get();
      payload['holdings'] = holdings.map((h) => h.toJson()).toList();
      totalRows += holdings.length;
    }

    if (SyncDataContract.canSync('alerts')) {
      final alerts = await _db.select(_db.alerts).get();
      payload['alerts'] = alerts.map((a) => a.toJson()).toList();
      totalRows += alerts.length;
    }

    if (SyncDataContract.canSync('portfolio_snapshots')) {
      final snapshots = await _db.select(_db.portfolioSnapshots).get();
      payload['portfolio_snapshots'] = snapshots.map((s) => s.toJson()).toList();
      totalRows += snapshots.length;
    }

    if (SyncDataContract.canSync('behavior_metrics')) {
      final metrics = await _db.select(_db.behaviorMetrics).get();
      payload['behavior_metrics'] = metrics.map((m) => m.toJson()).toList();
      totalRows += metrics.length;
    }

    if (SyncDataContract.canSync('confidence_meter')) {
      final scores = await _db.select(_db.confidenceMeter).get();
      payload['confidence_meter'] = scores.map((s) => s.toJson()).toList();
      totalRows += scores.length;
    }

    if (SyncDataContract.canSync('imports')) {
      final imports = await _db.select(_db.imports).get();
      payload['imports'] = imports.map((i) => i.toJson()).toList();
      totalRows += imports.length;
    }

    // Create metadata
    final plainJson = jsonEncode(payload);
    final checksum = sha256.convert(utf8.encode(plainJson)).toString();

    final metadata = BackupMetadata(
      version: '1.0',
      createdAt: DateTime.now().toUtc(),
      tableCount: payload.length,
      totalRows: totalRows,
      checksum: checksum,
    );

    // Wrap in envelope and encrypt
    final envelope = {
      'metadata': metadata.toJson(),
      'data': plainJson,
    };

    final encrypted = _encryptor.encrypt(jsonEncode(envelope));
    if (encrypted == null) {
      throw StateError('Failed to encrypt backup');
    }

    return encrypted;
  }

  /// Imports a backup from an encrypted string.
  ///
  /// Conflict resolution: local data always wins.
  /// This means existing rows are NOT overwritten.
  /// Only new rows (by ID) are inserted.
  Future<BackupMetadata> importBackup(String encryptedBackup) async {
    // Decrypt
    final decrypted = _encryptor.decrypt(encryptedBackup);
    if (decrypted == null) {
      throw StateError('Failed to decrypt backup — wrong key?');
    }

    final envelope = jsonDecode(decrypted) as Map<String, dynamic>;
    final metadata = BackupMetadata.fromJson(
      envelope['metadata'] as Map<String, dynamic>,
    );

    // Verify checksum
    final dataJson = envelope['data'] as String;
    final checksum = sha256.convert(utf8.encode(dataJson)).toString();
    if (checksum != metadata.checksum) {
      throw StateError('Backup checksum mismatch — data may be corrupted');
    }

    // Restore data — INSERT OR IGNORE (local always wins)
    final data = jsonDecode(dataJson) as Map<String, dynamic>;

    await _db.transaction(() async {
      // Restore each table that has data in the backup
      if (data.containsKey('trades')) {
        final trades = data['trades'] as List;
        for (final row in trades) {
          try {
            await _db.customInsert(
              'INSERT OR IGNORE INTO trades (id, instrument_symbol, instrument_name, exchange, trade_type, quantity, price_per_unit, total_value, trade_timestamp, broker, charges, currency, source, source_reference, parse_confidence, import_id, tamper_hash, created_at, updated_at) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              variables: [
                Variable.withString(row['id'] as String),
                Variable.withString(row['instrument_symbol'] as String),
                Variable.withString(row['instrument_name'] as String),
                Variable.withString(row['exchange'] as String? ?? ''),
                Variable.withInt(row['trade_type'] as int? ?? 0),
                Variable.withReal((row['quantity'] as num).toDouble()),
                Variable.withReal((row['price_per_unit'] as num).toDouble()),
                Variable.withReal((row['total_value'] as num).toDouble()),
                Variable.withString(row['trade_timestamp'] as String),
                Variable.withString(row['broker'] as String? ?? 'Unknown'),
                Variable.withReal((row['charges'] as num?)?.toDouble() ?? 0),
                Variable.withString(row['currency'] as String? ?? 'INR'),
                Variable.withInt(row['source'] as int? ?? 0),
                Variable.withString(row['source_reference'] as String? ?? ''),
                Variable.withInt(row['parse_confidence'] as int? ?? 100),
                Variable.withString(row['import_id'] as String? ?? ''),
                Variable.withString(row['tamper_hash'] as String? ?? ''),
                Variable.withString(row['created_at'] as String? ?? DateTime.now().toIso8601String()),
                Variable.withString(row['updated_at'] as String? ?? DateTime.now().toIso8601String()),
              ],
            );
          } catch (_) {
            // Skip row on conflict — local wins
          }
        }
      }

      if (data.containsKey('holdings')) {
        final holdings = data['holdings'] as List;
        for (final row in holdings) {
          try {
            await _db.customInsert(
              'INSERT OR IGNORE INTO holdings (instrument_symbol, instrument_name, total_quantity, average_price, invested_value) '
              'VALUES (?, ?, ?, ?, ?)',
              variables: [
                Variable.withString(row['instrument_symbol'] as String),
                Variable.withString(row['instrument_name'] as String),
                Variable.withReal((row['total_quantity'] as num).toDouble()),
                Variable.withReal((row['average_price'] as num).toDouble()),
                Variable.withReal((row['invested_value'] as num).toDouble()),
              ],
            );
          } catch (_) {}
        }
      }

      if (data.containsKey('alerts')) {
        final alerts = data['alerts'] as List;
        for (final row in alerts) {
          try {
            await _db.customInsert(
              'INSERT OR IGNORE INTO alerts (id, alert_type, severity, title, description, confidence, related_instrument, trigger_data, import_id, tamper_hash, is_dismissed, snoozed_until, created_at) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              variables: [
                Variable.withString(row['id'] as String),
                Variable.withString(row['alert_type'] as String),
                Variable.withInt(row['severity'] as int? ?? 0),
                Variable.withString(row['title'] as String),
                Variable.withString(row['description'] as String),
                Variable.withInt(row['confidence'] as int? ?? 0),
                Variable.withString(row['related_instrument'] as String? ?? ''),
                Variable.withString(row['trigger_data'] as String? ?? '{}'),
                Variable.withString(row['import_id'] as String? ?? ''),
                Variable.withString(row['tamper_hash'] as String? ?? ''),
                Variable.withBool(row['is_dismissed'] as bool? ?? false),
                Variable.withString(row['snoozed_until'] as String? ?? ''),
                Variable.withString(row['created_at'] as String? ?? DateTime.now().toIso8601String()),
              ],
            );
          } catch (_) {}
        }
      }

      if (data.containsKey('portfolio_snapshots')) {
        final snapshots = data['portfolio_snapshots'] as List;
        for (final row in snapshots) {
          try {
            await _db.customInsert(
              'INSERT OR IGNORE INTO portfolio_snapshots (id, snapshot_date, total_invested, current_value, unrealized_pnl, realized_pnl, confidence_score, created_at) '
              'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
              variables: [
                Variable.withString(row['id'] as String),
                Variable.withString(row['snapshot_date'] as String),
                Variable.withReal((row['total_invested'] as num).toDouble()),
                Variable.withReal((row['current_value'] as num).toDouble()),
                Variable.withReal((row['unrealized_pnl'] as num).toDouble()),
                Variable.withReal((row['realized_pnl'] as num).toDouble()),
                Variable.withReal((row['confidence_score'] as num?)?.toDouble() ?? 0),
                Variable.withString(row['created_at'] as String? ?? DateTime.now().toIso8601String()),
              ],
            );
          } catch (_) {}
        }
      }

      if (data.containsKey('imports')) {
        final imports = data['imports'] as List;
        for (final row in imports) {
          try {
            await _db.customInsert(
              'INSERT OR IGNORE INTO imports (id, import_type, source_name, rows_imported, success_rate, created_at) '
              'VALUES (?, ?, ?, ?, ?, ?)',
              variables: [
                Variable.withString(row['id'] as String),
                Variable.withInt(row['import_type'] as int? ?? 0),
                Variable.withString(row['source_name'] as String),
                Variable.withInt(row['rows_imported'] as int? ?? 0),
                Variable.withInt(row['success_rate'] as int? ?? 0),
                Variable.withString(row['created_at'] as String? ?? DateTime.now().toIso8601String()),
              ],
            );
          } catch (_) {}
        }
      }
    });

    return metadata;
  }

  /// Uploads the locally generated encrypted backup to Supabase Storage.
  /// Overwrites the previous backup.
  Future<void> pushToCloud() async {
    final encryptedData = await exportBackup();
    final supabase = Supabase.instance.client;
    
    // Using a fixed bucket name
    final bucket = supabase.storage.from('viren_vault');
    final fileBytes = utf8.encode(encryptedData);
    
    await bucket.uploadBinary(
      'latest_backup.viren',
      Uint8List.fromList(fileBytes),
      fileOptions: const FileOptions(upsert: true),
    );
  }

  /// Downloads the encrypted backup from Supabase Storage and attempts to import it.
  Future<BackupMetadata> pullFromCloud() async {
    final supabase = Supabase.instance.client;
    final bucket = supabase.storage.from('viren_vault');
    
    final fileBytes = await bucket.download('latest_backup.viren');
    final encryptedString = utf8.decode(fileBytes);
    
    return await importBackup(encryptedString);
  }
}
