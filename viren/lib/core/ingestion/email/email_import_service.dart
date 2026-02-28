import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import '../../database/enums.dart';
import '../../database/repositories/trade_repository.dart';
import '../../database/daos/import_dao.dart';
import '../../database/app_database.dart';
import '../../auth/auth_service.dart';
import '../../auth/token_vault.dart';
import 'broker_email_parser.dart';
import 'scanner_controller.dart';
import 'attachment_handler.dart';
import 'parsers/pdf_broker_parser.dart';
import 'parsers/nse_direct_parser.dart';
import 'parsers/nse_alerts_parser.dart';
import 'parsers/sbi_statement_parser.dart';
import '../tallying/ledger_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmailImportService — Orchestrates the email ingestion pipeline.
//
// Flow:
//   1. Connect to email via EmailConnector
//   2. Filter by broker sender whitelist
//   3. Parse with broker-specific structured parsers
//   4. Return preview for user confirmation
//   5. On confirmation, persist via TradeRepository
//
// Security invariants:
//   • Email body is NEVER persisted — only SHA-256 hash
//   • OAuth tokens stored encrypted (handled by caller)
//   • No full inbox sync
//   • Read-only access
// ─────────────────────────────────────────────────────────────────────────────

/// Preview of what was found in the email scan.
class EmailImportPreview {
  final List<EmailParseResult> results;
  final int totalTradesFound;
  final int totalEmailsScanned;
  final int aggregateConfidence;
  final int totalSnapshotsFound;
  final List<String> ledgerDiscrepancies;
  final List<String> ledgerErrors;

  const EmailImportPreview({
    required this.results,
    required this.totalTradesFound,
    required this.totalEmailsScanned,
    required this.aggregateConfidence,
    this.totalSnapshotsFound = 0,
    this.ledgerDiscrepancies = const [],
    this.ledgerErrors = const [],
  });

  bool get requiresConfirmation => aggregateConfidence < 90 || ledgerDiscrepancies.isNotEmpty;
  bool get hasTrades => totalTradesFound > 0;
  bool get hasDiscrepancies => ledgerDiscrepancies.isNotEmpty;
}

/// Result of committing email-imported trades.
class EmailImportResult {
  final String importId;
  final int totalTrades;
  final int successfulTrades;
  final int failedTrades;
  final List<String> errors;

  const EmailImportResult({
    required this.importId,
    required this.totalTrades,
    required this.successfulTrades,
    required this.failedTrades,
    required this.errors,
  });
}

class EmailImportService {
  final TradeRepository _tradeRepo;
  final ImportDao _importDao;
  final _uuid = const Uuid();

  EmailImportService({
    required TradeRepository tradeRepository,
    required ImportDao importDao,
  })  : _tradeRepo = tradeRepository,
        _importDao = importDao;

  /// Scans for broker emails and returns a preview.
  ///
  /// This method:
  ///   1. Connects to email server via ScannerController
  ///   2. Fetches unbounded emails from exact broker senders
  ///   3. Parses PDFs and extracts Trades & Snapshots
  ///   4. Runs LedgerEngine to validate and tally
  Future<EmailImportPreview> scan({
    required AuthService authService,
    required TokenVault tokenVault,
    DateTime? since, // If null -> unbounded full scan (First Run)
    int maxResults = 100,
  }) async {
    final scanner = ScannerController();
    final attachmentHandler = AttachmentHandler(tokenVault);

    final emails = await scanner.scanForBrokerEmails(
      authService: authService,
      since: since,
      maxResults: maxResults,
    );

    if (emails.isEmpty) {
      return const EmailImportPreview(
        results: [],
        totalTradesFound: 0,
        totalEmailsScanned: 0,
        aggregateConfidence: 0,
      );
    }

    final parserResults = <EmailParseResult>[];
    
    // Register V2 PDF Parsers
    final parsers = <PdfBrokerParserBase>[
      NseDirectParser(),
      NseAlertsParser(),
      SbiStatementParser(),
    ];

    for (final email in emails) {
      final fromEmail = email.from.toLowerCase();
      
      for (final parser in parsers) {
        if (parser.exactSenders.any((s) => fromEmail.contains(s))) {
          final res = await parser.parsePdf(email, scanner, attachmentHandler, authService);
          if (res.trades.isNotEmpty || res.snapshots.isNotEmpty || res.errors.isNotEmpty) {
            parserResults.add(res);
          }
          break; // Stop checking other parsers if one matched
        }
      }
    }

    // Run Ledger Engine
    final ledger = LedgerEngine();
    final ledgerResult = ledger.reconstruct(parserResults);

    final totalTrades = ledgerResult.validatedTrades.length;
    final totalEmailsScanned = emails.length;

    // Calculate confidence based on parsed results
    int totalConf = 0;
    int confCount = 0;
    for (final res in parserResults) {
      if (res.trades.isNotEmpty || res.snapshots.isNotEmpty) {
        totalConf += res.aggregateConfidence;
        confCount++;
      }
    }
    final avgConfidence = confCount == 0 ? 0 : (totalConf / confCount).round();

    // Count total snapshots
    int totalSnapshots = 0;
    for (final res in parserResults) {
      totalSnapshots += res.snapshots.length;
    }

    return EmailImportPreview(
      results: parserResults,
      totalTradesFound: totalTrades,
      totalEmailsScanned: totalEmailsScanned,
      aggregateConfidence: avgConfidence,
      totalSnapshotsFound: totalSnapshots,
      ledgerDiscrepancies: ledgerResult.discrepancies,
      ledgerErrors: ledgerResult.errors,
    );
  }

  /// Commits parsed email trades to the database.
  ///
  /// Call this after user confirms the preview.
  Future<EmailImportResult> commit(EmailImportPreview preview) async {
    final importId = _uuid.v4();
    final errors = <String>[];
    int successful = 0;
    int total = 0;

    // Log the import session
    final totalTrades = preview.totalTradesFound;
    await _importDao.logImport(
      ImportsCompanion.insert(
        id: importId,
        importType: ImportType.email,
        sourceName: 'Email Import',
        rowsImported: Value(totalTrades),
        successRate: Value(preview.aggregateConfidence),
      ),
    );

    // Insert each trade
    for (final result in preview.results) {
      for (final trade in result.trades) {
        total++;
        try {
          await _tradeRepo.insertTrade(
            instrumentSymbol: trade.symbol,
            instrumentName: trade.instrumentName,
            exchange: trade.exchange,
            tradeType: trade.tradeType,
            quantity: trade.quantity,
            pricePerUnit: trade.pricePerUnit,
            charges: trade.charges,
            broker: trade.broker,
            source: TradeSource.email,
            sourceReference: trade.sourceMessageHash,
            parseConfidence: trade.confidence,
            tradeTimestamp: trade.tradeDate,
            originImportId: importId,
          );
          successful++;
        } catch (e) {
          errors.add('${trade.symbol}: $e');
        }
      }
    }

    return EmailImportResult(
      importId: importId,
      totalTrades: total,
      successfulTrades: successful,
      failedTrades: total - successful,
      errors: errors,
    );
  }
}
