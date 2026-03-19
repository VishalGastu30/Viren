import '../database/app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AskVirenLauncher — Composes the context-aware prompt for the assistant.
//
// When the user taps "Ask Viren" on an insight card, this builds a prompt
// that includes:
//  1. The specific insight (what Viren noticed)
//  2. The affected holding and its position details
//  3. An open-ended invitation for the user's question
//
// The resulting string is passed to AssistantScreen as initialMessage.
// ─────────────────────────────────────────────────────────────────────────────

class AskVirenLauncher {
  /// Builds a pre-filled prompt string from an insight card.
  static String buildPrompt({
    required Alert alert,
    List<Holding> holdings = const [],
  }) {
    final holdingLine = _buildHoldingContext(alert, holdings);
    final insightType = _humanReadableType(alert.alertType);

    final buffer = StringBuffer();
    buffer.writeln('Viren flagged a $insightType for me:');
    buffer.writeln();
    buffer.writeln('"${alert.title}"');
    buffer.writeln();
    buffer.writeln('Details: ${alert.description}');
    if (holdingLine.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('My position: $holdingLine');
    }
    buffer.writeln();
    buffer.writeln('What should I think about here?');

    return buffer.toString();
  }

  static String _buildHoldingContext(
      Alert alert, List<Holding> holdings) {
    if (alert.relatedInstrument == null) return '';
    final symbol = alert.relatedInstrument!.toUpperCase();
    final holding = holdings
        .cast<Holding?>()
        .firstWhere(
            (h) => h!.instrumentSymbol.toUpperCase() == symbol,
            orElse: () => null);
    if (holding == null) return symbol;

    return '$symbol — avg cost ₹${holding.averagePrice.toStringAsFixed(2)}, '
        '${holding.totalQuantity.toStringAsFixed(0)} units, '
        'invested ₹${holding.investedValue.toStringAsFixed(0)}';
  }

  static String _humanReadableType(String alertType) {
    switch (alertType) {
      case 'DRAWDOWN_ALERT':       return 'drawdown alert';
      case 'RECOVERY_ALERT':       return 'recovery signal';
      case 'CIRCUIT_BREAKER':      return 'large price move';
      case 'NEWS_RELEVANT':        return 'news signal';
      case 'MACRO_EVENT':          return 'macro event';
      case 'DCA_OPPORTUNITY':      return 'DCA opportunity';
      case 'CONCENTRATION_DRIFT':  return 'concentration risk signal';
      case 'BEHAVIOUR_WARNING':    return 'behavioural pattern';
      case 'CONSISTENCY_STREAK':   return 'streak insight';
      case 'ACCUMULATION_PATTERN': return 'accumulation pattern';
      case 'INACTIVITY_ALERT':     return 'inactivity reminder';
      case 'PORTFOLIO_MILESTONE':  return 'milestone';
      default:                     return 'insight';
    }
  }
}
