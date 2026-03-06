import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'pdf_crypto_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AttachmentHandler — Downloads, decrypts, and extracts text from PDF attachments.
//
// Security invariants:
//   • PAN is supplied in-memory ONLY.
//   • Raw PDF bytes are never persisted unencrypted.
//   • Decryption AND text extraction happen entirely inside the Kotlin Native runtime
//     using PDFBox and MLKit.
// ─────────────────────────────────────────────────────────────────────────────

/// Result of processing a single PDF attachment.
class AttachmentResult {
  final String filename;
  final String attachmentHash;
  final String extractedText;
  final String extractionMethod;
  final bool wasPasswordProtected;
  final bool decryptionSucceeded;
  final String? errorMessage;

  const AttachmentResult({
    required this.filename,
    required this.attachmentHash,
    required this.extractedText,
    required this.extractionMethod,
    required this.wasPasswordProtected,
    required this.decryptionSucceeded,
    this.errorMessage,
  });

  bool get isSuccessful => extractedText.isNotEmpty && errorMessage == null;
}

class AttachmentHandler {
  AttachmentHandler();

  /// Process a downloaded PDF attachment.
  ///
  /// 1. Saves encrypted bytes to a temp file.
  /// 2. Invokes PdfCryptoService (Kotlin Native) to decrypt AND extract text.
  /// 3. Cleans up temp files.
  /// 4. Returns extracted text + metadata.
  Future<AttachmentResult> processPdfAttachment({
    required List<int> attachmentBytes,
    required String filename,
    required String attachmentHash,
    required String pan,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempPdfPath = p.join(tempDir.path, 'viren_${DateTime.now().millisecondsSinceEpoch}_$filename');

    try {
      // Write encrypted PDF to temp file
      await File(tempPdfPath).writeAsBytes(attachmentBytes);

      if (pan.trim().isEmpty) {
        return AttachmentResult(
          filename: filename,
          attachmentHash: attachmentHash,
          extractedText: '',
          extractionMethod: 'Unknown',
          wasPasswordProtected: true,
          decryptionSucceeded: false,
          errorMessage: 'Missing PAN. Cannot decrypt PDF broker statement.',
        );
      }

      final upperPan = pan.trim().toUpperCase();

      // Kotlin handles BOTH decryption AND text extraction in one call.
      PdfExtractionResult extractionResult;
      try {
        extractionResult = await PdfCryptoService.decryptAndExtract(
          inputPath: tempPdfPath,
          password: upperPan,
        );
      } on PdfCryptoException catch (e) {
        if (e.code == 'INCORRECT_PASSWORD') {
          return AttachmentResult(
            filename: filename,
            attachmentHash: attachmentHash,
            extractedText: '',
            extractionMethod: 'Unknown',
            wasPasswordProtected: true,
            decryptionSucceeded: false,
            errorMessage: 'Decryption failed: Incorrect PAN.',
          );
        } else {
          return AttachmentResult(
            filename: filename,
            attachmentHash: attachmentHash,
            extractedText: '',
            extractionMethod: 'Unknown',
            wasPasswordProtected: true,
            decryptionSucceeded: false,
            errorMessage: 'Native Engine Error: ${e.message}',
          );
        }
      }

      return AttachmentResult(
        filename: filename,
        attachmentHash: attachmentHash,
        extractedText: extractionResult.text,
        extractionMethod: extractionResult.method,
        wasPasswordProtected: true,
        decryptionSucceeded: true,
      );
    } catch (e) {
      return AttachmentResult(
        filename: filename,
        attachmentHash: attachmentHash,
        extractedText: '',
        extractionMethod: 'Unknown',
        wasPasswordProtected: false,
        decryptionSucceeded: false,
        errorMessage: 'PDF processing pipeline failed: $e',
      );
    } finally {
      // Clean up the temp encrypted PDF
      try { await File(tempPdfPath).delete(); } catch (_) {}
    }
  }
}
