import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../../database/enums.dart';
import 'email_connector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BrokerEmailParser — Structured Extraction from Broker Emails
//
// Uses regex + templates per broker. Never LLM-only parsing.
// Each parser extracts trade details with field-level confidence scores.
// ─────────────────────────────────────────────────────────────────────────────

/// A single trade extracted from a broker email.
class EmailParsedTrade {
  final String symbol;
  final String instrumentName;
  final String? exchange;
  final TradeType tradeType;
  final double quantity;
  final double pricePerUnit;
  final double? charges;
  final DateTime tradeDate;
  final String broker;
  final int confidence; // 0–100
  final String sourceMessageHash; // SHA-256 of message body
  final List<String> warnings;

  const EmailParsedTrade({
    required this.symbol,
    required this.instrumentName,
    this.exchange,
    required this.tradeType,
    required this.quantity,
    required this.pricePerUnit,
    this.charges,
    required this.tradeDate,
    required this.broker,
    required this.confidence,
    required this.sourceMessageHash,
    this.warnings = const [],
  });
}

/// A snapshot of holdings extracted from a state balance PDF (e.g. NSE Alerts).
class EmailParsedSnapshot {
  final String symbol;
  final double quantity;
  final DateTime snapshotDate;
  final String sourceMessageHash;

  const EmailParsedSnapshot({
    required this.symbol,
    required this.quantity,
    required this.snapshotDate,
    required this.sourceMessageHash,
  });
}

class EmailParseResult {
  final String messageId;
  final List<EmailParsedTrade> trades;
  final List<EmailParsedSnapshot> snapshots;
  final int aggregateConfidence;
  final List<String> warnings;
  final List<String> errors;

  const EmailParseResult({
    required this.messageId,
    this.trades = const [],
    this.snapshots = const [],
    required this.aggregateConfidence,
    required this.warnings,
    required this.errors,
  });

  bool get hasTrades => trades.isNotEmpty;
}

/// Abstract parser per broker. Subclasses implement broker-specific extraction.
abstract class BrokerEmailParserBase {
  /// The broker this parser handles.
  String get brokerName;

  /// Sender domain patterns this parser matches.
  List<String> get senderDomains;

  /// Attempts to parse trade data from an email body.
  EmailParseResult parse(EmailMessage message);

  /// Computes SHA-256 hash of the email body.
  String hashBody(String body) {
    return sha256.convert(utf8.encode(body)).toString();
  }
}

/// Zerodha (Kite) contract note email parser.
///
/// Zerodha sends contract notes with trade confirmations. The email body
/// typically contains structured text with trade details.
class ZerodhaEmailParser extends BrokerEmailParserBase {
  @override
  String get brokerName => 'Zerodha';

  @override
  List<String> get senderDomains => ['zerodha.com', 'kite.zerodha.com'];

