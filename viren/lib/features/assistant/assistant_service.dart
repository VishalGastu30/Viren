import 'package:flutter/services.dart';
import '../../core/ai/model_download_service.dart';
import '../../core/market/market_knowledge_service.dart';
import 'chat_message.dart';
import 'portfolio_analytics_engine.dart';

class AssistantService {
  static const _channel = MethodChannel('com.viren.viren/pdf_crypto');

  // ── Token budget (1 token ≈ 4 chars) ────────────────────────────────────
  // Context window: 1280 tokens. Reserve 1024 for response.
  // ~256 tokens = ~3200 chars for prompt.
  static const _maxPromptChars = 3200;

  // ── System prompt — tight, voice-defining ───────────────────────────────
  // Kept very short to preserve token budget for the guided data prompt.
  static const _systemPrompt =
      'You are Viren, a calm and precise portfolio analyst for an Indian retail investor. '
      'You have been given pre-verified data. Trust it completely — never recalculate or question it. '
      'Your response style: direct answer first, then key numbers, then brief context. '
      'Always start with the conclusion. Never start with "I" or "Sure" or "Great". '
      'Plain text only — no markdown, no asterisks, no bullet symbols, no backticks. '
      'Numbers must come from the verified data only — never invent or estimate. '
      'If showing a table use TABLE: format with END_TABLE. '
      'Be concise — 3 to 6 sentences maximum for most answers. '
      'Never recommend buying, selling, or holding. Never predict prices. '
      'CRITICAL: Never start your response with "Viren:" or your own name. ';

