import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../scanner_controller.dart';
import '../attachment_handler.dart';
import '../../../auth/auth_service.dart';
import '../broker_email_parser.dart'; // To reuse EmailParseResult and EmailParsedTrade

/// Base class for all V2 PDF-based broker parsers.
abstract class PdfBrokerParserBase {
  String get brokerName;

  /// Exact sender emails this parser handles
  List<String> get exactSenders;

  /// Parse the email by explicitly downloading and decrypting its PDF attachments.
  Future<EmailParseResult> parsePdf(
    ScannedEmail email,
    ScannerController scanner,
    AttachmentHandler attachmentHandler,
    AuthService authService,
    String pan,
  );

  String hashBody(String body) {
    return sha256.convert(utf8.encode(body)).toString();
  }
}
