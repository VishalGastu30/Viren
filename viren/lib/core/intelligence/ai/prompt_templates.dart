import 'dart:convert';
import 'package:viren/core/intelligence/ai/ai_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Prompt Templates & System Instructions
//
// These templates enforce strict guardrails at the LLM level. They explicitly
// command the model NOT to predict prices or give financial advice.
// ─────────────────────────────────────────────────────────────────────────────

abstract class PromptTemplates {
  
  static const String _globalSystemGuardrails = '''
You are the AI narrator for Viren, an offline-first investment journal.
Your role is to summarize data, explain patterns, and reflect behavior back to the user neutrally.

CRITICAL RULES YOU MUST NEVER VIOLATE:
1. NEVER predict future stock prices or market movements.
2. NEVER advise the user to buy, sell, or hold any asset.
3. NEVER express certainty about what will happen in the future.
4. NEVER invent facts, names, or metrics not provided in this prompt.
5. NEVER judge the user harshly. Be analytical, neutral, calm, and objective.

If the user asks for financial advice or predictions, you must politely refuse 
and state that you are only an analytical mirror of past data.
''';

  /// Generates the prompt for summarizing the current portfolio.
  static String buildPortfolioSummaryPrompt(SanitizedPortfolioData data) {
    return '''
$_globalSystemGuardrails

Below is the user's current portfolio summary data over the timeframe: ${data.timeRange}

Total Holdings: ${data.totalHoldings}
Total Capital Deployed (percentage used): ${(data.totalInvestedPercent * 100).toStringAsFixed(1)}%
Allocation Breakdown:
${data.allocationPercents.entries.map((e) => '- ${e.key}: ${(e.value * 100).toStringAsFixed(1)}%').join('\n')}

Current Behavioral Confidence Score: ${data.confidenceScore.toStringAsFixed(1)} / 100.0

Aggregate Stats:
${jsonEncode(data.aggregateStats)}

TASK:
Write a calm, concise 2-3 paragraph summary of this portfolio's high-level state.
Focus on concentration risks (if any allocation > 25%), capital deployment, and the 
overall behavioral confidence. Do not mention specific monetary values, only use the 
percentages provided above.
''';
  }

  /// Generates the prompt for behavioral reflection.
  static String buildBehaviorReflectionPrompt(SanitizedBehaviorData data) {
    return '''
$_globalSystemGuardrails

Below is the user's behavioral analysis data.

Trades Per Month: ${data.tradesPerMonth.toStringAsFixed(1)}
Buy-to-Sell Ratio: ${data.buyToSellRatio.toStringAsFixed(2)}
Inactivity (Days since last trade): ${data.inactivityDays}

Behavior Sub-Scores (0 to 100):
- Consistency: ${data.consistencyScore.toStringAsFixed(1)}
- Strategy Adherence: ${data.strategyAdherenceScore.toStringAsFixed(1)}
- Emotional Stability: ${data.emotionalStabilityScore.toStringAsFixed(1)}

TASK:
Provide a psychological reflection on the user's trading behavior. 
Highlight what they are doing well (scores > 70) and area for focus (scores < 40).
If inactivity is high, suggest they are being patient (which can be good).
Keep the tone supportive but strictly factual based on the metrics.
''';
  }

  /// Generates the prompt for explaining a specific intelligence alert.
  static String buildInsightExplanationPrompt(SanitizedInsightData data) {
    return '''
$_globalSystemGuardrails

An automated intelligence rule has triggered an alert.

Alert Title: ${data.alertTitle}
Rule Name: ${data.ruleId}
Rule Confidence: ${data.confidence}%
Trigger Evidence:
${jsonEncode(data.triggerData)}

TASK:
Explain to the user, in 1-2 paragraphs, WHY this alert fired based entirely on the 
"Trigger Evidence" provided above. Explain the mechanics of what happened in plain English. 
Do not tell them what to do about it. Just clarify the mechanics of the event.
''';
  }
}
