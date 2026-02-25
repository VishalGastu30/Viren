enum ConvictionTag { longTerm, conviction, experiment, hedge }

enum EmotionTag { calm, cautious, excited, fearful, disciplined }

class TradeEntry {
  final String symbol;
  final String action; // 'BUY' or 'SELL'
  final int quantity;
  final double price;
  final DateTime date;
  final String? reason;
  final List<ConvictionTag> tags;
  final EmotionTag? emotionTag;

  const TradeEntry({
    required this.symbol,
    required this.action,
    required this.quantity,
    required this.price,
    required this.date,
    this.reason,
    this.tags = const [],
    this.emotionTag,
  });
}

class Holding {
  final String symbol;
  final String name;
  final int quantity;
  final double avgPrice;
  final double currentPrice;
  final double percentOfPortfolio;
  final List<double> history;
  final String? investmentReason;
  final List<ConvictionTag> tags;
  final EmotionTag? emotionAtEntry;
  final DateTime? decisionDate;

  const Holding({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.avgPrice,
    required this.currentPrice,
    required this.percentOfPortfolio,
    required this.history,
    this.investmentReason,
    this.tags = const [],
    this.emotionAtEntry,
    this.decisionDate,
  });

  double get totalValue => quantity * currentPrice;
  double get totalPandL => (currentPrice - avgPrice) * quantity;
  double get totalPandLPercent => ((currentPrice - avgPrice) / avgPrice) * 100;
}

class HoldingsMock {
  static final List<Holding> holdings = [
    Holding(
      symbol: 'RELIANCE',
      name: 'Reliance Industries Ltd.',
      quantity: 50,
      avgPrice: 2400.0,
      currentPrice: 2850.50,
      percentOfPortfolio: 25.0,
      history: List.generate(30, (index) => 2800.0 + (index * 2) - (index % 3 * 10)),
      investmentReason: 'Energy transition play — Reliance is betting heavily on green hydrogen and retail. The conglomerate structure provides a natural hedge across consumer, energy, and telecom.',
      tags: [ConvictionTag.longTerm, ConvictionTag.conviction],
      emotionAtEntry: EmotionTag.disciplined,
      decisionDate: DateTime(2023, 6, 10),
    ),
    Holding(
      symbol: 'TCS',
      name: 'Tata Consultancy Services',
      quantity: 40,
      avgPrice: 3200.0,
      currentPrice: 3800.00,
      percentOfPortfolio: 20.0,
      history: List.generate(30, (index) => 3700.0 + (index * 5) - (index % 2 * 15)),
      investmentReason: 'Core IT holding for portfolio stability. TCS has consistent dividend history and global client base that insulates from domestic volatility.',
      tags: [ConvictionTag.longTerm],
      emotionAtEntry: EmotionTag.calm,
      decisionDate: DateTime(2023, 1, 15),
    ),
    Holding(
      symbol: 'HDFC',
      name: 'HDFC Bank Ltd.',
      quantity: 100,
      avgPrice: 1550.0,
      currentPrice: 1680.25,
      percentOfPortfolio: 20.0,
      history: List.generate(30, (index) => 1650.0 + (index * 1.5) - (index % 4 * 5)),
      investmentReason: 'Added on the dip following merger integration concerns. Valuation compressed to multi-year lows relative to ROE, fundamentals intact.',
      tags: [ConvictionTag.conviction],
      emotionAtEntry: EmotionTag.cautious,
      decisionDate: DateTime(2024, 2, 10),
    ),
    Holding(
      symbol: 'INFY',
      name: 'Infosys Ltd.',
      quantity: 80,
      avgPrice: 1450.0,
      currentPrice: 1420.00,
      percentOfPortfolio: 15.0,
      history: List.generate(30, (index) => 1430.0 - (index * 1) + (index % 2 * 3)),
      investmentReason: 'IT sector undervaluation thesis. Entered when sector P/E fell below historical average. Started as an experiment to understand IT cycles.',
      tags: [ConvictionTag.experiment],
      emotionAtEntry: EmotionTag.calm,
      decisionDate: DateTime(2024, 1, 2),
    ),
    Holding(
      symbol: 'ZOMATO',
      name: 'Zomato Ltd.',
      quantity: 500,
      avgPrice: 120.0,
      currentPrice: 165.50,
      percentOfPortfolio: 10.0,
      history: List.generate(30, (index) => 150.0 + (index * 0.5) - (index % 2 * 2)),
      investmentReason: 'Bet on India\'s food delivery duopoly solidifying. Hyper-local network effects are hard to replicate. Position is sized as an experiment — will review at 2x.',
      tags: [ConvictionTag.experiment, ConvictionTag.conviction],
      emotionAtEntry: EmotionTag.excited,
      decisionDate: DateTime(2023, 9, 5),
    ),
    Holding(
      symbol: 'ITC',
      name: 'ITC Ltd.',
      quantity: 200,
      avgPrice: 420.0,
      currentPrice: 440.00,
      percentOfPortfolio: 10.0,
      history: List.generate(30, (index) => 435.0 + (index * 0.2) - (index % 3 * 1)),
      investmentReason: 'Classic dividend compounder. ITC\'s FMCG transition reduces tobacco dependency over time. Held as a portfolio stabiliser.',
      tags: [ConvictionTag.longTerm, ConvictionTag.hedge],
      emotionAtEntry: EmotionTag.disciplined,
      decisionDate: DateTime(2022, 11, 20),
    ),
  ];

  static final List<TradeEntry> tradeHistory = [
    TradeEntry(
      symbol: 'HDFC',
      action: 'BUY',
      quantity: 50,
      price: 1550.0,
      date: DateTime(2024, 2, 10),
      reason: 'Averaging down. Bank fundamentals unchanged, merger overhang overdone.',
      tags: [ConvictionTag.conviction],
      emotionTag: EmotionTag.cautious,
    ),
    TradeEntry(
      symbol: 'ZOMATO',
      action: 'SELL',
      quantity: 200,
      price: 180.0,
      date: DateTime(2024, 1, 15),
      reason: 'Took 20% profits. The run-up was too fast relative to fundamentals. Derisking.',
      tags: [ConvictionTag.experiment],
      emotionTag: EmotionTag.disciplined,
    ),
    TradeEntry(
      symbol: 'INFY',
      action: 'BUY',
      quantity: 80,
      price: 1450.0,
      date: DateTime(2024, 1, 2),
      reason: 'IT sector undervaluation thesis entry.',
      tags: [ConvictionTag.experiment],
      emotionTag: EmotionTag.calm,
    ),
    TradeEntry(
      symbol: 'RELIANCE',
      action: 'BUY',
      quantity: 20,
      price: 2300.0,
      date: DateTime(2023, 11, 8),
      reason: 'Added to existing position on Jio tariff hike catalyst.',
      tags: [ConvictionTag.conviction],
      emotionTag: EmotionTag.calm,
    ),
  ];
}
