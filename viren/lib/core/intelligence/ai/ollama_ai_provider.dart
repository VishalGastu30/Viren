import 'package:ollama_dart/ollama_dart.dart';
import 'package:viren/core/intelligence/ai/ai_provider.dart';
import 'package:viren/core/intelligence/ai/prompt_templates.dart';
import 'package:viren/core/intelligence/ai/ai_guardrails.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Ollama AI Provider
//
// Executes local inference against an Ollama daemon running on localhost.
// Enforces templates, validates outputs via guardrails.
// ─────────────────────────────────────────────────────────────────────────────

class OllamaAiProvider extends AiProvider {
  late final OllamaClient _client;
  
  // Recommend tiny quantized models for speed on mobile
  final String _modelName;
  
  bool _isAvailable = false;

  OllamaAiProvider({
    String baseUrl = 'http://10.0.2.2:11434', // Android emulator default to localhost
    String modelName = 'gemma:2b',
  }) : _modelName = modelName {
    _client = OllamaClient(
      baseUrl: baseUrl,
    );
    _checkAvailability();
  }

  /// Pings the Ollama server to see if it's reachable.
  Future<void> _checkAvailability() async {
    try {
      // Just fetching tags to see if the server responds
      await _client.listModels();
      _isAvailable = true;
    } catch (_) {
      _isAvailable = false;
    }
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<AiResponse> summarize(SanitizedPortfolioData data) async {
    if (!isAvailable) {
      return _offlineFallback('summarize');
    }

    final prompt = PromptTemplates.buildPortfolioSummaryPrompt(data);
    return _generateAndValidate(prompt, 'Portfolio Summary');
  }

  @override
  Future<AiResponse> reflect(SanitizedBehaviorData data) async {
    if (!isAvailable) {
      return _offlineFallback('reflect');
    }

    final prompt = PromptTemplates.buildBehaviorReflectionPrompt(data);
    return _generateAndValidate(prompt, 'Behavior Reflection');
  }

  @override
  Future<AiResponse> explain(SanitizedInsightData data) async {
    if (!isAvailable) {
      return _offlineFallback('explain');
    }

    final prompt = PromptTemplates.buildInsightExplanationPrompt(data);
    return _generateAndValidate(prompt, 'Insight Explanation');
  }

  Future<AiResponse> _generateAndValidate(String prompt, String contextType) async {
    try {
      final response = await _client.generateCompletion(
        request: GenerateCompletionRequest(
          model: _modelName,
          prompt: prompt,
          options: const RequestOptions(
            temperature: 0.1, // extremely low temp for consistency
            topP: 0.9,
          ),
          stream: false,
        ),
      );

      final rawText = response.response ?? '';

      final draftResponse = AiResponse(
        content: rawText,
        citations: ['Analyzed Viren Database State'],
        isExplainable: true,
        metadata: {
          'model_used': _modelName,
          'generation_duration_ms': response.totalDuration ?? 0,
        },
      );

      // Pass through our strict Viren rule guardrails
      return AiGuardrails.validate(draftResponse, contextType: contextType);

    } catch (e) {
      return AiResponse(
        content: 'Ollama inference failed. Ensure the daemon is running and the "$_modelName" model is pulled. Error: $e',
        citations: [],
        isExplainable: false,
      );
    }
  }

  AiResponse _offlineFallback(String action) {
    return AiResponse(
      content: 'Cannot $action right now. The local Ollama AI daemon is unreachable.',
      citations: [],
      isExplainable: false,
    );
  }
}
