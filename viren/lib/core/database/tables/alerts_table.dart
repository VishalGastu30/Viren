import 'package:drift/drift.dart';
import '../enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// alerts — Explainable Nudges
//
// Alerts are immutable records. dismiss ≠ delete.
// trigger_data stores the JSON evidence that caused this alert to be raised,
// kept for full explainability traceability.
// ─────────────────────────────────────────────────────────────────────────────
class Alerts extends Table {
  /// UUID primary key.
  TextColumn get id => text().named('id')();

  /// Machine-readable alert type tag (e.g. "SUPPORT_BREAK", "52_WEEK_HIGH").
  TextColumn get alertType => text().named('alert_type')();

  /// Severity level.
  IntColumn get severity =>
      intEnum<AlertSeverity>().named('severity')();

  /// Short headline shown to the user.
  TextColumn get title => text().named('title')();

  /// Full explanatory description.
  TextColumn get description => text().named('description')();

  /// Confidence score (0–100) for this alert's trigger.
  IntColumn get confidence =>
      integer().named('confidence').withDefault(const Constant(0))();

  /// Symbol this alert relates to. Nullable for portfolio-wide alerts.
  TextColumn get relatedInstrument =>
      text().named('related_instrument').nullable()();

  /// JSON object representing the raw data that triggered this alert.
  /// Stored for explainability — the app can always re-derive why.
  TextColumn get triggerData =>
      text().named('trigger_data').withDefault(const Constant('{}'))();

  /// UTC creation timestamp.
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  /// Non-null when the user explicitly dismissed this alert.
  DateTimeColumn get dismissedAt =>
      dateTime().named('dismissed_at').nullable()();

  /// Non-null when the user has snoozed this alert until a future time.
  DateTimeColumn get snoozedUntil =>
      dateTime().named('snoozed_until').nullable()();

  /// Reference to the import session that triggered this alert.
  TextColumn get importId => text().named('import_id').nullable()();

  /// Cryptographic hash for tamper detection (Rolling chain).
  TextColumn get tamperHash => text().named('tamper_hash').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
