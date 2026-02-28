import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────────
// trade_reasons — Intent Memory
//
// 1:1 with trades. Links WHY to WHAT.
// reason_text and emotional_state_encrypted are stored as AES-256-GCM
// ciphertext blobs — they are NEVER stored in plaintext.
// ─────────────────────────────────────────────────────────────────────────────
class TradeReasons extends Table {
  /// UUID primary key.
  TextColumn get id => text().named('id')();

  /// FK → trades.id (enforced at repository layer). Unique enforces 1:1.
  TextColumn get tradeId => text().named('trade_id')();

  /// Encrypted investment thesis / reason text.
  /// Format: base64(version_byte || iv[12] || ciphertext || tag[16])
  TextColumn get reasonTextEncrypted =>
      text().named('reason_text_encrypted').nullable()();

  /// JSON array of conviction tags (e.g. ["Long-term", "Conviction"]).
  /// Stored as plain JSON — not sensitive.
  TextColumn get tagsJson =>
      text().named('tags_json').withDefault(const Constant('[]'))();

  /// Encrypted emotional state enum index.
  /// Encrypted because emotional labels are considered sensitive.
  TextColumn get emotionalStateEncrypted =>
      text().named('emotional_state_encrypted').nullable()();

  /// Self-reported confidence in the decision at time of entry (0–100).
  IntColumn get confidenceLevel =>
      integer().named('confidence_level').nullable()();

  /// Row creation time in UTC.
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  /// Cryptographic hash for tamper detection (Rolling chain).
  TextColumn get tamperHash => text().named('tamper_hash').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
