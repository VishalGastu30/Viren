import '../../../database/enums.dart';
import '../scanner_controller.dart';
import '../attachment_handler.dart';
import '../../../auth/auth_service.dart';
import '../broker_email_parser.dart';
import 'pdf_broker_parser.dart';
import 'dart:convert';
import 'dart:developer' as developer;

/// Parses statements from digidocemail@sbicapsec.com
/// Classifies PDFs into:
/// - CNB_*.pdf (Contract Note) -> secondary trade verification / price fallback
/// - DMRG_*.pdf (Margin) -> daily margin snapshot cross-checking
/// - Weekly/Monthly/Quarterly -> reconciliation only (ignored for trades)
class SbiStatementParser extends PdfBrokerParserBase {

  @override
  String get brokerName => 'SBI Securities';

  @override
  List<String> get exactSenders => ['digidocemail@sbicapsec.com'];

  @override
  Future<EmailParseResult> parsePdf(
    ScannedEmail email,
    ScannerController scanner,
    AttachmentHandler attachmentHandler,
    AuthService authService,
    String pan,
  ) async {
    final trades = <EmailParsedTrade>[];
    final snapshots = <EmailParsedSnapshot>[];
    final warnings = <String>[];
    final errors = <String>[];
    
    int totalRowsDetected = 0;
    int totalRowsParsed = 0;
    int totalRejectedRows = 0;

    for (final attachment in email.attachments) {
      if (!attachment.isPdf) continue;

      try {
        final filename = attachment.filename.toUpperCase();
        
        // 1. Classification
        bool isCNB = filename.contains('CNB_');
        bool isDMRG = filename.contains('DMRG_');
        bool isPeriodic = filename.contains('WEEKLY') || filename.contains('MONTHLY') || filename.contains('QUARTERLY');

        if (!isCNB && !isDMRG && !isPeriodic) {
          warnings.add('Unclassified SBI statement type: $filename');
          continue;
        }

        // We only extract data from CNB (prices) and DMRG (margin snapshot)
        if (isPeriodic) {
          warnings.add('Skipping periodic statement ($filename) as it is used only for manual audit.');
          continue;
        }

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
          errors.add(result.errorMessage ?? 'Failed to decrypt SBI PDF: $filename.');
          continue;
        }

        if (result.extractedText.isEmpty) {
          warnings.add('Decrypted SBI PDF is empty: $filename.');
          continue;
        }

        // PHASE 1: Normalize Extracted Text
        // Replace multiple spaces and newlines with a single space
        final normalizedText = result.extractedText.replaceAll(RegExp(r'\s+'), ' ').trim();

        if (isCNB) {
          // Parse Contract Note (CNB) for trade price fallbacks
          // PHASE 2: Tokenize from RIGHT-TO-LEFT across the tabular structure
          final cnPattern = RegExp(
            r'\b(B|S)\s+(.+?)\s+([A-Z0-9\-]+)\s+([A-Z]{2})\s+(\d{15,25})\s+(\d{2}:\d{2}:\d{2}\s(?:AM|PM))\s+(\d+)\s+(\d+(?:,\d+)*(?:\.\d+)?)\s+(\d+(?:,\d+)*(?:\.\d+)?)\b',
            caseSensitive: true,
          );

          final matches = cnPattern.allMatches(normalizedText);
          final rowsDetected = matches.length;
          totalRowsDetected += rowsDetected;

          for (final match in matches) {
            try {
              final typeStr = match.group(1)!;
              final symbol = match.group(3)!;
              final tradeNo = match.group(5)!;
              final qty = double.parse(match.group(7)!);
              final price = double.parse(match.group(8)!.replaceAll(',', ''));

              final tradeType = typeStr == 'B' ? TradeType.buy : TradeType.sell;

              trades.add(EmailParsedTrade(
                symbol: symbol,
                instrumentName: symbol,
                exchange: 'NSE',
                tradeType: tradeType,
                quantity: qty,
                pricePerUnit: price,
                tradeDate: email.date,
                broker: brokerName,
                confidence: 85, // Lower than NSE Direct, used as fallback
                sourceMessageHash: result.attachmentHash,
                tradeNo: tradeNo,
              ));
              
              totalRowsParsed++;
            } catch (e) {
              totalRejectedRows++;
              warnings.add('Failed to extract canonical row data from normalized CNB PDF: $e');
            }
          }
          
          if (rowsDetected > 0 && totalRowsParsed == 0) {
            errors.add('Parser logic bug: Detected $rowsDetected rows but generated 0 trades in SBI CNB.');
          }

          // REQUIRED DEBUG OUTPUT per user request
          final debugPayload = {
            "pdf": attachment.filename,
            "rows_detected": rowsDetected,
            "rows_parsed": rowsDetected - totalRejectedRows, // within this pdf
            "trades_created": trades.where((t) => t.sourceMessageHash == result.attachmentHash).length,
            "rejected_rows": totalRejectedRows,
          };
          developer.log(jsonEncode(debugPayload), name: 'SbiStatementParser');
          
        } else if (isDMRG) {
          // Parse Daily Margin Statement (DMRG) for ledger cross-check snapshots
          final marginPattern = RegExp(
            r'Margin\s+Balance\s*:\s*(-?\d+(?:,\d+)*(?:\.\d+)?)',
            caseSensitive: false,
          );
          
          final match = marginPattern.firstMatch(normalizedText);
          if (match != null) {
            try {
              final valStr = match.group(1)!;
              final marginVal = double.parse(valStr.replaceAll(',', ''));
              snapshots.add(EmailParsedSnapshot(
                symbol: 'MARGIN_BALANCE', 
                quantity: marginVal,
                snapshotDate: email.date,
                sourceMessageHash: result.attachmentHash,
              ));
            } catch (e) {
              warnings.add('Failed to parse DMRG margin balance: $e');
            }
          }
        }
      } catch (e) {
        errors.add('Error processing SBI attachment: $e');
      }
    }

    // Determine confidence
    int avgConfidence = 0;
    if (trades.isNotEmpty) {
      avgConfidence = (trades.fold<int>(0, (s, t) => s + t.confidence) / trades.length).round();
    } else if (snapshots.isNotEmpty) {
      avgConfidence = 90; // Snapshots are high confidence
    }

    return EmailParseResult(
      messageId: email.messageId,
      trades: trades,
      snapshots: snapshots,
      aggregateConfidence: avgConfidence,
      warnings: warnings,
      errors: errors,
      rowsDetected: totalRowsDetected,
      rowsParsed: totalRowsParsed,
      rejectedRows: totalRejectedRows,
    );
  }
}
