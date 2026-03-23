import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'enums.dart';

import 'tables/trades_table.dart';
import 'tables/trade_reasons_table.dart';
import 'tables/holdings_table.dart';
import 'tables/price_history_table.dart';
import 'tables/portfolio_snapshots_table.dart';
import 'tables/alerts_table.dart';
import 'tables/behavior_metrics_table.dart';
import 'tables/confidence_meter_table.dart';
import 'tables/imports_table.dart';
import 'tables/integrity_metadata_table.dart';
import 'tables/column_mappings_table.dart';
import 'tables/email_credentials_table.dart';
import 'tables/conversations_table.dart';
import 'tables/memory_table.dart';
import 'daos/trades_dao.dart';
import 'daos/holdings_dao.dart';
import 'daos/alerts_dao.dart';
import 'daos/behavior_dao.dart';
import 'daos/import_dao.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppDatabase — The Spine
//
// Schema version history:
//   v1 — Initial schema (all 9 core tables)
//
// Migration policy:
//   • Migrations are ADDITIVE ONLY. New columns use nullable or have defaults.
//   • Never drop columns or rename them — read old data formats forever.
//   • Bump schemaVersion and add a migration step for every change.
// ─────────────────────────────────────────────────────────────────────────────
@DriftDatabase(
  tables: [
    Trades,
    TradeReasons,
    Holdings,
    PriceHistory,
    PortfolioSnapshots,
    Alerts,
    BehaviorMetrics,
    ConfidenceMeter,
    Imports,
    IntegrityMetadata,
    ColumnMappings,
    EmailCredentials,
    Conversations,
    ConversationMessages,
    AssistantMemories,
  ],
  daos: [
    TradesDao,
    HoldingsDao,
    AlertsDao,
    BehaviorDao,
    ImportDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // Create all tables in dependency order.
          await m.createAll();

          // ── Indexes ───────────────────────────────────────────────────
          // trades: fast lookup by time (most common query) and by symbol.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_trades_timestamp '
            'ON trades (trade_timestamp DESC)',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_trades_symbol '
            'ON trades (instrument_symbol)',
          );

          // price_history: composite index for range queries per symbol.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_price_history_symbol_time '
            'ON price_history (instrument_symbol, timestamp DESC)',
          );

          // portfolio_snapshots: fast chronological lookup.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_snapshots_date '
            'ON portfolio_snapshots (snapshot_date DESC)',
          );

          // alerts: most recent first, for the active-alerts stream.
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_alerts_created '
            'ON alerts (created_at DESC)',
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: Add tamper detection hardening
            await m.createTable(integrityMetadata);
            await m.addColumn(trades, trades.tamperHash);
            await m.addColumn(alerts, alerts.tamperHash);
            await m.addColumn(tradeReasons, tradeReasons.tamperHash);
          }
          if (from < 3) {
            // v3: Add lineage tracking
            await m.addColumn(trades, trades.importId);
            await m.addColumn(alerts, alerts.importId);
          }
          if (from < 4) {
            // v4: Ingestion support tables
            await m.createTable(columnMappings);
            await m.createTable(emailCredentials);
          }
          if (from < 5) {
            // v5: Conversation history for AI assistant
            await m.createTable(conversations);
            await m.createTable(conversationMessages);
          }
          if (from < 6) {
            // v6: Assistant memory — compressed conversation summaries
            await m.createTable(assistantMemories);
          }
          if (from < 7) {
            // v7: CNB-only import — ISIN, settlement date, trade time, order number
            await m.addColumn(trades, trades.isin as GeneratedColumn);
            await m.addColumn(trades, trades.settlementDate as GeneratedColumn);
            await m.addColumn(trades, trades.tradeTime as GeneratedColumn);
            await m.addColumn(trades, trades.orderNo as GeneratedColumn);
          }
        },
        beforeOpen: (details) async {
          // Enable WAL mode for better concurrent read performance on mobile.
          await customStatement('PRAGMA journal_mode=WAL');
          // Enforce FK integrity at runtime (SQLite default: OFF).
          await customStatement('PRAGMA foreign_keys=ON');

          // Clean up corrupted symbols from bad imports.
          // These cause live price fetch loops that lag the UI.
          await customStatement(
            "DELETE FROM trades WHERE instrument_symbol LIKE '%LIMITED' "
            "OR instrument_symbol = 'UNKNOWN' "
            "OR instrument_symbol = 'BANKLIMITED' "
            "OR instrument_symbol LIKE '%STATEMENT%' "
            "OR length(instrument_symbol) > 20",
          );
          await customStatement(
            "DELETE FROM holdings WHERE instrument_symbol LIKE '%LIMITED' "
            "OR instrument_symbol = 'UNKNOWN' "
            "OR instrument_symbol = 'BANKLIMITED' "
            "OR length(instrument_symbol) > 20",
          );
        },
      );

  /// Opens a persistent SQLite database at the app's documents directory.
  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'viren_vault');
  }

  /// Opens an in-memory database — used for unit tests only.
  static AppDatabase forTesting() {
    return AppDatabase(NativeDatabase.memory());
  }
}