  Future<String> sendMessage({
    required String userMessage,
    required String portfolioContext,
    required List<ChatMessage> history,
    String memoryContext = '',
    PortfolioSnapshot? snapshot, // pre-built snapshot passed from screen
  }) async {
    try {
      final modelPath = await ModelDownloadService.getModelPath();
      if (!await ModelDownloadService.modelFileExists()) {
        throw Exception('MODEL_FILE_MISSING: file not found at $modelPath');
      }

      // ── Detect intent ──────────────────────────────────────────────────
      final intent = PortfolioAnalyticsEngine.detectIntent(userMessage);

      // ── Handle "what can you do" without needing portfolio data ────────
      if (intent == QuestionIntent.whatCanYouDo) {
        final prompt = _buildGuidedPromptOnly(
          PortfolioAnalyticsEngine.buildGuidedPrompt(
            intent: intent,
            snap: snapshot ?? _emptySnapshot(),
            userMessage: userMessage,
          ),
        );
        return _callModel(prompt, userMessage);
      }

      // ── Empty portfolio guard ──────────────────────────────────────────
      // Only fires for portfolio-specific questions, not general ones
      final isPortfolioQuestion = intent != QuestionIntent.general;
      if (isPortfolioQuestion && _isPortfolioEmpty(portfolioContext)) {
        return "I don't see any holdings in your portfolio yet. "
            "Once your trades are imported, I can analyse your performance, "
            "returns, charges, and a lot more.";
      }

      // ── Build prompt based on intent ───────────────────────────────────
      String prompt;

      if (intent != QuestionIntent.general && snapshot != null) {
        // Analytics path — Flutter pre-calculated, model just narrates
        final guidedPrompt = PortfolioAnalyticsEngine.buildGuidedPrompt(
          intent: intent,
          snap: snapshot,
          userMessage: userMessage,
        );

        if (guidedPrompt.isNotEmpty) {
          prompt = _buildGuidedPromptOnly(guidedPrompt);
        } else {
          // Fallback to normal path
          prompt = _buildNormalPrompt(
            userMessage: userMessage,
            portfolioContext: portfolioContext,
            history: _sanitiseHistory(history),
            memoryContext: memoryContext,
            knowledge: MarketKnowledgeService.relevantSection(userMessage),
          );
        }
      } else {
        // General question — normal prompt with full context
        prompt = _buildNormalPrompt(
          userMessage: userMessage,
          portfolioContext: portfolioContext,
          history: _sanitiseHistory(history),
          memoryContext: memoryContext,
          knowledge: MarketKnowledgeService.relevantSection(userMessage),
        );
      }

      return _callModel(prompt, userMessage);
    } on PlatformException catch (e) {
      if (e.code == 'MODEL_MISSING') {
        throw Exception('MODEL_FILE_MISSING: ${e.message}');
      }
      throw Exception('PLATFORM_ERROR: code=${e.code} message=${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  // ── Call the model ────────────────────────────────────────────────────────
  Future<String> _callModel(String prompt, String userMessage) async {
    final modelPath = await ModelDownloadService.getModelPath();
    final String? response = await _channel.invokeMethod('chat', {
      'prompt': prompt,
      'modelPath': modelPath,
    });

    if (response == null || response.trim().isEmpty) {
      return "I didn't get a response. Try again in a moment.";
    }

    return _postProcess(response.trim(), userMessage);
  }

  // ── Guided prompt — system + guided data only, no history ────────────────
  // Used for portfolio-specific questions where the answer is pre-computed.
  // No history needed — the guided data IS the context.
  String _buildGuidedPromptOnly(String guidedPrompt) {
    final full = '$_systemPrompt\n\n$guidedPrompt\n\nAssistant:';
    // Hard trim if needed
    if (full.length > _maxPromptChars + 200) {
      return '$_systemPrompt\n\n${guidedPrompt.substring(0, _maxPromptChars - _systemPrompt.length - 50)}\n\nAssistant:';
    }
    return full;
  }

  // ── Normal prompt — for general questions ────────────────────────────────
  String _buildNormalPrompt({
    required String userMessage,
    required String portfolioContext,
    required List<ChatMessage> history,
    required String memoryContext,
    required String knowledge,
  }) {
    final systemBlock = '$_systemPrompt\n\n';
    final portfolioBlock = '$portfolioContext\n\n';
    final userBlock = 'User: $userMessage\nAssistant:';

    int usedChars =
        systemBlock.length + portfolioBlock.length + userBlock.length;

    String knowledgeBlock = '';
    if (knowledge.isNotEmpty) {
      final candidate = 'Market reference:\n$knowledge\n\n';
      if (usedChars + candidate.length < _maxPromptChars) {
        knowledgeBlock = candidate;
        usedChars += candidate.length;
      }
    }

    String memoryBlock = '';
    if (memoryContext.isNotEmpty) {
      final candidate = '$memoryContext\n\n';
      if (usedChars + candidate.length < _maxPromptChars) {
        memoryBlock = candidate;
        usedChars += candidate.length;
      }
    }

    String historyBlock = '';
    final recentHistory =
        history.length > 4 ? history.sublist(history.length - 4) : history;
    if (recentHistory.isNotEmpty) {
      final historyStr = recentHistory
          .map((m) => '${m.isUser ? "User" : "Assistant"}: ${m.text}')
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

    if (full.length > _maxPromptChars + userBlock.length) {
      return systemBlock + portfolioBlock + userBlock;
    }

    return full;
  }

  // ── Empty portfolio check ─────────────────────────────────────────────────
  bool _isPortfolioEmpty(String portfolioContext) {
    if (portfolioContext.trim().isEmpty) return true;
    final lower = portfolioContext.toLowerCase();
    final hasHoldingSection =
        lower.contains('symbol') || lower.contains('holding');
    final hasRupeeValue = portfolioContext.contains('₹');
    final hasSymbol = RegExp(r'\b[A-Z]{2,10}\b').hasMatch(portfolioContext);
    return !(hasHoldingSection && hasRupeeValue && hasSymbol);
  }

  // ── Empty snapshot for when no DB access needed ───────────────────────────
  PortfolioSnapshot _emptySnapshot() => const PortfolioSnapshot(
        holdings: [],
        totalInvested: 0,
        totalCurrentValue: 0,
        totalPnL: 0,
        totalReturnPct: 0,
        totalCharges: 0,
        totalTrades: 0,
        firstTradeDate: 'N/A',
        hasPriceData: false,
        today: '',
        profitableCount: 0,
        xirr: null,
        trades: [],
      );

  // ── Sanitise history ──────────────────────────────────────────────────────
  List<ChatMessage> _sanitiseHistory(List<ChatMessage> history) {
    return history.where((m) {
      if (!m.isUser) {
        final text = m.text.trim();
        if (text.isEmpty) return false;
        final endsCleanly = text.endsWith('.') ||
            text.endsWith('!') ||
            text.endsWith('?') ||
            text.endsWith('END_TABLE') ||
            text.endsWith('yours.');
        if (!endsCleanly && text.length < 120) return false;
      }
      return true;
    }).map((m) {
      if (m.isUser) return m;
      return ChatMessage(
        text: _stripRolePrefix(m.text),
        isUser: false,
        timestamp: m.timestamp,
      );
    }).toList();
  }

  String _stripRolePrefix(String text) {
    String result = text.trim();
    final prefixPattern =
        RegExp(r'^(Viren|Assistant)\s*:\s*', caseSensitive: false);
    while (prefixPattern.hasMatch(result)) {
      result = result.replaceFirst(prefixPattern, '').trim();
    }
    return result;
  }

  // ── Post-process model output ─────────────────────────────────────────────
  String _postProcess(String raw, String userMessage) {
    String text = raw;

    // Strip role prefixes
    text = _stripRolePrefix(text);

    // Remove hallucinated conversation continuations
    final conversationPattern =
        RegExp(r'\n(User|Viren|Assistant)\s*:.*$', dotAll: true);
    text = text.replaceAll(conversationPattern, '').trim();
    text = _stripRolePrefix(text);

    // Strip markdown bold/italic using replaceAllMapped (Dart-safe)
    text = text.replaceAllMapped(
        RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '');
    text = text.replaceAllMapped(
        RegExp(r'\*(.+?)\*'), (m) => m.group(1) ?? '');
    // Also strip any literal $1 artifacts from previous bad builds
    text = text.replaceAll(r'$1', '');

    // Safe echo removal — only strip if line has no financial data
    final firstLine = text.split('\n').first.trim();
    if (_isEchoLine(firstLine, userMessage)) {
      final newlineIdx = text.indexOf('\n');
      if (newlineIdx != -1) {
        text = text.substring(newlineIdx + 1).trim();
      } else {
        text = '';
      }
    }

    // Safe sentence trim — only for non-table responses
    final trimmed = text.trim();
    final hasTable =
        trimmed.contains('TABLE:') || trimmed.contains('END_TABLE');
    if (!hasTable && trimmed.length > 80) {
      final lastPunctuation = trimmed.lastIndexOf(RegExp(r'[.!?]'));
      if (lastPunctuation > trimmed.length * 0.75) {
        text = trimmed.substring(0, lastPunctuation + 1).trim();
      }
    }

    text = _stripRolePrefix(text).trim();

    return text.isEmpty
        ? "I couldn't form a complete response. Try rephrasing."
        : text;
  }

  bool _isEchoLine(String line, String userMessage) {
    if (line.length > 120) return false;
    if (RegExp(r'[₹\d%]').hasMatch(line)) return false;
    final questionWords = userMessage
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
    if (questionWords.isEmpty) return false;
    final lineWords = line.toLowerCase().split(RegExp(r'\s+'));
    final overlap = questionWords
        .where((w) => lineWords.any((l) => l.contains(w)))
        .length;
    return overlap / questionWords.length > 0.6;
  }
}