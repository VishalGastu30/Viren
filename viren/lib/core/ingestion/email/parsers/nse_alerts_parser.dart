import '../scanner_controller.dart';
import '../attachment_handler.dart';
import '../../../auth/auth_service.dart';
import '../broker_email_parser.dart';
import 'pdf_broker_parser.dart';

/// Parses "Funds / Securities Balance" from nse_alerts@nse.co.in.
/// This parses holdings snapshots used for cross-checking the Ledger engine.
class NseAlertsParser extends PdfBrokerParserBase {

  @override
  String get brokerName => 'NSE Alerts';

  @override
  List<String> get exactSenders => ['nse_alerts@nse.co.in'];

  @override
  Future<EmailParseResult> parsePdf(
    ScannedEmail email,
    ScannerController scanner,
    AttachmentHandler attachmentHandler,
    AuthService authService,
    String pan,
  ) async {
    final snapshots = <EmailParsedSnapshot>[];
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
          pan: pan,
        );

        if (!result.decryptionSucceeded) {
          errors.add(result.errorMessage ?? 'Failed to decrypt NSE Alerts PDF.');
          continue;
        }

        if (result.extractedText.isEmpty) {
          warnings.add('Decrypted NSE Alerts PDF is empty.');
          continue;
        }

        // Logic to extract snapshot balances.
        // Look for ISIN/Symbol and quantities.
        final pattern = RegExp(
          r'([A-Z][A-Z0-9\-]{1,20})\s+(?:\w+\s+)?(-?\d+(?:\.\d+)?)',
          caseSensitive: false,
        );

        for (final match in pattern.allMatches(result.extractedText)) {
          try {
            final symbol = match.group(1)!;
            final qtyStr = match.group(2)!;
            final qty = double.parse(qtyStr.replaceAll(',', ''));

            snapshots.add(EmailParsedSnapshot(
              symbol: symbol,
              quantity: qty, // Can be negative (payable)
              snapshotDate: email.date,
              sourceMessageHash: result.attachmentHash,
            ));
          } catch (e) {
            warnings.add('Failed to parse a row in NSE Alerts PDF: $e');
          }
        }
      } catch (e) {
        errors.add('Error processing NSE Alerts attachment: $e');
      }
    }

    if (snapshots.isEmpty && errors.isEmpty) {
      errors.add('No snapshot balances found in NSE Alerts email.');
    }

    return EmailParseResult(
      messageId: email.messageId,
      trades: const [], // Snapshots contain NO trades
      snapshots: snapshots,
      aggregateConfidence: 90, // Snapshots are high confidence exact values
      warnings: warnings,
      errors: errors,
    );
  }
}
