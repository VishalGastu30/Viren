import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_database.dart';
import '../daos/trades_dao.dart';
import '../daos/holdings_dao.dart';
import '../daos/alerts_dao.dart';
import '../daos/behavior_dao.dart';
import '../daos/import_dao.dart';
import '../repositories/trade_repository.dart';
import '../repositories/holdings_repository.dart';
import '../repositories/alert_repository.dart';
import '../repositories/behavior_repository.dart';
import '../../security/key_manager.dart';
import '../../security/field_encryptor.dart';
import '../../integrity/integrity_service.dart';

// ── Ingestion ────────────────────────────────────────────────────────────────
import '../../ingestion/csv_import_service.dart';
import '../../ingestion/manual_trade_service.dart';
import '../../ingestion/email/email_import_service.dart';

// ── Intelligence ─────────────────────────────────────────────────────────────
import '../../intelligence/rules/rule_engine.dart';
import '../../intelligence/rules/allocation_drift_rule.dart';
import '../../intelligence/rules/avg_price_deviation_rule.dart';
import '../../intelligence/rules/inactivity_rule.dart';
import '../../intelligence/rules/overtrading_rule.dart';
import '../../intelligence/rules/dip_buy_pattern_rule.dart';
import '../../intelligence/confidence_calculator.dart';
import '../../intelligence/stats/stats_service.dart';
import '../../intelligence/stats/portfolio_snapshot_service.dart';
import '../../intelligence/ai/ai_provider.dart';
import '../../intelligence/ai/data_sanitizer.dart';
import '../../intelligence/ai/ai_guardrails.dart';
import '../../intelligence/ai/ollama_ai_provider.dart';

// ── Sync ─────────────────────────────────────────────────────────────────────
import '../../sync/encrypted_backup_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Database Providers
//
// The AppDatabase and KeyManager are seeded as ProviderScope overrides
// in main.dart (after async initialization). All downstream providers depend
// on those two root providers.
// ─────────────────────────────────────────────────────────────────────────────

// ── Root providers (overridden in main.dart) ──────────────────────────────────

/// The singleton AppDatabase instance, opened once at startup.
final appDatabaseProvider = Provider<AppDatabase>(
  (_) => throw UnimplementedError('AppDatabase must be initialized in main()'),
);

/// The singleton KeyManager instance, initialized after secure storage read.
final keyManagerProvider = Provider<KeyManager>(
  (_) => throw UnimplementedError('KeyManager must be initialized in main()'),
);

// ── Security ──────────────────────────────────────────────────────────────────

final fieldEncryptorProvider = Provider<FieldEncryptor>((ref) {
  final km = ref.watch(keyManagerProvider);
  return FieldEncryptor(km);
});

final integrityServiceProvider = Provider<IntegrityService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return IntegrityService(db);
});

// ── DAOs ──────────────────────────────────────────────────────────────────────

final tradesDaoProvider = Provider<TradesDao>((ref) {
  return ref.watch(appDatabaseProvider).tradesDao;
});

final holdingsDaoProvider = Provider<HoldingsDao>((ref) {
  return ref.watch(appDatabaseProvider).holdingsDao;
});

final alertsDaoProvider = Provider<AlertsDao>((ref) {
  return ref.watch(appDatabaseProvider).alertsDao;
});

final behaviorDaoProvider = Provider<BehaviorDao>((ref) {
  return ref.watch(appDatabaseProvider).behaviorDao;
});

final importDaoProvider = Provider<ImportDao>((ref) {
  return ref.watch(appDatabaseProvider).importDao;
});

// ── Repositories ──────────────────────────────────────────────────────────────

final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  return TradeRepository(
    tradesDao: ref.watch(tradesDaoProvider),
    holdingsDao: ref.watch(holdingsDaoProvider),
    encryptor: ref.watch(fieldEncryptorProvider),
    integrityService: ref.watch(integrityServiceProvider),
    snapshotService: ref.watch(portfolioSnapshotServiceProvider),
  );
});

