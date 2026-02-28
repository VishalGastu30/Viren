import 'package:logger/logger.dart';

import '../../../database/enums.dart';
import '../scanner_controller.dart';
import '../attachment_handler.dart';
import '../../../auth/auth_service.dart';
import '../broker_email_parser.dart';
import 'pdf_broker_parser.dart';

/// Parses "Trades Executed at NSE" from nse-direct@nse.co.in.
/// This is the ground truth for pure execution trades (BUY/SELL).
class NseDirectParser extends PdfBrokerParserBase {
  final _logger = Logger();

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
  ) async {
    final trades = <EmailParsedTrade>[];
    final warnings = <String>[];
    final errors = <String>[];

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
        );

        if (!result.decryptionSucceeded) {
          errors.add(result.errorMessage ?? 'Failed to decrypt NSE Direct PDF.');
          continue;
        }

        if (result.extractedText.isEmpty) {
          warnings.add('Decrypted NSE Direct PDF is empty.');
          continue;
        }

        // Logic to extract trades from NSE Direct PDF text.
        // Look for tabular data containing execution quantities and prices.
        // Example pattern: SYMBOL BUY/SELL QTY PRICE
        final pattern = RegExp(
          r'([A-Z][A-Z0-9\-]{1,20})\s+(BUY|SELL)\s+(\d+(?:\.\d+)?)\s+(\d+(?:,\d+)*(?:\.\d+)?)',
          caseSensitive: false,
        );

        for (final match in pattern.allMatches(result.extractedText)) {
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
              confidence: 95, // High confidence because it's a direct NSE extract
              sourceMessageHash: result.attachmentHash, // Link to PDF hash
            ));
          } catch (e) {
            warnings.add('Failed to parse a row in NSE Direct PDF: $e');
          }
        }
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
    );
  }
}
