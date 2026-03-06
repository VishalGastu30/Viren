import 'dart:convert';
import 'package:flutter/services.dart';

class PdfCryptoException implements Exception {
  final String code;
  final String message;
  final String? details;

  PdfCryptoException(this.code, this.message, [this.details]);

  @override
  String toString() => 'PdfCryptoException($code): $message ${details != null ? '[$details]' : ''}';
}

/// Result from the native PDF extraction layer.
class PdfExtractionResult {
  final String text;
  final String method; // e.g. "PDFBox" or "OCR"

  PdfExtractionResult({required this.text, required this.method});
}

/// Service that delegates PDF decryption AND text extraction to the local
/// Kotlin runtime via native Android MethodChannels.
class PdfCryptoService {
  static const _channel = MethodChannel('com.viren.viren/pdf_crypto');

  /// Decrypts the PDF at [inputPath] using [password] and extracts all text.
  /// Returns the extracted text and method used.
  /// Throws [PdfCryptoException] if the password is wrong or execution fails.
  static Future<PdfExtractionResult> decryptAndExtract({
    required String inputPath,
    required String password,
  }) async {
    try {
      final String? jsonResponse = await _channel.invokeMethod<String>('decryptAndExtract', {
        'inputPath': inputPath,
        'password': password,
      });

      if (jsonResponse == null) return PdfExtractionResult(text: '', method: 'Unknown');

      final Map<String, dynamic> parsed = jsonDecode(jsonResponse);
      return PdfExtractionResult(
        text: parsed['text'] as String? ?? '',
        method: parsed['method'] as String? ?? 'PDFBox',
      );
    } on PlatformException catch (e) {
      throw PdfCryptoException(
        e.code,
        e.message ?? 'Unknown platform exception',
        e.details?.toString(),
      );
    }
  }
}
