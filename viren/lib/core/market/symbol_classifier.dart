import '../../core/database/app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SymbolClassifier — Dynamic intelligence for any Indian stock or ETF.
//
// Works for any symbol — not just the hardcoded 4.
// Used by MacroEngine, BehaviourEngine, and InsightEngine to understand
// what drives each holding's price and what news matters to it.
// ─────────────────────────────────────────────────────────────────────────────

enum AssetClass {
  niftyEtf,      // NIFTYBEES, SETFNIF50, etc. — tracks Nifty 50
  goldEtf,       // GOLDBEES, GOLDCASE, etc. — tracks gold
  silverEtf,     // SILVERIETF, SILVERBEES — tracks silver
  bankEtf,       // BANKETF, PSUBNKBEES — tracks banking sector
  energyEtf,     // ENERGIETF, PSUENERGY — tracks energy/PSU
  pharmaEtf,     // PHARMABEES, HEALTHIETF — tracks pharma
  itEtf,         // ITETF, TECHIETF — tracks IT sector
  debtEtf,       // LIQUIDBEES, CPSEETF — debt/liquid funds
  otherEtf,      // Any other ETF
  bankStock,     // Individual bank stocks
  itStock,       // Individual IT stocks
  pharmaStock,   // Individual pharma stocks
  energyStock,   // Individual energy stocks
  fmcgStock,     // Individual FMCG stocks
  metalStock,    // Individual metal stocks
  autoStock,     // Individual auto stocks
  nbfcStock,     // NBFCs
  generalEquity, // Anything else
}

class SymbolInfo {
  final String symbol;
  final AssetClass assetClass;
  final String description;
  final List<String> macroDrIvers; // what macro events matter to this
  final List<String> correlations; // what global assets it correlates with
  final bool isEtf;

  const SymbolInfo({
    required this.symbol,
    required this.assetClass,
    required this.description,
    required this.macroDrIvers,
    required this.correlations,
    required this.isEtf,
  });

  /// One-line description for Qwen context
  String get qwenContext =>
      '$symbol ($description). Key drivers: ${macroDrIvers.take(3).join(', ')}.';
}

class SymbolClassifier {
  // Known ETF patterns — matched by prefix/substring
  static const _goldPatterns = ['GOLD', 'GOLDCASE', 'GOLDSHARE'];
  static const _silverPatterns = ['SILVER'];
  static const _niftyPatterns = ['NIFTYBEES', 'SETFNIF', 'NIF50', 'JUNIORBEES', 'MON100'];
  static const _bankPatterns = ['BANKETF', 'BANKBEES', 'PSUBNK', 'KOTAKBKETF'];
  static const _energyPatterns = ['ENERGY', 'PSUENERGY', 'INFRABEES'];

  // Known individual stocks by sector
  static const _bankStocks = [
    'HDFCBANK', 'ICICIBANK', 'SBIN', 'KOTAKBANK', 'AXISBANK',
    'INDUSINDBK', 'BANKBARODA', 'YESBANK', 'IDFCFIRSTB', 'FEDERALBNK',
    'BANDHANBNK', 'AUBANK', 'RBLBANK',
  ];
  static const _itStocks = [
    'TCS', 'INFY', 'WIPRO', 'HCLTECH', 'TECHM', 'LTIM',
    'MPHASIS', 'COFORGE', 'PERSISTENT', 'LTTS',
  ];
  static const _pharmaStocks = [
    'SUNPHARMA', 'DRREDDY', 'CIPLA', 'DIVISLAB', 'AUROPHARMA',
    'LUPIN', 'BIOCON', 'ALKEM', 'TORNTPHARM',
  ];
  static const _energyStocks = [
    'RELIANCE', 'ONGC', 'BPCL', 'IOC', 'POWERGRID', 'NTPC',
    'TATAPOWER', 'ADANIGREEN', 'ADANIPOWER', 'CESC',
  ];
  static const _fmcgStocks = [
    'HINDUNILVR', 'ITC', 'NESTLEIND', 'BRITANNIA', 'DABUR',
    'MARICO', 'GODREJCP', 'COLPAL',
  ];
  static const _metalStocks = [
    'TATASTEEL', 'HINDALCO', 'JSWSTEEL', 'SAIL', 'COALINDIA',
    'NMDC', 'VEDL', 'JINDALSTEL',
  ];
  static const _autoStocks = [
    'MARUTI', 'TATAMOTORS', 'M&M', 'BAJAJ-AUTO', 'HEROMOTOCO',
    'EICHERMOT', 'ASHOKLEY', 'TVSMOTOR',
  ];
  static const _nbfcStocks = [
    'BAJFINANCE', 'BAJAJFINSV', 'CHOLAFIN', 'MUTHOOTFIN',
    'MANAPPURAM', 'LICHOUSFIN', 'PNBHOUSING',
  ];

