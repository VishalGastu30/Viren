import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmotionRecallService — Stores and retrieves user trade notes.
//
// Notes are stored as EMOTION_NOTE alert rows:
//   - alertType: 'EMOTION_NOTE'
//   - relatedInstrument: symbol
//   - description: the user's note text
//   - triggerData: { 'tradeId': '...', 'tradeDate': '...', 'tradePrice': 0.0 }
//   - dismissedAt: null (notes are permanent)
//   - snoozedUntil: null
//
// This is a zero-migration solution — no new columns needed.
// EMOTION_NOTE rows are filtered from the insights feed and replay screen.
// ─────────────────────────────────────────────────────────────────────────────

class EmotionRecallService {
  final AppDatabase _db;
  final _uuid = const Uuid();

  EmotionRecallService(this._db);

  /// Saves or updates a note for a specific trade.
  /// If a note already exists for this tradeId, it is updated in place.
  Future<void> saveNote({
    required String tradeId,
    required String symbol,
    required String noteText,
    required DateTime tradeDate,
    required double tradePrice,
  }) async {
    if (noteText.trim().isEmpty) {
      await deleteNote(tradeId: tradeId, symbol: symbol);
      return;
    }

    final existing = await _getNoteForTrade(tradeId);
    final data = jsonEncode({
      'tradeId': tradeId,
      'tradeDate': tradeDate.toIso8601String(),
      'tradePrice': tradePrice,
    });

    if (existing != null) {
      await (_db.update(_db.alerts)
            ..where((a) => a.id.equals(existing.id)))
          .write(AlertsCompanion(
        description: Value(noteText.trim()),
        triggerData: Value(data),
      ));
    } else {
      await _db.into(_db.alerts).insert(
        AlertsCompanion.insert(
          id: _uuid.v4(),
          alertType: 'EMOTION_NOTE',
          severity: AlertSeverity.info,
          title: 'Note: $symbol',
          description: noteText.trim(),
          relatedInstrument: Value(symbol),
          triggerData: Value(data),
          // Never dismissed — notes are permanent until user deletes
        ),
      );
    }
  }

  /// Deletes a note for a specific trade.
  Future<void> deleteNote({
    required String tradeId,
    required String symbol,
  }) async {
    final existing = await _getNoteForTrade(tradeId);
    if (existing == null) return;
    await (_db.delete(_db.alerts)
          ..where((a) => a.id.equals(existing.id)))
        .go();
  }

  /// Returns the note text for a specific trade, or null if none.
  Future<String?> getNoteText(String tradeId) async {
    final note = await _getNoteForTrade(tradeId);
    return note?.description;
  }

  /// Returns all notes for a specific symbol, newest first.
  Future<List<Alert>> getNotesForSymbol(String symbol) async {
    return (_db.select(_db.alerts)
          ..where((a) =>
              a.alertType.equals('EMOTION_NOTE') &
              a.relatedInstrument.equals(symbol.toUpperCase()) &
              a.dismissedAt.isNull())
          ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
        .get();
  }

  Future<Alert?> _getNoteForTrade(String tradeId) async {
    final notes = await (_db.select(_db.alerts)
          ..where((a) =>
              a.alertType.equals('EMOTION_NOTE') &
              a.dismissedAt.isNull()))
        .get();

    for (final note in notes) {
      try {
        final data =
            jsonDecode(note.triggerData) as Map<String, dynamic>;
        if (data['tradeId'] == tradeId) return note;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
