import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../auth/token_vault.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AttachmentHandler — Downloads, decrypts, and extracts text from PDF attachments.
//
// Security invariants:
//   • PAN is retrieved from encrypted Vault, used in-memory, then discarded.
//   • Raw PDF bytes are never persisted unencrypted.
//   • Uses `pdftotext` (poppler-utils) on Linux/Desktop for text extraction.
//   • On mobile, uses platform channel or bundled native library.
// ─────────────────────────────────────────────────────────────────────────────

/// Result of processing a single PDF attachment.
class AttachmentResult {
  final String filename;
  final String attachmentHash;
  final String extractedText;
  final bool wasPasswordProtected;
  final bool decryptionSucceeded;
  final String? errorMessage;

  const AttachmentResult({
    required this.filename,
    required this.attachmentHash,
    required this.extractedText,
    required this.wasPasswordProtected,
    required this.decryptionSucceeded,
    this.errorMessage,
  });

  bool get isSuccessful => extractedText.isNotEmpty && errorMessage == null;
}

class AttachmentHandler {
  final TokenVault _vault;

  AttachmentHandler(this._vault);

  /// Process a downloaded PDF attachment.
  ///
  /// 1. Saves bytes to a temp file.
  /// 2. Attempts to extract text (with password from Vault if needed).
  /// 3. Cleans up temp files.
  /// 4. Returns extracted text + metadata.
  Future<AttachmentResult> processPdfAttachment({
    required List<int> attachmentBytes,
    required String filename,
    required String attachmentHash,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempPdfPath = p.join(tempDir.path, 'viren_${DateTime.now().millisecondsSinceEpoch}_$filename');
    final tempTxtPath = '$tempPdfPath.txt';

    try {
      // Write PDF to temp file
      await File(tempPdfPath).writeAsBytes(attachmentBytes);

      // Rule: PDFs are ALWAYS password-protected with PAN in UPPERCASE
      final pan = await _vault.getPan();
      
      if (pan == null || pan.trim().isEmpty) {
        return AttachmentResult(
          filename: filename,
          attachmentHash: attachmentHash,
          extractedText: '',
          wasPasswordProtected: true,
          decryptionSucceeded: false,
          errorMessage: 'Missing PAN. Cannot decrypt PDF broker statement.',
        );
      }

      final upperPan = pan.trim().toUpperCase();

      // Try with uppercase PAN as password
      final extractedText = await _extractPdfText(tempPdfPath, tempTxtPath, password: upperPan);

      if (extractedText.trim().isEmpty) {
        return AttachmentResult(
          filename: filename,
          attachmentHash: attachmentHash,
          extractedText: '',
          wasPasswordProtected: true,
          decryptionSucceeded: false,
          errorMessage: 'Decryption failed: Incorrect PAN. (Expected uppercase PAN)',
        );
      }

      return AttachmentResult(
        filename: filename,
        attachmentHash: attachmentHash,
        extractedText: extractedText,
        wasPasswordProtected: true,
        decryptionSucceeded: true,
      );
    } catch (e) {
      return AttachmentResult(
        filename: filename,
        attachmentHash: attachmentHash,
        extractedText: '',
        wasPasswordProtected: false,
        decryptionSucceeded: false,
        errorMessage: 'PDF processing failed: $e',
      );
    } finally {
      // Clean up temp files
      try { await File(tempPdfPath).delete(); } catch (_) {}
      try { await File(tempTxtPath).delete(); } catch (_) {}
    }
  }

  /// Extracts text from a PDF using pdftotext (poppler-utils).
  ///
  /// On Linux/Desktop: uses `pdftotext` CLI tool.
  /// Falls back gracefully if the tool is unavailable.
  Future<String> _extractPdfText(String pdfPath, String txtPath, {String? password}) async {
    // Build pdftotext command
    final args = <String>[];
    if (password != null && password.isNotEmpty) {
      args.addAll(['-upw', password]);
    }
    args.addAll(['-layout', pdfPath, txtPath]);

    try {
      final result = await Process.run('pdftotext', args);

      if (result.exitCode == 0 && await File(txtPath).exists()) {
        final text = await File(txtPath).readAsString();
        return text.trim();
      }

      // Non-zero exit may mean wrong password or corrupted PDF
      return '';
    } on ProcessException catch (_) {
      // pdftotext not installed — provide guidance
      throw Exception(
        'pdftotext (poppler-utils) is not installed. '
        'Install with: sudo apt install poppler-utils',
      );
    }
  }
}
