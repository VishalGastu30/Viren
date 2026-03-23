import '../broker_email_parser.dart';
import '../document_content_parser.dart';
import '../pdf_classifier.dart';

class NseAlertsParser implements DocumentContentParser {
  @override
  PdfDocumentType get supportedType => PdfDocumentType.nseAlertsStatement;

  @override
  Future<EmailParseResult> parseRawText({
    required String rawText,
    required String filename,
    required String attachmentHash,
    required DateTime emailDate,
  }) async {
    final snapshots = <EmailParsedSnapshot>[];
    final warnings = <String>[];
    
    // Logic to extract snapshot balances.
    // Look for ISIN/Symbol and quantities.
    final pattern = RegExp(
      r'([A-Z][A-Z0-9\-]{1,20})\s+(?:\w+\s+)?(-?\d+(?:\.\d+)?)',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(rawText)) {
      try {
        final symbol = match.group(1)!;
        final qtyStr = match.group(2)!;
        final qty = double.parse(qtyStr.replaceAll(',', ''));

        snapshots.add(EmailParsedSnapshot(
          symbol: symbol,
          quantity: qty, // Can be negative (payable)
          snapshotDate: emailDate,
          sourceMessageHash: attachmentHash,
        ));
      } catch (e) {
        warnings.add('Failed to parse a row in NSE Alerts PDF ($filename): $e');
      }
    }

    return EmailParseResult(
      messageId: 'DOCUMENT_PARSER_DELEGATE',
      trades: const [], // Snapshots contain NO trades
      snapshots: snapshots,
      aggregateConfidence: snapshots.isNotEmpty ? 90 : 0, // Snapshots are high confidence exact values
      warnings: warnings,
      errors: snapshots.isEmpty ? ['No snapshot balances found in NSE Alerts document: $filename'] : const [],
    );
  }
}
