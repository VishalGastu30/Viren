import '../../../database/enums.dart';
import '../scanner_controller.dart';
import '../attachment_handler.dart';
import '../../../auth/auth_service.dart';
import '../broker_email_parser.dart';
import 'pdf_broker_parser.dart';

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
  ) async {
    final trades = <EmailParsedTrade>[];
    final snapshots = <EmailParsedSnapshot>[];
    final warnings = <String>[];
    final errors = <String>[];

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
        );

        if (!result.decryptionSucceeded) {
          errors.add(result.errorMessage ?? 'Failed to decrypt SBI PDF: $filename.');
          continue;
        }

        if (result.extractedText.isEmpty) {
          warnings.add('Decrypted SBI PDF is empty: $filename.');
          continue;
        }

        if (isCNB) {
          // Parse Contract Note (CNB) for trade price fallbacks
          // Very strict regex for Contract Note tabular data
          final cnPattern = RegExp(
            r'([A-Z][A-Z0-9\-]{1,20})\s+(BUY|SELL)\s+(\d+(?:\.\d+)?)\s+(\d+(?:,\d+)*(?:\.\d+)?)',
            caseSensitive: false,
          );

          for (final match in cnPattern.allMatches(result.extractedText)) {
            try {
              final symbol = match.group(1)!;
              final typeStr = match.group(2)!.toUpperCase();
              final qty = double.parse(match.group(3)!);
              final price = double.parse(match.group(4)!.replaceAll(',', ''));

              final tradeType = typeStr == 'BUY' ? TradeType.buy : TradeType.sell;

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
              ));
            } catch (e) {
              warnings.add('Failed to parse a CNB row: $e');
            }
          }
        } else if (isDMRG) {
          // Parse Daily Margin Statement (DMRG) for ledger cross-check snapshots
          final marginPattern = RegExp(
            r'Margin\s+Balance\s*:\s*(-?\d+(?:,\d+)*(?:\.\d+)?)',
            caseSensitive: false,
          );
          
          final match = marginPattern.firstMatch(result.extractedText);
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
    );
  }
}
