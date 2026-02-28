import 'dart:convert';
import 'package:ollama_dart/ollama_dart.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI Fallback Parser — Classification ONLY (V2)
//
// V2 RULE: AI is NEVER used to extract trades or prices.
// It is ONLY used to classify unrecognised documents so a human can
// decide what to do.
//
// Constraints:
//   • Input  = sanitised text excerpt (first 500 chars max)
//   • Output = document classification label
//   • Runs offline via local Ollama instance
//   • Deterministic seed for reproducibility
// ─────────────────────────────────────────────────────────────────────────────

/// Classification result from the AI fallback.
class AiClassificationResult {
  final String documentType;   // e.g. 'contract_note', 'margin_statement', 'holdings_report', 'unknown'
  final int confidence;        // 0–100
  final List<String> warnings;

  const AiClassificationResult({
    required this.documentType,
    required this.confidence,
    this.warnings = const [],
  });
}

class AiFallbackParser {
  final String _model;
  final String _ollamaHost;

  AiFallbackParser({
    String model = 'mistral',
    String ollamaHost = 'http://localhost:11434',
  })  : _model = model,
        _ollamaHost = ollamaHost;

  /// Classifies a PDF's text content into a document type.
  ///
  /// This does NOT extract trades. It only labels the document so the user
  /// can decide if it warrants manual attention.
  Future<AiClassificationResult> classify(String text, {String broker = 'Unknown'}) async {
    final client = OllamaClient(baseUrl: _ollamaHost);

    // Truncate to 500 chars to minimise data exposure
    final truncated = text.length > 500 ? text.substring(0, 500) : text;

    final prompt = '''
You are a financial document classifier. Given the following text excerpt from a PDF,
determine the document type. Return ONLY a valid JSON object with these exact fields:
- "document_type": one of "contract_note", "margin_statement", "holdings_report", "trade_confirmation", "account_statement", "unknown"
- "confidence": integer 0–100

Do NOT extract any financial data, trades, prices, or quantities.
Do NOT include any explanation outside the JSON object.

TEXT:
$truncated
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

      final jsonStr = _extractJsonObject(responseText);
      if (jsonStr == null) {
        return const AiClassificationResult(
          documentType: 'unknown',
          confidence: 0,
          warnings: ['AI returned non-JSON response'],
        );
      }

      final parsed = json.decode(jsonStr) as Map<String, dynamic>;
      final docType = (parsed['document_type'] as String?) ?? 'unknown';
      final conf = (parsed['confidence'] as num?)?.toInt() ?? 0;

      return AiClassificationResult(
        documentType: docType,
        confidence: conf,
      );
    } catch (e) {
      return AiClassificationResult(
        documentType: 'unknown',
        confidence: 0,
        warnings: ['AI classification failed: $e'],
      );
    }
  }

  /// Extract a JSON object from potentially mixed text response.
  String? _extractJsonObject(String text) {
    final braceStart = text.indexOf('{');
    final braceEnd = text.lastIndexOf('}');
    if (braceStart >= 0 && braceEnd > braceStart) {
      return text.substring(braceStart, braceEnd + 1);
    }
    return null;
  }
}
