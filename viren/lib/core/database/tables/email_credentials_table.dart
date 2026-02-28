import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────────
// email_credentials — Encrypted Email Access
//
// Stores encrypted IMAP/OAuth credentials. The credentials_encrypted column
// is an AES-256-GCM blob — the FieldEncryptor handles this transparently.
// Only one row per email address is expected (single-user system).
// ─────────────────────────────────────────────────────────────────────────────
class EmailCredentials extends Table {
  /// UUID primary key.
  TextColumn get id => text().named('id')();

  /// Email address for display/identification.
  TextColumn get emailAddress => text().named('email_address')();

  /// Auth method: 0 = IMAP, 1 = Gmail OAuth.
  IntColumn get authType => integer().named('auth_type')();

  /// AES-256-GCM encrypted credentials blob.
  /// Contains either IMAP password or OAuth refresh token.
  TextColumn get credentialsEncrypted =>
      text().named('credentials_encrypted')();

  /// UTC creation timestamp.
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  /// Last successful connection timestamp.
  DateTimeColumn get lastUsedAt =>
      dateTime().named('last_used_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
