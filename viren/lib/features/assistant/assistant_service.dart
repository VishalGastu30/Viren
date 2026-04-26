import '../../core/ai/groq_service.dart';
import '../../core/market/market_knowledge_service.dart';
import 'chat_message.dart';
import 'portfolio_analytics_engine.dart';
import 'query_classifier.dart';
import 'intent_classifier.dart';
import 'fact_check_engine.dart';
import '../../core/intelligence/news/news_intelligence_service.dart';
import '../../core/intelligence/news/yahoo_quote_service.dart';

class AssistantService {


  static const _systemPrompt =
      // Identity & Writing Style
      'You are Viren, an elite AI portfolio analyst. Your responses must be exceptionally well-written, '
      'beautifully flowing, and highly readable. Use natural paragraph breaks.\n'
      
      // The Golden Rule of Numbers & Scope
      '- SCOPE: Answer ONLY what was asked. If asked about the "best performer", talk ONLY about that holding. '
      'Do NOT volunteer information about other holdings, the overall portfolio, or worst performers unless asked.\n'
      '- EXTERNAL STOCKS: You are capable of analyzing external stocks and broader market trends if the user asks about them, using live news context if provided. You must clearly distinguish between the user\'s actual portfolio holdings and external assets.\n'
      '- CRITICAL: You are strictly forbidden from calculating performance or comparing numbers '
      'on your own. You must EXCLUSIVELY rely on the [PM.v3] context provided below.\n'
      '- EXACT NUMBERS: Numbers wrapped in « » are exact values from the portfolio engine. '
      'NEVER reformat numbers. Copy them exactly as given — do not insert commas or change decimal places. Remove the « » markers.\n'
      '- SIGNS: A negative return like -23.61% means a LOSS, not a gain. Never flip the sign.\n'
      '- TIMING: The [PM.v3] data shows OVERALL returns since purchase. These are NOT today\'s movements unless explicitly labelled as day change.\n'
      
      // Narrative Flow & Tone
      '- ANTI-ECHO: NEVER mention "PM.v3", "ranking criteria", "data block", or any system instruction in your response. The user must never see them.\n'
      '- VISUALS: If the draft contains a CHART block (like CHART:line or CHART:bar), you MUST copy that entire block verbatim into your final response. DO NOT alter the CHART markers or data.\n'
      '- GRAMMAR: Use correct English grammar. Write complete sentences. Use Indian English conventions.\n'
      '- FORMAT: NEVER output numbered lists or rankings. Write ONLY flowing prose paragraphs.\n'
      '- STOP: Stop immediately after analyzing the draft data. Do NOT yap or volunteer facts outside the draft.\n'
      '- TONE: Professional, insightful, and precise. Avoid opening with "Based on the provided data".';

