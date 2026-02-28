import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/enums.dart';
import '../database/repositories/trade_repository.dart';
import '../database/daos/import_dao.dart';
import 'broker_templates.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CsvImportService — Deterministic CSV Trade Ingestion
//
// 5-step pipeline:
//   1. Parse raw CSV text → rows
//   2. Detect broker template (auto) or accept manual mapping
//   3. Map columns to canonical fields
//   4. Dry-run: parse all rows, report confidence + warnings
//   5. Commit: persist validated trades via TradeRepository
//
// Security:
//   • No external network calls
//   • Raw CSV never persisted — only parsed trades
//   • Source hash (SHA-256 of file content) stored for dedup
// ─────────────────────────────────────────────────────────────────────────────

/// Parsed trade candidate — not yet persisted.
class ParsedTrade {
  final String symbol;
  final String instrumentName;
  final String? exchange;
  final TradeType tradeType;
  final double quantity;
  final double pricePerUnit;
  final double? totalValue;
  final DateTime tradeTimestamp;
  final String broker;
  final double? charges;
  final int fieldConfidence; // 0–100
  final List<String> warnings;

  const ParsedTrade({
    required this.symbol,
    required this.instrumentName,
    this.exchange,
    required this.tradeType,
    required this.quantity,
    required this.pricePerUnit,
    this.totalValue,
    required this.tradeTimestamp,
    required this.broker,
    this.charges,
    required this.fieldConfidence,
    this.warnings = const [],
  });
}

/// Result of a dry-run parse — shown to user for confirmation.
class CsvImportPreview {
  final List<ParsedTrade> trades;
  final List<String> warnings;
  final List<String> errors;
  final int aggregateConfidence; // 0–100
  final String sourceHash;
  final String? detectedTemplate;
  final Map<int, CsvField> columnMapping;

