import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';

import '../../database/enums.dart';
import '../../database/repositories/trade_repository.dart';
import '../../database/daos/import_dao.dart';
import '../../database/app_database.dart';
import '../../intelligence/confidence_calculator.dart';
import '../../auth/auth_service.dart';
import 'broker_email_parser.dart';
import 'scanner_controller.dart';
import 'attachment_handler.dart';
import 'pdf_classifier.dart';
import 'document_content_parser.dart';
import 'ai_trade_extractor.dart';
import 'parsers/nse_trade_confirmation_parser.dart';
import 'parsers/sbi_contract_note_parser.dart';
import 'parsers/sbi_margin_statement_parser.dart';
import 'parsers/sbi_funds_statement_parser.dart';
import 'parsers/sbi_securities_statement_parser.dart';
import 'parsers/nse_alerts_parser_v2.dart';
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
  
  // ── Stats ──
  final int totalUnknownDocuments;

  const EmailImportPreview({
    required this.totalBrokerEmailsFound,
    required this.totalPdfAttachments,
    required this.results,
    required this.totalTradesFound,
    required this.aggregateConfidence,
    this.totalSnapshotsFound = 0,
    this.pdfDecryptionFailures = 0,
    this.totalUnknownDocuments = 0,
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
  final List<String> warnings;

  const EmailImportResult({
    required this.importId,
    required this.totalTrades,
    required this.successfulTrades,
    required this.failedTrades,
    required this.errors,
    this.warnings = const [],
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
  final AppDatabase _db;
  final ConfidenceCalculator _confidenceCalculator;
  final _uuid = const Uuid();

  EmailImportService({
    required TradeRepository tradeRepository,
    required ImportDao importDao,
    required AppDatabase db,
    required ConfidenceCalculator confidenceCalculator,
  })  : _tradeRepo = tradeRepository,
        _importDao = importDao,
        _db = db,
        _confidenceCalculator = confidenceCalculator;

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

  /// STAGE 3, 4, 5: DECRYPT, CLASSIFY, PARSE, LEDGER
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
    final attachmentHandler = AttachmentHandler();
    final parserResults = <EmailParseResult>[];
    int decryptFailures = 0;
    final decryptErrors = <String>[];

    // Registry of our specialized Layer 4 parsers
    final Map<PdfDocumentType, DocumentContentParser> parsers = {
      PdfDocumentType.nseTradeConfirmation: NseTradeConfirmationParser(),
      PdfDocumentType.nseAlertsStatement: NseAlertsParser(),
      PdfDocumentType.sbiContractNote: SbiContractNoteParser(),
      PdfDocumentType.sbiMarginStatement: SbiMarginStatementParser(),
      PdfDocumentType.sbiFundsStatement: SbiFundsStatementParser(),
      PdfDocumentType.sbiSecuritiesStatement: SbiSecuritiesStatementParser(),
    };

    for (final email in discovery.rawEmails) {
      for (final attachment in email.attachments) {
        if (!attachment.isPdf) continue;

        try {
          // LAYER 2: Explicit Decryption (Independent of Parsing)
          final bytes = await scanner.downloadAttachment(
            authService: authService,
            messageId: email.messageId,
            attachmentId: attachment.attachmentId,
          );

          final result = await attachmentHandler.processPdfAttachment(
            attachmentBytes: bytes,
            filename: attachment.filename,
            attachmentHash: scanner.computeAttachmentHash(bytes),
            pan: pan,
          );

          if (!result.decryptionSucceeded) {
            decryptFailures++;
            decryptErrors.add(result.errorMessage ?? 'Failed to decrypt ${attachment.filename}.');
            continue;
          }

          if (result.extractedText.isEmpty) {
            continue;
          }

          // LAYER 3: Semantic Document Classification
          final docType = PdfClassifier.classify(
            filename: attachment.filename,
            senderEmail: email.from,
            rawText: result.extractedText,
          );

          if (docType == PdfDocumentType.unknown) {
             parserResults.add(EmailParseResult(
                messageId: email.messageId,
                trades: const [],
                warnings: ['Unknown document format or sender: ${attachment.filename}'],
                errors: const [],
                aggregateConfidence: 0,
             ));
             continue;
          }

          // LAYER 4: Specialized Parsing
          final parser = parsers[docType];
          if (parser != null) {
              final parseRes = parser.parseRawText(
                rawText: result.extractedText,
                filename: attachment.filename,
                attachmentHash: result.attachmentHash,
                emailDate: email.date,
              );
              
              List<EmailParsedTrade> finalTrades = List.from(parseRes.trades);
              final warnings = List<String>.from(parseRes.warnings);
              int finalConfidence = parseRes.aggregateConfidence;

              // --- AI SEMANTIC EXTRACTION FALLBACK ---
              // ONLY allowed for NSE Direct executions. SBI and others are strictly
              // snapshots/reconciliation and must NEVER hit the AI extractor.
              final isTradeDocument = docType == PdfDocumentType.nseTradeConfirmation;

              if (isTradeDocument && finalTrades.isEmpty && parseRes.rawCandidates.isNotEmpty) {
                 final aiExtractor = AiTradeExtractor();
                 final aiTrades = <EmailParsedTrade>[];
                 
                 for (final candidate in parseRes.rawCandidates) {
                     final extractedList = await aiExtractor.extractTrades(
                       candidate: candidate,
                       documentTypeLabel: docType.name,
                       emailDate: email.date,
                       sourceMessageHash: result.attachmentHash,
                     );
                     aiTrades.addAll(extractedList);
                 }

                 if (aiTrades.isNotEmpty) {
                    finalTrades = aiTrades;
                    // Calculate an aggregate confidence from the AI trades
                    final sumConf = aiTrades.fold<int>(0, (sum, t) => sum + t.confidence);
                    finalConfidence = (sumConf / aiTrades.length).round();
                    warnings.add('Regex failed. Recovered ${aiTrades.length} trades via AI fallback (qwen2.5:3b).');
                 } else {
                    warnings.add('Regex and AI fallback both failed to extract any trades from this document.');
                 }
              }

              parserResults.add(EmailParseResult(
                messageId: email.messageId, // Map back to original email ID
                trades: finalTrades,
                snapshots: parseRes.snapshots,
                aggregateConfidence: finalConfidence,
                warnings: warnings,
                errors: parseRes.errors,
                rowsDetected: parseRes.rowsDetected,
                rowsParsed: parseRes.rowsParsed,
                rejectedRows: parseRes.rejectedRows,
              ));
          }
        } catch (e) {
          decryptErrors.add('System error processing ${attachment.filename}: $e');
        }
      }
    }

    // STAGE 5: TALLYING (LedgerEngine)
    final ledger = LedgerEngine();
    final ledgerResult = ledger.reconstruct(parserResults);

    final totalTrades = ledgerResult.validatedTrades.length;

    // Compute confidence and stats
    int totalConf = 0;
    int confCount = 0;
    int totalUnknown = 0;
    for (final res in parserResults) {
      if (res.trades.isNotEmpty || res.snapshots.isNotEmpty) {
        totalConf += res.aggregateConfidence;
        confCount++;
      }
      if (res.warnings.any((w) => w.contains('Unknown document format'))) {
        totalUnknown++;
      }
    }
    final avgConfidence = confCount == 0 ? 0 : (totalConf / confCount).round();

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
      totalUnknownDocuments: totalUnknown,
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
            brokerage: trade.brokerage,
            stt: trade.stt,
            gst: trade.gst,
            otherLevies: trade.otherLevies,
            netAmountAfterLevies: trade.netAmountAfterLevies,
            trueCostBasis: trade.trueCostBasis,
            status: trade.status,
            broker: trade.broker,
            source: trade.source ?? TradeSource.email,
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

    // Recompute confidence score after new trades are imported
    try {
      final allTrades = await _db.select(_db.trades).get();
      // Build reasons map: tradeId → rawTradeNo as proxy for reason
      // (actual reasons are stored encrypted — use empty map for now,
      //  strategy score will reflect % of trades with reasons)
      final reasons = <String, String?>{};
      final emotionalStates = <String, String?>{};
      for (final t in allTrades) {
        // Use rawTradeNo as a signal that the trade was documented
        reasons[t.id] = t.rawTradeNo?.isNotEmpty == true
            ? 'Imported from broker' : null;
        emotionalStates[t.id] = null; // no emotional data from imports
      }
      await _confidenceCalculator.compute(
        trades: allTrades,
        reasons: reasons,
        emotionalStates: emotionalStates,
      );
    } catch (_) {
      // Non-fatal — score update failure must never block trade import
    }

    final allWarnings = <String>[];
    allWarnings.addAll(preview.ledgerDiscrepancies);
    for (final result in preview.results) {
      allWarnings.addAll(result.warnings);
    }

    return EmailImportResult(
      importId: importId,
      totalTrades: total,
      successfulTrades: successful,
      failedTrades: total - successful,
      errors: errors,
      warnings: allWarnings,
    );
  }
}
