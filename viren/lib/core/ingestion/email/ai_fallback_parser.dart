import 'dart:convert';
import 'package:ollama_dart/ollama_dart.dart';

import 'parsers/sbi_nse_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI Fallback Parser — Uses local Ollama LLM for ambiguous PDF text.
//
// Only invoked when deterministic parsing confidence < threshold.
// Constraints:
//   • Input = sanitized text only (no keys, no raw PDF binary)
//   • Output = strict JSON schema
//   • Runs offline via local Ollama instance
//   • Deterministic seed for reproducibility
// ─────────────────────────────────────────────────────────────────────────────

class AiFallbackParser {
  final String _model;
  final String _ollamaHost;

  AiFallbackParser({
    String model = 'mistral',
    String ollamaHost = 'http://localhost:11434',
  })  : _model = model,
        _ollamaHost = ollamaHost;

  /// Attempts to extract trades from ambiguous text using local AI.
  ///
  /// Returns trades with `parsedBy: 'ai'` and reduced confidence.
  Future<PdfParseResult> parseWithAi(String text, {String broker = 'Unknown'}) async {
    final client = OllamaClient(baseUrl: _ollamaHost);

    final prompt = '''
You are a financial document parser. Extract ALL trade transactions from the following text.
Return ONLY a valid JSON array. Each object MUST have these exact fields:
- "symbol": string (stock ticker, e.g. "RELIANCE", "TCS")
- "trade_type": string ("BUY" or "SELL")
- "quantity": number (integer, shares traded)
- "price": number (price per share)
- "total_value": number (quantity * price)
- "trade_date": string (ISO 8601 date, e.g. "2026-02-24")

If no trades are found, return an empty array: []

Do NOT include any explanation, markdown, or text outside the JSON array.

TEXT:
$text
''';

    try {
      final response = await client.generateCompletion(
        request: GenerateCompletionRequest(
          model: _model,
          prompt: prompt,
          options: RequestOptions(
            temperature: 0.0,
            seed: 42,
          ),
        ),
      );

      final responseText = response.response ?? '';

      // Extract JSON from response
      final jsonStr = _extractJson(responseText);
      if (jsonStr == null) {
        return PdfParseResult(
          trades: [],
          documentType: 'unknown',
          aggregateConfidence: 0,
          broker: broker,
          warnings: ['AI returned non-JSON response'],
        );
      }

      final parsed = json.decode(jsonStr) as List<dynamic>;
      final trades = <PdfParsedTrade>[];

      for (final item in parsed) {
        if (item is Map<String, dynamic>) {
          final symbol = (item['symbol'] as String?) ?? '';
          final tradeType = (item['trade_type'] as String?) ?? '';
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
          final price = (item['price'] as num?)?.toDouble() ?? 0;
          final totalValue = (item['total_value'] as num?)?.toDouble() ?? (qty * price);
          final dateStr = (item['trade_date'] as String?) ?? '';

          if (symbol.isEmpty || qty <= 0 || price <= 0) continue;

          trades.add(PdfParsedTrade(
            symbol: symbol.toUpperCase(),
            tradeType: tradeType.toUpperCase(),
            quantity: qty,
            price: price,
            totalValue: totalValue,
            charges: 0,
            tradeTimestamp: DateTime.tryParse(dateStr) ?? DateTime.now(),
            confidence: 70, // AI gets lower confidence
            parsedBy: 'ai',
          ));
        }
      }

      return PdfParseResult(
        trades: trades,
        documentType: 'ai_extracted',
        aggregateConfidence: trades.isEmpty ? 0 : 70,
        broker: broker,
      );
    } catch (e) {
      return PdfParseResult(
        trades: [],
        documentType: 'unknown',
        aggregateConfidence: 0,
        broker: broker,
        warnings: ['AI fallback failed: $e. Manual review required.'],
      );
    }
  }

  /// Extract JSON array from potentially mixed text response.
  String? _extractJson(String text) {
    // Try to find a JSON array in the response
    final bracketStart = text.indexOf('[');
    final bracketEnd = text.lastIndexOf(']');
    if (bracketStart >= 0 && bracketEnd > bracketStart) {
      return text.substring(bracketStart, bracketEnd + 1);
    }
    return null;
  }
}
