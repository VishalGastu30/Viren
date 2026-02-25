enum BehaviorPatternType {
  overtrading,
  panicBuying,
  longInactivity,
  convictionDrift,
  excessiveProfit,
}

class BehavioralPattern {
  final BehaviorPatternType type;
  final String title;
  final String description;
  final String why; // Why it matters — factual, no judgment
  final double confidence; // 0.0 to 1.0
  final String dateRange;
  final List<String> relatedSymbols;

  const BehavioralPattern({
    required this.type,
    required this.title,
    required this.description,
    required this.why,
    required this.confidence,
    required this.dateRange,
    this.relatedSymbols = const [],
  });
}

class ConfidenceMetric {
  final double strategicConsistency; // 0.0 to 1.0
  final double timeDiscipline; // 0.0 to 1.0
  final double emotionalStability; // 0.0 to 1.0
  final String strategicNote;
  final String timeNote;
  final String emotionalNote;

  const ConfidenceMetric({
    required this.strategicConsistency,
    required this.timeDiscipline,
    required this.emotionalStability,
    required this.strategicNote,
    required this.timeNote,
    required this.emotionalNote,
  });
}

class BehavioralMock {
  static const List<BehavioralPattern> patterns = [
    BehavioralPattern(
      type: BehaviorPatternType.panicBuying,
      title: 'Repeated Dip Purchases',
      description: '3 of your last 4 buy orders were placed within 48 hours of a 5%+ market decline — Jan 2024, Nov 2023, and Sep 2023.',
      why: 'Frequent dip-buying without a pre-defined entry rule can create an emotionally-driven average-down loop that increases concentration risk.',
      confidence: 0.82,
      dateRange: 'Sep 2023 – Feb 2024',
      relatedSymbols: ['HDFC', 'INFY'],
    ),
    BehavioralPattern(
      type: BehaviorPatternType.overtrading,
      title: 'High Activity in Short Windows',
      description: '6 trades were placed in a 3-week window in January 2024 — notably higher than your 3-month baseline of 1–2 trades per month.',
      why: 'Clusters of activity often correlate with elevated market noise. High-frequency decision-making in short periods can increase transaction costs and emotional exposure.',
      confidence: 0.71,
      dateRange: 'Jan 2024',
      relatedSymbols: ['ZOMATO', 'INFY', 'HDFC'],
    ),
    BehavioralPattern(
      type: BehaviorPatternType.longInactivity,
      title: '83-Day Inactive Streak',
      description: 'No trades were placed between June 2023 and September 2023. Markets moved 8.4% during this period.',
      why: 'Long inactivity is not inherently negative — it may reflect patience. Viren flags it to help you distinguish intentional discipline from inadvertent neglect.',
      confidence: 0.95,
      dateRange: 'Jun – Sep 2023',
      relatedSymbols: [],
    ),
    BehavioralPattern(
      type: BehaviorPatternType.convictionDrift,
      title: 'Conviction Tag Inconsistency',
      description: 'ZOMATO was tagged "Experiment" at entry but has grown to 10% of portfolio — above your self-stated experiment ceiling of 7%.',
      why: 'Position sizing that drifts beyond its original intent can distort risk exposure without a conscious decision to change it.',
      confidence: 0.88,
      dateRange: 'Sep 2023 – present',
      relatedSymbols: ['ZOMATO'],
    ),
    BehavioralPattern(
      type: BehaviorPatternType.excessiveProfit,
      title: 'Early Profit-Taking on Strong Positions',
      description: 'ZOMATO was partially sold at ₹180 — up 50% from entry. It subsequently rose to ₹220 within 6 weeks.',
      why: 'Selling winners early while holding losers longer is a documented behavioral pattern. Viren does not judge this — it surfaces it for your awareness.',
      confidence: 0.65,
      dateRange: 'Jan – Mar 2024',
      relatedSymbols: ['ZOMATO'],
    ),
  ];

  static const ConfidenceMetric metric = ConfidenceMetric(
    strategicConsistency: 0.74,
    timeDiscipline: 0.61,
    emotionalStability: 0.82,
    strategicNote: 'Most positions align with their stated conviction tags. One drift detected in ZOMATO.',
    timeNote: 'One high-activity cluster in January. Long stretches of inactivity suggest patience, with occasional reactive bursts.',
    emotionalNote: 'Emotion tags at entry were predominantly calm and disciplined. One excited entry (ZOMATO) remains in portfolio.',
  );
}
