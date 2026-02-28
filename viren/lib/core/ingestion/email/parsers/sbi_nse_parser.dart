// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SBI Securities Contract Note / Statement Parser (Deterministic)
//
// Parses extracted PDF text from SBI Securities contract notes and statements.
// Uses template-based column detection with regex patterns.
// ─────────────────────────────────────────────────────────────────────────────

/// A single trade extracted from a contract note PDF.
class PdfParsedTrade {
  final String? tradeId;
  final String symbol;
  final String? isin;
  final String tradeType; // BUY or SELL
  final double quantity;
  final double price;
  final double totalValue;
  final double charges;
  final DateTime tradeTimestamp;
  final int confidence;
  final String parsedBy;

  const PdfParsedTrade({
    this.tradeId,
    required this.symbol,
    this.isin,
    required this.tradeType,
    required this.quantity,
    required this.price,
    required this.totalValue,
    required this.charges,
    required this.tradeTimestamp,
    required this.confidence,
    required this.parsedBy,
  });

  Map<String, dynamic> toJson() => {
    'trade_id': tradeId,
    'symbol': symbol,
    'isin': isin,
    'trade_type': tradeType,
    'quantity': quantity,
    'price': price,
    'total_value': totalValue,
    'charges': charges,
    'trade_timestamp': tradeTimestamp.toIso8601String(),
    'confidence': confidence,
    'parsed_by': parsedBy,
  };
}

/// Result of parsing a PDF document.
class PdfParseResult {
  final List<PdfParsedTrade> trades;
  final String documentType; // 'contract_note', 'margin_statement', 'account_statement'
  final int aggregateConfidence;
  final String broker;
  final List<String> warnings;

  const PdfParseResult({
    required this.trades,
    required this.documentType,
    required this.aggregateConfidence,
    required this.broker,
    this.warnings = const [],
  });

  bool get hasTrades => trades.isNotEmpty;
}

/// Holding entry from a statement PDF.
class StatementHolding {
  final String symbol;
  final String? isin;
  final double quantity;
  final double? marketValue;
  final double? avgCost;

  const StatementHolding({
    required this.symbol,
    this.isin,
    required this.quantity,
    this.marketValue,
    this.avgCost,
  });
}

/// Result of parsing a statement PDF.
class StatementParseResult {
  final List<StatementHolding> holdings;
  final double? cashBalance;
  final double? marginAvailable;
  final int confidence;
  final List<String> warnings;