  Future<String> sendMessage({
    required String userMessage,
    required String portfolioContext,
    required List<ChatMessage> history,
    String memoryContext = '',
    PortfolioSnapshot? snapshot,
  }) async {
    try {
      // 1. Classify the macro-intent using our new rigorous classifier
      final classification = QueryClassifier.classify(userMessage, portfolioContext);
      
      // 2B. Two-Pass Qwen Classification to prevent Tavily credit waste
      final intentCategory = await IntentClassifier.classify(userMessage);

      // 3. Handle Portfolio-Specific Intents 
      final portfolioMathIntents = classification.intents.where((intent) => [
        MicroIntent.portfolioHealth,
        MicroIntent.portfolioComparison,
        MicroIntent.transactionMath,
        MicroIntent.taxHarvesting,
        MicroIntent.holdingSpecific,
      ].contains(intent)).toSet();

      final engineFallbackIntent = snapshot != null
          ? PortfolioAnalyticsEngine.detectIntent(userMessage, holdings: snapshot.holdings)
          : PortfolioAnalyticsEngine.detectIntent(userMessage);
      
      final needsPortfolioMath = portfolioMathIntents.isNotEmpty || 
          engineFallbackIntent != QuestionIntent.general;
      
      String combinedDraft = '';

      if (needsPortfolioMath) {
        if (portfolioContext.contains('PORTFOLIO:ERROR')) {
          return "I encountered a temporary issue loading your live portfolio data. Please wait a moment and try again.";
        }
        if (_isPortfolioEmpty(portfolioContext)) {
          return "I don't see any active holdings in your portfolio yet. "
              "Once your trades are imported, I can analyse your performance, "
              "returns, charges, and more.";
        }

        if (snapshot != null) {
          // If we have specific intents from the classifier, build them
          List<String> externalSymbols = [];
          if (portfolioMathIntents.isNotEmpty) {
             if (portfolioMathIntents.contains(MicroIntent.portfolioComparison)) {
                try {
                  final microPrompt = '''[SYSTEM]
Extract stock/commodity ticker symbols from this query. Return a valid JSON object with a single key "symbols" containing an array of strings. Use Yahoo Finance NSE symbols (e.g. {"symbols": ["ITC.NS", "GOLDBEES.NS"]}). If unsure, guess the most likely NSE symbol. For commodities, use futures: gold->GC=F, silver->SI=F, copper->HG=F.
[USER]
$userMessage
''';
                  final microResponse = await GroqService.chatJson(
                      prompt: microPrompt,
                      model: GroqService.lightModel,
                  );
                  if (microResponse != null) {
                      // Handle potential variations in JSON output
                      final symbolsList = microResponse['symbols'] ?? microResponse['ticker_symbols'] ?? microResponse.values.firstOrNull;
                      if (symbolsList is List) {
                        externalSymbols = symbolsList.map((e) => e.toString().trim().toUpperCase()).where((e) => e.isNotEmpty).toList();
                      } else if (symbolsList is String) {
                        externalSymbols = symbolsList.split(',').map((e) => e.trim().toUpperCase()).where((e) => e.isNotEmpty).toList();
                      }
                  }
                } catch (_) {}
             }

             for (final intent in portfolioMathIntents) {
                 QuestionIntent? engineIntent;
                 switch(intent) {
                     case MicroIntent.portfolioHealth: engineIntent = QuestionIntent.portfolioSummary; break;
                     case MicroIntent.transactionMath: engineIntent = QuestionIntent.charges; break;
                     case MicroIntent.holdingSpecific: engineIntent = QuestionIntent.specificHolding; break;
                     case MicroIntent.portfolioComparison: engineIntent = QuestionIntent.comparison; break;
                     default: break;
                 }
                 
                 if (engineIntent == null || engineIntent == QuestionIntent.general) {
                     engineIntent = PortfolioAnalyticsEngine.detectIntent(userMessage, holdings: snapshot.holdings);
                 }

                 if (engineIntent != QuestionIntent.general) {
                     final draft = await PortfolioAnalyticsEngine.buildGuidedPrompt(
                         intent: engineIntent,
                         snap: snapshot,
                         userMessage: userMessage,
                         externalSymbols: externalSymbols,
                     );
                     if (draft.isNotEmpty && !combinedDraft.contains(draft)) {
                         if (combinedDraft.isNotEmpty) combinedDraft += '\n\n';
                         combinedDraft += draft;
                     }
                 }
             }
          } 
          
          if (combinedDraft.isEmpty) {
              final specificIntent = PortfolioAnalyticsEngine.detectIntent(
                userMessage,
                holdings: snapshot.holdings,
              );
              if (specificIntent != QuestionIntent.general) {
                final draft = await PortfolioAnalyticsEngine.buildGuidedPrompt(
                  intent: specificIntent,
                  snap: snapshot,
                  userMessage: userMessage,
                );
                if (draft.isNotEmpty) {
                    combinedDraft = draft;
                }
              }
          }
        }
      }

      // 4. Handle Concept Explanations (Internal Knowledge)
      String knowledgeDraft = '';
      if (classification.intents.contains(MicroIntent.conceptExplain)) {
        final knowledge = MarketKnowledgeService.relevantSection(userMessage);
        if (knowledge.isNotEmpty) {
          knowledgeDraft = _compactKnowledge(knowledge);
        }
      }

      // 5. Split dynamic UI blocks (Charts, Tables) from internal math hints
      final (proseDraft, structuredBlocks) = _splitStructuredBlocks(combinedDraft);

      // 6. Pre-flight Live News Fetching
      String liveNewsContext = '';
      bool newsFetchFailed = false;
      String factualPrefix = '';

      // Determine the asset class
      String? newsAssetClass = classification.assetClass;
      
      // Dual-path check: trigger news if EITHER the IntentClassifier OR QueryClassifier says so
      final needsNews = intentCategory == IntentCategory.newsNeeded || 
          intentCategory == IntentCategory.hybrid ||
          classification.intents.contains(MicroIntent.marketNewsMacro) ||
          classification.intents.contains(MicroIntent.marketNewsAsset);
      
      if (needsNews) {
        // If no asset class from QueryClassifier, default to macro_india for broad queries
        if (newsAssetClass == null || newsAssetClass == 'unknown') {
          newsAssetClass = 'macro_india';
        }
        
        if (engineFallbackIntent == QuestionIntent.bestPerformer && snapshot != null) {
          newsAssetClass = QueryClassifier.mapSymbolToAssetClass(snapshot.bestByReturn?.symbol ?? 'nifty');
        } else if (engineFallbackIntent == QuestionIntent.worstPerformer && snapshot != null) {
          newsAssetClass = QueryClassifier.mapSymbolToAssetClass(snapshot.worstByReturn?.symbol ?? 'nifty');
        }

        if (newsAssetClass != 'unknown') {
          try {
            final factCheck = FactCheckEngine.evaluate(userMessage, newsAssetClass, snapshot);
            factualPrefix = factCheck.factualPrefix;
            
            // Fetch Tavily narrative + Yahoo numerical data in parallel
            final newsFuture = NewsIntelligenceService.fetchContext(newsAssetClass, factCheck.neutralQuery);
            final yahooSymbol = YahooQuoteService.mapAssetClassToSymbol(newsAssetClass);
            final quoteFuture = YahooQuoteService.fetchQuote(yahooSymbol);
            
            final results = await Future.wait([newsFuture, quoteFuture]);
            liveNewsContext = results[0] as String;
            final quote = results[1];
            
            // Blend Yahoo numerical data into the news context
            if (quote != null) {
              final q = quote as ({double cmp, double dayChangePct, double dayChangeAbs, String name});
              final sign = q.dayChangePct >= 0 ? '+' : '';
              final yahooBlend = '\n[LIVE MARKET DATA] ${q.name}: ₹${q.cmp.toStringAsFixed(2)} ($sign${q.dayChangePct.toStringAsFixed(2)}%, $sign₹${q.dayChangeAbs.toStringAsFixed(2)} today)';
              liveNewsContext = '$liveNewsContext$yahooBlend';
            }
            
            if (liveNewsContext.trim().isEmpty) newsFetchFailed = true;
          } catch (_) {
            newsFetchFailed = true;
          }
        }
      }

      // Component 1: Conditional Portfolio Context Injection
      final isPureNewsQuery = needsNews && !needsPortfolioMath && combinedDraft.isEmpty;
      
      // Component 9: Graceful Fallback if pure news and ALL news sources failed
      if (isPureNewsQuery && newsFetchFailed && liveNewsContext.isEmpty) {
        return "I don't have access to live market data right now. "
            "For real-time market updates, please check moneycontrol.com or the NSE/BSE websites. "
            "I can still help with your portfolio questions — try asking about your holdings, charges, or returns.";
      }

      // Handle news failure gracefully for portfolio+news hybrid
      if (newsAssetClass != null && newsFetchFailed && liveNewsContext.isEmpty) {
        liveNewsContext = "[CRITICAL INSTRUCTION: Live news fetch failed. You MUST NOT attempt to answer the user's question using old news from the chat history. Apologize and state clearly that you cannot access live internet data right now.]";
      }

      final combinedNewsContext = factualPrefix.isNotEmpty && liveNewsContext.isNotEmpty
          ? '$factualPrefix\n\n$liveNewsContext' 
          : (factualPrefix.isNotEmpty ? factualPrefix : liveNewsContext);

      // The Math Matrix suppression
      final effectivePortfolioContext = isPureNewsQuery ? '' : portfolioContext;

      // 7. Execute the Unified Context Matrix
      final systemPrompt = _buildSystemPrompt(
        portfolioContext: effectivePortfolioContext, // Suppressed for pure news
        memoryContext: memoryContext,
        knowledge: knowledgeDraft,
        newsContext: combinedNewsContext,
        internalMathHint: proseDraft,
      );

      final groqHistory = history.map((m) => {
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.text,
      }).toList();

      return await _callModel(
        userMessage: userMessage, 
        systemPrompt: systemPrompt,
        history: groqHistory,
        structuredBlocks: structuredBlocks, 
        combinedDraft: combinedDraft,
      );
    } catch (e) {
      rethrow;
    }
  }

