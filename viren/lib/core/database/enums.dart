// ─────────────────────────────────────────────────────────────────────────────
// VIREN — Database Enums
//
// All domain enums used across tables. Stored as INTEGER in SQLite via Drift's
// IntEnum converter. Adding new variants is always additive — never rename or
// reorder existing values, as that would corrupt stored data.
// ─────────────────────────────────────────────────────────────────────────────

/// The direction of a trade execution.
enum TradeType {
  buy,
  sell,
}

/// How the trade record entered the system.
enum TradeSource {
  email,
  csv,
  manual,
  nseDirect,
  sbiContractNote,
  both,
}

/// The reconciliation status of a trade.
enum TradeStatus {
  unconfirmed,
  confirmed,
  reconciled,
  discrepant,
}

/// Severity level for alerts shown to the user.
enum AlertSeverity {
  info,
  success,
  warning,
  critical,
}

/// Behavioral patterns detected by the intelligence engine.
enum BehaviorMetricType {
  overtrading,
  inactivity,
  panic,
  consistency,
}

/// Self-reported emotional state at the time of a trade.
enum EmotionalState {
  calm,
  cautious,
  excited,
  fearful,
  disciplined,
}

/// Origin of a cached price data point.
enum PriceSource {
  manual,
  cached,
  imported,
}

/// Type of data import session.
enum ImportType {
  email,
  csv,
}

/// Encryption algorithm version tag embedded in every encrypted field blob.
/// Never delete old versions — they are needed to decrypt legacy data.
enum EncryptionVersion {
  /// AES-256-GCM with 12-byte IV and 16-byte auth tag.
  v1,
}
