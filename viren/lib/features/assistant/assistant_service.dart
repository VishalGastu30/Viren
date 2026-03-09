import 'package:flutter/services.dart';
import '../../core/ai/model_download_service.dart';
import 'chat_message.dart';

class AssistantService {
  static const _channel = MethodChannel('com.viren.viren/pdf_crypto');

  static const _systemPrompt = '''
You are Viren, a private investment companion.
You have complete access to the user's portfolio data provided below.
Your personality:
- Calm, precise, never excited
- Short sentences. No unnecessary words.
- Never use emojis
- Never start a response with "Great question!", "Certainly!", "Of course!", "Sure!" or any filler phrase
- Never give investment advice
- Never say buy, sell, hold, or recommend any action
- Never predict prices or market movements
- Speak like a trusted analyst reviewing facts
What you can do:
- Answer questions about the portfolio factually using the data provided
- Calculate and explain returns, charges, holding periods
- Describe patterns in trading behavior
- Compare holdings against each other using the numbers
- Explain what the data means in plain language
What you must never do:
- Predict future prices
- Recommend any action
- Fabricate any number not present in the context
- Comment on whether any stock is a good or bad investment
If asked for investment advice respond with exactly:
"I can show you the data. The decision is yours."
Keep responses under 150 words unless a detailed breakdown is genuinely needed.
Do not use markdown formatting. Write in plain text only.
''';

  Future<String> sendMessage({
    required String userMessage,
    required String portfolioContext,
    required List<ChatMessage> history,
  }) async {
    try {
      final modelPath = await ModelDownloadService.getModelPath();

      // Guard: if the file doesn't exist at this path, throw immediately
      // so the caller's catch block handles it — not a silent empty string.
      // This prevents the diagnostic in model_setup_screen from treating
      // a MODEL_MISSING response as a passing result.
      final fileExists = await ModelDownloadService.modelFileExists();
      if (!fileExists) {
        throw Exception('MODEL_FILE_MISSING: file not found at $modelPath');
      }

      final historyStr = history.length > 6
          ? history.sublist(history.length - 6)
          : history;
      final historyFormatted = historyStr
          .map((m) => '${m.isUser ? "User" : "Viren"}: ${m.text}')
          .join('\n');

      final fullPrompt = '''
$_systemPrompt
$portfolioContext
Conversation so far:
$historyFormatted
User: $userMessage
Viren:''';

      final String? response = await _channel.invokeMethod('chat', {
        'prompt': fullPrompt,
        'modelPath': modelPath,
      });

      if (response == null || response.trim().isEmpty) {
        return "I did not get a response. Try again in a moment.";
      }

      return response.trim();
    } on PlatformException catch (e) {
      if (e.code == 'MODEL_MISSING') {
        // Re-throw so callers like model_setup_screen can detect actual failure
        // rather than silently receiving a friendly string that looks like success.
        throw Exception('MODEL_FILE_MISSING: ${e.message}');
      }
      // For all other platform errors, re-throw so callers handle them explicitly.
      throw Exception('PLATFORM_ERROR: code=${e.code} message=${e.message}');
    } catch (e) {
      rethrow;
    }
  }
}