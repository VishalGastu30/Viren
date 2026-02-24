class Holding {
  final String symbol;
  final String name;
  final int quantity;
  final double avgPrice;
  final double currentPrice;
  final double percentOfPortfolio;
  final List<double> history;

  const Holding({
    required this.symbol,
    required this.name,
    required this.quantity,
    required this.avgPrice,
    required this.currentPrice,
    required this.percentOfPortfolio,
    required this.history,
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
    ),
    Holding(
      symbol: 'TCS',
      name: 'Tata Consultancy Services',
      quantity: 40,
      avgPrice: 3200.0,
      currentPrice: 3800.00,
      percentOfPortfolio: 20.0,
      history: List.generate(30, (index) => 3700.0 + (index * 5) - (index % 2 * 15)),
    ),
    Holding(
      symbol: 'HDFC',
      name: 'HDFC Bank Ltd.',
      quantity: 100,
      avgPrice: 1550.0,
      currentPrice: 1680.25,
      percentOfPortfolio: 20.0,
      history: List.generate(30, (index) => 1650.0 + (index * 1.5) - (index % 4 * 5)),
    ),
    Holding(
      symbol: 'INFY',
      name: 'Infosys Ltd.',
      quantity: 80,
      avgPrice: 1450.0,
      currentPrice: 1420.00, // Slightly down
      percentOfPortfolio: 15.0,
      history: List.generate(30, (index) => 1430.0 - (index * 1) + (index % 2 * 3)),
    ),
    Holding(
      symbol: 'ZOMATO',
      name: 'Zomato Ltd.',
      quantity: 500,
      avgPrice: 120.0,
      currentPrice: 165.50,
      percentOfPortfolio: 10.0,
      history: List.generate(30, (index) => 150.0 + (index * 0.5) - (index % 2 * 2)),
    ),
    Holding(
      symbol: 'ITC',
      name: 'ITC Ltd.',
      quantity: 200,
      avgPrice: 420.0,
      currentPrice: 440.00,
      percentOfPortfolio: 10.0,
      history: List.generate(30, (index) => 435.0 + (index * 0.2) - (index % 3 * 1)),
    ),
  ];
}
