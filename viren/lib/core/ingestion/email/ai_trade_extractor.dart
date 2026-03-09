import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

import 'broker_email_parser.dart';
import '../../database/enums.dart';
import '../../ai/model_download_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AI Trade Extractor — On-Device Qwen/Gemma LLM for Trade Extraction
//
// Two modes:
//   1. NSE Direct primary parser (extractNseDirectTrades + retry)
//   2. Legacy fallback for other brokers (extractTrades)
//
// Relies on on-device ML via MediaPipe LLM Inference.
// ─────────────────────────────────────────────────────────────────────────────

/// Result from the NSE Direct Qwen-primary extraction pipeline.
class NseDirectExtractionResult {
  final List<EmailParsedTrade> validatedTrades;   // math passed
  final List<UnresolvedTrade> unresolvedTrades;    // math failed after retry

  const NseDirectExtractionResult({
    this.validatedTrades = const [],
    this.unresolvedTrades = const [],
  });
}

/// A trade that Qwen returned but failed math validation after both attempts.
class UnresolvedTrade {
  final String filename;
  final String rawJson;
  final String reason;

  const UnresolvedTrade({
    required this.filename,
    required this.rawJson,
    required this.reason,
  });
}

class AiTradeExtractor {
  static const _channel = MethodChannel('com.viren.viren/pdf_crypto');

  AiTradeExtractor();

