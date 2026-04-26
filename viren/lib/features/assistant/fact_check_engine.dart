import 'portfolio_analytics_engine.dart';

class FactCheckResult {
  final String neutralQuery;
  final String factualPrefix;

  const FactCheckResult(this.neutralQuery, this.factualPrefix);
}

class FactCheckEngine {
  /// Analyzes the user's query and the portfolio snapshot to extract the undeniable truth.
  /// Returns a FactCheckResult containing the corrected neutral query for Tavily
  /// and the factual string to inject into the LLM draft.
  static FactCheckResult evaluate(
      String userMessage, String assetClass, PortfolioSnapshot? snapshot) {
    // 1. Determine Neutral Query base
    // Default to userMessage to preserve specific intents (e.g., Iran-US war).
    String neutralQuery = userMessage;

    // 2. Determine Day Change Direction from Portfolio
    double? dayChange;
    if (snapshot != null) {
      if (assetClass == 'gold') {
        dayChange = snapshot.holdings
            .where((h) => h.symbol.contains('GOLD'))
            .firstOrNull
            ?.dayChangePercent;
      } else if (assetClass == 'nifty') {
        dayChange = snapshot.holdings
            .where((h) => h.symbol.contains('NIFTY'))
            .firstOrNull
            ?.dayChangePercent;
      } else if (assetClass == 'banking') {
        dayChange = snapshot.holdings
            .where((h) => [
                  'YESBANK',
                  'HDFCBANK',
                  'ICICIBANK',
                  'KOTAKBANK',
                  'SBIN',
                  'AXISBANK'
                ].contains(h.symbol))
            .firstOrNull
            ?.dayChangePercent;
      }
    }

    String factualPrefix = '';
    final m = userMessage.toLowerCase();

    if (dayChange != null && dayChange.abs() > 0.05) {
      bool userSaidDrop = ['drop', 'fell', 'fall', 'crash', 'down', 'loss']
          .any((w) => m.contains(w));
      bool userSaidRise = ['rise', 'rose', 'up', 'gain', 'jump', 'rally']
          .any((w) => m.contains(w));

      bool actuallyDropped = dayChange < -0.1;
      bool actuallyRose = dayChange > 0.1;

      if (userSaidDrop && actuallyRose) {
        // User is wrong — rewrite query to neutral/positive and inject correction
        neutralQuery = '$assetClass price rose today market reasons India';
        factualPrefix =
            'FACT CHECK: The user stated the price dropped, but $assetClass is actually UP by ${dayChange.toStringAsFixed(2)}% today. Correct the user politely and explain why it is rising.';
      } else if (userSaidRise && actuallyDropped) {
        // User is wrong — rewrite query to neutral/negative and inject correction
        neutralQuery = '$assetClass price dropped today market reasons India';
        factualPrefix =
            'FACT CHECK: The user stated the price rose, but $assetClass is actually DOWN by ${dayChange.toStringAsFixed(2)}% today. Correct the user politely and explain why it is falling.';
      } else if (actuallyDropped) {
        neutralQuery = '$assetClass price dropped today market reasons India';
        factualPrefix =
            'FACT: $assetClass is currently DOWN by ${dayChange.toStringAsFixed(2)}% today.';
      } else if (actuallyRose) {
        neutralQuery = '$assetClass price rose today market reasons India';
        factualPrefix =
            'FACT: $assetClass is currently UP by ${dayChange.toStringAsFixed(2)}% today.';
      }
    } else {
      // If no day change found, look closely at the query
      if (['drop', 'fell', 'crash', 'down'].any((w) => m.contains(w))) {
        neutralQuery = '$assetClass price dropped today market reasons India';
      } else if (['rise', 'rose', 'gain', 'up', 'rally'].any((w) => m.contains(w))) {
        neutralQuery = '$assetClass price rose today market reasons India';
      }
    }

    return FactCheckResult(neutralQuery, factualPrefix);
  }

  static String _getNeutralQuery(String assetClass) {
    switch (assetClass) {
      case 'gold':
        return 'gold price movement today India reasons';
      case 'silver':
        return 'silver price movement today India reasons';
      case 'nifty':
        return 'Nifty 50 market movement today reasons India';
      case 'banking':
        return 'Indian banking sector RBI news today';
      case 'us_markets':
        return 'US stock market S&P 500 movement today reasons';
      case 'macro_india':
        return 'India economy macro news today RBI inflation';
      default:
        return 'Indian stock market news today macro';
    }
  }
}
