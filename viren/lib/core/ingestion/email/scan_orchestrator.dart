import 'dart:async';
import 'dart:developer' as developer;


import '../../database/enums.dart';
import '../../database/repositories/trade_repository.dart';
import '../../database/daos/import_dao.dart';
import '../../auth/auth_service.dart';
import 'broker_email_parser.dart';
import 'scanner_controller.dart';
import 'attachment_handler.dart';
import 'pdf_classifier.dart';
import 'document_content_parser.dart';
import 'ai_trade_extractor.dart';
import 'email_import_service.dart';
import 'gmail_smoke_test.dart';
import 'parsers/nse_trade_confirmation_parser.dart';
import 'parsers/sbi_contract_note_parser.dart';
import 'parsers/sbi_margin_statement_parser.dart';
import 'parsers/sbi_funds_statement_parser.dart';
import 'parsers/sbi_securities_statement_parser.dart';
import 'parsers/nse_alerts_parser_v2.dart';
import '../tallying/ledger_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scan Orchestrator — Stream-based progress emitter for the email pipeline.
//
// Wraps the EmailImportService internals and emits ScanEvent for each
// granular step. The UI listens to this stream to drive the Command Center.
// ─────────────────────────────────────────────────────────────────────────────

/// Canonical scan stages — DO NOT RENAME.
enum ScanStage {
  gmailDiscovery,
  emailClassification,
  pdfDecryption,
  textExtraction,
  tokenization,
  tokenWindowScan,
  regexParsing,
  aiSemanticRepair,
  ledgerInsert,
  snapshotReconciliation,
  finalization,
}

enum StageStatus { waiting, running, completed, skipped, failed }

/// Human-readable display names for each scan stage.
extension ScanStageDisplay on ScanStage {
  String get displayName {
    switch (this) {
      case ScanStage.gmailDiscovery: return 'Gmail Discovery';
      case ScanStage.emailClassification: return 'Email Classification';
      case ScanStage.pdfDecryption: return 'PDF Decryption';
      case ScanStage.textExtraction: return 'Text Extraction';
      case ScanStage.tokenization: return 'Tokenization';
      case ScanStage.tokenWindowScan: return 'Token Window Scan';
      case ScanStage.regexParsing: return 'Fast Pattern Match';
      case ScanStage.aiSemanticRepair: return 'AI Fallback & Verification';
      case ScanStage.ledgerInsert: return 'Ledger Insert';
      case ScanStage.snapshotReconciliation: return 'Snapshot Reconciliation';
      case ScanStage.finalization: return 'Finalization';
    }
  }

  String get actionText {
    switch (this) {
      case ScanStage.gmailDiscovery: return 'Connecting to Gmail and searching for broker emails…';
      case ScanStage.emailClassification: return 'Classifying discovered emails by sender and type…';
      case ScanStage.pdfDecryption: return 'Decrypting PDF attachments with your PAN…';
      case ScanStage.textExtraction: return 'Extracting text content from decrypted PDFs…';
      case ScanStage.tokenization: return 'Breaking extracted text into token streams…';
      case ScanStage.tokenWindowScan: return 'Scanning token windows for trade-shaped structures…';
      case ScanStage.regexParsing: return 'Attempting deterministic regex trade matching…';
      case ScanStage.aiSemanticRepair: return 'Running AI semantic repair on unresolved candidates…';
      case ScanStage.ledgerInsert: return 'Inserting validated trades into the secure ledger…';
      case ScanStage.snapshotReconciliation: return 'Reconciling snapshots against discovered trades…';
      case ScanStage.finalization: return 'Finalizing scan and computing portfolio state…';
    }
  }
}

/// A structured progress event emitted by the ScanOrchestrator.
class ScanEvent {
  final ScanStage stage;
  final StageStatus status;
  final double progress; // 0.0 – 1.0
  final String? currentItem;
  final int processed;
  final int total;
  final int elapsedMs;
  final int estimatedRemainingMs;
  final String? actionText;

  // Live counters (accumulated across all stages)
  final ScanCounters counters;

  const ScanEvent({
    required this.stage,
    required this.status,
    this.progress = 0.0,
    this.currentItem,
    this.processed = 0,
    this.total = 0,
    this.elapsedMs = 0,
    this.estimatedRemainingMs = 0,
    this.actionText,
    this.counters = const ScanCounters(),
  });
}

/// Special event signaling that PAN input is required.
class ScanPanRequiredEvent extends ScanEvent {
  final int emailsFound;
  final int pdfsFound;

  ScanPanRequiredEvent({
    required this.emailsFound,
    required this.pdfsFound,
    required super.counters,
  }) : super(
    stage: ScanStage.pdfDecryption,
    status: StageStatus.waiting,
    actionText: 'PAN required to decrypt $pdfsFound PDF attachments.',
  );
}

