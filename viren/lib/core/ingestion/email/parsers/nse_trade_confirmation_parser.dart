import 'dart:convert';
import 'dart:developer' as developer;

import '../../../database/enums.dart';
import '../broker_email_parser.dart';
import '../document_content_parser.dart';
import '../pdf_classifier.dart';

class NseTradeConfirmationParser implements DocumentContentParser {
  @override
  PdfDocumentType get supportedType => PdfDocumentType.nseTradeConfirmation;

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

    // 1. Normalize
    // We intentionally keep single spaces but remove newlines/tabs so the pattern can match continuously
    final normalizedText = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (normalizedText.isEmpty) {
      errors.add('Decrypted NSE Direct PDF $filename is empty.');
      return _buildResult(trades, warnings, errors, totalRowsDetected, totalRowsParsed, totalRejectedRows);
    }

    // 2. The primary regex pattern for the specific clean row:
    // [SYMBOL] EQ [19-digit TradeNo] [HH:MM:SS AM/PM] [Qty] [Price] [TradeValue]
    final tradeLinePattern = RegExp(
      r'\b([A-Z][A-Z0-9]{2,19})\s+EQ\s+(\d{15,25})\s+(\d{2}:\d{2}:\d{2}\s+(?:AM|PM))\s+(\d+)\s+([\d.]+)\s+([\d.]+)',
      caseSensitive: true,
    );
    
    // Pattern to search backwards for B or S
    final bsPattern = RegExp(r'\b(B|S)\b', caseSensitive: true);

    final matches = tradeLinePattern.allMatches(normalizedText);
    totalRowsDetected = matches.length;

    for (final match in matches) {
      try {
        final symbol = match.group(1)!;
        final tradeNo = match.group(2)!;
        // group 3 is time, but we don't store time right now
        final qtyStr = match.group(4)!;
        final priceStr = match.group(5)!;
        final tradeValueStr = match.group(6)!;

        final qty = double.parse(qtyStr);
        final price = double.parse(priceStr);
        final tradeValue = double.parse(tradeValueStr);

        // 3. Math Validation (`qty * price ≈ tradeValue ±1%`)
        final calculatedValue = qty * price;
        final deviation = tradeValue == 0 
            ? 0.0 
            : (calculatedValue - tradeValue).abs() / tradeValue;

        if (deviation > 0.01) {
          totalRejectedRows++;
          warnings.add('Math validation failed for $symbol (TradeNo: $tradeNo): Qty($qty) * Price($price) = $calculatedValue, but PDF says $tradeValue. Deviation: ${(deviation*100).toStringAsFixed(2)}%');
          continue;
        }

        // 4. Find B/S for this trade by looking *backwards* from this match start
        final textBeforeMatch = normalizedText.substring(0, match.start);
        final bsMatches = bsPattern.allMatches(textBeforeMatch);
        
        TradeType tradeType = TradeType.buy; // Defaulting, but should always find one
        if (bsMatches.isNotEmpty) {
           final lastMatch = bsMatches.last.group(1)!;
           tradeType = lastMatch == 'B' ? TradeType.buy : TradeType.sell;
        } else {
           warnings.add('Could not clearly find Buy/Sell indicator for $symbol (TradeNo: $tradeNo). Defaulting to BUY.');
        }

        trades.add(EmailParsedTrade(
          symbol: symbol,
          instrumentName: symbol,
          exchange: 'NSE',
          tradeType: tradeType,
          quantity: qty,
          pricePerUnit: price,
          tradeDate: emailDate.subtract(const Duration(days: 1)),
          broker: 'NSE Direct',
          confidence: 80, // NSE Direct Regex Baseline
          sourceMessageHash: attachmentHash, 
          tradeNo: tradeNo,
          source: TradeSource.nseDirect,
        ));
        
        totalRowsParsed++;
        
      } catch (e) {
        totalRejectedRows++;
        warnings.add('Failed to parse canonical row data from candidate via Regex: $e');
      }
    }

    final debugPayload = {
      "pdf": filename,
      "total_tokens": normalizedText.split(' ').length,
      "regex_trades_created": trades.length,
      "math_rejections": totalRejectedRows,
    };
    developer.log(jsonEncode(debugPayload), name: 'NseTradeConfirmationParser');

    return _buildResult(trades, warnings, errors, totalRowsDetected, totalRowsParsed, totalRejectedRows);
  }

  EmailParseResult _buildResult(
    List<EmailParsedTrade> trades, 
    List<String> warnings, 
    List<String> errors,
    int detected, int parsed, int rejected
  ) {
    int avgConfidence = trades.isEmpty ? 0 : 80;

    return EmailParseResult(
      messageId: 'DOCUMENT_PARSER_DELEGATE',
      trades: trades,
      aggregateConfidence: avgConfidence,
      warnings: warnings,
      errors: errors,
      rowsDetected: detected,
      rowsParsed: parsed,
      rejectedRows: rejected,
      rawCandidatesDetected: 0,
      rawCandidates: [],
    );
  }
}
