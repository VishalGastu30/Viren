import '../broker_email_parser.dart';
import '../document_content_parser.dart';
import '../pdf_classifier.dart';

class SbiMarginStatementParser implements DocumentContentParser {
  @override
  PdfDocumentType get supportedType => PdfDocumentType.sbiMarginStatement;

  @override
  EmailParseResult parseRawText({
    required String rawText,
    required String filename,
    required String attachmentHash,
    required DateTime emailDate,
  }) {
    final snapshots = <EmailParsedSnapshot>[];
    final warnings = <String>[];
    
    // Normalize Extracted Text
    final normalizedText = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();

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
          snapshotDate: emailDate,
          sourceMessageHash: attachmentHash,
        ));
      } catch (e) {
        warnings.add('Failed to parse DMRG margin balance from $filename: $e');
      }
    } else {
      warnings.add('Margin balance not found in DMRG statement: $filename');
    }

    return EmailParseResult(
      messageId: 'DOCUMENT_PARSER_DELEGATE',
      trades: const [],
      snapshots: snapshots,
      aggregateConfidence: snapshots.isNotEmpty ? 90 : 0,
      warnings: warnings,
      errors: const [],
    );
  }
}