/// Special event signaling scan completion.
class ScanCompleteEvent extends ScanEvent {
  final EmailImportPreview? preview;
  final EmailImportResult? importResult;
  final String summaryMessage;
  final List<DebugPdfInfo> debugPayloads;

  ScanCompleteEvent({
    required this.summaryMessage,
    this.preview,
    this.importResult,
    required super.counters,
    this.debugPayloads = const [],
  }) : super(
    stage: ScanStage.finalization,
    status: StageStatus.completed,
    progress: 1.0,
  );
}

/// Special event for errors that halt the pipeline.
class ScanErrorEvent extends ScanEvent {
  final String errorMessage;

  ScanErrorEvent({
    required super.stage,
    required this.errorMessage,
    required super.counters,
  }) : super(
    status: StageStatus.failed,
    actionText: errorMessage,
  );
}

/// Debug snapshot of a single PDF's extraction result.
class DebugPdfInfo {
  final String filename;
  final String sender;
  final String extractionMethod;
  final String docType;
  final int textLength;
  final String extractedText;
  final int regexTrades;
  final int aiTrades;
  final int candidateWindows;
  final List<String> warnings;
  final List<String> unresolvedTrades;

  const DebugPdfInfo({
    required this.filename,
    required this.sender,
    required this.extractionMethod,
    required this.docType,
    required this.textLength,
    required this.extractedText,
    required this.regexTrades,
    required this.aiTrades,
    required this.candidateWindows,
    this.warnings = const [],
    this.unresolvedTrades = const [],
  });
}

/// Accumulated live counters for the entire scan.
class ScanCounters {
  final int emailsFound;
  final int pdfsFound;
  final int pdfsDecrypted;
  final int pdfsProcessed;
  final int currentPdfIndex;
  final String? currentPdfName;
  final int rawCandidatesDetected;
  final int regexTradesFound;
  final int aiTradesRepaired;
  final int totalTradesInserted;
  final int snapshotsParsed;
  final int decryptionFailures;

  const ScanCounters({
    this.emailsFound = 0,
    this.pdfsFound = 0,
    this.pdfsDecrypted = 0,
    this.pdfsProcessed = 0,
    this.currentPdfIndex = 0,
    this.currentPdfName,
    this.rawCandidatesDetected = 0,
    this.regexTradesFound = 0,
    this.aiTradesRepaired = 0,
    this.totalTradesInserted = 0,
    this.snapshotsParsed = 0,
    this.decryptionFailures = 0,
  });

  ScanCounters copyWith({
    int? emailsFound,
    int? pdfsFound,
    int? pdfsDecrypted,
    int? pdfsProcessed,
    int? currentPdfIndex,
    String? currentPdfName,
    int? rawCandidatesDetected,
    int? regexTradesFound,
    int? aiTradesRepaired,
    int? totalTradesInserted,
    int? snapshotsParsed,
    int? decryptionFailures,
  }) {
    return ScanCounters(
      emailsFound: emailsFound ?? this.emailsFound,
      pdfsFound: pdfsFound ?? this.pdfsFound,
      pdfsDecrypted: pdfsDecrypted ?? this.pdfsDecrypted,
      pdfsProcessed: pdfsProcessed ?? this.pdfsProcessed,
      currentPdfIndex: currentPdfIndex ?? this.currentPdfIndex,
      currentPdfName: currentPdfName ?? this.currentPdfName,
      rawCandidatesDetected: rawCandidatesDetected ?? this.rawCandidatesDetected,
      regexTradesFound: regexTradesFound ?? this.regexTradesFound,
      aiTradesRepaired: aiTradesRepaired ?? this.aiTradesRepaired,
      totalTradesInserted: totalTradesInserted ?? this.totalTradesInserted,
      snapshotsParsed: snapshotsParsed ?? this.snapshotsParsed,
      decryptionFailures: decryptionFailures ?? this.decryptionFailures,
    );
  }
}

/// The Scan Orchestrator. Drives the full email scan pipeline and emits
/// real-time [ScanEvent]s for the UI to consume.
class ScanOrchestrator {
  final TradeRepository _tradeRepo;
  final ImportDao _importDao;

  final _controller = StreamController<ScanEvent>.broadcast();
  Stream<ScanEvent> get events => _controller.stream;

  // PAN completer — orchestrator pauses here until the UI provides PAN.
  Completer<String>? _panCompleter;

  // Timing
  final _stopwatch = Stopwatch();
  final List<int> _pdfProcessingTimesMs = [];

  // Mutable counters
  ScanCounters _counters = const ScanCounters();

  ScanOrchestrator({
    required TradeRepository tradeRepository,
    required ImportDao importDao,
  })  : _tradeRepo = tradeRepository,
        _importDao = importDao;

  /// Provide the PAN from the UI side. Resumes the pipeline.
  void submitPan(String pan) {
    _panCompleter?.complete(pan);
  }