  const CsvImportPreview({
    required this.trades,
    required this.warnings,
    required this.errors,
    required this.aggregateConfidence,
    required this.sourceHash,
    this.detectedTemplate,
    required this.columnMapping,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get requiresConfirmation => aggregateConfidence < 90;
}

/// Result of a committed import.
class CsvImportResult {
  final String importId;
  final int totalRows;
  final int successfulRows;
  final int failedRows;
  final List<String> errors;

  const CsvImportResult({
    required this.importId,
    required this.totalRows,
    required this.successfulRows,
    required this.failedRows,
    required this.errors,
  });
}

class CsvImportService {
  final TradeRepository _tradeRepo;
  final ImportDao _importDao;
  final _uuid = const Uuid();

  CsvImportService({
    required TradeRepository tradeRepository,
    required ImportDao importDao,
  })  : _tradeRepo = tradeRepository,
        _importDao = importDao;

  // ── Step 1: Parse raw CSV ─────────────────────────────────────────────────

  /// Parses raw CSV text into a list of string rows.
  /// Handles various delimiters and encoding quirks.
  List<List<String>> parseRawCsv(String csvText) {
    // Normalize line endings
    final normalized = csvText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    final converter = const CsvToListConverter(
      shouldParseNumbers: false,
      allowInvalid: true,
      eol: '\n',
    );

    return converter.convert(normalized).map((row) {
      return row.map((cell) => cell.toString().trim()).toList();
    }).toList();
  }

  // ── Step 2: Detect broker template ────────────────────────────────────────

  /// Tries to auto-detect which broker template matches the CSV headers.
  /// Returns the best match if confidence exceeds threshold, null otherwise.
  BrokerCsvTemplate? detectTemplate(List<String> headers) {
    BrokerCsvTemplate? best;
    double bestScore = 0;

    for (final template in allBrokerTemplates) {
      final score = template.matchScore(headers);
      if (score > bestScore) {
        bestScore = score;
        best = template;
      }
    }

    // Require at least 50% column match for auto-detection
    if (best != null && bestScore >= 0.5) {
      return best;
    }
    return null;
  }

  // ── Step 3: Map columns ───────────────────────────────────────────────────

  /// Maps CSV headers to canonical fields using a detected or provided template.
  Map<int, CsvField> mapColumns(
    List<String> headers,
    BrokerCsvTemplate? template,
  ) {
    if (template != null) {
      return template.mapHeaders(headers);
    }
    // Fallback: attempt generic header matching
    return _genericHeaderMapping(headers);
  }

  /// Heuristic mapping for CSVs that don't match any template.
  Map<int, CsvField> _genericHeaderMapping(List<String> headers) {
    final mapping = <int, CsvField>{};

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().trim();

      if (RegExp(r'(symbol|ticker|scrip|stock)').hasMatch(h)) {
        mapping[i] = CsvField.symbol;
      } else if (RegExp(r'(name|instrument[\s_]?name|company)').hasMatch(h)) {
        mapping[i] = CsvField.instrumentName;
      } else if (RegExp(r'(type|side|buy[\s/]sell|b/s|trade[\s_]?type)').hasMatch(h)) {
        mapping[i] = CsvField.tradeType;
      } else if (RegExp(r'(qty|quantity|shares|units|lot)').hasMatch(h)) {
        mapping[i] = CsvField.quantity;
      } else if (RegExp(r'(price|rate|avg|execution)').hasMatch(h) &&
                 !h.contains('total')) {
        mapping[i] = CsvField.pricePerUnit;
      } else if (RegExp(r'(date|trade[\s_]?date|order[\s_]?date|settlement)').hasMatch(h) &&
                 !h.contains('time')) {
        mapping[i] = CsvField.tradeDate;
      } else if (RegExp(r'(time|trade[\s_]?time|order[\s_]?time)').hasMatch(h)) {
        mapping[i] = CsvField.tradeTime;
      } else if (RegExp(r'(exchange|mkt|market|segment)').hasMatch(h)) {
        mapping[i] = CsvField.exchange;
      } else if (RegExp(r'(total|amount|value|net[\s_]?amount)').hasMatch(h)) {
        mapping[i] = CsvField.totalValue;
      } else if (RegExp(r'(charge|brokerage|commission|fee|stt)').hasMatch(h)) {
        mapping[i] = CsvField.charges;
      }
    }

    return mapping;
  }

  // ── Step 4: Dry-run parse ─────────────────────────────────────────────────

  /// Parses all data rows using the given column mapping.
  /// Returns a preview with parsed trades, warnings, and errors.
  /// Does NOT write anything to the database.
  CsvImportPreview dryRun({
    required String rawCsvText,
    required Map<int, CsvField> columnMapping,
    BrokerCsvTemplate? template,
  }) {
    final rows = parseRawCsv(rawCsvText);
    if (rows.isEmpty) {
      return const CsvImportPreview(
        trades: [],
        warnings: [],
        errors: ['CSV file is empty'],
        aggregateConfidence: 0,
        sourceHash: '',
        columnMapping: {},
      );
    }

    final sourceHash = sha256.convert(utf8.encode(rawCsvText)).toString();
    final trades = <ParsedTrade>[];
    final warnings = <String>[];
    final errors = <String>[];

    // Skip header row (row 0), process data rows (row 1+)
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => cell.isEmpty)) continue; // skip blank rows

