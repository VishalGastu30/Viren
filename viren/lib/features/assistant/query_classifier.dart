// QueryClassifier — Rigorous micro-intent classification for exact routing.

enum MicroIntent {
  /// General portfolio health, summary, breakdowns (No news)
  portfolioHealth,
  
  /// Inquiring about a specific stock's performance (No news unless context asks for it)
  holdingSpecific,
  
  /// Brokerage, STT, charges, number of units, math calculations (No news)
  transactionMath,
  
  /// Market news regarding a specific asset like Gold, banking, etc. (Fetch News)
  marketNewsAsset,
  
  /// Broad macroeconomic news, outlooks, RBI (Fetch Macro News)
  marketNewsMacro,
  
  /// Questions about LTCG, STCG, harvesting (Internal logic)
  taxHarvesting,
  
  /// Explaining financial concepts like P/E, Risk-off (Fetch Knowledge)
  conceptExplain,
  
  /// Asking which is better, comparing two or more assets (Internal logic + chart output)
  portfolioComparison,
  
  /// Follow up on previous message
  followUp,
  
  /// Unknown/General chatting
  general,
}

class QueryClassification {
  final Set<MicroIntent> intents;
  final String? assetClass; // E.g., 'gold', 'banking', 'macro_india'
  final String? specificHolding; // E.g., 'RELIANCE', 'GOLDBEES'

  QueryClassification({
    required this.intents,
    this.assetClass,
    this.specificHolding,
  });
}

class QueryClassifier {
  /// Categorises user queries into specific MicroIntents to guarantee exact routing.
  static QueryClassification classify(String message, String portfolioContext) {
    final m = message.toLowerCase();
    final intents = <MicroIntent>{};
    String? assetClass;
    String? specificHolding;

    // 1. Transaction Math (Highest priority — absolutely no news)
    final mathPatterns = [
      'brokerage', 'charges', 'stt', 'gst', 'fee', 'how much did i pay',
      'total invested', 'how many units', 'average cost', 'cost basis',
    ];
    if (mathPatterns.any((p) => m.contains(p))) {
      intents.add(MicroIntent.transactionMath);
    }

    // 2. Portfolio Health / Overview
    final healthPatterns = [
      'granular breakdown', 'breakdown', 'summary', 'overview', 'how is my portfolio',
      'total p&l', 'total profit', 'total loss', 'xirr', 'performance of my portfolio',
    ];
    if (healthPatterns.any((p) => m.contains(p))) {
      intents.add(MicroIntent.portfolioHealth);
    }

    // 3. Portfolio Comparison
    final comparePatterns = [
      'compare', 'vs', 'versus', 'better than', 'worse than',
    ];
    if (comparePatterns.any((p) => m.contains(p))) {
      intents.add(MicroIntent.portfolioComparison);
    }
    
    // 4. Tax Harvesting
    final taxPatterns = [
      'tax', 'stcg', 'ltcg', 'harvest', 'loss harvesting', 'capital gain',
    ];
    if (taxPatterns.any((p) => m.contains(p))) {
      intents.add(MicroIntent.taxHarvesting);
    }

    // 5. Concept Explain
    final conceptPatterns = [
      'explain', 'what is', 'what does', 'meaning of', 'define',
      'risk on', 'risk off', 'p/e', 'xirr', 'cagr',
    ];
    // "What is my" usually implies portfolio health, not concept explain
    if (conceptPatterns.any((p) => m.contains(p)) && !m.contains('what is my')) {
      intents.add(MicroIntent.conceptExplain);
    }

    // 6. Specific Holding (Is the user asking about a specific stock they own?)
    final portfolioSymbols = RegExp(r'([A-Z0-9]+):')
        .allMatches(portfolioContext)
        .map((match) => match.group(1)!)
        .toList();
        
    for (final sym in portfolioSymbols) {
      if (m.contains(sym.toLowerCase())) {
        specificHolding = sym;
        // Did they also ask for news about this specific holding?
        final newsKeywords = ['why', 'news', 'dropped', 'fell', 'rising', 'what happened', 'today', 'reason', 'go up'];
        if (newsKeywords.any((kw) => m.contains(kw))) {
           assetClass = mapSymbolToAssetClass(sym);
           intents.add(MicroIntent.marketNewsAsset);
        }
        intents.add(MicroIntent.holdingSpecific);
        break;
      }
    }

    // 7. Parse Asset Class (but do NOT add news intents here, IntentClassifier handles that)
    if (assetClass == null) {
      if (m.contains('gold') || m.contains('goldbees') || m.contains('yellow metal')) {
        assetClass = 'gold';
      } else if (m.contains('silver') || m.contains('silverietf')) {
        assetClass = 'silver';
      } else if (m.contains('nifty') || m.contains('niftybees') || m.contains('sensex')) {
        assetClass = 'nifty';
      } else if (m.contains('yesbank') || m.contains('yes bank') || m.contains('banking') || m.contains('bank nifty')) {
        assetClass = 'banking';
      } else if (m.contains('fed') || m.contains('dollar') || m.contains('us market') || m.contains('nasdaq') || m.contains('s&p')) {
        assetClass = 'us_markets';
      } else if (m.contains('market') || m.contains('economy') || m.contains('rbi') || m.contains('budget')) {
        assetClass = 'macro_india';
      }
    }

    // 8. Broad market news detection — if asset class is macro and no specific holding
    if (assetClass != null && specificHolding == null) {
      final broadNewsKeywords = ['how did', 'how is', 'perform', 'crash', 'rally', 'today', 'news', 'what happened', 'why'];
      if (broadNewsKeywords.any((k) => m.contains(k))) {
        intents.add(MicroIntent.marketNewsMacro);
      }
    }

    // Default
    if (intents.isEmpty) {
      intents.add(MicroIntent.general);
    }

    return QueryClassification(
      intents: intents,
      assetClass: assetClass,
      specificHolding: specificHolding,
    );
  }

  static String mapSymbolToAssetClass(String symbol) {
    switch (symbol) {
      case 'GOLDBEES':
      case 'SETFGOLD': return 'gold';
      case 'SILVERIETF':
      case 'SILVERBEES': return 'silver';
      case 'NIFTYBEES': return 'nifty';
      case 'YESBANK':
      case 'HDFCBANK':
      case 'ICICIBANK':
      case 'KOTAKBANK':
      case 'SBIN':
      case 'AXISBANK': return 'banking';
      default: return 'nifty'; // Default broad market for others
    }
  }
}