  void _emit(ScanStage stage, StageStatus status, {
    double progress = 0.0,
    String? currentItem,
    int processed = 0,
    int total = 0,
    String? actionText,
  }) {
    _controller.add(ScanEvent(
      stage: stage,
      status: status,
      progress: progress,
      currentItem: currentItem,
      processed: processed,
      total: total,
      elapsedMs: _stopwatch.elapsedMilliseconds,
      estimatedRemainingMs: _estimateRemainingMs(processed, total),
      actionText: actionText ?? stage.actionText,
      counters: _counters,
    ));
  }

  int _estimateRemainingMs(int processed, int total) {
    if (_pdfProcessingTimesMs.isEmpty || processed == 0 || total == 0) return 0;
    final avgMs = _pdfProcessingTimesMs.reduce((a, b) => a + b) / _pdfProcessingTimesMs.length;
    return (avgMs * (total - processed)).round();
  }

  /// Run the full scan pipeline. Call this once from the UI.
  Future<void> run({required AuthService authService}) async {
    _stopwatch.start();

    try {
      // ═══════════════════════════════════════════════════════════════
      // STAGE 0: Gmail Smoke Test
      // ═══════════════════════════════════════════════════════════════
      _emit(ScanStage.gmailDiscovery, StageStatus.running);

      final proofResult = await GmailSmokeTest.run(authService);
      if (!proofResult.gmailReachable || proofResult.messageCount == 0) {
        _controller.add(ScanErrorEvent(
          stage: ScanStage.gmailDiscovery,
          errorMessage: !proofResult.gmailReachable
              ? 'Cannot reach Gmail. Check your internet connection.'
              : 'Gmail is reachable but no messages found.',
          counters: _counters,
        ));
        return;
      }

      // ═══════════════════════════════════════════════════════════════
      // STAGE 1: DISCOVERY
      // ═══════════════════════════════════════════════════════════════
      _emit(ScanStage.gmailDiscovery, StageStatus.running,
          actionText: 'Discovering broker statements…');

      final scanner = ScannerController();
      final emails = await scanner.scanForBrokerEmails(
        authService: authService,
        since: null,
        maxResults: 500,
      );

      int totalPdfs = 0;
      for (final email in emails) {
        totalPdfs += email.attachments.where((a) => a.isPdf).length;
      }

      _counters = _counters.copyWith(emailsFound: emails.length, pdfsFound: totalPdfs);
      _emit(ScanStage.gmailDiscovery, StageStatus.completed,
          progress: 1.0, processed: emails.length, total: emails.length);

      if (emails.isEmpty) {
        _controller.add(ScanCompleteEvent(
          summaryMessage: 'No broker emails found from NSE or SBI.',
          counters: _counters,
        ));
        return;
      }

      // ═══════════════════════════════════════════════════════════════
      // STAGE 2: EMAIL CLASSIFICATION (instant — sender-based)
      // ═══════════════════════════════════════════════════════════════
      _emit(ScanStage.emailClassification, StageStatus.running);
      // Classification happens per-PDF during processing, mark complete instantly
      _emit(ScanStage.emailClassification, StageStatus.completed, progress: 1.0);

      // ═══════════════════════════════════════════════════════════════
      // STAGE 3: PAN REQUEST (pause and wait)
      // ═══════════════════════════════════════════════════════════════
      String pan = '';
      if (totalPdfs > 0) {
        _panCompleter = Completer<String>();
        _controller.add(ScanPanRequiredEvent(
          emailsFound: emails.length,
          pdfsFound: totalPdfs,
          counters: _counters,
        ));

        pan = await _panCompleter!.future;
        _panCompleter = null;

        if (pan.isEmpty) {
          _controller.add(ScanErrorEvent(
            stage: ScanStage.pdfDecryption,
            errorMessage: 'PAN is required to decrypt broker PDFs.',
            counters: _counters,
          ));
          return;
        }

        // ── PAN Verification (1-PDF test) ──
        _emit(ScanStage.pdfDecryption, StageStatus.running,
            actionText: 'Verifying PAN with first PDF…');

        try {
          final firstEmail = emails.firstWhere((e) => e.attachments.any((a) => a.isPdf));
          final testAttachment = firstEmail.attachments.firstWhere((a) => a.isPdf);

          final bytes = await scanner.downloadAttachment(
            authService: authService,
            messageId: firstEmail.messageId,
            attachmentId: testAttachment.attachmentId,
          );

          final attachmentHandler = AttachmentHandler();
          final testResult = await attachmentHandler.processPdfAttachment(
            attachmentBytes: bytes,
            filename: testAttachment.filename,
            attachmentHash: scanner.computeAttachmentHash(bytes),
            pan: pan,
          );

          if (!testResult.decryptionSucceeded) {
            _controller.add(ScanErrorEvent(
              stage: ScanStage.pdfDecryption,
              errorMessage: testResult.errorMessage?.contains('Incorrect PAN') == true
                  ? 'Incorrect PAN. Please try again.'
                  : 'Cannot decrypt broker PDFs. (${testResult.errorMessage})',
              counters: _counters,
            ));
            return;
          }
        } catch (e) {
          _controller.add(ScanErrorEvent(
            stage: ScanStage.pdfDecryption,
            errorMessage: 'PAN verification failed: $e',
            counters: _counters,
          ));
          return;
        }
      }

      // ═══════════════════════════════════════════════════════════════
      // STAGES 3-8: STRICT BATCH PROCESSING PIPELINE
      // ═══════════════════════════════════════════════════════════════
      final attachmentHandler = AttachmentHandler();
      int decryptFailures = 0;
      final decryptErrors = <String>[];
      int pdfIndex = 0;

      final Map<PdfDocumentType, DocumentContentParser> parsers = {
        PdfDocumentType.nseTradeConfirmation: NseTradeConfirmationParser(),
        PdfDocumentType.nseAlertsStatement: NseAlertsParser(),
        PdfDocumentType.sbiContractNote: SbiContractNoteParser(),
        PdfDocumentType.sbiMarginStatement: SbiMarginStatementParser(),
        PdfDocumentType.sbiFundsStatement: SbiFundsStatementParser(),
        PdfDocumentType.sbiSecuritiesStatement: SbiSecuritiesStatementParser(),
      };

      // Create payloads
      final payloads = <PipelinePayload>[];
      for (final email in emails) {
        for (final attachment in email.attachments) {
          if (!attachment.isPdf) continue;
          payloads.add(PipelinePayload(
            email: email,
            attachment: attachment,
          ));
        }
      }

      // --- STAGE 3: PDF DECRYPTION ---
      for (final payload in payloads) {
        pdfIndex++;
        final pdfTimer = Stopwatch()..start();

        _counters = _counters.copyWith(
          currentPdfIndex: pdfIndex,
          currentPdfName: payload.attachment.filename,
        );

        _emit(ScanStage.pdfDecryption, StageStatus.running,
            progress: pdfIndex / totalPdfs,
            currentItem: payload.attachment.filename,
            processed: pdfIndex, total: totalPdfs,
            actionText: 'Decrypting ${payload.attachment.filename}…');

        try {
          final bytes = await scanner.downloadAttachment(
            authService: authService,
            messageId: payload.email.messageId,
            attachmentId: payload.attachment.attachmentId,
          );

          payload.attachmentHash = scanner.computeAttachmentHash(bytes);

          final result = await attachmentHandler.processPdfAttachment(
            attachmentBytes: bytes,
            filename: payload.attachment.filename,
            attachmentHash: payload.attachmentHash!,
            pan: pan,
          );

          if (!result.decryptionSucceeded) {
            // true failure — log and skip
            decryptFailures++;
            decryptErrors.add(result.errorMessage ?? 'Decryption failed: ${payload.attachment.filename}');
            _counters = _counters.copyWith(decryptionFailures: decryptFailures);
          } else {
            // Always store the payload even if text is short or empty
            payload.extractedText = result.extractedText;
            payload.extractionMethod = result.extractionMethod;
            _counters = _counters.copyWith(pdfsDecrypted: _counters.pdfsDecrypted + 1);
            // Log a warning if text is suspiciously short but do NOT discard
            if (result.extractedText.trim().length < 50) {
              payload.warnings.add('WARNING: Only ${result.extractedText.trim().length} chars extracted from ${payload.attachment.filename}. OCR may be needed.');
              developer.log('[EXTRACTION_WARNING] Short text from ${payload.attachment.filename}: "${result.extractedText.trim()}"', name: 'ScanOrchestrator');
            }
          }
        } catch (e) {
            decryptErrors.add('System error processing ${payload.attachment.filename}: $e');
        }

        // --- MANDATORY DEBUG LOG: DECRYPT RESULT ---
        developer.log(
          '[DECRYPT_RESULT] ${payload.attachment.filename} | decrypted=${payload.extractedText != null} | chars=${payload.extractedText?.length ?? 0} | sender=${payload.email.from}',
          name: 'ScanOrchestrator',
        );

        pdfTimer.stop();
        _pdfProcessingTimesMs.add(pdfTimer.elapsedMilliseconds);
      }
      _emit(ScanStage.pdfDecryption, StageStatus.completed, progress: 1.0);

      // Filter out only true decryption failures (extractedText is null).
      // PDFs with empty text are kept — they may still be classifiable by sender.
      final decryptedPayloads = payloads.where((p) => p.extractedText != null).toList();

      // --- STAGE 4: TEXT EXTRACTION & CLASSIFICATION ---
      for (int i = 0; i < decryptedPayloads.length; i++) {
        final payload = decryptedPayloads[i];
        
        _emit(ScanStage.textExtraction, StageStatus.running,
            progress: (i + 1) / decryptedPayloads.length,
            currentItem: payload.attachment.filename,
            processed: i + 1, total: decryptedPayloads.length,
            actionText: 'Extracting & Classifying ${payload.attachment.filename}…');

        payload.docType = PdfClassifier.classify(
          filename: payload.attachment.filename,
          senderEmail: payload.email.from,
          rawText: payload.extractedText!,
        );

        if (payload.docType == PdfDocumentType.unknown) {
           payload.warnings.add('Unknown document format: ${payload.attachment.filename}');
        }

        // --- MANDATORY DEBUG LOG: CLASSIFY RESULT ---
        developer.log(
          '[CLASSIFY_RESULT] ${payload.attachment.filename} | docType=${payload.docType} | sender=${payload.email.from}',
          name: 'ScanOrchestrator',
        );
      }
      _emit(ScanStage.textExtraction, StageStatus.completed, progress: 1.0);

      final classifiedPayloads = decryptedPayloads.where((p) => p.docType != PdfDocumentType.unknown).toList();

      // --- STAGE 5: TOKENIZATION & WINDOW SCAN ---
      if (classifiedPayloads.isNotEmpty) {
        for (int i = 0; i < classifiedPayloads.length; i++) {
          final payload = classifiedPayloads[i];
          
          _emit(ScanStage.tokenization, StageStatus.running,
              progress: (i + 1) / classifiedPayloads.length,
              currentItem: payload.attachment.filename,
              processed: i + 1, total: classifiedPayloads.length,
              actionText: 'Tokenizing ${payload.attachment.filename}…');

          final parser = parsers[payload.docType];
          if (parser != null) {
            final parseRes = parser.parseRawText(
              rawText: payload.extractedText!,
              filename: payload.attachment.filename,
              attachmentHash: payload.attachmentHash!,
              emailDate: payload.email.date,
            );

            payload.rawCandidates = parseRes.rawCandidates;
            payload.rawCandidatesDetected = parseRes.rawCandidatesDetected;
            payload.regexTrades = List.from(parseRes.trades);
            payload.snapshots = List.from(parseRes.snapshots);
            payload.confidence = parseRes.aggregateConfidence;
            payload.warnings.addAll(parseRes.warnings);
            payload.errors.addAll(parseRes.errors);
            payload.rowsDetected = parseRes.rowsDetected;
            payload.rowsParsed = parseRes.rowsParsed;
            payload.rejectedRows = parseRes.rejectedRows;

            _counters = _counters.copyWith(
              rawCandidatesDetected: _counters.rawCandidatesDetected + payload.rawCandidatesDetected,
              snapshotsParsed: _counters.snapshotsParsed + payload.snapshots.length,
            );
          }
        }
      }
      _emit(ScanStage.tokenization, StageStatus.completed, progress: 1.0);
      _emit(ScanStage.tokenWindowScan, StageStatus.completed, progress: 1.0);

      // --- STAGE 6: REGEX PARSING ---
      for (final payload in classifiedPayloads) {
        if (payload.regexTrades.isNotEmpty) {
          _counters = _counters.copyWith(
            regexTradesFound: _counters.regexTradesFound + payload.regexTrades.length,
          );
        }
      }
      _emit(ScanStage.regexParsing, StageStatus.completed, progress: 1.0);
      
      // Calculate parsed PDFs for the loop counter
      _counters = _counters.copyWith(pdfsProcessed: classifiedPayloads.length);

      // --- STAGE 7: AI PARSING ---
      // NSE Direct: Qwen fallback (full text) ONLY if regex found 0 trades
      // Others: legacy AI fallback (candidate windows) ONLY if regex found 0 trades

      for (int i = 0; i < classifiedPayloads.length; i++) {
        final payload = classifiedPayloads[i];
        final isNseDirect = payload.email.from.toLowerCase().contains('nse-direct@nse.co.in');

        if (payload.regexTrades.isEmpty) {
          if (isNseDirect) {
            // ═══ QWEN FALLBACK PATH (NSE Direct) ═══
            _emit(ScanStage.aiSemanticRepair, StageStatus.running,
                progress: (i + 1) / classifiedPayloads.length,
                currentItem: payload.attachment.filename,
                actionText: 'Regex returned 0. Triggering Qwen fallback for ${payload.attachment.filename}…');

            developer.log(
              '[QWEN_GATE] NSE Direct PDF ${payload.attachment.filename} | chars=${payload.extractedText?.length ?? 0} | regex failed, entering fallback',
              name: 'ScanOrchestrator',
            );

            final aiExtractor = AiTradeExtractor();
            final result = await aiExtractor.extractNseDirectTrades(
              extractedText: payload.extractedText ?? '',
              filename: payload.attachment.filename,
              emailDate: payload.email.date,
              sourceMessageHash: payload.attachmentHash!,
            );

            payload.aiTrades = result.validatedTrades;
            payload.confidence = result.validatedTrades.isNotEmpty ? 80 : 0;
            payload.unresolvedTrades = result.unresolvedTrades.map(
              (u) => '⚠️ UNRESOLVED: ${u.filename} — ${u.reason}. Raw: ${u.rawJson}'
            ).toList();

            if (result.validatedTrades.isNotEmpty) {
              _counters = _counters.copyWith(
                aiTradesRepaired: _counters.aiTradesRepaired + result.validatedTrades.length,
              );
              payload.warnings.add('Qwen fallback: ${result.validatedTrades.length} trades recovered.');
            }
            if (result.unresolvedTrades.isNotEmpty) {
              payload.warnings.addAll(payload.unresolvedTrades);
            }
            if (result.validatedTrades.isEmpty && result.unresolvedTrades.isEmpty) {
              payload.warnings.add('Qwen fallback returned 0 trades for ${payload.attachment.filename}.');
            }

            developer.log(
              '[QWEN_GATE_RESULT] ${payload.attachment.filename} | recovered=${result.validatedTrades.length} | unresolved=${result.unresolvedTrades.length}',
              name: 'ScanOrchestrator',
            );

          } else {
            // ═══ LEGACY AI FALLBACK (non-NSE-Direct) ═══
            final isTradeDocument = payload.docType == PdfDocumentType.nseTradeConfirmation ||
                                    payload.docType == PdfDocumentType.sbiContractNote;
            if (isTradeDocument) {
              developer.log(
                '[AI_LEGACY] Fallback for ${payload.attachment.filename}: regex found 0 trades',
                name: 'ScanOrchestrator',
              );
              // Legacy AI uses candidate windows
              if (payload.rawCandidates.isNotEmpty) {
                final aiExtractor = AiTradeExtractor();
                final aiTrades = <EmailParsedTrade>[];
                for (final candidate in payload.rawCandidates) {
                  final extractedList = await aiExtractor.extractTrades(
                    candidate: candidate,
                    documentTypeLabel: payload.docType.name,
                    emailDate: payload.email.date,
                    sourceMessageHash: payload.attachmentHash!,
                  );
                  aiTrades.addAll(extractedList);
                }
                if (aiTrades.isNotEmpty) {
                  payload.aiTrades = aiTrades;
                  _counters = _counters.copyWith(
                    aiTradesRepaired: _counters.aiTradesRepaired + aiTrades.length,
                  );
                }
              }
            }
          }
        } else {
          developer.log(
            '[AI_SKIP] ${payload.attachment.filename}: regex found ${payload.regexTrades.length} trades, skipping AI.',
            name: 'ScanOrchestrator',
          );
        }
        
        // --- DEBUG LOG ---
        developer.log(
          '=== PIPELINE STAGE TRANSITION DEBUGLOG ===\n'
          'Email Sender: ${payload.email.from}\n'
          'PDF Filename: ${payload.attachment.filename}\n'
          'Extracted Text Length: ${payload.extractedText?.length ?? 0}\n'
          'Extraction Method: ${payload.extractionMethod}\n'
          'Regex Trades: ${payload.regexTrades.length}\n'
          'AI Trades: ${payload.aiTrades.length}\n'
          'Unresolved: ${payload.unresolvedTrades.length}',
          name: 'ScanOrchestrator'
        );
      }
      _emit(ScanStage.aiSemanticRepair, StageStatus.completed, progress: 1.0);

      // --- AGGREGATE RESULTS ---
      final parserResults = payloads.map((p) {
        return EmailParseResult(
          messageId: p.email.messageId,
          trades: p.aiTrades.isNotEmpty ? p.aiTrades : p.regexTrades,
          snapshots: p.snapshots,
          aggregateConfidence: p.confidence,
          warnings: p.warnings,
          errors: p.errors,
          rowsDetected: p.rowsDetected,
          rowsParsed: p.rowsParsed,
          rejectedRows: p.rejectedRows,
        );
      }).toList();

      // ═══════════════════════════════════════════════════════════════
      // STAGE 9: LEDGER ENGINE
      // ═══════════════════════════════════════════════════════════════
      _emit(ScanStage.ledgerInsert, StageStatus.running,
          actionText: 'Validating trades with the LedgerEngine…');

      final ledger = LedgerEngine();
      final ledgerResult = ledger.reconstruct(parserResults);

      final totalTrades = ledgerResult.validatedTrades.length;
      int totalConf = 0, confCount = 0, totalUnknown = 0, totalSnapshots = 0;
      for (final res in parserResults) {
        if (res.trades.isNotEmpty || res.snapshots.isNotEmpty) {
          totalConf += res.aggregateConfidence;
          confCount++;
        }
        if (res.warnings.any((w) => w.contains('Unknown document format'))) totalUnknown++;
        totalSnapshots += res.snapshots.length;
      }
      final avgConfidence = confCount == 0 ? 0 : (totalConf / confCount).round();

      final preview = EmailImportPreview(
        totalBrokerEmailsFound: emails.length,
        totalPdfAttachments: totalPdfs,
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

      _emit(ScanStage.ledgerInsert, StageStatus.completed, progress: 1.0);

      // ═══════════════════════════════════════════════════════════════
      // STAGE 10: 3-SOURCE CROSS-REFERENCING & RECONCILIATION
      // ═══════════════════════════════════════════════════════════════
      _emit(ScanStage.snapshotReconciliation, StageStatus.running,
          actionText: 'Cross-referencing trades across 3 sources…');
      _counters = _counters.copyWith(snapshotsParsed: totalSnapshots);

      // --- PHASE A: NSE Direct ↔ SBI Contract Note Trade Matching ---
      // Collect all trades by source
      final nseDirectTrades = <EmailParsedTrade>[];
      final sbiCnbTrades = <EmailParsedTrade>[];
      for (final res in parserResults) {
        for (final t in res.trades) {
          if (t.source == TradeSource.nseDirect) {
            nseDirectTrades.add(t);
          } else if (t.source == TradeSource.sbiContractNote) {
            sbiCnbTrades.add(t);
          }
        }
      }

      int matchCount = 0;
      final matchedNseIndices = <int>{};
      final matchedCnbIndices = <int>{};

      for (int i = 0; i < nseDirectTrades.length; i++) {
        final nse = nseDirectTrades[i];
        for (int j = 0; j < sbiCnbTrades.length; j++) {
          if (matchedCnbIndices.contains(j)) continue;
          final cnb = sbiCnbTrades[j];

          // Match criteria: same symbol, same qty, price within 1%, date within 1 day
          final symbolMatch = nse.symbol.toUpperCase() == cnb.symbol.toUpperCase();
          final qtyMatch = nse.quantity == cnb.quantity;
          final priceDiff = (nse.pricePerUnit - cnb.pricePerUnit).abs();
          final priceMatch = nse.pricePerUnit > 0 && (priceDiff / nse.pricePerUnit) <= 0.01;
          final dateDiff = nse.tradeDate.difference(cnb.tradeDate).inDays.abs();
          final dateMatch = dateDiff <= 1;

          if (symbolMatch && qtyMatch && priceMatch && dateMatch) {
            matchedNseIndices.add(i);
            matchedCnbIndices.add(j);
            matchCount++;

            // Upgrade the NSE trade with CNB charge data
            nseDirectTrades[i] = nse.copyWith(
              source: TradeSource.both,
              status: TradeStatus.confirmed,
              confidence: 95,
              brokerage: cnb.brokerage,
              stt: cnb.stt,
              gst: cnb.gst,
              otherLevies: cnb.otherLevies,
              netAmountAfterLevies: cnb.netAmountAfterLevies,
              trueCostBasis: cnb.trueCostBasis,
            );
            break; // Each NSE trade matches at most one CNB trade
          }
        }
      }

      developer.log(
        '[CROSS_REF] Matched $matchCount trades between NSE Direct and SBI Contract Notes',
        name: 'ScanOrchestrator',
      );

      // --- PHASE B: Snapshot ↔ Ledger Reconciliation ---
      // Compare NSE Alerts snapshots against the reconstructed ledger holdings
      final allSnapshots = <EmailParsedSnapshot>[];
      for (final res in parserResults) {
        allSnapshots.addAll(res.snapshots);
      }

      int reconciledCount = 0;
      int discrepantCount = 0;
      final reconciliationNotes = <String>[];

      if (allSnapshots.isNotEmpty && ledgerResult.holdings.isNotEmpty) {
        // Group snapshots by symbol, keep the latest
        final latestSnapshots = <String, EmailParsedSnapshot>{};
        for (final snap in allSnapshots) {
          final existing = latestSnapshots[snap.symbol];
          if (existing == null || snap.snapshotDate.isAfter(existing.snapshotDate)) {
            latestSnapshots[snap.symbol] = snap;
          }
        }

        for (final entry in latestSnapshots.entries) {
          final snapSymbol = entry.key;
          final snapQty = entry.value.quantity;

          // Try to find a matching holding (fuzzy name matching since NSE Alerts uses long names)
          ReconstructedHolding? matchingHolding;
          for (final hEntry in ledgerResult.holdings.entries) {
            if (hEntry.key.toUpperCase() == snapSymbol.toUpperCase() ||
                snapSymbol.toUpperCase().contains(hEntry.key.toUpperCase()) ||
                hEntry.key.toUpperCase().contains(snapSymbol.toUpperCase())) {
              matchingHolding = hEntry.value;
              break;
            }
          }

          if (matchingHolding != null) {
            if ((matchingHolding.netQuantity - snapQty).abs() < 0.01) {
              reconciledCount++;
              reconciliationNotes.add('${matchingHolding.symbol}: Qty ${snapQty.toStringAsFixed(0)} — Reconciled');
            } else {
              discrepantCount++;
              reconciliationNotes.add(
                '${matchingHolding.symbol}: Ledger=${matchingHolding.netQuantity.toStringAsFixed(0)}, '
                'Snapshot=${snapQty.toStringAsFixed(0)} — DISCREPANT',
              );
            }
          } else {
            discrepantCount++;
            reconciliationNotes.add('$snapSymbol: Not found in ledger but snapshot reports ${snapQty.toStringAsFixed(0)} — MISSING');
          }
        }
      }

      developer.log(
        '[RECONCILIATION] Reconciled=$reconciledCount, Discrepant=$discrepantCount',
        name: 'ScanOrchestrator',
      );

      _emit(ScanStage.snapshotReconciliation, StageStatus.completed, progress: 1.0);

      // ═══════════════════════════════════════════════════════════════
      // STAGE 11: COMMIT + FINALIZATION
      // ═══════════════════════════════════════════════════════════════
      _emit(ScanStage.finalization, StageStatus.running,
          actionText: 'Committing trades to the ledger…');

      EmailImportResult? importResult;
      if (preview.hasTrades) {
        final importService = EmailImportService(
          tradeRepository: _tradeRepo,
          importDao: _importDao,
        );
        importResult = await importService.commit(preview);
        _counters = _counters.copyWith(
          totalTradesInserted: importResult.successfulTrades,
        );
      }

      _stopwatch.stop();

      // Build summary message
      final totalUnresolved = payloads.fold<int>(0, (s, p) => s + p.unresolvedTrades.length);
      String summaryMessage;
      if (totalTrades > 0) {
        summaryMessage = '${importResult?.successfulTrades ?? 0} trades imported. '
            '$totalSnapshots snapshots recorded for reconciliation.';
        if (totalUnresolved > 0) {
          summaryMessage += ' ⚠️ $totalUnresolved trade(s) need manual review.';
        }
      } else if (totalSnapshots > 0) {
        summaryMessage = 'No executed trades found — $totalSnapshots snapshots recorded for reconciliation.';
        if (totalUnresolved > 0) {
          summaryMessage += ' ⚠️ $totalUnresolved trade(s) need manual review.';
        }
      } else if (totalUnresolved > 0) {
        summaryMessage = 'Scan complete. ⚠️ $totalUnresolved trade(s) could not be validated — manual review required.';
      } else {
        summaryMessage = 'Scan complete. No trades or snapshots found.';
      }

      // Build debug payload snapshots for UI
      final debugInfos = payloads.map((p) => DebugPdfInfo(
        filename: p.attachment.filename,
        sender: p.email.from,
        extractionMethod: p.extractionMethod,
        docType: p.docType.name,
        textLength: p.extractedText?.length ?? 0,
        extractedText: p.extractedText ?? '',
        regexTrades: p.regexTrades.length,
        aiTrades: p.aiTrades.length,
        candidateWindows: p.rawCandidates.length,
        warnings: List.from(p.warnings),
        unresolvedTrades: List.from(p.unresolvedTrades),
      )).toList();

      _controller.add(ScanCompleteEvent(
        summaryMessage: summaryMessage,
        preview: preview,
        importResult: importResult,
        counters: _counters,
        debugPayloads: debugInfos,
      ));

    } catch (e) {
      developer.log('ScanOrchestrator fatal error: $e', name: 'ScanOrchestrator', error: e);
      _controller.add(ScanErrorEvent(
        stage: ScanStage.gmailDiscovery,
        errorMessage: 'Scan failed: $e',
        counters: _counters,
      ));
    }
  }

  void dispose() {
    _controller.close();
  }
}

/// Represents the intermediate state of a single PDF attachment
/// as it flows through the batch processing pipeline.
class PipelinePayload {
  final ScannedEmail email;
  final ScannedAttachment attachment;
  String? attachmentHash;
  
  String? extractedText;
  String extractionMethod = 'Unknown';
  PdfDocumentType docType = PdfDocumentType.unknown;
  
  int rawCandidatesDetected = 0;
  List<RawTradeCandidate> rawCandidates = [];
  
  List<EmailParsedTrade> regexTrades = [];
  List<EmailParsedTrade> aiTrades = [];
  List<EmailParsedSnapshot> snapshots = [];
  List<String> unresolvedTrades = [];
  
  int confidence = 0;
  List<String> warnings = [];
  List<String> errors = [];
  int rowsDetected = 0;
  int rowsParsed = 0;
  int rejectedRows = 0;

  PipelinePayload({
    required this.email,
    required this.attachment,
  });
}
