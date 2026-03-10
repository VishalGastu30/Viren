import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import '../../core/database/app_database.dart';
import '../../core/ai/model_download_service.dart';

class MemoryService {
  final AppDatabase db;
  static const _channel = MethodChannel('com.viren.viren/pdf_crypto');

  // Maximum number of memories to keep — older ones are pruned
  static const _maxMemories = 10;

  MemoryService(this.db);

  /// Call this when a conversation ends (user starts new chat or closes app).
  /// Summarises the conversation and stores it as a memory.
  /// Only runs if the conversation had at least 2 exchanges.
  Future<void> summariseAndStore({
    required int conversationId,
    required List<Map<String, String>> messages, // [{role: user/viren, text: ...}]
  }) async {
    // Need at least 2 user messages to be worth summarising
    final userMessages = messages.where((m) => m['role'] == 'user').toList();
    if (userMessages.length < 2) return;

    // Check if memory for this conversation already exists
    final existing = await (db.select(db.assistantMemories)
          ..where((m) => m.conversationId.equals(conversationId)))
        .get();
    if (existing.isNotEmpty) return;

    try {
      final conversationText = messages
          .map((m) => '${m['role'] == 'user' ? 'User' : 'Viren'}: ${m['text']}')
          .join('\n');

      final summaryPrompt =
          'Summarise this investment conversation in 3 bullet points. '
          'Max 60 words total. Focus on: what the user asked about, '
          'what data was discussed, any specific stocks or numbers mentioned. '
          'Plain text, no markdown.\n\n$conversationText\n\nSummary:';

      final modelPath = await ModelDownloadService.getModelPath();
      final String? summary = await _channel.invokeMethod('chat', {
        'prompt': summaryPrompt,
        'modelPath': modelPath,
      });

      if (summary == null || summary.trim().isEmpty) return;

      await db.into(db.assistantMemories).insert(
        AssistantMemoriesCompanion.insert(
          conversationId: conversationId,
          summary: summary.trim(),
          createdAt: DateTime.now(),
        ),
      );

      // Prune old memories — keep only the most recent _maxMemories
      await _pruneOldMemories();
    } catch (_) {
      // Memory generation failing should never crash the app
    }
  }

  /// Returns the last 3 memories formatted as a compact context block.
  /// Returns empty string if no memories exist.
  Future<String> getMemoryContext() async {
    final memories = await (db.select(db.assistantMemories)
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
          ..limit(3))
        .get();

    if (memories.isEmpty) return '';

    final buffer = StringBuffer('From previous conversations:\n');
    for (final m in memories) {
      buffer.writeln('- ${m.summary}');
    }
    return buffer.toString();
  }

  Future<void> _pruneOldMemories() async {
    final all = await (db.select(db.assistantMemories)
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();

    if (all.length > _maxMemories) {
      final toDelete = all.sublist(_maxMemories);
      for (final m in toDelete) {
        await (db.delete(db.assistantMemories)
              ..where((row) => row.id.equals(m.id)))
            .go();
      }
    }
  }

  /// Call this to wipe all memories — exposed in Settings.
  Future<void> clearAllMemories() async {
    await db.delete(db.assistantMemories).go();
  }
}