  bool _isResponseComplete(String text) {
    if (text.trim().isEmpty) return false;
    final hasStructuredBlock = text.contains('TABLE:') ||
        text.contains('CHART:') ||
        text.contains('CARD:') ||
        text.contains('TIMELINE:') ||
        text.contains('WARNING:');
    if (hasStructuredBlock) return true;
    final trimmed = text.trim();
    return trimmed.endsWith('.') || trimmed.endsWith('!') || trimmed.endsWith('?');
  }

  // ── Call the model ────────────────────────────────────────────────────────
  Future<String> _callModel({
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> history,
    List<String> structuredBlocks = const [], 
    String? combinedDraft,
  }) async {
    String fullResponse = '';

    try {
      fullResponse = await GroqService.chat(
        prompt: userMessage,
        systemPrompt: systemPrompt,
        history: history,
        model: GroqService.heavyModel,
      );
    } catch (e) {
      if (combinedDraft != null && combinedDraft.isNotEmpty && e is GroqException && e.isConnectionError) {
        fullResponse = combinedDraft;
      } else {
        rethrow;
      }
    }

    if (fullResponse.trim().isEmpty) {
      if (combinedDraft != null && combinedDraft.isNotEmpty) {
        fullResponse = combinedDraft;
      } else {
        return "I didn't get a response. Try again in a moment.";
      }
    }

    final postProcessed = _postProcess(fullResponse.trim(), userMessage);
    return _reassembleResponse(postProcessed, structuredBlocks);
  }

