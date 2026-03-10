import 'package:flutter/services.dart';
import '../../core/ai/model_download_service.dart';
import '../../core/market/market_knowledge_service.dart';
import 'chat_message.dart';

class AssistantService {
  static const _channel = MethodChannel('com.viren.viren/pdf_crypto');

  // ── Token budget constants (1 token ≈ 4 chars) ──────────────────────────
  // Total context window: 1280 tokens = ~5120 chars
  // We leave 1024 tokens for the response (maxTokens in MainActivity).
  // That gives us 256 tokens = ~1024 chars for the entire prompt.
  // We enforce this hard limit by trimming aggressively.
  static const _maxPromptChars = 3200; // ~800 tokens for prompt

  // ── System prompt — compact but complete ────────────────────────────────
  static const _systemPrompt =
      'You are Viren, a personal investment companion for an Indian retail investor. '
      'You have live portfolio data below with pre-calculated returns. Trust the numbers — do not recalculate or guess. '
      'Be conversational, warm, and precise — like a sharp friend who knows markets. '
      'Show your reasoning when comparing. Mention standout patterns naturally. '
      'Plain text only — no markdown, no asterisks, no bullet symbols. '
      'For comparisons with 3+ items: output TABLE: on its own line, then header row as Col1|Col2|Col3, then each data row as Val1|Val2|Val3, then END_TABLE on its own line. Put the table BEFORE any explanatory text. Keep tables to 4 columns maximum. '
      'For ranked lists (best/worst/top performers): output as numbered list — "1. SYMBOL - metric" format, one per line. '
      'Never recommend buying, selling, or holding. Never predict prices. '
      'Never fabricate any number not in the data. '
      'If asked for advice: say what the data shows, then add "The decision is yours." '
      'If current prices are unavailable, say so clearly — do not estimate. '
      'Important: complete your response fully. If showing a table, always write END_TABLE before any closing sentence. ';

  Future<String> sendMessage({
    required String userMessage,
    required String portfolioContext,
    required List<ChatMessage> history,
    String memoryContext = '',
  }) async {
    try {
      final modelPath = await ModelDownloadService.getModelPath();
      if (!await ModelDownloadService.modelFileExists()) {
        throw Exception('MODEL_FILE_MISSING: file not found at $modelPath');
      }

      // Get relevant market knowledge for this specific question
      final knowledge = MarketKnowledgeService.relevantSection(userMessage);

      // Build the full answer prompt with budget enforcement
      final prompt = _buildPrompt(
        userMessage: userMessage,
        portfolioContext: portfolioContext,
        history: history,
        memoryContext: memoryContext,
        knowledge: knowledge,
      );

      final String? response = await _channel.invokeMethod('chat', {
        'prompt': prompt,
        'modelPath': modelPath,
      });

      if (response == null || response.trim().isEmpty) {
        return "I didn't get a response. Try again in a moment.";
      }

      return _postProcess(response.trim(), userMessage);
    } on PlatformException catch (e) {
      if (e.code == 'MODEL_MISSING') {
        throw Exception('MODEL_FILE_MISSING: ${e.message}');
      }
      throw Exception('PLATFORM_ERROR: code=${e.code} message=${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  String _buildPrompt({
    required String userMessage,
    required String portfolioContext,
    required List<ChatMessage> history,
    required String memoryContext,
    required String knowledge,
  }) {
    // Start with fixed elements
    final systemBlock = '$_systemPrompt\n\n';
    final portfolioBlock = '$portfolioContext\n\n';
    final userBlock = 'User: $userMessage\nViren:';

    // Fixed budget used
    int usedChars =
        systemBlock.length + portfolioBlock.length + userBlock.length;

    // Add knowledge block if it fits
    String knowledgeBlock = '';
    if (knowledge.isNotEmpty) {
      final candidate = 'Market reference:\n$knowledge\n\n';
      if (usedChars + candidate.length < _maxPromptChars) {
        knowledgeBlock = candidate;
        usedChars += candidate.length;
      }
    }

    // Add memory block if it fits
    String memoryBlock = '';
    if (memoryContext.isNotEmpty) {
      final candidate = '$memoryContext\n\n';
      if (usedChars + candidate.length < _maxPromptChars) {
        memoryBlock = candidate;
        usedChars += candidate.length;
      }
    }

    // Add history — most recent first, trim to fit
    String historyBlock = '';
    final recentHistory = history.length > 4
        ? history.sublist(history.length - 4)
        : history;

    if (recentHistory.isNotEmpty) {
      final historyStr = recentHistory
          .map((m) => '${m.isUser ? "User" : "Viren"}: ${m.text}')
          .join('\n');
      final candidate = 'Recent:\n$historyStr\n\n';
      if (usedChars + candidate.length < _maxPromptChars) {
        historyBlock = candidate;
      }
    }

    final full = systemBlock +
        portfolioBlock +
        knowledgeBlock +
        memoryBlock +
        historyBlock +
        userBlock;

    // Hard safety trim — should not be needed with budget system but just in case
    if (full.length > _maxPromptChars + userBlock.length) {
      return systemBlock + portfolioBlock + userBlock;
    }

    return full;
  }

  /// Post-processes the model response to clean up common issues.
  String _postProcess(String raw, String userMessage) {
    String text = raw;

    // Remove any "User:" or "Viren:" the model might hallucinate
    final conversationPattern = RegExp(r'\n(User|Viren):\s.*$', dotAll: true);
    text = text.replaceAll(conversationPattern, '').trim();

    // Remove repeated question echoing
    final questionWords = userMessage
        .toLowerCase()
        .split(' ')
        .where((w) => w.length > 4)
        .take(3)
        .join('|');
    if (questionWords.isNotEmpty) {
      final firstLine = text.split('\n').first.toLowerCase();
      if (firstLine.contains(RegExp(questionWords, caseSensitive: false)) &&
          firstLine.length < 80) {
        text = text.substring(text.indexOf('\n') + 1).trim();
      }
    }

    // Ensure response ends on a complete sentence
    if (text.length > 50) {
      final lastPunctuation =
          text.lastIndexOf(RegExp(r'[.!?]'));
      if (lastPunctuation > text.length * 0.7) {
        // Only trim if the last sentence ending is in the latter 30% of text
        text = text.substring(0, lastPunctuation + 1).trim();
      }
    }

    return text.isEmpty ? "I couldn't form a complete response. Try rephrasing." : text;
  }
}