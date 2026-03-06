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

    // Normalize text for regex matching
    final normalizedText = rawText.replaceAll(RegExp(r'\s+'), ' ');

    if (normalizedText.trim().isEmpty) {
      errors.add('Decrypted SBI CNB PDF $filename is empty.');
      return EmailParseResult(
        messageId: 'DOCUMENT_PARSER_DELEGATE',
        aggregateConfidence: 0,
        warnings: warnings,
        errors: errors,
      );
    }

    // --- ANNEXURE B: Global Charges ---
    // We will attempt to find summary totals. Commonly formatted as trailing numbers.
    double extractAmount(String label) {
      final reg = RegExp(label + r'[^0-9]+([\d,]+\.\d+)', caseSensitive: false);
      final match = reg.firstMatch(normalizedText);
      if (match != null) {
        return double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0.0;
      }
      return 0.0;
    }

    // Try to extract charges by common SBI labels
    final brokerage = extractAmount(r'Brokerage');
    final stt = extractAmount(r'Securities Transaction Tax');
    final cgst = extractAmount(r'CGST');
    final sgst = extractAmount(r'SGST');
    final igst = extractAmount(r'IGST');
    final gst = cgst + sgst + igst;
    
    final stampDuty = extractAmount(r'Stamp Duty');
    final exchangeCharges = extractAmount(r'Exchange Transaction Charges');
    final sebiFees = extractAmount(r'SEBI Turnover Fees');
    final otherLevies = stampDuty + exchangeCharges + sebiFees;

    final netAmountAfterLevies = extractAmount(r'Net Amount receivable|Net Amount payable');
    
    // --- ANNEXURE A: Trades ---
    final annexureAPattern = RegExp(
      r'(\d{13,20})\s+(\d{2}:\d{2}:\d{2})\s+([A-Z0-9\-]+)-Cash-\S+\s+(B|S)\s+(\d+)\s+([\d.]+)',
      caseSensitive: true,
    );

    final matches = annexureAPattern.allMatches(normalizedText);
    totalRowsDetected = matches.length;

    // We will apportion the global charges across the trades by transaction value to calculate True Cost Basis.
    double totalTradeValue = 0.0;
    final parsedRawTrades = <Map<String, dynamic>>[];

    for (final match in matches) {
      try {
        final tradeNo = match.group(1)!;
        final symbol = match.group(3)!;
        final typeStr = match.group(4)!;
        final qtyStr = match.group(5)!;
        final priceStr = match.group(6)!;

        final qty = double.parse(qtyStr);
        final price = double.parse(priceStr);
        final tradeType = typeStr == 'B' ? TradeType.buy : TradeType.sell;
        
        final value = qty * price;
        totalTradeValue += value;

        parsedRawTrades.add({
          'tradeNo': tradeNo,
          'symbol': symbol,
          'type': tradeType,
          'qty': qty,
          'price': price,
          'value': value,
        });
        
        totalRowsParsed++;
      } catch (e) {
        totalRejectedRows++;
        warnings.add('Failed to parse SBI contract note trade: $e');
      }
    }

    // Create final EmailParsedTrade objects with apportioned charges
    for (final raw in parsedRawTrades) {
      final proportion = totalTradeValue > 0 ? (raw['value'] / totalTradeValue) : 0;
      
      final apportionedBrokerage = proportion * brokerage;
      final apportionedStt = proportion * stt;
      final apportionedGst = proportion * gst;
      final apportionedOther = proportion * otherLevies;
      
      // Calculate true cost basis = (grossValue + totalCharges) / qty
      // For SBI, we add charges to both buy and sell true cost basis mathematically for performance checking
      final totalChargesForTrade = apportionedBrokerage + apportionedStt + apportionedGst + apportionedOther;
      final trueCostBasis = (raw['value'] + totalChargesForTrade) / raw['qty'];

      trades.add(EmailParsedTrade(
        symbol: raw['symbol'],
        instrumentName: raw['symbol'],
        exchange: 'NSE',
        tradeType: raw['type'],
        quantity: raw['qty'],
        pricePerUnit: raw['price'],
        tradeDate: emailDate,
        broker: 'SBI Securities',
        confidence: 85, 
        sourceMessageHash: attachmentHash, 
        tradeNo: raw['tradeNo'],
        source: TradeSource.sbiContractNote,
        brokerage: apportionedBrokerage,
        stt: apportionedStt,
        gst: apportionedGst,
        otherLevies: apportionedOther,
        netAmountAfterLevies: proportion * netAmountAfterLevies,
        trueCostBasis: trueCostBasis,
      ));
    }

    developer.log(
      '[SBI_CN_PARSER] $filename | Found ${trades.length} trades | TCB Apportioned',
      name: 'SbiContractNoteParser',
    );

    return EmailParseResult(
      messageId: 'DOCUMENT_PARSER_DELEGATE',
      trades: trades,
      aggregateConfidence: trades.isEmpty ? 0 : 85,
      warnings: warnings,
      errors: errors,
      rowsDetected: totalRowsDetected,
      rowsParsed: totalRowsParsed,
      rejectedRows: totalRejectedRows,
      rawCandidatesDetected: 0,
      rawCandidates: [],
      snapshots: [],
    );
  }
}