  // ── Internal Thinking Engine: Split & Reassemble ──────────────────────────

  (String, List<String>) _splitStructuredBlocks(String draft) {
    if (draft.isEmpty) return ('', []);
    
    final blocks = <String>[];
    String prose = draft;

    final markers = ['TABLE', 'CHART:bar', 'CHART:donut', 'CHART:line', 'CARD', 'TIMELINE', 'WARNING'];

    for (final marker in markers) {
      final startTag = marker.contains(':') ? marker : '$marker:';
      final endTag = 'END_${marker.split(':')[0]}';
      
      while (prose.contains(startTag) && prose.contains(endTag)) {
        final startIndex = prose.indexOf(startTag);
        final endIndex = prose.indexOf(endTag) + endTag.length;
        
        if (startIndex < endIndex) {
          blocks.add(prose.substring(startIndex, endIndex));
          prose = prose.replaceRange(startIndex, endIndex, '');
        } else {
          break; // Malformed boundary
        }
      }
    }
    
    return (prose.trim(), blocks);
  }

  String _reassembleResponse(String llmProse, List<String> blocks) {
    if (blocks.isEmpty) return llmProse;
    return '$llmProse\n\n${blocks.join('\n\n')}'.trim();
  }

  // ── Unified System Prompt Builder ──────────────────────────────────────────────
  String _buildSystemPrompt({
    required String portfolioContext,
    required String memoryContext,
    required String knowledge,
    required String newsContext,
    required String internalMathHint,
  }) {
    final systemBlock = '$_systemPrompt\n\n';
    
    // Inject Date/Time & Market State
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final currentDay = days[now.weekday - 1];
    
    final marketStateBlock = '''[CURRENT SYSTEM TIME & MARKET STATE]
Today is $currentDay, ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}.
Note: Indian stock markets are open Mon-Fri, 9:15 AM to 3:30 PM IST. 
If today is Saturday or Sunday, the market is CLOSED and the live market data reflects the LAST trading session.
The market is also CLOSED on the following 2026 holidays:
- Jan 26: Republic Day
- Mar 03: Maha Shivaratri
- Mar 20: Holi
- Apr 03: Good Friday
- Apr 14: Dr. Baba Saheb Ambedkar Jayanti
- Apr 18: Ram Navami
- May 01: Maharashtra Day
- Aug 15: Independence Day
- Sep 15: Ganesh Chaturthi
- Oct 02: Mahatma Gandhi Jayanti
- Oct 19: Dussehra
- Nov 08: Diwali
- Nov 24: Gurunanak Jayanti
- Dec 25: Christmas

''';

    final portfolioBlock = portfolioContext.isNotEmpty ? '$portfolioContext\n\n' : '';
    final mathHintBlock = internalMathHint.isNotEmpty ? '[INTERNAL ALGORITHMIC HINT (USE IF HELPFUL)]\n$internalMathHint\n\n' : '';

    String newsBlock = '';
    if (newsContext.isNotEmpty) {
      newsBlock = '[LIVE MARKET NEWS]\n$newsContext\n\n';
    }

    String knowledgeBlock = '';
    if (knowledge.isNotEmpty) {
      knowledgeBlock = '[MARKET KNOWLEDGE CONTEXT]\n$knowledge\n\n';
    }

    String memoryBlock = '';
    if (memoryContext.isNotEmpty) {
      memoryBlock = '[LONG TERM MEMORY]\n$memoryContext\n\n';
    }

    return systemBlock +
        marketStateBlock +
        portfolioBlock +
        mathHintBlock +
        newsBlock +
        knowledgeBlock +
        memoryBlock;
  }

