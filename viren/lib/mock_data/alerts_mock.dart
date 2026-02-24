enum AlertSeverity { info, success, warning, critical }

class Alert {
  final String title;
  final String description;
  final AlertSeverity severity;
  final String time;

  const Alert({
    required this.title,
    required this.description,
    required this.severity,
    required this.time,
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
  static const List<Alert> insights = [
    Alert(
      title: 'HDFC crossed 50-DMA',
      description: 'The stock has shown consistent upward momentum over the last week. This indicates institutional accumulation.',
      severity: AlertSeverity.info,
      time: '2 hours ago',
    ),
    Alert(
      title: 'Zomato Q3 Results Incoming',
      description: 'Earnings report is scheduled for tomorrow. High volatility expected.',
      severity: AlertSeverity.warning,
      time: '5 hours ago',
    ),
     Alert(
      title: 'INFY Support Broken',
      description: 'The stock closed below its crucial support of 1430. Proceed with caution.',
      severity: AlertSeverity.critical,
      time: '1 day ago',
    ),
    Alert(
      title: 'RELIANCE hits 52-week high',
      description: 'Continuing its strong run, the stock broke past its previous resistance.',
      severity: AlertSeverity.success,
      time: '2 days ago',
    ),
  ];

  static const List<JournalEntry> journal = [
    JournalEntry(
      date: '10 Feb 2024',
      note: 'Added more HDFC on the dip. Valuation seems reasonable compared to peers.',
      tag: 'Bought HDFC',
    ),
    JournalEntry(
      date: '15 Jan 2024',
      note: 'Took 20% profits in Zomato. The run up was too fast, derisking a bit.',
      tag: 'Sold Zomato',
    ),
    JournalEntry(
      date: '02 Jan 2024',
      note: 'Starting the year with a focus on large caps. IT sector looks undervalued.',
      tag: 'Strategy',
    ),
  ];
}
