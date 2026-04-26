class MarketKnowledgeService {

  static Future<void> init() async {
    // No longer loads from file; using hardcoded targeted snippets.
  }

  static String relevantSection(String question) {
    final q = question.toLowerCase();

    // Gold: 3 key facts, max 200 chars
    if (q.contains('gold') || q.contains('goldbees') || q.contains('setfgold') || q.contains('gold etf')) {
      return 'GOLD MECHANICS: Gold rises in crises and when dollar weakens. '
          'In India, rupee depreciation amplifies gold returns in INR. '
          'Gold falls when real interest rates rise (bonds become attractive).';
    }

    // Silver: shorter — users understand it moves like gold but more volatile
    if (q.contains('silver') || q.contains('silverietf') || q.contains('silverbees') || q.contains('silver etf')) {
      return 'SILVER MECHANICS: 70% industrial demand (manufacturing/solar), '
          '30% store of value. More volatile than gold. Tracks gold in crises '
          'but also tracks industrial cycle.';
    }

    // YES BANK: context for reconstruction
    if (q.contains('yesbank') || q.contains('yes bank')) {
      return 'YES BANK CONTEXT: Underwent RBI-supervised reconstruction in 2020. '
          'Now 26% owned by SBI. Sensitive to NPA concerns and RBI policy. '
          'Very high retail investor ownership — prone to sharp moves.';
    }

    // Nifty / broad market
    if (q.contains('nifty') || q.contains('market') || q.contains('sensex') || q.contains('niftybees')) {
      return 'NIFTY DRIVERS: FII flows dominate (check NSE FII data). '
          'DXY (Dollar Index) rise → FII outflows → Nifty falls. '
          'RBI rate cuts boost banking+auto. India VIX above 20 = fear zone.';
    }

    // RBI / rates
    if (q.contains('rbi') || q.contains('rate') || q.contains('inflation')) {
      return 'RBI IMPACT: Rate cuts → banking stocks and real estate rally. '
          'Rate hikes → gold falls, bonds fall, growth stocks correct. '
          'RBI watches CPI (target 4%) and INR stability.';
    }

    // US macro
    if (q.contains('fed') || q.contains('dollar') || q.contains('dxy') ||
        q.contains('us ') || q.contains('tariff') || q.contains('trump')) {
      return 'US-INDIA LINK: Strong dollar (DXY rise) → rupee weakens → FII sell India. '
          'Fed rate hikes → gold falls. US tariffs → IT exports at risk. '
          'INR at 84+ signals FII outflow pressure.';
    }

    return ''; // No knowledge needed — saves tokens for news
  }
}
