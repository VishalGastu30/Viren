import '../broker_email_parser.dart';
import '../document_content_parser.dart';
import '../pdf_classifier.dart';

class SbiFundsStatementParser implements DocumentContentParser {
  @override
  PdfDocumentType get supportedType => PdfDocumentType.sbiFundsStatement;

  @override
  EmailParseResult parseRawText({
    required String rawText,
    required String filename,
    required String attachmentHash,
    required DateTime emailDate,
  }) {
    // Currently, Funds/Periodic statements are used strictly for manual
    // audit/reconciliation, not automatic trade ingestion.
    return EmailParseResult(
      messageId: 'DOCUMENT_PARSER_DELEGATE',
      trades: const [],
      snapshots: const [],
      aggregateConfidence: 0,
      warnings: ['Skipping periodic funds statement ($filename) as it is used only for manual audit.'],
      errors: const [],
    );
  }
}