  static SymbolInfo classify(String symbol) {
    final s = symbol.toUpperCase().trim();

    // ── ETF classification ─────────────────────────────────────────────────

    if (_matchesAny(s, _goldPatterns)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.goldEtf,
        description: 'Gold ETF — tracks domestic gold price',
        macroDrIvers: [
          'US Federal Reserve interest rate decisions',
          'Dollar index (DXY) — gold moves inversely to USD',
          'Geopolitical tensions and global uncertainty',
          'Inflation data (CPI/WPI) — gold is an inflation hedge',
          'RBI gold reserve announcements',
          'Global gold spot price movements',
        ],
        correlations: ['Gold spot price (XAU/USD)', 'US Dollar Index', 'SILVERIETF'],
        isEtf: true,
      );
    }

    if (_matchesAny(s, _silverPatterns)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.silverEtf,
        description: 'Silver ETF — tracks domestic silver price',
        macroDrIvers: [
          'Global silver spot price',
          'Industrial demand (silver is 50% industrial use)',
          'US Fed rate decisions — same as gold but more volatile',
          'Solar panel demand growth (silver is a key input)',
          'Global manufacturing PMI data',
          'Gold price movements — silver follows with higher beta',
        ],
        correlations: ['Silver spot price (XAG/USD)', 'GOLDBEES', 'Global manufacturing data'],
        isEtf: true,
      );
    }

    if (_matchesAny(s, _niftyPatterns)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.niftyEtf,
        description: 'Nifty 50 index ETF — tracks Indian large-cap equity market',
        macroDrIvers: [
          'RBI monetary policy and repo rate decisions',
          'India GDP and IIP data releases',
          'FII/DII flows into Indian equity',
          'US markets (S&P 500/NASDAQ) — Indian market follows global cues',
          'Gift Nifty futures — predicts opening gap',
          'Rupee vs Dollar — affects FII returns',
          'India inflation (CPI/WPI) data',
        ],
        correlations: ['S&P 500', 'NASDAQ', 'Gift Nifty futures', 'FII flows'],
        isEtf: true,
      );
    }

    if (_matchesAny(s, _bankPatterns)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.bankEtf,
        description: 'Banking sector ETF — tracks Indian banking index',
        macroDrIvers: [
          'RBI repo rate — directly affects bank margins',
          'NPA and credit growth data',
          'RBI policy statements on banking regulation',
          'India economic growth — affects loan demand',
          'Liquidity conditions in the banking system',
        ],
        correlations: ['RBI policy', 'NIFTYBEES', 'Bank Nifty index'],
        isEtf: true,
      );
    }

    if (_matchesAny(s, _energyPatterns)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.energyEtf,
        description: 'Energy/PSU sector ETF — tracks Indian energy companies',
        macroDrIvers: [
          'Crude oil prices (Brent/WTI)',
          'OPEC production decisions',
          'Government energy policy and subsidies',
          'Rupee vs Dollar — India imports 80% of crude oil',
          'Global geopolitical events affecting oil supply',
        ],
        correlations: ['Crude oil (Brent)', 'Rupee/Dollar', 'ONGC', 'Reliance'],
        isEtf: true,
      );
    }

    // ── Individual stock classification ────────────────────────────────────

    if (_bankStocks.contains(s)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.bankStock,
        description: '$s — private/public sector bank equity',
        macroDrIvers: [
          'RBI repo rate decisions — affects lending margins directly',
          'Quarterly NPA data and credit growth',
          'RBI regulatory actions and banking circulars',
          'India GDP growth — drives loan book expansion',
        ],
        correlations: ['RBI policy', 'Bank Nifty', 'Sector peers'],
        isEtf: false,
      );
    }

    if (_itStocks.contains(s)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.itStock,
        description: '$s — Indian IT services equity',
        macroDrIvers: [
          'US economic outlook — India IT revenue is 60%+ from US clients',
          'USD/INR exchange rate — rupee depreciation boosts earnings',
          'US Fed rate decisions — affects IT client spending budgets',
          'Quarterly deal wins and guidance',
          'US recession fears — IT is first to get budget cuts',
        ],
        correlations: ['USD/INR', 'US S&P 500 IT sector', 'NASDAQ'],
        isEtf: false,
      );
    }

    if (_pharmaStocks.contains(s)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.pharmaStock,
        description: '$s — pharmaceutical company equity',
        macroDrIvers: [
          'US FDA approvals and import alerts',
          'USD/INR rate — pharma earns in USD, spends in INR',
          'US drug pricing policy',
          'DCGI regulatory decisions in India',
          'API raw material prices (mostly China-sourced)',
        ],
        correlations: ['USD/INR', 'US FDA calendar', 'China API prices'],
        isEtf: false,
      );
    }

    if (_energyStocks.contains(s)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.energyStock,
        description: '$s — Indian energy sector equity',
        macroDrIvers: [
          'Crude oil prices (Brent/WTI)',
          'Government fuel pricing decisions',
          'OPEC production cuts/increases',
          'Geopolitical events affecting oil supply routes',
          'Rupee vs Dollar for import costs',
        ],
        correlations: ['Brent crude', 'Rupee/Dollar', 'OPEC decisions'],
        isEtf: false,
      );
    }

    if (_fmcgStocks.contains(s)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.fmcgStock,
        description: '$s — FMCG consumer goods equity',
        macroDrIvers: [
          'Rural demand and monsoon data',
          'Commodity input prices (palm oil, wheat, sugar)',
          'Urban consumption trends',
          'Inflation — affects discretionary spending',
        ],
        correlations: ['India rural consumption', 'Commodity prices'],
        isEtf: false,
      );
    }

    if (_metalStocks.contains(s)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.metalStock,
        description: '$s — metals and mining equity',
        macroDrIvers: [
          'China manufacturing PMI — China drives global metal demand',
          'Global steel/aluminium/coal prices',
          'India infrastructure spending (government capex)',
          'US dollar strength — commodities are dollar-denominated',
        ],
        correlations: ['China PMI', 'London Metal Exchange prices', 'Infrastructure spend'],
        isEtf: false,
      );
    }

    if (_autoStocks.contains(s)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.autoStock,
        description: '$s — automobile sector equity',
        macroDrIvers: [
          'Monthly auto sales data (SIAM)',
          'Fuel prices — affects vehicle demand',
          'Interest rates — auto loans drive purchases',
          'EV transition policy',
          'Semiconductor supply for modern vehicles',
        ],
        correlations: ['SIAM sales data', 'Fuel prices', 'Interest rates'],
        isEtf: false,
      );
    }

    if (_nbfcStocks.contains(s)) {
      return SymbolInfo(
        symbol: s,
        assetClass: AssetClass.nbfcStock,
        description: '$s — non-banking financial company',
        macroDrIvers: [
          'RBI repo rate — affects cost of funds',
          'Credit growth and NPA trends',
          'Liquidity conditions in the market',
          'RBI NBFC regulations',
        ],
        correlations: ['RBI policy', 'Bank Nifty', 'Credit market'],
        isEtf: false,
      );
    }

    // Default for anything unrecognised
    // Try to guess ETF from name patterns
    final isEtf = s.endsWith('BEES') || s.endsWith('ETF') ||
        s.endsWith('IETF') || s.contains('ETF');

    return SymbolInfo(
      symbol: s,
      assetClass: isEtf ? AssetClass.otherEtf : AssetClass.generalEquity,
      description: isEtf ? '$s ETF' : '$s equity',
      macroDrIvers: [
        'Indian market conditions (Nifty 50 direction)',
        'RBI monetary policy',
        'Global market sentiment',
        'FII/DII flows',
      ],
      correlations: ['NIFTYBEES', 'Indian market broad indices'],
      isEtf: isEtf,
    );
  }

  static bool _matchesAny(String symbol, List<String> patterns) {
    return patterns.any((p) => symbol.contains(p));
  }

  /// Build Qwen context string for an entire portfolio
  static String buildPortfolioQwenContext(List<Holding> holdings) {
    return holdings.map((h) {
      final info = classify(h.instrumentSymbol);
      return '${info.qwenContext} '
          'Position: ${h.totalQuantity.toStringAsFixed(0)} units, '
          'avg cost ₹${h.averagePrice.toStringAsFixed(2)}, '
          'invested ₹${h.investedValue.toStringAsFixed(0)}';
    }).join('\n');
  }
}