  // ── Compact knowledge text for drafts ────────────────────────────────────
  String _compactKnowledge(String knowledge) {
    // Remove section headers and condense
    return knowledge
        .replaceAll(RegExp(r'^[A-Z ]+:\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^- ', multiLine: true), '')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }



  // ── Empty portfolio check ─────────────────────────────────────────────────
  bool _isPortfolioEmpty(String portfolioContext) {
    if (portfolioContext.trim().isEmpty) return true;
    // Explicit empty markers
    if (portfolioContext.contains('PORTFOLIO:EMPTY')) return true;
    if (portfolioContext.contains('PORTFOLIO:ERROR')) return true;
    if (portfolioContext.contains('NO_ACTIVE_HOLDINGS')) return true;
    
    // The new Math Matrix format uses these markers
    final hasMatrix = portfolioContext.contains('PORTFOLIO MATH MATRIX');
    final hasRanking = portfolioContext.contains('RANKING:');
    final hasRupeeValue = portfolioContext.contains('₹');
    
    // If it has the matrix header and currency values, it's not empty
    return !(hasMatrix && hasRupeeValue) && !(hasRanking && hasRupeeValue);
  }

  // ── Post-process model output ─────────────────────────────────────────────
  String _postProcess(String raw, String userMessage) {
    String text = raw;

    // Strip role prefixes
    text = text.replaceFirst(RegExp(r'^(Viren|Assistant)\s*:\s*', caseSensitive: false), '').trim();

    // Remove exact number protection markers
    text = text.replaceAll('«', '').replaceAll('»', '');

    // Remove "DRAFT:" prefix if the model echoed it
    text = text.replaceFirst(RegExp(r'^DRAFT:\s*', caseSensitive: false), '');
    
    // Aggressive Cryptic Marker Scrubbing
    text = text.replaceAll('<<<DATA_BLOCK_ALPHA>>>', '');
    text = text.replaceAll('<<<DATA_BLOCK_BETA>>>', '');

    // Strip system prompt leaks
    text = text.replaceAll(RegExp(r'Portfolio Math Matrix', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'Math Matrix', caseSensitive: false), ''); 
    text = text.replaceAll(RegExp(r'\bPM\.v3\b', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'ranking criteria', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'provided (raw )?data', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'the (absolute )?authority', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'adhere to these findings', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'without any deviation', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'data block', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'\bthe system\b', caseSensitive: false), '');

    // Fix Indian number formatting (remove LLM-inserted commas)
    // "₹100,95.40" → "₹10095.40"
    text = text.replaceAllMapped(
      RegExp(r'₹(\d{1,3}),(\d{2}\.\d{2})'), 
      (m) => '₹${m[1]}${m[2]}'
    );
    // Also "100,95.40%" → "10095.40%"
    text = text.replaceAllMapped(
      RegExp(r'(\d{1,3}),(\d{2}\.\d{2})%'), 
      (m) => '${m[1]}${m[2]}%'
    );

    // Fix sign confusion in output: "gained -23%" → "lost 23%"  
    text = text.replaceAllMapped(
      RegExp(r'gain(ed|s|ing)?\s+(of\s+)?-'), 
      (m) => 'lost '
    );

    // PHASE 3D/3F: Anti-Hallucination Fortress
    text = text.replaceAll(RegExp(r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]'), ''); // Chinese/Japanese/Korean
    text = text.replaceAll(RegExp(r'\([^)]*(just now|ago|AI Summary)[^)]*\)', caseSensitive: false), ''); // Attribution tags
    text = text.replaceAll(' USD', ' INR').replaceAll('\$', '₹'); // USD to INR bailout

    // Aggressive Hallucination Truncation
    final hwPattern = RegExp(
        r'(I\s+apologize|I\s+don\x27t\s+have|I\s+cannot\s+provide|Please\s+note\s+that\s+I\s+am|As\s+an\s+AI)[^\n]*',
        caseSensitive: false);
    final hwMatch = hwPattern.firstMatch(text);
    if (hwMatch != null) {
      final idx = hwMatch.start;
      if (idx > 0) {
        text = text.substring(0, idx).trim();
      } else {
        text = "Here is the analysis based on your portfolio data.";
      }
    }

    // Deduplicate consecutive paragraphs (Phase 3F)
    final paras = text.split('\n\n');
    if (paras.length > 1) {
      final List<String> uniqueParas = [paras.first];
      for (int i = 1; i < paras.length; i++) {
        // Very simple dedup: if paragraph strictly contains the previous paragraph or vice versa, skip
        if (!uniqueParas.last.contains(paras[i]) && !paras[i].contains(uniqueParas.last) && paras[i].trim().isNotEmpty) {
           uniqueParas.add(paras[i]);
        }
      }
      text = uniqueParas.join('\n\n');
    }

    // Voice spec: remove weak filler openings
    final weakOpenings = [
      RegExp(r'^Based on [^,.\n]+[,.]?\s*', caseSensitive: false),
      RegExp(r'^Looking at [^,.\n]+[,.]?\s*', caseSensitive: false),
      RegExp(r'^It (appears|seems|looks) (like|that)\s*', caseSensitive: false),
      RegExp(r'^As (per|mentioned|noted|stated)\s*', caseSensitive: false),
      RegExp(r'^Please note (that)?\s*', caseSensitive: false),
      RegExp(r'^I (can see|can note|can tell|would say|notice)\s*', caseSensitive: false),
    ];
    for (final pattern in weakOpenings) {
      if (pattern.hasMatch(text)) {
        text = text.replaceFirst(pattern, '').trim();
        // Capitalize new first character
        if (text.isNotEmpty) {
          text = text[0].toUpperCase() + text.substring(1);
        }
      }
    }

    // Voice spec: strip hype language
    text = text
        .replaceAll(RegExp(r'\b(amazing|excellent|great|fantastic|incredible|wonderful)\b',
            caseSensitive: false), 'significant')
        .replaceAll(RegExp(r'\b(looks promising|quite bullish|very bullish)\b',
            caseSensitive: false), 'trending upward')
        .replaceAll(RegExp(r'\bbleeding\b', caseSensitive: false), 'declining')
        .replaceAll(RegExp(r'\bbooming\b', caseSensitive: false), 'rising');

    // Voice spec: ensure INR not USD
    text = text
        .replaceAll(RegExp(r'\$(\d)'), r'₹$1')
        .replaceAll(RegExp(r'USD\s*(\d)'), r'₹$1');

    // Safe echo removal
    final firstLine = text.split('\n').first.trim();
    if (_isEchoLine(firstLine, userMessage)) {
      final newlineIdx = text.indexOf('\n');
      if (newlineIdx != -1) {
        text = text.substring(newlineIdx + 1).trim();
      } else {
        text = '';
      }
    }

    // Remove knowledge block parroting — Qwen sometimes opens by repeating
    // the "Context:" section verbatim before giving the actual answer.
    // Detect and strip if first 2 lines are pure knowledge echoing.
    final lines = text.split('\n');
    if (lines.length > 2) {
      final knowledgeEchoPatterns = [
        'mechanics:', 'drives ', 'impact:', 'context:',
        'foreign institutional investors drive',
        'gold rises in crises',
        'silver: 70%',
      ];
      final firstLineLower = lines.first.toLowerCase();
      if (knowledgeEchoPatterns.any((p) => firstLineLower.contains(p))) {
        // Skip the echo line and start from the second line
        text = lines.skip(1).join('\n').trim();
      }
    }

    text = text.replaceFirst(RegExp(r'^(Viren|Assistant)\s*:\s*', caseSensitive: false), '').trim();

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