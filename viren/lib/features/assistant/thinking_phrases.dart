import 'dart:math';

class ThinkingPhrases {
  static final _random = Random();
  static String? _lastPhrase;

  // ── Category pools ────────────────────────────────────────────────────────

  static const _returns = [
    'calculating your returns...',
    'running the numbers...',
    'working out your P&L...',
    'crunching gains and losses...',
    'checking what the market gave you...',
    'tallying up the performance...',
    'computing return percentages...',
  ];

  static const _holdings = [
    'scanning your holdings...',
    'reading your positions...',
    'going through your portfolio...',
    'looking at what you own...',
    'pulling up your stocks...',
    'checking each position...',
    'reviewing your holdings...',
  ];

  static const _comparison = [
    'ranking your positions...',
    'lining them up side by side...',
    'comparing across your portfolio...',
    'sorting by performance...',
    'weighing each holding...',
    'finding the leaders and laggards...',
    'building the comparison...',
  ];

  static const _charges = [
    'adding up your charges...',
    'tallying brokerage and taxes...',
    'digging through transaction costs...',
    'counting what went to charges...',
    'calculating STT and fees...',
    'totalling the cost of trading...',
  ];

  static const _tax = [
    'checking your tax position...',
    'working out STCG and LTCG...',
    'looking at your holding periods...',
    'calculating tax liability...',
    'seeing what\'s short-term vs long-term...',
    'working out your capital gains...',
  ];

  static const _history = [
    'going through your trade history...',
    'reading the timeline...',
    'tracing your trades...',
    'checking the records...',
    'scrolling back through transactions...',
    'pulling up past activity...',
  ];

  static const _price = [
    'fetching current prices...',
    'checking the market...',
    'looking at where things stand today...',
    'reading live data...',
    'checking current valuations...',
  ];

  static const _news = [
    'checking latest news...',
    'reading the full article...',
    'scanning the headlines...',
    'looking up current events...',
    'checking what the world is doing...',
  ];

  static const _live = [
    'checking gold spot price...',
    'looking at global markets...',
    'getting live numbers...',
  ];

  static const _summary = [
    'putting together a summary...',
    'building the full picture...',
    'pulling everything together...',
    'assembling your portfolio view...',
    'getting the complete overview...',
  ];

  static const _general = [
    'verifying 0-unit holdings...',
    'checking live portfolio context...',
    'validating asset snapshot...',
    'checking multi-intent routing...',
    'building analytical drafts...',
    'assembling internal data markers...',
    'checking for cross-asset confusion...',
    'resolving portfolio math...',
    'processing context...',
  ];

  // ── Keyword detection ─────────────────────────────────────────────────────

  static String forMessage(String userMessage) {
    final m = userMessage.toLowerCase();

    List<String> pool;

    if (_containsAny(m, ['tax', 'stcg', 'ltcg', 'capital gain', 'slab'])) {
      pool = _tax;
    } else if (_containsAny(m, ['charge', 'brokerage', 'stt', 'gst', 'fee', 'cost'])) {
      pool = _charges;
    } else if (_containsAny(m, ['best', 'worst', 'top', 'rank', 'compare', 'vs', 'versus', 'which'])) {
      pool = _comparison;
    } else if (_containsAny(m, ['return', 'profit', 'loss', 'gain', 'p&l', 'percent', '%'])) {
      pool = _returns;
    } else if (_containsAny(m, ['price', 'cmp', 'current', 'today', 'now', 'market'])) {
      pool = _price;
    } else if (_containsAny(m, ['when', 'date', 'history', 'ago', 'since', 'first', 'last', 'trade'])) {
      pool = _history;
    } else if (_containsAny(m, ['holding', 'stock', 'share', 'position', 'own'])) {
      pool = _holdings;
    } else if (_containsAny(m, ['summary', 'overview', 'total', 'all', 'everything', 'portfolio'])) {
      pool = _summary;
    } else if (_containsAny(m, ['news', 'why', 'happened', 'reason', 'article'])) {
      pool = _news;
    } else if (_containsAny(m, ['live', 'spot', 'global'])) {
      pool = _live;
    } else {
      pool = _general;
    }

    // Avoid repeating the last phrase
    String phrase;
    int attempts = 0;
    do {
      phrase = pool[_random.nextInt(pool.length)];
      attempts++;
    } while (phrase == _lastPhrase && pool.length > 1 && attempts < 10);

    _lastPhrase = phrase;
    return phrase;
  }

  static bool _containsAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}
