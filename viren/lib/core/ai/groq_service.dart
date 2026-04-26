import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GroqException implements Exception {
  final String message;
  final bool isConnectionError;

  GroqException(this.message, {this.isConnectionError = false});

  @override
  String toString() => message;
}

class GroqService {
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  // Two-tier model selection
  static const heavyModel = 'llama-3.3-70b-versatile';   // chat, digests, briefings
  static const lightModel = 'llama-3.1-8b-instant';      // classification, scoring

  static String get _apiKey {
    final key = dotenv.env['GROQ_API']?.replaceAll('"', '');
    if (key == null || key.isEmpty) {
      throw GroqException('GROQ_API key is missing from .env');
    }
    return key;
  }

  /// Core method: send a prompt, get a response.
  static Future<String> chat({
    required String prompt,
    String? systemPrompt,
    String model = heavyModel,
    double temperature = 0.7,
    int maxTokens = 2048,
    List<Map<String, String>>? history,
  }) async {
    try {
      final messages = <Map<String, String>>[];
      
      if (systemPrompt != null) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }

      if (history != null) {
        messages.addAll(history);
      }

      messages.add({'role': 'user', 'content': prompt});

      final response = await _sendRequest(
        model: model,
        messages: messages,
        temperature: temperature,
        maxTokens: maxTokens,
      );

      return response['choices'][0]['message']['content']?.trim() ?? '';
    } on SocketException {
      throw GroqException('Viren requires an active internet connection to synthesize your portfolio data. Please check your network and try again.', isConnectionError: true);
    } catch (e) {
      if (e is GroqException) rethrow;
      debugPrint('GroqService error: $e');
      throw GroqException('Failed to communicate with AI: $e');
    }
  }

  /// Structured JSON output (for news scoring, classification)
  static Future<Map<String, dynamic>?> chatJson({
    required String prompt,
    String? systemPrompt,
    String model = lightModel,
    double temperature = 0.0,
  }) async {
    try {
      final messages = <Map<String, String>>[];
      
      if (systemPrompt != null) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }

      messages.add({'role': 'user', 'content': prompt});

      final response = await _sendRequest(
        model: model,
        messages: messages,
        temperature: temperature,
        maxTokens: 1024,
        responseFormat: {'type': 'json_object'},
      );

      final content = response['choices'][0]['message']['content'];
      if (content == null) return null;

      try {
        return jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    } on SocketException {
      throw GroqException('Viren requires an active internet connection.', isConnectionError: true);
    } catch (e) {
      if (e is GroqException) rethrow;
      debugPrint('GroqService JSON error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> _sendRequest({
    required String model,
    required List<Map<String, String>> messages,
    required double temperature,
    required int maxTokens,
    Map<String, dynamic>? responseFormat,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    if (responseFormat != null) {
      body['response_format'] = responseFormat;
    }

    // Basic retry logic for rate limits (429)
    int maxRetries = 2;
    int currentTry = 0;

    while (currentTry <= maxRetries) {
      final res = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else if (res.statusCode == 429) {
        currentTry++;
        if (currentTry <= maxRetries) {
          await Future.delayed(Duration(seconds: 1 * currentTry));
          continue;
        }
      }

      throw GroqException('API Error ${res.statusCode}: ${res.body}');
    }

    throw GroqException('Failed after retries');
  }
}