  const StatementParseResult({
    required this.holdings,
    this.cashBalance,
    this.marginAvailable,
    required this.confidence,
    this.warnings = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SBI Securities Parser
// ─────────────────────────────────────────────────────────────────────────────

class SbiSecuritiesParser {
  /// Classify the document type from extracted PDF text.
  String classifyDocument(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('contract note') || lower.contains('annexure')) {
      return 'contract_note';
    }
    if (lower.contains('margin statement') || lower.contains('daily margin')) {
      return 'margin_statement';
    }
    if (lower.contains('statement of account') || lower.contains('holding statement')) {
      return 'account_statement';
    }
    return 'unknown';
  }

  /// Parse contract note text into trades.
  PdfParseResult parseContractNote(String text, {DateTime? fallbackDate}) {
    final trades = <PdfParsedTrade>[];
    final warnings = <String>[];
    final lines = text.split('\n');
    int confidence = 95;

    // SBI contract notes typically have:
    // - Trade date in header
    // - Annexure A (equity) / Annexure B (F&O)
    // - Columns: Order No, Trade No, Trade Time, Security/Contract, Buy/Sell, Qty, Rate, Net Rate, Amount

    // Extract trade date from header
    DateTime tradeDate = fallbackDate ?? DateTime.now();
    final datePattern = RegExp(r'Trade\s*Date\s*[:\-]?\s*(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})', caseSensitive: false);
    final dateMatch = datePattern.firstMatch(text);
    if (dateMatch != null) {
      tradeDate = _parseIndianDate(dateMatch.group(1)!) ?? tradeDate;
    }

    // Pattern to match trade rows
    // Typical: trade_no | time | symbol | BUY/SELL | qty | rate | amount
    final tradeRowPattern = RegExp(
      r'(\d+)\s+'                                  // Trade/Order number
      r'(\d{2}:\d{2}:\d{2})?\s*'                   // Optional time
      r'([A-Z][A-Z0-9&\-\.\s]{1,30})\s+'            // Symbol/Security name
      r'(BUY|SELL|B|S)\s+'                          // Buy/Sell indicator
      r'(\d+)\s+'                                   // Quantity
      r'(\d+[\.\d]*)\s+'                            // Rate/Price
      r'(\d+[\.\d]*)',                              // Amount
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = tradeRowPattern.firstMatch(line.trim());
      if (match != null) {
        final tradeId = match.group(1)?.trim();
        final timeStr = match.group(2)?.trim();
        final symbol = _normalizeSymbol(match.group(3)?.trim() ?? '');
        final typeStr = (match.group(4)?.trim() ?? '').toUpperCase();
        final qty = double.tryParse(match.group(5)?.trim() ?? '') ?? 0;
        final price = double.tryParse(match.group(6)?.trim() ?? '') ?? 0;
        final amount = double.tryParse(match.group(7)?.trim() ?? '') ?? 0;

        if (symbol.isEmpty || qty <= 0 || price <= 0) {
          warnings.add('Skipped row with invalid data: $line');
          continue;
        }

        final tradeType = (typeStr == 'B' || typeStr == 'BUY') ? 'BUY' : 'SELL';

        // Parse trade time
        DateTime timestamp = tradeDate;
        if (timeStr != null) {
          final parts = timeStr.split(':');
          if (parts.length >= 3) {
            timestamp = DateTime(
              tradeDate.year, tradeDate.month, tradeDate.day,
              int.tryParse(parts[0]) ?? 0,
              int.tryParse(parts[1]) ?? 0,
              int.tryParse(parts[2]) ?? 0,
            );
          }
        }

        trades.add(PdfParsedTrade(
          tradeId: 'CN_${tradeDate.toIso8601String().substring(0, 10)}_${tradeId}_${trades.length}',
          symbol: symbol,
          tradeType: tradeType,
          quantity: qty,
          price: price,
          totalValue: amount,
          charges: 0, // Charges typically in a summary section
          tradeTimestamp: timestamp,
          confidence: confidence,
          parsedBy: 'deterministic',
        ));
      }
    }

    // Try to extract total charges from summary
    final chargesPattern = RegExp(r'(?:Total\s+)?(?:Brokerage|Charges|STT|Turnover Tax)\s*[:\-]?\s*₹?\s*(\d+[\.\d]*)', caseSensitive: false);
    double totalCharges = 0;
    for (final match in chargesPattern.allMatches(text)) {
      totalCharges += double.tryParse(match.group(1) ?? '') ?? 0;
    }

    // Distribute charges proportionally across trades
    if (totalCharges > 0 && trades.isNotEmpty) {
      final chargePerTrade = totalCharges / trades.length;
      final updatedTrades = trades.map((t) => PdfParsedTrade(
        tradeId: t.tradeId,
        symbol: t.symbol,
        isin: t.isin,
        tradeType: t.tradeType,
        quantity: t.quantity,
        price: t.price,
        totalValue: t.totalValue,
        charges: chargePerTrade,
        tradeTimestamp: t.tradeTimestamp,
        confidence: t.confidence,
        parsedBy: t.parsedBy,
      )).toList();
      
      return PdfParseResult(
        trades: updatedTrades,
        documentType: 'contract_note',
        aggregateConfidence: trades.isEmpty ? 0 : confidence,
        broker: 'SBI Securities',
        warnings: warnings,
      );
    }

    return PdfParseResult(
      trades: trades,
      documentType: 'contract_note',
      aggregateConfidence: trades.isEmpty ? 0 : confidence,
      broker: 'SBI Securities',
      warnings: warnings,
    );
  }

  /// Parse statement PDF into holdings and balances.
  StatementParseResult parseStatement(String text) {
    final holdings = <StatementHolding>[];
    final warnings = <String>[];
    int confidence = 90;

    // Pattern: ISIN | Symbol | Qty | Avg Cost | Market Value
    final holdingPattern = RegExp(
      r'(INE[A-Z0-9]{9})\s+'    // ISIN
      r'([A-Z][A-Z0-9&\-\s]{1,30})\s+'  // Symbol/Name
      r'(\d+)\s+'                // Quantity
      r'(\d+[\.\d]*)\s+'        // Avg Cost
      r'(\d+[\.\d]*)',          // Market Value
      caseSensitive: false,
    );

    for (final match in holdingPattern.allMatches(text)) {
      final isin = match.group(1)?.trim();
      final symbol = _normalizeSymbol(match.group(2)?.trim() ?? '');
      final qty = double.tryParse(match.group(3)?.trim() ?? '') ?? 0;
      final avgCost = double.tryParse(match.group(4)?.trim() ?? '');
      final mktValue = double.tryParse(match.group(5)?.trim() ?? '');

      if (symbol.isNotEmpty && qty > 0) {
        holdings.add(StatementHolding(
          symbol: symbol,
          isin: isin,
          quantity: qty,
          avgCost: avgCost,
          marketValue: mktValue,
        ));
      }
    }

    // Extract cash balance
    double? cashBalance;
    final cashPattern = RegExp(r'(?:Cash|Ledger)\s*Balance\s*[:\-]?\s*₹?\s*([\d,]+[\.\d]*)', caseSensitive: false);
    final cashMatch = cashPattern.firstMatch(text);
    if (cashMatch != null) {
      cashBalance = double.tryParse(cashMatch.group(1)?.replaceAll(',', '') ?? '');
    }

    // Extract margin
    double? marginAvailable;
    final marginPattern = RegExp(r'(?:Available\s+)?Margin\s*[:\-]?\s*₹?\s*([\d,]+[\.\d]*)', caseSensitive: false);
    final marginMatch = marginPattern.firstMatch(text);
    if (marginMatch != null) {
      marginAvailable = double.tryParse(marginMatch.group(1)?.replaceAll(',', '') ?? '');
    }

    return StatementParseResult(
      holdings: holdings,
      cashBalance: cashBalance,
      marginAvailable: marginAvailable,
      confidence: holdings.isEmpty ? 0 : confidence,
      warnings: warnings,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _normalizeSymbol(String raw) {
    // Remove common suffixes like "LTD", "LIMITED", "INDUSTRIES" etc.
    return raw
        .replaceAll(RegExp(r'\s+(LTD|LIMITED|IND|INDU|INDUSTRIES)\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim()
        .toUpperCase();
  }

  DateTime? _parseIndianDate(String dateStr) {
    // Try DD/MM/YYYY or DD-MM-YYYY
    final parts = dateStr.split(RegExp(r'[\/\-]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      int? year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      }
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NSE Alerts Parser
// ─────────────────────────────────────────────────────────────────────────────

class NseAlertsParser {
  /// Parse NSE alert email/attachment text for trade execution data.
  PdfParseResult parseTradeAlert(String text, {DateTime? fallbackDate}) {
    final trades = <PdfParsedTrade>[];
    final warnings = <String>[];
    int confidence = 90;

    // NSE alerts may contain:
    // Execution details with symbol, qty, price, exchange
    final tradePattern = RegExp(
      r'([A-Z][A-Z0-9&]{1,20})\s+'     // Symbol
      r'(BUY|SELL|BOUGHT|SOLD)\s+'      // Trade type
      r'(\d+)\s+'                        // Quantity
      r'@?\s*₹?\s*(\d+[\.\d]*)',        // Price
      caseSensitive: false,
    );

    final date = fallbackDate ?? DateTime.now();

    for (final match in tradePattern.allMatches(text)) {
      final symbol = match.group(1)?.trim().toUpperCase() ?? '';
      final typeStr = (match.group(2)?.trim() ?? '').toUpperCase();
      final qty = double.tryParse(match.group(3)?.trim() ?? '') ?? 0;
      final price = double.tryParse(match.group(4)?.trim() ?? '') ?? 0;

      if (symbol.isEmpty || qty <= 0 || price <= 0) continue;

      final tradeType = (typeStr == 'BOUGHT' || typeStr == 'BUY') ? 'BUY' : 'SELL';

      trades.add(PdfParsedTrade(
        symbol: symbol,
        tradeType: tradeType,
        quantity: qty,
        price: price,
        totalValue: qty * price,
        charges: 0,
        tradeTimestamp: date,
        confidence: confidence,
        parsedBy: 'deterministic',
      ));
    }

    return PdfParseResult(
      trades: trades,
      documentType: 'trade_alert',
      aggregateConfidence: trades.isEmpty ? 0 : confidence,
      broker: 'NSE Direct',
      warnings: warnings,
    );
  }
}
