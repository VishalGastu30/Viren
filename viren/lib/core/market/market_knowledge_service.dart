import 'package:flutter/services.dart';

class MarketKnowledgeService {
  static String? _fullKnowledge;

  static Future<void> init() async {
    _fullKnowledge = await rootBundle
        .loadString('assets/viren_market_knowledge.txt');
  }

  /// Returns only the section of knowledge relevant to the user's question.
  /// Returns empty string if no relevant section found.
  static String relevantSection(String userMessage) {
    if (_fullKnowledge == null) return '';
    final m = userMessage.toLowerCase();

    if (_containsAny(m, ['tax', 'stcg', 'ltcg', 'capital gain', 'slab', 'loss harvest'])) {
      return _extractSection('TAXATION');
    }
    if (_containsAny(m, ['charge', 'brokerage', 'stt', 'gst', 'fee', 'cost', 'stamp'])) {
      return _extractSection('CHARGES');
    }
    if (_containsAny(m, ['settle', 't+1', 'credit', 'debit', 'intraday'])) {
      return _extractSection('SETTLEMENT');
    }
    if (_containsAny(m, ['circuit', 'halt', 'freeze', 'upper', 'lower'])) {
      return _extractSection('CIRCUIT BREAKERS');
    }
    if (_containsAny(m, ['p/e', 'pe ratio', 'p/b', 'eps', 'roe', 'dividend yield', 'ratio'])) {
      return _extractSection('KEY RATIOS');
    }
    if (_containsAny(m, ['return', 'xirr', 'cagr', 'calculate', 'unrealised', 'realised', 'p&l'])) {
      return _extractSection('RETURN CALCULATIONS');
    }
    if (_containsAny(m, ['nifty', 'sensex', 'index', 'midcap', 'smallcap'])) {
      return _extractSection('INDICES');
    }
    if (_containsAny(m, ['market hour', 'open', 'close', 'timing', 'pre-open'])) {
      return _extractSection('MARKET HOURS');
    }

    return '';
  }

  static String _extractSection(String sectionName) {
    if (_fullKnowledge == null) return '';
    final lines = _fullKnowledge!.split('\n');
    final buffer = StringBuffer();
    bool inSection = false;

    for (final line in lines) {
      if (line.startsWith(sectionName)) {
        inSection = true;
        buffer.writeln(line);
        continue;
      }
      if (inSection) {
        // Stop at next section (line that is all caps and ends with colon)
        if (line.isNotEmpty &&
            line == line.toUpperCase() &&
            line.endsWith(':')) {
          break;
        }
        buffer.writeln(line);
      }
    }
    return buffer.toString().trim();
  }

  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}
