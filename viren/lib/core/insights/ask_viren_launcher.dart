import '../database/app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AskVirenLauncher — Composes the context-aware prompt for the assistant.
//
// When the user taps "Ask Viren" on an insight card, this builds a prompt
// that includes:
//  1. The specific insight (what Viren noticed)
//  2. The affected holding and its position details (with live prices)
//  3. A specific, context-aware question based on the alert type
//
// The resulting string is passed to AssistantScreen as initialMessage.
// ─────────────────────────────────────────────────────────────────────────────

class AskVirenLauncher {
  /// Builds a pre-filled prompt string from an insight card.
  static String buildPrompt({
    required Alert alert,
    List<Holding> holdings = const [],
    Map<String, double> currentPrices = const {},
  }) {
    final holdingContext = _buildFullHoldingContext(alert, holdings, currentPrices);
    final insightType = _humanReadableType(alert.alertType);
    final specificQuestion = _specificQuestion(alert, holdings, currentPrices);

    final buffer = StringBuffer();
    buffer.writeln('Viren flagged a $insightType for me:');
    buffer.writeln();
    buffer.writeln('"${alert.title}"');
    buffer.writeln();
    buffer.writeln('Details: ${alert.description}');

    if (holdingContext.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('My position:');
      buffer.writeln(holdingContext);
    }

    buffer.writeln();
    buffer.writeln(specificQuestion);

    return buffer.toString();
  }

  static String _buildFullHoldingContext(
    Alert alert,
    List<Holding> holdings,
    Map<String, double> currentPrices,
  ) {
    if (alert.relatedInstrument == null) {
      // Portfolio-level alert — summarise all holdings
      if (holdings.isEmpty) return '';
      return holdings.map((h) {
        final cmp = currentPrices[h.instrumentSymbol.toUpperCase()];
        final currentValue = cmp != null ? cmp * h.totalQuantity : null;
        final pnl = currentValue != null
            ? currentValue - h.investedValue
            : null;
        final pnlStr = pnl != null
            ? ' | P&L ${pnl >= 0 ? '+' : ''}₹${pnl.toStringAsFixed(0)}'
            : '';
        return '${h.instrumentSymbol}: ${h.totalQuantity.toStringAsFixed(0)} units '
            '@ avg ₹${h.averagePrice.toStringAsFixed(2)}'
            '${cmp != null ? ' | CMP ₹${cmp.toStringAsFixed(2)}' : ''}$pnlStr';
      }).join('\n');
    }

    final symbol = alert.relatedInstrument!.toUpperCase();
    final holding = holdings
        .cast<Holding?>()
        .firstWhere(
            (h) => h!.instrumentSymbol.toUpperCase() == symbol,
            orElse: () => null);

    if (holding == null) return symbol;

    final cmp = currentPrices[symbol];
    final investedValue = holding.investedValue;
    final currentValue = cmp != null ? cmp * holding.totalQuantity : null;
    final pnl = currentValue != null ? currentValue - investedValue : null;
    final pnlPct = pnl != null && investedValue > 0
        ? (pnl / investedValue) * 100
        : null;
    final daysHeld = DateTime.now()
        .difference(holding.lastUpdated)
        .inDays;

    final lines = <String>[
      '$symbol: ${holding.totalQuantity.toStringAsFixed(0)} units',
      'Avg cost: ₹${holding.averagePrice.toStringAsFixed(2)}',
      if (cmp != null) 'Current price: ₹${cmp.toStringAsFixed(2)}',
      'Total invested: ₹${investedValue.toStringAsFixed(0)}',
      if (currentValue != null)
        'Current value: ₹${currentValue.toStringAsFixed(0)}',
      if (pnl != null && pnlPct != null)
        'Unrealised P&L: ${pnl >= 0 ? '+' : ''}₹${pnl.toStringAsFixed(0)} '
        '(${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(1)}%)',
      'Days held: $daysHeld days',
    ];

    return lines.join(' | ');
  }