final holdingsRepositoryProvider = Provider<HoldingsRepository>((ref) {
  return HoldingsRepository(ref.watch(holdingsDaoProvider));
});

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepository(
    ref.watch(alertsDaoProvider),
    ref.watch(integrityServiceProvider),
  );
});

final behaviorRepositoryProvider = Provider<BehaviorRepository>((ref) {
  return BehaviorRepository(ref.watch(behaviorDaoProvider));
});

// ── Reactive data providers ───────────────────────────────────────────────────

/// Live stream of all trades with decrypted reason text.
final allTradesProvider = StreamProvider((ref) {
  return ref.watch(tradeRepositoryProvider).watchAllTrades();
});

/// Live stream of current holdings (from the cache table).
final holdingsStreamProvider = StreamProvider((ref) {
  return ref.watch(holdingsRepositoryProvider).watchHoldings();
});

/// Live stream of active (non-dismissed) alerts.
final activeAlertsProvider = StreamProvider((ref) {
  return ref.watch(alertRepositoryProvider).watchActiveAlerts();
});

/// Live stream of the latest confidence score.
final confidenceScoreProvider = StreamProvider((ref) {
  return ref.watch(behaviorRepositoryProvider).watchLatestConfidenceScore();
});

/// Live stream of all import records (for the Import Center parse history).
final importsStreamProvider = StreamProvider((ref) {
  return ref.watch(importDaoProvider).watchAllImports();
});

/// Portfolio snapshots (for the dashboard sparkline).
final portfolioSnapshotsProvider = FutureProvider((ref) {
  return ref.watch(portfolioSnapshotServiceProvider).getAllSnapshots();
});

// ── Ingestion Services ────────────────────────────────────────────────────────

final csvImportServiceProvider = Provider<CsvImportService>((ref) {
  return CsvImportService(
    tradeRepository: ref.watch(tradeRepositoryProvider),
    importDao: ref.watch(importDaoProvider),
  );
});

final manualTradeServiceProvider = Provider<ManualTradeService>((ref) {
  return ManualTradeService(
    tradeRepository: ref.watch(tradeRepositoryProvider),
  );
});

final emailImportServiceProvider = Provider<EmailImportService>((ref) {
  return EmailImportService(
    tradeRepository: ref.watch(tradeRepositoryProvider),
    importDao: ref.watch(importDaoProvider),
  );
});

// ── Intelligence ──────────────────────────────────────────────────────────────

final ruleEngineProvider = Provider<RuleEngine>((ref) {
  return RuleEngine([
    AllocationDriftRule(),
    AvgPriceDeviationRule(),
    InactivityRule(),
    OvertradingRule(),
    DipBuyPatternRule(),
  ]);
});

final confidenceCalculatorProvider = Provider<ConfidenceCalculator>((ref) {
  return ConfidenceCalculator(ref.watch(behaviorRepositoryProvider));
});

final statsServiceProvider = Provider<StatsService>((ref) {
  return StatsService();
});

final portfolioSnapshotServiceProvider = Provider<PortfolioSnapshotService>((ref) {
  return PortfolioSnapshotService(ref.watch(appDatabaseProvider));
});

// ── AI ────────────────────────────────────────────────────────────────────────

/// AI provider — defaults to OllamaAiProvider for local offline inference.
final aiProviderProvider = Provider<AiProvider>((ref) {
  return OllamaAiProvider();
});

final dataSanitizerProvider = Provider<DataSanitizer>((ref) {
  return DataSanitizer();
});

final aiGuardrailsProvider = Provider<AiGuardrails>((ref) {
  return AiGuardrails();
});

// ── Sync / Backup ─────────────────────────────────────────────────────────────

final encryptedBackupServiceProvider = Provider<EncryptedBackupService>((ref) {
  return EncryptedBackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(fieldEncryptorProvider),
  );
});