  @override
  EmailParseResult parse(EmailMessage message) {
    final trades = <EmailParsedTrade>[];
    final warnings = <String>[];
    final errors = <String>[];
    final bodyHash = hashBody(message.body);
    final body = message.body;

    // Pattern: Match lines that contain trade information
    // Zerodha contract notes format varies, but typically include:
    // - Symbol/scrip name
    // - BUY/SELL indicator
    // - Quantity
    // - Price
    //
    // Common patterns in Zerodha emails:
    // "BUY RELIANCE 10 @ 2450.00"
    // "SOLD TCS 5 @ 3200.50"

    // Pattern 1: "BUY/SELL SYMBOL QTY @ PRICE" or "SYMBOL BUY/SELL QTY @ PRICE"
    final pattern1 = RegExp(
      r'(BUY|SELL|BOUGHT|SOLD)\s+'
      r'([A-Z][A-Z0-9\-]{1,49})\s+'
      r'(\d+(?:\.\d+)?)\s*(?:@|at)\s*'
      r'(\d+(?:,\d+)*(?:\.\d+)?)',
      caseSensitive: false,
    );

    // Pattern 2: Tabular data "SYMBOL | EXCHANGE | QTY | PRICE | TYPE"
    final pattern2 = RegExp(
      r'([A-Z][A-Z0-9\-]{1,49})\s*\|\s*'
      r'(NSE|BSE)\s*\|\s*'
      r'(\d+(?:\.\d+)?)\s*\|\s*'
      r'(\d+(?:,\d+)*(?:\.\d+)?)\s*\|\s*'
      r'(BUY|SELL)',
      caseSensitive: false,
    );

    // Try Pattern 1
    for (final match in pattern1.allMatches(body)) {
      try {
        final typeStr = match.group(1)!.toUpperCase();
        final symbol = match.group(2)!;
        final qty = double.parse(match.group(3)!);
        final price = double.parse(match.group(4)!.replaceAll(',', ''));

        final tradeType = (typeStr == 'BUY' || typeStr == 'BOUGHT')
            ? TradeType.buy
            : TradeType.sell;

        trades.add(EmailParsedTrade(
          symbol: symbol,
          instrumentName: symbol,
          exchange: 'NSE',
          tradeType: tradeType,
          quantity: qty,
          pricePerUnit: price,
          tradeDate: message.date,
          broker: brokerName,
          confidence: 75,
          sourceMessageHash: bodyHash,
        ));
      } catch (e) {
        warnings.add('Pattern match failed: $e');
      }
    }

    // Try Pattern 2 if Pattern 1 found nothing
    if (trades.isEmpty) {
      for (final match in pattern2.allMatches(body)) {
        try {
          final symbol = match.group(1)!;
          final exchange = match.group(2)!;
          final qty = double.parse(match.group(3)!);
          final price = double.parse(match.group(4)!.replaceAll(',', ''));
          final typeStr = match.group(5)!.toUpperCase();

          final tradeType = typeStr == 'BUY' ? TradeType.buy : TradeType.sell;

          trades.add(EmailParsedTrade(
            symbol: symbol,
            instrumentName: symbol,
            exchange: exchange,
            tradeType: tradeType,
            quantity: qty,
            pricePerUnit: price,
            tradeDate: message.date,
            broker: brokerName,
            confidence: 80,
            sourceMessageHash: bodyHash,
          ));
        } catch (e) {
          warnings.add('Pattern 2 match failed: $e');
        }
      }
    }

    if (trades.isEmpty) {
      errors.add('Could not extract trade data from Zerodha email');
    }

    final avgConfidence = trades.isEmpty
        ? 0
        : (trades.fold<int>(0, (s, t) => s + t.confidence) / trades.length)
              .round();

    return EmailParseResult(
      messageId: message.messageId,
      trades: trades,
      aggregateConfidence: avgConfidence,
      warnings: warnings,
      errors: errors,
    );
  }
}

/// Registry of all available email parsers.
final List<BrokerEmailParserBase> allEmailParsers = [
  ZerodhaEmailParser(),
  GrowwEmailParser(),
  // Generic parser is used as fallback — not registered here.
  // Use findParserForSender() which falls back to GenericBrokerEmailParser.
];

/// Groww trade confirmation email parser.
///
/// Groww sends trade confirmations with structured text.
/// Common patterns:
///   "You have successfully bought 10 units of RELIANCE at ₹2,450.00"
///   "Order executed: SELL TCS x 5 @ ₹3,200.50"
class GrowwEmailParser extends BrokerEmailParserBase {
  @override
  String get brokerName => 'Groww';

  @override
  List<String> get senderDomains => ['groww.in'];

