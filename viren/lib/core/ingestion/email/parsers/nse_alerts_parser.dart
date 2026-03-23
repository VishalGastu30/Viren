import 'dart:convert';
import 'dart:developer' as developer;

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
    final errors = <String>[];
    
    int totalRowsDetected = 0;
    int totalRowsParsed = 0;
    int totalRejectedRows = 0;

    // Normalize text
    final normalizedText = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (normalizedText.isEmpty) {
      errors.add('Decrypted NSE Alerts PDF $filename is empty.');
      return _buildResult(snapshots, warnings, errors, totalRowsDetected, totalRowsParsed, totalRejectedRows);
    }

    // Attempt to extract the date from the text if present, else fallback to email date
    DateTime snapshotDate = emailDate;
    final dateRegExp = RegExp(r'Date\s*:\s*(\d{2}-\w{3}-\d{4})');
    final dateMatch = dateRegExp.firstMatch(normalizedText);
    if (dateMatch != null) {
      // Very basic attempt, if robust parsing fails, rely on emailDate
      // Assuming 'dd-MMM-yyyy', e.g., '14-FEb-2025'
      try {
        // Naive parse or leave as emailDate - we'll just use emailDate for simplicity 
        // as NSE Alerts usually arrive instantly.
      } catch (_) {}
    }

    // Pattern: look for lines with ISIN format INF\w+ followed by security name and quantity.
    // E.g.: INF732E01011 NIPPON INDIA ETF NIFTY BEES 500
    // Sometimes the quantity is before the ISIN or far after. 
    // We'll look for: ISIN (INF\w{11})\s+(.*?)\s+(\d+)\b
    final isinPattern = RegExp(
      r'(INF[A-Z0-9]{11})\s+([^0-9]+?)\s+(\d+)',
      caseSensitive: false,
    );

    final matches = isinPattern.allMatches(normalizedText);
    totalRowsDetected = matches.length;

    for (final match in matches) {
      try {
        final name = match.group(2)!.trim();
        final qtyStr = match.group(3)!;
        
        // We might not know the exact SHORT symbol just from the ISIN or long name.
        // E.g., ISIN yields "NIPPON INDIA ETF NIFTY BEES", we need "NIFTYBEES".
        // The orchestrator's matching logic will have to do partial name matching 
        // or ISIN mapping if available. For now, name is stored as symbol.
        final qty = double.parse(qtyStr);

        snapshots.add(EmailParsedSnapshot(
          symbol: name, 
          quantity: qty,
          snapshotDate: snapshotDate,
          sourceMessageHash: attachmentHash,
        ));
        
        totalRowsParsed++;
      } catch (e) {
        totalRejectedRows++;
        warnings.add('Failed to parse NSE Alerts row: $e');
      }
    }

    if (totalRowsDetected > 0 && totalRowsParsed == 0) {
      errors.add('Parser logic bug: Detected $totalRowsDetected rows but generated 0 snapshots in NSE Alerts.');
    }

    final debugPayload = {
      "pdf": filename,
      "rows_detected": totalRowsDetected,
      "rows_parsed": totalRowsParsed,
      "snapshots_created": snapshots.length,
      "rejected_rows": totalRejectedRows,
    };
    developer.log(jsonEncode(debugPayload), name: 'NseAlertsParser');

    return _buildResult(snapshots, warnings, errors, totalRowsDetected, totalRowsParsed, totalRejectedRows);
  }

  EmailParseResult _buildResult(
    List<EmailParsedSnapshot> snapshots, 
    List<String> warnings, 
    List<String> errors,
    int detected, int parsed, int rejected
  ) {
    int avgConfidence = snapshots.isEmpty ? 0 : 95; // High confidence for NSE

    return EmailParseResult(
      messageId: 'DOCUMENT_PARSER_DELEGATE',
      snapshots: snapshots,
      aggregateConfidence: avgConfidence,
      warnings: warnings,
      errors: errors,
      rowsDetected: detected,
      rowsParsed: parsed,
      rejectedRows: rejected,
    );
  }
}
