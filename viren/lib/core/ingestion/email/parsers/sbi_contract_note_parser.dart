import 'dart:convert';
import 'dart:developer' as developer;

import '../../../database/enums.dart';
import '../broker_email_parser.dart';
import '../document_content_parser.dart';
import '../pdf_classifier.dart';

class SbiContractNoteParser implements DocumentContentParser {
  @override
  PdfDocumentType get supportedType => PdfDocumentType.sbiContractNote;

  @override
  EmailParseResult parseRawText({
    required String rawText,
    required String filename,
    required String attachmentHash,
    required DateTime emailDate,
  }) {
    final trades = <EmailParsedTrade>[];
    final warnings = <String>[];
    final errors = <String>[];
    
    int totalRowsDetected = 0;
    int totalRowsParsed = 0;
    int totalRejectedRows = 0;

    // PHASE 1: Normalize Extracted Text
    final normalizedText = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (normalizedText.isEmpty) {
      errors.add('Decrypted SBI CNB PDF $filename is empty.');
      return _buildResult(trades, warnings, errors, totalRowsDetected, totalRowsParsed, totalRejectedRows);
    }

    // PHASE 2: Tokenize From THE END
    // 1: B/S | 2: Security Name | 3: Symbol | 4: Series | 5: Trade No | 6: Time | 7: Qty | 8: Price | 9: Traded Value
    final cnPattern = RegExp(
      r'\b(B|S)\s+(.+?)\s+([A-Z0-9\-]+)\s+([A-Z]{2})\s+(\d{15,25})\s+(\d{2}:\d{2}:\d{2}\s(?:AM|PM))\s+(\d+)\s+(\d+(?:,\d+)*(?:\.\d+)?)\s+(\d+(?:,\d+)*(?:\.\d+)?)\b',
      caseSensitive: true,
    );

    final matches = cnPattern.allMatches(normalizedText);
    totalRowsDetected = matches.length;

    for (final match in matches) {
      try {
        final typeStr = match.group(1)!;
        final symbol = match.group(3)!;
        final tradeNo = match.group(5)!;
        final qty = double.parse(match.group(7)!);
        final price = double.parse(match.group(8)!.replaceAll(',', ''));

        final tradeType = typeStr == 'B' ? TradeType.buy : TradeType.sell;

        trades.add(EmailParsedTrade(
          symbol: symbol,
          instrumentName: symbol,
          exchange: 'NSE',
          tradeType: tradeType,
          quantity: qty,
          pricePerUnit: price,
          tradeDate: emailDate,
          broker: 'SBI Securities',
          confidence: 85, // Lower than NSE Direct, used as fallback
          sourceMessageHash: attachmentHash,
          tradeNo: tradeNo,
        ));
        
        totalRowsParsed++;
      } catch (e) {
        totalRejectedRows++;
        warnings.add('Failed to extract canonical row data from normalized CNB PDF: $e');
      }
    }
    
    if (totalRowsDetected > 0 && totalRowsParsed == 0) {
      errors.add('Parser logic bug: Detected $totalRowsDetected rows but generated 0 trades in SBI CNB.');
    }

    // REQUIRED DEBUG OUTPUT per user request
    final debugPayload = {
      "pdf": filename,
      "rows_detected": totalRowsDetected,
      "rows_parsed": totalRowsParsed,
      "trades_created": trades.length,
      "rejected_rows": totalRejectedRows,
    };
    developer.log(jsonEncode(debugPayload), name: 'SbiContractNoteParser');

    return _buildResult(trades, warnings, errors, totalRowsDetected, totalRowsParsed, totalRejectedRows);
  }

  EmailParseResult _buildResult(
    List<EmailParsedTrade> trades, 
    List<String> warnings, 
    List<String> errors,
    int detected, int parsed, int rejected
  ) {
    int avgConfidence = trades.isEmpty ? 0 : 85;

    return EmailParseResult(
      messageId: 'DOCUMENT_PARSER_DELEGATE',
      trades: trades,
      aggregateConfidence: avgConfidence,
      warnings: warnings,
      errors: errors,
      rowsDetected: detected,
      rowsParsed: parsed,
      rejectedRows: rejected,
    );
  }
}
