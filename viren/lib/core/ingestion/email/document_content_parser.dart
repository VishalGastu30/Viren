import 'broker_email_parser.dart';
import 'pdf_classifier.dart';

/// LAYER 4: SPECIALIZED PARSING INTERFACE
/// Single-responsibility parsers that take raw text and output canonical trade/snapshot structured data.
/// They do NOT download or decrypt attachments. They only parse text.
abstract class DocumentContentParser {
  /// The type of document this parser is strictly bound to.
  PdfDocumentType get supportedType;

  /// Parse the raw decrypted text into a structured EmailParseResult.
  EmailParseResult parseRawText({
    required String rawText,
    required String filename,
    required String attachmentHash,
    required DateTime emailDate,
  });
}
