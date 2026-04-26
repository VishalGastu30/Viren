import '../../core/ai/groq_service.dart';

enum IntentCategory {
  mathOnly,
  newsNeeded,
  hybrid,
  general
}

class IntentClassifier {

  /// Classifies the user's intent to decide whether we need Tavily news
  /// or if we can just answer using the local portfolio Math Matrix.
  static Future<IntentCategory> classify(String userMessage) async {
    // ── Deterministic keyword fallback (always runs, zero failure) ──────────
    // This catches obvious market/news queries even if the LLM classifier fails.
    final m = userMessage.toLowerCase();
    final newsKeywords = [
      'market', 'sensex', 'nifty', 'bse', 'nse', 'economy', 'rbi',
      'fed', 'inflation', 'gdp', 'crash', 'rally', 'bull', 'bear',
      'why did', 'what happened', 'news', 'today in market',
      'stock market', 'global market', 'us market', 'nasdaq', 's&p',
      'war', 'conflict', 'election', 'global', 'crisis',
    ];
    final mathKeywords = [
      'best', 'worst', 'breakdown', 'charges', 'brokerage', 'compare',
      'p&l', 'return', 'invested', 'holding', 'portfolio',
    ];

    final hasNewsKeyword = newsKeywords.any((k) => m.contains(k));
    final hasMathKeyword = mathKeywords.any((k) => m.contains(k));

    if (hasNewsKeyword && hasMathKeyword) return IntentCategory.hybrid;
    if (hasNewsKeyword && !hasMathKeyword) return IntentCategory.newsNeeded;

    // ── LLM-based classification (enhanced accuracy for ambiguous queries) ──
    try {
      const systemPrompt = '''
You are an intent classifier. Categorize the user's query into EXACTLY ONE of these categories:
MATH_ONLY = asks about portfolio numbers, rankings, performance, charges, P&L, or best/worst performers.
NEWS_NEEDED = asks about market news, why a stock moved, today's events, or forward-looking outlook.
HYBRID = asks for BOTH portfolio performance AND news/outlook.
GENERAL = casual chat, greetings, asking what you can do, explaining financial concepts.

Output a JSON object with a single key "category" containing the chosen label.

Examples:
"Which holding is performing best?" -> {"category": "MATH_ONLY"}
"How did gold perform today?" -> {"category": "NEWS_NEEDED"}
"What is my best performer and its outlook this week?" -> {"category": "HYBRID"}
"What is XIRR?" -> {"category": "GENERAL"}
"Give me a full portfolio breakdown" -> {"category": "MATH_ONLY"}
"Why did nifty fall today?" -> {"category": "NEWS_NEEDED"}
"How did market perform today?" -> {"category": "NEWS_NEEDED"}
"How did sensex perform today?" -> {"category": "NEWS_NEEDED"}
"Is the stock market crashing?" -> {"category": "NEWS_NEEDED"}
"How is ITC doing?" -> {"category": "HYBRID"}
''';

      final prompt = 'User: $userMessage';

      final response = await GroqService.chatJson(
        prompt: prompt,
        model: GroqService.lightModel,
        systemPrompt: systemPrompt,
      );

      if (response == null || !response.containsKey('category')) {
        // Fall back to keyword result if LLM had no output
        return hasMathKeyword ? IntentCategory.mathOnly : IntentCategory.general;
      }

      final label = response['category'].toString().trim().toUpperCase();

      if (label.contains('MATH_ONLY')) return IntentCategory.mathOnly;
      if (label.contains('NEWS_NEEDED')) return IntentCategory.newsNeeded;
      if (label.contains('HYBRID')) return IntentCategory.hybrid;

      return hasMathKeyword ? IntentCategory.mathOnly : IntentCategory.general;
    } catch (e) {
      // LLM classifier failed — deterministic fallback already handled news keywords above
      return hasMathKeyword ? IntentCategory.mathOnly : IntentCategory.general;
    }
  }
}
