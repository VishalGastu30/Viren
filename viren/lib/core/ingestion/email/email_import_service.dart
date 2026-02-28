import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import '../../database/enums.dart';
import '../../database/repositories/trade_repository.dart';
import '../../database/daos/import_dao.dart';
import '../../database/app_database.dart';
import '../../auth/auth_service.dart';
import 'broker_email_parser.dart';
import 'scanner_controller.dart';
import 'attachment_handler.dart';
import 'parsers/pdf_broker_parser.dart';
import 'parsers/nse_direct_parser.dart';
import 'parsers/nse_alerts_parser.dart';
import 'parsers/sbi_statement_parser.dart';
import '../tallying/ledger_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmailImportService — Orchestrates the 3-stage email ingestion pipeline.
//
// Stage 1: DISCOVERY  — Query Gmail, fetch full messages (PAN-independent)
// Stage 2: DECRYPTION — Download PDFs, decrypt with PAN, extract text
// Stage 3: TALLYING   — LedgerEngine validates and cross-checks
//
// CRITICAL DESIGN RULE:
//   Discovery MUST succeed independently of PAN.
//   PAN failure ≠ "no broker emails".
//   These are two completely different failure states.
// ─────────────────────────────────────────────────────────────────────────────

/// Preview of what was found in the email scan.
class EmailImportPreview {
  // ── Stage 1: Discovery (PAN-independent) ──
  final int totalBrokerEmailsFound;
  final int totalPdfAttachments;

  // ── Stage 2: Decryption + Parsing ──
  final List<EmailParseResult> results;
  final int totalTradesFound;
  final int totalSnapshotsFound;
  final int aggregateConfidence;
  final int pdfDecryptionFailures;
  final List<String> decryptionErrors;

  // ── Stage 3: Ledger ──
  final List<String> ledgerDiscrepancies;
  final List<String> ledgerErrors;

  const EmailImportPreview({
    required this.totalBrokerEmailsFound,
    required this.totalPdfAttachments,
    required this.results,
    required this.totalTradesFound,
    required this.aggregateConfidence,
    this.totalSnapshotsFound = 0,
    this.pdfDecryptionFailures = 0,
    this.decryptionErrors = const [],
    this.ledgerDiscrepancies = const [],
    this.ledgerErrors = const [],
  });

  /// True if Gmail returned zero broker emails (PAN is irrelevant here).
  bool get noBrokerEmailsExist => totalBrokerEmailsFound == 0;

  /// True if broker emails exist but all PDFs failed to decrypt.
  bool get allDecryptionsFailed =>
      totalBrokerEmailsFound > 0 &&
      pdfDecryptionFailures > 0 &&
      totalTradesFound == 0 &&
      totalSnapshotsFound == 0;

  bool get hasTrades => totalTradesFound > 0;
  bool get hasDiscrepancies => ledgerDiscrepancies.isNotEmpty;
  bool get requiresConfirmation =>
      aggregateConfidence < 90 || ledgerDiscrepancies.isNotEmpty;
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

/// Result of Stage 1: Discovery.
class EmailDiscoveryResult {
  final List<ScannedEmail> rawEmails;
  final int totalBrokerEmailsFound;
  final int totalPdfAttachments;

  const EmailDiscoveryResult({
    required this.rawEmails,
    required this.totalBrokerEmailsFound,
    required this.totalPdfAttachments,
  });

  bool get isEmpty => totalBrokerEmailsFound == 0;
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

  /// STAGE 1: DISCOVERY
  /// Queries Gmail, fetches full messages. PAN-independent.
  Future<EmailDiscoveryResult> discover({
    required AuthService authService,
    DateTime? since,
    int maxResults = 500,
  }) async {
    final scanner = ScannerController();

    final emails = await scanner.scanForBrokerEmails(
      authService: authService,
      since: since,
      maxResults: maxResults,
    );

    int totalPdfs = 0;
    for (final email in emails) {
      totalPdfs += email.attachments.where((a) => a.isPdf).length;
    }

    return EmailDiscoveryResult(
      rawEmails: emails,
      totalBrokerEmailsFound: emails.length,
      totalPdfAttachments: totalPdfs,
    );
  }

  /// STAGE 3, 4, 5: DECRYPT, PARSE, LEDGER
  /// Processes previously discovered emails using the in-memory PAN.
  Future<EmailImportPreview> process({
    required EmailDiscoveryResult discovery,
    required String pan,
    required AuthService authService,
  }) async {
    if (discovery.isEmpty) {
      return const EmailImportPreview(
        totalBrokerEmailsFound: 0,
        totalPdfAttachments: 0,
        results: [],
        totalTradesFound: 0,
        aggregateConfidence: 0,
      );
    }

    final scanner = ScannerController();
    final attachmentHandler = const AttachmentHandler(); // No Vault dependency
    final parserResults = <EmailParseResult>[];
    int decryptFailures = 0;
    final decryptErrors = <String>[];

    final parsers = <PdfBrokerParserBase>[
      NseDirectParser(),
      NseAlertsParser(),
      SbiStatementParser(),
    ];

    for (final email in discovery.rawEmails) {
      final fromEmail = email.from.toLowerCase();

      for (final parser in parsers) {
        if (parser.exactSenders.any((s) => fromEmail.contains(s))) {
          final res = await parser.parsePdf(
            email, scanner, attachmentHandler, authService, pan,
          );

          // Track decrypt failures from this result's errors
          for (final err in res.errors) {
            if (err.contains('decrypt') ||
                err.contains('PAN') ||
                err.contains('password')) {
              decryptFailures++;
              decryptErrors.add(err);
            }
          }

          parserResults.add(res);
          break;
        }
      }
    }

    // STAGE 5: TALLYING (LedgerEngine)
    final ledger = LedgerEngine();
    final ledgerResult = ledger.reconstruct(parserResults);

    final totalTrades = ledgerResult.validatedTrades.length;

    // Compute confidence
    int totalConf = 0;
    int confCount = 0;
    for (final res in parserResults) {
      if (res.trades.isNotEmpty || res.snapshots.isNotEmpty) {
        totalConf += res.aggregateConfidence;
        confCount++;
      }
    }
    final avgConfidence =
        confCount == 0 ? 0 : (totalConf / confCount).round();

    int totalSnapshots = 0;
    for (final res in parserResults) {
      totalSnapshots += res.snapshots.length;
    }

    return EmailImportPreview(
      totalBrokerEmailsFound: discovery.totalBrokerEmailsFound,
      totalPdfAttachments: discovery.totalPdfAttachments,
      results: parserResults,
      totalTradesFound: totalTrades,
      aggregateConfidence: avgConfidence,
      totalSnapshotsFound: totalSnapshots,
      pdfDecryptionFailures: decryptFailures,
      decryptionErrors: decryptErrors,
      ledgerDiscrepancies: ledgerResult.discrepancies,
      ledgerErrors: ledgerResult.errors,
    );
  }

  /// Commits parsed email trades to the database.
  Future<EmailImportResult> commit(EmailImportPreview preview) async {
    final importId = _uuid.v4();
    final errors = <String>[];
    int successful = 0;
    int total = 0;

    await _importDao.logImport(
      ImportsCompanion.insert(
        id: importId,
        importType: ImportType.email,
        sourceName: 'Email Import',
        rowsImported: Value(preview.totalTradesFound),
        successRate: Value(preview.aggregateConfidence),
      ),
    );

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
            rawTradeNo: trade.tradeNo,
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
