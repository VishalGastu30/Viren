import '../../../database/enums.dart';
import '../scanner_controller.dart';
import '../attachment_handler.dart';
import '../../../auth/auth_service.dart';
import '../broker_email_parser.dart';
import 'pdf_broker_parser.dart';
import 'dart:convert';
import 'dart:developer' as developer;

/// Parses "Trades Executed at NSE" from nse-direct@nse.co.in.
/// This is the ground truth for pure execution trades (BUY/SELL).
class NseDirectParser extends PdfBrokerParserBase {

  @override
  String get brokerName => 'NSE Direct';

  @override
  List<String> get exactSenders => ['nse-direct@nse.co.in'];

  @override
  Future<EmailParseResult> parsePdf(
    ScannedEmail email,
    ScannerController scanner,
    AttachmentHandler attachmentHandler,
    AuthService authService,
    String pan,
  ) async {
    final trades = <EmailParsedTrade>[];
    final warnings = <String>[];
    final errors = <String>[];
    
    int totalRowsDetected = 0;
    int totalRowsParsed = 0;
    int totalRejectedRows = 0;

    for (final attachment in email.attachments) {
      if (!attachment.isPdf) continue;

      try {
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
          errors.add(result.errorMessage ?? 'Failed to decrypt NSE Direct PDF.');
          continue;
        }

        // PHASE 1: Normalize Extracted Text
        // Replace multiple spaces and newlines with a single space
        final normalizedText = result.extractedText.replaceAll(RegExp(r'\s+'), ' ').trim();

        if (normalizedText.isEmpty) {
          warnings.add('Decrypted NSE Direct PDF is empty or missing tabular data.');
          continue;
        }

        // PHASE 2: Tokenize From THE END
        // 1: B/S | 2: Security Name | 3: Symbol | 4: Series | 5: Trade No | 6: Time | 7: Qty | 8: Price | 9: Traded Value
        final pattern = RegExp(
          r'\b(B|S)\s+(.+?)\s+([A-Z0-9\-]+)\s+([A-Z]{2})\s+(\d{15,25})\s+(\d{2}:\d{2}:\d{2}\s(?:AM|PM))\s+(\d+)\s+(\d+(?:,\d+)*(?:\.\d+)?)\s+(\d+(?:,\d+)*(?:\.\d+)?)\b',
          caseSensitive: true,
        );

        final matches = pattern.allMatches(normalizedText);
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
              confidence: 95, 
              sourceMessageHash: result.attachmentHash, 
              tradeNo: tradeNo,
            ));
            
            totalRowsParsed++;
          } catch (e) {
            totalRejectedRows++;
            warnings.add('Failed to extract canonical row data from normalized NSE Direct PDF: $e');
          }
        }
        
        // Debug invariant
        if (rowsDetected > 0 && trades.isEmpty) {
           errors.add('Parser logic bug: Detected $rowsDetected rows but generated 0 trades. Review regex targeting in Phase 2.');
        }

        // REQUIRED DEBUG OUTPUT per user request
        final debugPayload = {
          "pdf": attachment.filename,
          "rows_detected": rowsDetected,
          "rows_parsed": rowsDetected - totalRejectedRows, // within this pdf
          "trades_created": trades.where((t) => t.sourceMessageHash == result.attachmentHash).length,
          "rejected_rows": totalRejectedRows,
        };
        developer.log(jsonEncode(debugPayload), name: 'NseDirectParser');

      } catch (e) {
        errors.add('Error processing NSE Direct attachment: $e');
      }
    }

    if (trades.isEmpty && errors.isEmpty) {
      errors.add('No execution trades found in NSE Direct email.');
    }

    final avgConfidence = trades.isEmpty
        ? 0
        : (trades.fold<int>(0, (s, t) => s + t.confidence) / trades.length).round();

    return EmailParseResult(
      messageId: email.messageId,
      trades: trades,
      aggregateConfidence: avgConfidence,
      warnings: warnings,
      errors: errors,
      rowsDetected: totalRowsDetected,
      rowsParsed: totalRowsParsed,
      rejectedRows: totalRejectedRows,
    );
  }
}