  @override
  EmailParseResult parse(EmailMessage message) {
    final trades = <EmailParsedTrade>[];
    final warnings = <String>[];
    final errors = <String>[];
    final bodyHash = hashBody(message.body);
    final body = message.body;

    // Pattern 1: "successfully bought/sold X units of SYMBOL at ₹PRICE"
    final pattern1 = RegExp(
      r'(?:successfully\s+)?(bought|sold|purchased)\s+'
      r'(\d+(?:\.\d+)?)\s*(?:units?\s+of|shares?\s+of|qty\s+of|x)?\s*'
      r'([A-Z][A-Z0-9\-]{1,49})\s*(?:at|@)\s*'
      r'(?:₹|Rs\.?|INR)?\s*(\d+(?:,\d+)*(?:\.\d+)?)',
      caseSensitive: false,
    );

    // Pattern 2: "BUY/SELL SYMBOL QTY @ PRICE" (generic Groww format)
    final pattern2 = RegExp(
      r'(BUY|SELL|BOUGHT|SOLD)\s+'
      r'([A-Z][A-Z0-9\-]{1,49})\s+'
      r'(\d+(?:\.\d+)?)\s*(?:@|at)\s*'
      r'(?:₹|Rs\.?|INR)?\s*(\d+(?:,\d+)*(?:\.\d+)?)',
      caseSensitive: false,
    );

    // Try Pattern 1
    for (final match in pattern1.allMatches(body)) {
      try {
        final typeStr = match.group(1)!.toUpperCase();
        final qty = double.parse(match.group(2)!);
        final symbol = match.group(3)!;
        final price = double.parse(match.group(4)!.replaceAll(',', ''));

        final tradeType = (typeStr == 'BOUGHT' || typeStr == 'PURCHASED')
            ? TradeType.buy
            : TradeType.sell;

        trades.add(EmailParsedTrade(
          symbol: symbol,
          instrumentName: symbol,
          exchange: 'NSE',
          tradeType: tradeType,
          quantity: qty,
          pricePerUnit: price,
          tradeDate: message.date,
          broker: brokerName,
          confidence: 80,
          sourceMessageHash: bodyHash,
        ));
      } catch (e) {
        warnings.add('Groww pattern 1 match failed: $e');
      }
    }

    // Try Pattern 2 if Pattern 1 found nothing
    if (trades.isEmpty) {
      for (final match in pattern2.allMatches(body)) {
        try {
          final typeStr = match.group(1)!.toUpperCase();
          final symbol = match.group(2)!;
          final qty = double.parse(match.group(3)!);
          final price = double.parse(match.group(4)!.replaceAll(',', ''));

          final tradeType = (typeStr == 'BUY' || typeStr == 'BOUGHT')
              ? TradeType.buy
              : TradeType.sell;

          trades.add(EmailParsedTrade(
            symbol: symbol,
            instrumentName: symbol,
            exchange: 'NSE',
            tradeType: tradeType,
            quantity: qty,
            pricePerUnit: price,
            tradeDate: message.date,
            broker: brokerName,
            confidence: 75,
            sourceMessageHash: bodyHash,
          ));
        } catch (e) {
          warnings.add('Groww pattern 2 match failed: $e');
        }
      }
    }

    if (trades.isEmpty) {
      errors.add('Could not extract trade data from Groww email');
    }

    final avgConfidence = trades.isEmpty
        ? 0
        : (trades.fold<int>(0, (s, t) => s + t.confidence) / trades.length)
              .round();

    return EmailParseResult(
      messageId: message.messageId,
      trades: trades,
      aggregateConfidence: avgConfidence,
      warnings: warnings,
      errors: errors,
    );
  }
}

/// Generic broker email parser — fallback for any broker.
///
/// Uses broad regex patterns that match most Indian broker trade confirmations.
/// Lower confidence scores since patterns are less specific.
class GenericBrokerEmailParser extends BrokerEmailParserBase {
  @override
  String get brokerName => 'Unknown Broker';

  @override
  List<String> get senderDomains => []; // Not matched by domain — used as fallback