  /// Returns a specific, context-aware question based on the alert type.
  /// This replaces the generic "What should I think about here?"
  static String _specificQuestion(
    Alert alert,
    List<Holding> holdings,
    Map<String, double> currentPrices,
  ) {
    final symbol = alert.relatedInstrument ?? 'my portfolio';
    final holding = alert.relatedInstrument != null
        ? holdings.cast<Holding?>().firstWhere(
              (h) => h!.instrumentSymbol.toUpperCase() ==
                  alert.relatedInstrument!.toUpperCase(),
              orElse: () => null)
        : null;
    final cmp = alert.relatedInstrument != null
        ? currentPrices[alert.relatedInstrument!.toUpperCase()]
        : null;

    switch (alert.alertType) {
      case 'DRAWDOWN_ALERT':
        return 'Given that $symbol is in drawdown — should I consider adding more '
            'at the current price of ${cmp != null ? '₹${cmp.toStringAsFixed(2)}' : 'this level'}, '
            'or is this a signal to review my position? '
            'What would a disciplined investor do here?';

      case 'RECOVERY_ALERT':
        return '$symbol is recovering toward my avg cost. '
            'What does this recovery tell me about the stock\'s strength? '
            'Is this a good time to hold, add, or review?';

      case 'CIRCUIT_BREAKER':
        return '$symbol just made a large move. What could be driving this? '
            'Should I be doing anything with my ${holding != null ? '${holding.totalQuantity.toStringAsFixed(0)} units' : 'position'}?';

      case 'MOMENTUM_ALERT':
        return '$symbol moved fast in the last 15 minutes. '
            'Is this likely news-driven or just market noise? '
            'My avg cost is ${holding != null ? '₹${holding.averagePrice.toStringAsFixed(2)}' : 'on record'}. '
            'How should I interpret this relative to my position?';

      case 'DCA_OPPORTUNITY':
        return 'Based on my DCA pattern in $symbol, '
            'is this a good level to continue? '
            'What is the mathematical benefit of adding here versus waiting?';

      case 'ACCUMULATION_PATTERN':
        return 'Viren says I have an accumulation pattern going. '
            'What does this mean for my long-term cost basis? '
            'Am I building this position optimally?';

      case 'CONCENTRATION_DRIFT':
        return 'My portfolio allocation has drifted. '
            'Which holding is most overweight right now and what are '
            'the realistic risks of keeping this concentration?';

      case 'CONSISTENCY_STREAK':
        return 'I\'ve been investing consistently. '
            'How does consistent monthly investing compare mathematically '
            'to lump-sum investing? And what should my next step be to '
            'keep this momentum going?';

      case 'BEHAVIOUR_WARNING':
        return 'Viren flagged a behavioural pattern I\'ve repeated before. '
            'What specifically should I watch out for, '
            'and what would a more experienced investor do differently here?';

      case 'NEWS_RELEVANT':
        return 'This news was flagged as relevant to my $symbol position. '
            'What is the likely short and medium term impact on the price? '
            'Should I do anything with my position right now?';

      case 'MACRO_EVENT':
        return 'This macro event was flagged as affecting my portfolio. '
            'Break down exactly which of my holdings is most exposed '
            'and what the historical pattern is for this type of macro event.';

      case 'MORNING_BRIEFING':
        return 'Based on what happened overnight, '
            'what should I specifically watch for in today\'s session? '
            'Is there any action I should consider?';

      case 'INACTIVITY_ALERT':
        return 'I haven\'t traded in a while. '
            'Given current market conditions and my existing positions, '
            'what opportunities might I be missing by staying inactive?';

      case 'PORTFOLIO_MILESTONE':
        return 'My portfolio just hit a milestone. '
            'At this level, should I be thinking about my allocation differently? '
            'What do successful investors typically do at this stage?';

      default:
        return 'What does this mean for my portfolio and what should I do next?';
    }
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
      case 'MOMENTUM_ALERT':       return 'momentum alert';
      case 'MORNING_BRIEFING':     return 'morning briefing';
      case 'WEEKLY_DIGEST':        return 'weekly digest';
      default:                     return 'insight';
    }
  }
}
