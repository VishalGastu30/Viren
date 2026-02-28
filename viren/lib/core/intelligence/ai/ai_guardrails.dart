import 'package:viren/core/intelligence/ai/ai_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI Guardrails & Post-Processing
//
// Ensures the LLM output conforms to the PRD restrictions before displaying it
// to the user. Acts as a safety net if the LLM hallucinates past the prompt.
// ─────────────────────────────────────────────────────────────────────────────

class AiGuardrails {
  
  static final List<RegExp> _bannedPatterns = [
    RegExp(r'\b(predict|prediction|forecast|target price)\b', caseSensitive: false),
    RegExp(r'\b(buy|sell|short|accumulate|dump)\s+(now|immediately|soon)\b', caseSensitive: false),
    RegExp(r'\b(will reach|will go to|expected to hit)\b', caseSensitive: false),
    RegExp(r'\b(financial advice|investment advice)\b', caseSensitive: false),
  ];

  /// Validates the output from the AI.
  /// Throws an exception or returns a fallback response if the text violently
  /// violates core rules (e.g. telling the user to buy a stock).
  static AiResponse validate(AiResponse response, {required String contextType}) {
    if (response.content.trim().isEmpty) {
       return _sanitizedFallback(contextType, 'Empty response generated.');
    }

    final lowerText = response.content.toLowerCase();

    // 1. Check for banned predictive/advice language
    for (final pattern in _bannedPatterns) {
      if (pattern.hasMatch(lowerText)) {
        return _sanitizedFallback(
          contextType, 
          'The AI generated text containing restricted predictive or prescriptive language.',
        );
      }
    }

    // 2. Check for extreme confidence inflation (e.g. "I am 100% certain")
    if (lowerText.contains('100% sure') || lowerText.contains('guaranteed to') || lowerText.contains('certainly will')) {
       return _sanitizedFallback(
          contextType, 
          'The AI expressed inappropriate certainty about market dynamics.',
        );
    }

    // If it passes all checks, return the original response
    return response;
  }

  static AiResponse _sanitizedFallback(String contextType, String reason) {
    return AiResponse(
      content: 'I analyzed the $contextType data, but the generated insight was blocked because it violated Viren\'s deterministic safety parameters. ($reason)',
      citations: [],
      isExplainable: false,
    );
  }
}