  @override
  EmailParseResult parse(EmailMessage message) {
    final trades = <EmailParsedTrade>[];
    final warnings = <String>[];
    final errors = <String>[];
    final bodyHash = hashBody(message.body);
    final body = message.body;

    // Broad pattern: "BUY/SELL SYMBOL QTY @ PRICE" in any format
    final broadPattern = RegExp(
      r'(BUY|SELL|BOUGHT|SOLD|PURCHASE[D]?)\s+'
      r'([A-Z][A-Z0-9\-]{1,49})\s+'
      r'(\d+(?:\.\d+)?)\s*(?:@|at|x)\s*'
      r'(?:₹|Rs\.?|INR|\$)?\s*(\d+(?:,\d+)*(?:\.\d+)?)',
      caseSensitive: false,
    );

    // Reverse pattern: "SYMBOL BUY/SELL QTY @ PRICE"
    final reversePattern = RegExp(
      r'([A-Z][A-Z0-9\-]{1,49})\s+'
      r'(BUY|SELL|BOUGHT|SOLD)\s+'
      r'(\d+(?:\.\d+)?)\s*(?:@|at)\s*'
      r'(?:₹|Rs\.?|INR|\$)?\s*(\d+(?:,\d+)*(?:\.\d+)?)',
      caseSensitive: false,
    );

    // Try broad pattern
    for (final match in broadPattern.allMatches(body)) {
      try {
        final typeStr = match.group(1)!.toUpperCase();
        final symbol = match.group(2)!;
        final qty = double.parse(match.group(3)!);
        final price = double.parse(match.group(4)!.replaceAll(',', ''));
        if (qty <= 0 || price <= 0) continue;

        final tradeType = typeStr.startsWith('BUY') || typeStr.startsWith('BOUGHT') || typeStr.startsWith('PURCHASE')
            ? TradeType.buy
            : TradeType.sell;

        trades.add(EmailParsedTrade(
          symbol: symbol,
          instrumentName: symbol,
          tradeType: tradeType,
          quantity: qty,
          pricePerUnit: price,
          tradeDate: message.date,
          broker: brokerName,
          confidence: 60,
          sourceMessageHash: bodyHash,
        ));
      } catch (_) {}
    }

    // Try reverse pattern if nothing found
    if (trades.isEmpty) {
      for (final match in reversePattern.allMatches(body)) {
        try {
          final symbol = match.group(1)!;
          final typeStr = match.group(2)!.toUpperCase();
          final qty = double.parse(match.group(3)!);
          final price = double.parse(match.group(4)!.replaceAll(',', ''));
          if (qty <= 0 || price <= 0) continue;

          final tradeType = (typeStr == 'BUY' || typeStr == 'BOUGHT')
              ? TradeType.buy
              : TradeType.sell;

          trades.add(EmailParsedTrade(
            symbol: symbol,
            instrumentName: symbol,
            tradeType: tradeType,
            quantity: qty,
            pricePerUnit: price,
            tradeDate: message.date,
            broker: brokerName,
            confidence: 50,
            sourceMessageHash: bodyHash,
          ));
        } catch (_) {}
      }
    }

    if (trades.isEmpty) {
      errors.add('Could not extract trade data from email');
    }

    final avgConfidence = trades.isEmpty
        ? 0
        : (trades.fold<int>(0, (s, t) => s + t.confidence) / trades.length)
              .round();

    return EmailParseResult(
      messageId: message.messageId,
      trades: trades,
      aggregateConfidence: avgConfidence,
      warnings: warnings,
      errors: errors,
    );
  }
}

/// Finds the appropriate parser for a sender email address.
/// Falls back to GenericBrokerEmailParser if no specific parser matches.
BrokerEmailParserBase? findParserForSender(String senderEmail) {
  final lower = senderEmail.toLowerCase();
  for (final parser in allEmailParsers) {
    for (final domain in parser.senderDomains) {
      if (lower.contains(domain)) {
        return parser;
      }
    }
  }
  // Fallback: use generic parser for any broker email in the whitelist
  return GenericBrokerEmailParser();
}
