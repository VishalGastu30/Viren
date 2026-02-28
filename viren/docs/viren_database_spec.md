# VIREN — Database Specification (v1.0)

This document serves as the technical source of truth for the manual and automated implementation of the Viren local database layer.

## Overview
Viren uses **SQLite** via the **Drift** (formerly Moor) ORM. The database follows an **offline-first** architecture where the local state is the absolute authority.

- **Storage Location:** Platform-specific documents directory (e.g., App Support on iOS).
- **File Name:** `viren_vault.db`
- **Schema Version:** 1
- **Journal Mode:** Write-Ahead Logging (WAL) enabled for dual-reader performance.

---

## Security Model

Viren implements a tiered security model to ensure single-user privacy.

### 1. Key Management
- **Master Encryption Key (MEK):** A 256-bit random key generated on first launch.
- **Storage:** Persisted in the platform's secure enclave (`flutter_secure_storage`).
- **Derivation:** Purpose-specific keys flow from the MEK via **HKDF-SHA256**:
    - `DATA_KEY`: Used for field-level encryption.
    - `SYNC_KEY`: For future encrypted cloud syncing.

### 2. Field-Level Encryption
Sensitive fields are never stored in plaintext. They utilize **AES-256GCM** encryption.
- **Payload Format:** `base64(version_byte || iv[12] || ciphertext || auth_tag[16])`
- **Version Byte:** `0x01` (AES-GCM). Allows for future algorithm rotation.
- **Authenticated Data:** The version byte is included as AAD to prevent tampering with the encryption type.

---

## Schema Design

### Core Tables

| Table Name | Purpose | Primary Key | Volatility |
| :--- | :--- | :--- | :--- |
| `trades` | The atomic truth of all actions | UUID (`id`) | Low |
| `trade_reasons` | Intent and emotional metadata | UUID (`id`) | Low |
| `holdings` | Derived cache of open positions | Ticker (`instrument_symbol`) | Med (recomputed) |
| `price_history` | Market data snapshots for charts | UUID (`id`) | High |
| `portfolio_snapshots` | Time-series performance data | UUID (`id`) | Daily |
| `alerts` | Immutable journal of system nudges | UUID (`id`) | Med |
| `behavior_metrics` | Quantified behavioral signals | UUID (`id`) | Weekly |
| `confidence_meter` | Aggregate behavioral health score | UUID (`id`) | Monthly |
| `imports` | Data lineage for ingestion events | UUID (`id`) | Low |

---

## Table Details

### `trades`
The append-only log of every execution.
- **Constraints:** `instrument_symbol` is normalized to uppercase.
- **Indexes:** 
    - `idx_trades_timestamp` (DESC): For history views.
    - `idx_trades_symbol`: For per-ticker filtering.

### `trade_reasons` (Sensitive)
Stores the "Why" behind the "What".
- **Encrypted Fields:** `reason_text_encrypted`, `emotional_state_encrypted`.
- **Relationship:** 1:1 with `trades` via `trade_id`.

### `holdings` (Derived)
A performance cache. It is **destructively recomputed** from the `trades` table whenever a trade is added or modified.
- **Aggregation:** Uses VWAP (Volume Weighted Average Price) for purchase history.

### `alerts`
Immutable notifications.
- **Explainability:** `trigger_data` (JSON) contains the raw data points that caused the alert.
- **Soft State:** Dismissal is a `dismissed_at` timestamp; the row is never deleted.

---

## Migration Policy

Viren follows a **strict additive-only** migration policy.
1. **Never rename or delete columns.**
2. **Never change the semantics of existing data.**
3. **Additive changes only:** New columns must be nullable or have a default value.
4. **Data conversion:** If a data format changes, the application code must remain capable of reading the old format (via the versioning system) indefinitely.

---

## Performance Targets
- **Insertion:** < 50ms for a single trade (including encryption overhead).
- **Holdings Recompute:** < 200ms for portfolios up to 500 trades.
- **Search:** Instantaneous lookup on symbols via B-Tree indexing.