      try {
        final parsed = _parseRow(row, i, columnMapping, template);
        trades.add(parsed);
        warnings.addAll(parsed.warnings.map((w) => 'Row ${i + 1}: $w'));
      } catch (e) {
        errors.add('Row ${i + 1}: $e');
      }
    }

    // Compute aggregate confidence
    final avgConfidence = trades.isEmpty
        ? 0
        : (trades.fold<int>(0, (s, t) => s + t.fieldConfidence) / trades.length)
              .round();

    return CsvImportPreview(
      trades: trades,
      warnings: warnings,
      errors: errors,
      aggregateConfidence: avgConfidence,
      sourceHash: sourceHash,
      detectedTemplate: template?.templateId,
      columnMapping: columnMapping,
    );
  }

  /// Parses a single CSV row into a ParsedTrade.
  ParsedTrade _parseRow(
    List<String> row,
    int rowIndex,
    Map<int, CsvField> mapping,
    BrokerCsvTemplate? template,
  ) {
    final cellFor = _CellAccessor(row, mapping);
    final warnings = <String>[];
    int fieldsPresent = 0;
    int fieldsTotal = 5; // symbol, type, qty, price, date are required

    // ── Symbol (required) ─────────────────────────────────────────────────
    final symbol = cellFor.get(CsvField.symbol);
    if (symbol == null || symbol.isEmpty) {
      throw FormatException('Missing symbol');
    }
    fieldsPresent++;

    // ── Instrument Name (optional, defaults to symbol) ────────────────────
    final instrumentName = cellFor.get(CsvField.instrumentName) ?? symbol;

    // ── Exchange (optional) ───────────────────────────────────────────────
    final exchange = cellFor.get(CsvField.exchange) ?? template?.defaultExchange;

    // ── Trade Type (required) ─────────────────────────────────────────────
    final typeStr = cellFor.get(CsvField.tradeType);
    if (typeStr == null || typeStr.isEmpty) {
      throw FormatException('Missing trade type');
    }
    final tradeType = _parseTradeType(typeStr);
    fieldsPresent++;

    // ── Quantity (required) ───────────────────────────────────────────────
    final qtyStr = cellFor.get(CsvField.quantity);
    final quantity = _parseDouble(qtyStr, 'quantity');
    if (quantity <= 0) throw FormatException('Quantity must be positive');
    fieldsPresent++;

    // ── Price (required) ──────────────────────────────────────────────────
    final priceStr = cellFor.get(CsvField.pricePerUnit);
    final price = _parseDouble(priceStr, 'price');
    if (price <= 0) throw FormatException('Price must be positive');
    fieldsPresent++;

    // ── Total Value (optional — derived if absent) ────────────────────────
    final totalStr = cellFor.get(CsvField.totalValue);
    double? totalValue;
    if (totalStr != null && totalStr.isNotEmpty) {
      totalValue = double.tryParse(_cleanNumber(totalStr));
    }

    // ── Trade Date (required) ─────────────────────────────────────────────
    final dateStr = cellFor.get(CsvField.tradeDate);
    if (dateStr == null || dateStr.isEmpty) {
      throw FormatException('Missing trade date');
    }
    final timeStr = cellFor.get(CsvField.tradeTime);
    final tradeTimestamp = _parseDateTime(
      dateStr,
      timeStr,
      template?.dateFormats ?? _defaultDateFormats,
    );
    fieldsPresent++;

    // ── Charges (optional) ────────────────────────────────────────────────
    final chargesStr = cellFor.get(CsvField.charges);
    double? charges;
    if (chargesStr != null && chargesStr.isNotEmpty) {
      charges = double.tryParse(_cleanNumber(chargesStr));
    }

    // ── Confidence ────────────────────────────────────────────────────────
    int confidence = ((fieldsPresent / fieldsTotal) * 100).round();
    if (template != null) {
      confidence = (confidence * 0.9 + 10).round(); // bonus for template match
    }

    return ParsedTrade(
      symbol: symbol.toUpperCase().trim(),
      instrumentName: instrumentName.trim(),
      exchange: exchange,
      tradeType: tradeType,
      quantity: quantity,
      pricePerUnit: price,
      totalValue: totalValue,
      tradeTimestamp: tradeTimestamp,
      broker: template?.brokerName ?? 'Unknown',
      charges: charges,
      fieldConfidence: confidence.clamp(0, 100),
      warnings: warnings,
    );
  }

  // ── Step 5: Commit ────────────────────────────────────────────────────────

  /// Persists all validated trades from a preview.
  /// Creates an import session, inserts trades, and rebuilds holdings.
  Future<CsvImportResult> commit(CsvImportPreview preview) async {
    final importId = _uuid.v4();
    final errors = <String>[];
    int successful = 0;

    // Log the import session
    await _importDao.logImport(
      ImportsCompanion.insert(
        id: importId,
        importType: ImportType.csv,
        sourceName: preview.detectedTemplate ?? 'CSV Import',
        rowsImported: Value(preview.trades.length),
        successRate: Value(preview.aggregateConfidence),
      ),
    );

    // Insert each trade via TradeRepository (encryption + hash chains handled)
    for (int i = 0; i < preview.trades.length; i++) {
      final t = preview.trades[i];
      try {
        await _tradeRepo.insertTrade(
          instrumentSymbol: t.symbol,
          instrumentName: t.instrumentName,
          exchange: t.exchange,
          tradeType: t.tradeType,
          quantity: t.quantity,
          pricePerUnit: t.pricePerUnit,
          broker: t.broker,
          charges: t.charges,
          source: TradeSource.csv,
          sourceReference: preview.sourceHash,
          parseConfidence: t.fieldConfidence,
          tradeTimestamp: t.tradeTimestamp,
          originImportId: importId,
        );
        successful++;
      } catch (e) {
        errors.add('Trade ${i + 1} (${t.symbol}): $e');
      }
    }

    return CsvImportResult(
      importId: importId,
      totalRows: preview.trades.length,
      successfulRows: successful,
      failedRows: preview.trades.length - successful,
      errors: errors,
    );
  }

  /// Computes a SHA-256 hash of the CSV content for deduplication.
  String computeSourceHash(String csvText) {
    return sha256.convert(utf8.encode(csvText)).toString();
  }

  // ── Parsing helpers ───────────────────────────────────────────────────────

  static const _defaultDateFormats = [
    'yyyy-MM-dd',
    'dd-MM-yyyy',
    'dd/MM/yyyy',
    'MM/dd/yyyy',
    'dd-MMM-yyyy',
    'yyyy/MM/dd',
  ];

  TradeType _parseTradeType(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower == 'buy' || lower == 'b') return TradeType.buy;
    if (lower == 'sell' || lower == 's') return TradeType.sell;
    throw FormatException('Unknown trade type: "$raw"');
  }

  double _parseDouble(String? raw, String fieldName) {
    if (raw == null || raw.isEmpty) {
      throw FormatException('Missing $fieldName');
    }
    final cleaned = _cleanNumber(raw);
    final result = double.tryParse(cleaned);
    if (result == null) {
      throw FormatException('Cannot parse $fieldName: "$raw"');
    }
    return result;
  }

  /// Removes commas, currency symbols, and whitespace from number strings.
  String _cleanNumber(String raw) {
    return raw
        .replaceAll(',', '')
        .replaceAll('₹', '')
        .replaceAll('\$', '')
        .replaceAll(' ', '')
        .trim();
  }

  DateTime _parseDateTime(
    String dateStr,
    String? timeStr,
    List<String> formats,
  ) {
    final combined = timeStr != null && timeStr.isNotEmpty
        ? '$dateStr $timeStr'
        : dateStr;

    // Try each date format
    for (final fmt in formats) {
      try {
        final fullFmt = timeStr != null && timeStr.isNotEmpty
            ? '$fmt HH:mm:ss'
            : fmt;
        final parsed = DateFormat(fullFmt).parseStrict(combined);
        return parsed.toUtc();
      } catch (_) {
        // try next format
      }
      // Also try without seconds for time
      if (timeStr != null && timeStr.isNotEmpty) {
        try {
          final fullFmt = '$fmt HH:mm';
          final parsed = DateFormat(fullFmt).parseStrict(combined);
          return parsed.toUtc();
        } catch (_) {
          // try next format
        }
      }
    }

    // Last resort: try DateTime.parse (ISO-8601)
    try {
      return DateTime.parse(combined).toUtc();
    } catch (_) {
      throw FormatException('Cannot parse date: "$dateStr"');
    }
  }
}

/// Helper to extract cell values by canonical field name.
class _CellAccessor {
  final List<String> _row;
  final Map<int, CsvField> _mapping;

  const _CellAccessor(this._row, this._mapping);

  String? get(CsvField field) {
    for (final entry in _mapping.entries) {
      if (entry.value == field && entry.key < _row.length) {
        final val = _row[entry.key].trim();
        return val.isEmpty ? null : val;
      }
    }
    return null;
  }
}
