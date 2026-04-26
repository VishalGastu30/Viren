import '../groq_service.dart';

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
//   • Runs via Groq API (Llama 3.1 8B is sufficient for classification)
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
  AiFallbackParser();

  /// Classifies a PDF's text content into a document type.
  ///
  /// This does NOT extract trades. It only labels the document so the user
  /// can decide if it warrants manual attention.
  Future<AiClassificationResult> classify(String text, {String broker = 'Unknown'}) async {
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
      final parsed = await GroqService.chatJson(
        prompt: prompt,
        systemPrompt: "You are a financial document classifier.",
        model: GroqService.lightModel,
      );

      if (parsed == null) {
        return const AiClassificationResult(
          documentType: 'unknown',
          confidence: 0,
          warnings: ['AI returned invalid response'],
        );
      }

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


