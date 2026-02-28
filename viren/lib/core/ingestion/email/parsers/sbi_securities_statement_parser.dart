import '../broker_email_parser.dart';
import '../document_content_parser.dart';
import '../pdf_classifier.dart';

class SbiSecuritiesStatementParser implements DocumentContentParser {
  @override
  PdfDocumentType get supportedType => PdfDocumentType.sbiSecuritiesStatement;

  @override
  EmailParseResult parseRawText({
    required String rawText,
    required String filename,
    required String attachmentHash,
    required DateTime emailDate,
  }) {
    // Securities (Holdings) statements will be fully implemented 
    // for advanced Snapshot integration later.
    // For now, they pass safely through the pipeline.
    return EmailParseResult(
      messageId: 'DOCUMENT_PARSER_DELEGATE',
      trades: const [],
      snapshots: const [],
      aggregateConfidence: 0,
      warnings: ['Securities Holdings Statement parsing is slated for future snapshot integration: $filename'],
      errors: const [],
    );
  }
}
