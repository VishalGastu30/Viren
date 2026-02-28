// ─────────────────────────────────────────────────────────────────────────────
// Broker CSV Templates — Known Column Layouts
//
// Each template describes the expected column structure for a specific
// broker's CSV export. Used for auto-detection during CSV import.
//
// Adding a new broker:
//   1. Export a sample from the broker.
//   2. Record the column headers (case-insensitive regex patterns).
//   3. Create a BrokerCsvTemplate entry.
//   4. Template matching uses a confidence score — partial matches OK.
// ─────────────────────────────────────────────────────────────────────────────

/// A single column-to-field mapping within a broker template.
class ColumnFieldMapping {
  /// Regex pattern that matches the CSV header (case-insensitive).
  final RegExp headerPattern;

  /// The canonical field this column maps to.
  final CsvField field;

  const ColumnFieldMapping(this.headerPattern, this.field);
}

/// Canonical fields that Viren recognizes for trade ingestion.
enum CsvField {
  symbol,
  instrumentName,
  exchange,
  tradeType,     // BUY / SELL
  quantity,
  pricePerUnit,
  totalValue,    // optional — derived if absent
  tradeDate,
  tradeTime,     // optional — merged with tradeDate if present
  broker,
  charges,
  orderNumber,   // ignored but recognized
  ignore,        // known column, explicitly skipped
}

/// Template for a known broker CSV export format.
class BrokerCsvTemplate {
  /// Display name for the user (e.g. "Zerodha Tradebook").
  final String displayName;

  /// Short identifier used internally.
  final String templateId;

  /// Default broker name to assign to imported trades.
  final String brokerName;

  /// Default exchange if not present in CSV.
  final String? defaultExchange;

  /// Date format string(s) used in this broker's CSV (e.g. "yyyy-MM-dd").
  final List<String> dateFormats;

  /// Expected column mappings. Order doesn't matter — matching is by header.
  final List<ColumnFieldMapping> columns;

  /// Minimum number of column matches required to auto-detect this template.
  final int minMatchThreshold;

  const BrokerCsvTemplate({
    required this.displayName,
    required this.templateId,
    required this.brokerName,
    this.defaultExchange,
    required this.dateFormats,
    required this.columns,
    this.minMatchThreshold = 4,
  });

  /// Scores how well a list of CSV headers matches this template.
  /// Returns a value from 0.0 (no match) to 1.0 (perfect match).
  double matchScore(List<String> headers) {
    int matched = 0;
    for (final col in columns) {
      for (final header in headers) {
        if (col.headerPattern.hasMatch(header.trim())) {
          matched++;
          break;
        }
      }
    }
    return columns.isEmpty ? 0 : matched / columns.length;
  }

  /// Attempts to map CSV headers to canonical fields.
  /// Returns a map of column_index → CsvField.
  Map<int, CsvField> mapHeaders(List<String> headers) {
    final result = <int, CsvField>{};
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].trim();
      for (final col in columns) {
        if (col.headerPattern.hasMatch(header)) {
          result[i] = col.field;
          break;
        }
      }
    }
    return result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BROKER TEMPLATES
// ─────────────────────────────────────────────────────────────────────────────

/// Zerodha (Kite) Tradebook CSV export
final zerodhaTradebookTemplate = BrokerCsvTemplate(
  displayName: 'Zerodha Tradebook',
  templateId: 'zerodha_tradebook',
  brokerName: 'Zerodha',
  defaultExchange: 'NSE',
  dateFormats: ['yyyy-MM-dd', 'dd-MM-yyyy'],
  columns: [
    ColumnFieldMapping(
      RegExp(r'^symbol$', caseSensitive: false),
      CsvField.symbol,
    ),
    ColumnFieldMapping(
      RegExp(r'^(trade[\s_]?type|type)$', caseSensitive: false),
      CsvField.tradeType,
    ),
    ColumnFieldMapping(
      RegExp(r'^(quantity|qty)$', caseSensitive: false),
      CsvField.quantity,
    ),
    ColumnFieldMapping(
      RegExp(r'^(price|avg[\.\s_]?price|trade[\s_]?price)$', caseSensitive: false),
      CsvField.pricePerUnit,
    ),
    ColumnFieldMapping(
      RegExp(r'^(trade[\s_]?date|date|order[\s_]?date)$', caseSensitive: false),
      CsvField.tradeDate,
    ),
    ColumnFieldMapping(
      RegExp(r'^(trade[\s_]?time|time|order[\s_]?time)$', caseSensitive: false),
      CsvField.tradeTime,
    ),
    ColumnFieldMapping(
      RegExp(r'^exchange$', caseSensitive: false),
      CsvField.exchange,
    ),
    ColumnFieldMapping(
      RegExp(r'^(isin|instrument[\s_]?name)$', caseSensitive: false),
      CsvField.instrumentName,
    ),
    ColumnFieldMapping(
      RegExp(r'^order[\s_]?no\.?$', caseSensitive: false),
      CsvField.orderNumber,
    ),
  ],
  minMatchThreshold: 4,
);

/// Zerodha Contract Note CSV (alternate format)
final zerodhaContractNoteTemplate = BrokerCsvTemplate(
  displayName: 'Zerodha Contract Note',
  templateId: 'zerodha_contract_note',
  brokerName: 'Zerodha',
  defaultExchange: 'NSE',
  dateFormats: ['dd/MM/yyyy', 'dd-MM-yyyy', 'yyyy-MM-dd'],
  columns: [
    ColumnFieldMapping(
      RegExp(r'^(scrip[\s_]?name|symbol|instrument)$', caseSensitive: false),
      CsvField.symbol,
    ),
    ColumnFieldMapping(
      RegExp(r'^(buy[\s/]sell|b/s|trade[\s_]?type|type)$', caseSensitive: false),
      CsvField.tradeType,
    ),
    ColumnFieldMapping(
      RegExp(r'^(quantity|qty|net[\s_]?qty)$', caseSensitive: false),
      CsvField.quantity,
    ),
    ColumnFieldMapping(
      RegExp(r'^(rate|price|avg[\.\s_]?rate)$', caseSensitive: false),
      CsvField.pricePerUnit,
    ),
    ColumnFieldMapping(
      RegExp(r'^(trade[\s_]?date|date|settlement[\s_]?date)$', caseSensitive: false),
      CsvField.tradeDate,
    ),
    ColumnFieldMapping(
      RegExp(r'^(net[\s_]?amount|amount|total)$', caseSensitive: false),
      CsvField.totalValue,
    ),
    ColumnFieldMapping(
      RegExp(r'^(brokerage|charges|total[\s_]?charges)$', caseSensitive: false),
      CsvField.charges,
    ),
    ColumnFieldMapping(
      RegExp(r'^exchange$', caseSensitive: false),
      CsvField.exchange,
    ),
  ],
  minMatchThreshold: 4,
);

/// All registered broker templates. Searched in priority order.
final List<BrokerCsvTemplate> allBrokerTemplates = [
  zerodhaTradebookTemplate,
  zerodhaContractNoteTemplate,
];
