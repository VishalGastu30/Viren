enum AlertSeverity { info, success, warning, critical }

class Alert {
  final String title;
  final String description;
  final AlertSeverity severity;
  final String time;
  final double confidence; // 0.0 to 1.0
  final String historicalContext;
  final String? relatedSymbol;
  bool isDismissed;
  bool isSnoozed;

  Alert({
    required this.title,
    required this.description,
    required this.severity,
    required this.time,
    required this.confidence,
    required this.historicalContext,
    this.relatedSymbol,
    this.isDismissed = false,
    this.isSnoozed = false,
  });
}

class JournalEntry {
  final String date;
  final String note;
  final String tag;

  const JournalEntry({
    required this.date,
    required this.note,
    required this.tag,
  });
}

class AlertsMock {
  static List<Alert> insights = [
    Alert(
      title: 'HDFC crossed 50-DMA',
      description: 'The stock has shown consistent upward momentum over the last week. Institutional accumulation signals are present.',
      severity: AlertSeverity.info,
      time: '2 hours ago',
      confidence: 0.78,
      historicalContext: 'HDFC has historically shown 6–9% upside within 30 days of crossing its 50-DMA in bullish market conditions.',
      relatedSymbol: 'HDFC',
    ),
    Alert(
      title: 'Zomato Q3 Results Incoming',
      description: 'Earnings report is scheduled for tomorrow. High volatility expected in either direction.',
      severity: AlertSeverity.warning,
      time: '5 hours ago',
      confidence: 0.92,
      historicalContext: 'ZOMATO historically moves 8–15% on earnings day. Your position is sized at 10% of portfolio.',
      relatedSymbol: 'ZOMATO',
    ),
    Alert(
      title: 'INFY Support Broken',
      description: 'The stock closed below its crucial support of ₹1430. This is a structural break, not a routine pullback.',
      severity: AlertSeverity.critical,
      time: '1 day ago',
      confidence: 0.85,
      historicalContext: 'When INFY broke this level in 2022, it declined 18% over the following 6 weeks before recovering. Context differs today — global IT demand remains soft.',
      relatedSymbol: 'INFY',
    ),
    Alert(
      title: 'RELIANCE hits 52-week high',
      description: 'Continuing its strong run across energy, retail, and telecom segments, the stock broke past previous resistance.',
      severity: AlertSeverity.success,
      time: '2 days ago',
      confidence: 0.88,
      historicalContext: 'RELIANCE 52-week highs have preceded an average 12% additional run over the next quarter in 4 of the last 5 occurrences.',
      relatedSymbol: 'RELIANCE',
    ),
    Alert(
      title: 'TCS Q4 Guidance Below Estimate',
      description: 'Management guided for cautious growth in Q4, citing macro softness in BFSI demand from North America.',
      severity: AlertSeverity.warning,
      time: '3 days ago',
      confidence: 0.71,
      historicalContext: 'TCS has revised Q4 guidance downward 3 times in the past 5 years. Stock averaged -4% in the following month before recovering.',
      relatedSymbol: 'TCS',
    ),
  ];

  static const List<JournalEntry> journal = [
    JournalEntry(
      date: '10 Feb 2024',
      note: 'Added more HDFC on the dip. Valuation seems reasonable compared to peers. Conviction remains high despite the merger noise.',
      tag: 'Bought HDFC',
    ),
    JournalEntry(
      date: '15 Jan 2024',
      note: 'Took 20% profits in Zomato. The run up was too fast, derisking a bit. Will re-enter below ₹140 if opportunity presents.',
      tag: 'Sold Zomato',
    ),
    JournalEntry(
      date: '02 Jan 2024',
      note: 'Starting the year with a focus on large caps. IT sector looks undervalued on a P/E basis relative to historical averages.',
      tag: 'Strategy',
    ),
    JournalEntry(
      date: '08 Nov 2023',
      note: 'Added to Reliance on Jio tariff hike news. Timing felt right — markets had already priced in a rate pause.',
      tag: 'Bought RELIANCE',
    ),
  ];

  // Mock Assistant Q&A pairs
  static const Map<String, String> assistantQA = {
    'Summarize my portfolio': 'Your portfolio is up 14.04% overall. RELIANCE and ZOMATO are your strongest contributors. INFY is your only position in the red — down 2.07% from your average entry of ₹1450.',
    'How was January 2024?': 'January was your most active month in 4 months — 3 trades placed. You bought INFY and averaged down on HDFC. ZOMATO was partially sold for a 50% gain. Net portfolio change: +2.3%.',
    'What was my behaviour pattern?': 'Viren noticed a cluster of 3 trades in January, which is higher than your baseline of 1–2 per month. Two of those trades were placed within 48 hours of market declines. No judgment — just a pattern worth noting.',
    'Which holding deviates from my intent?': 'ZOMATO was tagged as an Experiment at entry with a position ceiling of 7%. It currently sits at 10% of portfolio. Worth reviewing whether the sizing still matches your intent.',
  };
}