  // ═══════════════════════════════════════════════════════════════════════════
  // NSE DIRECT PRIMARY PARSER — Qwen with math validation + retry
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fallback extraction for NSE Direct PDFs when Regex returns 0 trades.
  /// Returns validated trades (confidence 80) and unresolved trades.
  Future<NseDirectExtractionResult> extractNseDirectTrades({
    required String extractedText,
    required String filename,
    required DateTime emailDate,
    required String sourceMessageHash,
  }) async {
    developer.log('[QWEN_FALLBACK] Starting fallback parse for $filename (${extractedText.length} chars)', name: 'AiTradeExtractor');

    final prompt = '''
<|im_start|>system
You are a trade extraction engine. Return only valid JSON arrays. No explanation. No markdown.<|im_end|>
<|im_start|>user
Extract trades from this NSE Direct PDF text.
Return ONLY JSON array, no explanation:
[{"symbol":"","type":"BUY or SELL","qty":0,"price":0,"tradeValue":0}]
If none found return: []
TEXT: $extractedText
<|im_end|>
<|im_start|>assistant
''';

    // Step 1: Parse
    final rawTrades = await _invokeQwen(prompt, filename);
    if (rawTrades.isEmpty) {
      developer.log('[QWEN_FALLBACK] Qwen returned 0 trades for $filename', name: 'AiTradeExtractor');
      return const NseDirectExtractionResult();
    }

    developer.log('[QWEN_FALLBACK] Qwen returned ${rawTrades.length} raw trades for $filename', name: 'AiTradeExtractor');

    // Step 2: Math validation gate (±1%)
    final validated = <EmailParsedTrade>[];
    final unresolved = <UnresolvedTrade>[];

    for (final t in rawTrades) {
      final result = _mathValidate(t, emailDate, sourceMessageHash, 70);
      if (result != null) {
        validated.add(result);
      } else {
        unresolved.add(UnresolvedTrade(
          filename: filename,
          rawJson: jsonEncode(t),
          reason: 'qty × price ≠ tradeValue (deviation > 1%)',
        ));
      }
    }

    developer.log('[QWEN_FALLBACK] Math validation: ${validated.length} passed, ${unresolved.length} unresolved', name: 'AiTradeExtractor');

    return NseDirectExtractionResult(
      validatedTrades: validated,
      unresolvedTrades: unresolved,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Invoke Qwen and return parsed JSON array of trade maps.
  Future<List<Map<String, dynamic>>> _invokeQwen(String prompt, String filename) async {
    try {
      final modelPath = await ModelDownloadService.getModelPath();
      final responseText = await _channel.invokeMethod<String>('extractAiTrades', {
        'promptText': prompt,
        'modelPath': modelPath,
      });

      if (responseText == null || responseText.isEmpty) {
        developer.log('[QWEN] Empty response from model', name: 'AiTradeExtractor');
        return [];
      }

      // 1. Mandatory log of exactly what Qwen generated, unconditionally
      developer.log('[QWEN_RAW_OUTPUT] $filename: $responseText', name: 'AiTradeExtractor');

      // 2. Clean markdown fences
      String cleanResponse(String raw) {
        return raw
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      }
      
      final cleanJson = cleanResponse(responseText);

      dynamic decoded;
      try {
        decoded = json.decode(cleanJson);
      } catch (e) {
        // 3. Log specifically if parsing fails
        developer.log('[QWEN_PARSE_FAIL] JSON parse failed for $filename. Raw output was: $responseText', name: 'AiTradeExtractor');
        return [];
      }

      // Handle both array format and object-with-trades format
      List<dynamic> tradesList;
      if (decoded is List) {
        tradesList = decoded;
      } else if (decoded is Map<String, dynamic>) {
        tradesList = decoded['trades'] as List<dynamic>? ?? [];
      } else {
        developer.log('[QWEN] Unexpected response type: ${decoded.runtimeType}', name: 'AiTradeExtractor');
        return [];
      }

      return tradesList
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      developer.log('[QWEN] Invocation failed: $e', name: 'AiTradeExtractor', error: e);
      return [];
    }
  }

  /// Math validation: qty × price must be within ±1% of tradeValue.
  /// Returns an EmailParsedTrade if validation passes, null if it fails.
  EmailParsedTrade? _mathValidate(
    Map<String, dynamic> t,
    DateTime emailDate,
    String sourceMessageHash,
    int confidence,
  ) {
    try {
      final symbol = (t['symbol'] as String?)?.trim() ?? '';
      final typeStr = (t['type'] as String?)?.toUpperCase() ?? 'BUY';
      final qty = (t['qty'] as num?)?.toDouble() ?? 0.0;
      final price = (t['price'] as num?)?.toDouble() ?? 0.0;
      final tradeValue = (t['tradeValue'] as num?)?.toDouble() ?? 0.0;
      final tradeNo = (t['tradeNo'] as String?)?.trim();
      final time = (t['time'] as String?)?.trim();

      if (symbol.isEmpty || qty <= 0 || price <= 0) {
        developer.log('[MATH] Rejected: missing critical fields. $t', name: 'AiTradeExtractor');
        return null;
      }

      final calculated = qty * price;

      // If tradeValue is 0 or missing, we can't validate — treat as fail
      if (tradeValue <= 0) {
        developer.log('[MATH] Rejected: tradeValue is 0 or missing. $t', name: 'AiTradeExtractor');
        return null;
      }

      final deviation = (calculated - tradeValue).abs() / tradeValue;

      if (deviation > 0.01) {
        developer.log(
          '[MATH] FAILED: $symbol | qty=$qty × price=$price = $calculated vs tradeValue=$tradeValue | deviation=${(deviation * 100).toStringAsFixed(2)}%',
          name: 'AiTradeExtractor',
        );
        return null;
      }

      developer.log(
        '[MATH] PASSED: $symbol | qty=$qty × price=$price = $calculated ≈ tradeValue=$tradeValue | deviation=${(deviation * 100).toStringAsFixed(2)}%',
        name: 'AiTradeExtractor',
      );

      final tradeType = typeStr.startsWith('S') ? TradeType.sell : TradeType.buy;

      return EmailParsedTrade(
        symbol: symbol,
        instrumentName: symbol,
        exchange: 'NSE',
        tradeType: tradeType,
        quantity: qty,
        pricePerUnit: price,
        charges: (tradeValue - calculated).abs(),
        tradeDate: emailDate,
        broker: 'NSE Direct',
        confidence: confidence,
        sourceMessageHash: sourceMessageHash,
        tradeNo: tradeNo,
        warnings: [
          'Qwen primary parse (confidence $confidence%)',
          if (time != null) 'Trade time: $time',
        ],
      );
    } catch (e) {
      developer.log('[MATH] Exception during validation: $e', name: 'AiTradeExtractor');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEGACY: Generic AI extraction for non-NSE-Direct brokers
  // ═══════════════════════════════════════════════════════════════════════════

  /// Given a discrete RawTradeCandidate, ask the AI to form trades.
  /// Used only for non-NSE-Direct documents.
  Future<List<EmailParsedTrade>> extractTrades({
    required RawTradeCandidate candidate,
    required String documentTypeLabel,
    required DateTime emailDate,
    required String sourceMessageHash,
  }) async {
    final truncatedText = candidate.rawText.length > 2000
        ? candidate.rawText.substring(0, 2000)
        : candidate.rawText;

    final prompt = '''
<|im_start|>system
You are a precision financial extraction system. Return only formatting valid JSON arrays. No explanation. No markdown.<|im_end|>
<|im_start|>user
Your exact job is to extract trades from a messy broker "$documentTypeLabel" PDF.

RULES:
1. Output ONLY valid JSON containing the trades. No markdown, no explanations.
2. The JSON must exactly match the schema below.
3. If no executed trades are found, return an empty "trades" array.
4. "side" must be either "BUY" or "SELL".
5. "confidence" must be a float between 0.0 and 1.0.
6. Do NOT hallucinate data.

SCHEMA:
{"trades":[{"security_name":"...","symbol":"...","exchange":"NSE","side":"BUY","quantity":0,"price":0.0,"traded_value":0.0,"trade_no":"...","broker":"...","confidence":0.0}]}

TEXT TO EXTRACT FROM:
$truncatedText
<|im_end|>
<|im_start|>assistant
''';

    try {
      final modelPath = await ModelDownloadService.getModelPath();
      final responseText = await _channel.invokeMethod<String>('extractAiTrades', {
        'promptText': prompt,
        'modelPath': modelPath,
      });

      if (responseText == null || responseText.isEmpty) return [];

      final cleanJson = responseText.replaceAll(RegExp(r'```json\n?|```\n?'), '').trim();
      final parsed = json.decode(cleanJson) as Map<String, dynamic>;
      final tradesList = parsed['trades'] as List<dynamic>? ?? [];
      final extractedTrades = <EmailParsedTrade>[];

      for (final t in tradesList) {
        if (t is! Map<String, dynamic>) continue;
        try {
          final symbol = (t['symbol'] as String?)?.trim() ?? '';
          final sideStr = (t['side'] as String?)?.toUpperCase() ?? 'BUY';
          final quantity = (t['quantity'] as num?)?.toDouble() ?? 0.0;
          final price = (t['price'] as num?)?.toDouble() ?? 0.0;
          if (quantity <= 0 || price <= 0) continue;

          final confidence = (((t['confidence'] as num?)?.toDouble() ?? 1.0) * 100).toInt().clamp(0, 100);
          if (confidence < 85) continue;

          extractedTrades.add(EmailParsedTrade(
            symbol: symbol.isNotEmpty ? symbol : 'UNKNOWN',
            instrumentName: (t['security_name'] as String?)?.trim() ?? symbol,
            exchange: (t['exchange'] as String?)?.toUpperCase() ?? 'NSE',
            tradeType: sideStr.startsWith('S') ? TradeType.sell : TradeType.buy,
            quantity: quantity,
            pricePerUnit: price,
            tradeDate: emailDate,
            broker: (t['broker'] as String?)?.trim() ?? 'Unknown',
            confidence: confidence,
            sourceMessageHash: sourceMessageHash,
            tradeNo: (t['trade_no'] as String?)?.trim(),
            warnings: ['Extracted via legacy AI ($confidence%)'],
          ));
        } catch (_) {}
      }
      return extractedTrades;
    } catch (e) {
      developer.log('Legacy AI extraction failed: $e', name: 'AiTradeExtractor', error: e);
      return [];
    }
  }
}
