import 'package:drift/drift.dart';
import '../../core/database/app_database.dart';

class ConversationRepository {
  final AppDatabase _db;
  ConversationRepository(this._db);

  Future<Conversation> createConversation() async {
    final now = DateTime.now();
    final id = await _db.into(_db.conversations).insert(
      ConversationsCompanion.insert(
        title: 'New conversation',
        createdAt: now,
        updatedAt: now,
      ),
    );
    return Conversation(
      id: id,
      title: 'New conversation',
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<Conversation>> getAllConversations() {
    return (_db.select(_db.conversations)
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .get();
  }

  Stream<List<Conversation>> watchAllConversations() {
    return (_db.select(_db.conversations)
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .watch();
  }

  Future<List<ConversationMessage>> getMessages(int conversationId) {
    return (_db.select(_db.conversationMessages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .get();
  }

  Stream<List<ConversationMessage>> watchMessages(int conversationId) {
    return (_db.select(_db.conversationMessages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .watch();
  }

  Future<ConversationMessage> addMessage({
    required int conversationId,
    required String text,
    required bool isUser,
    bool isError = false,
  }) async {
    final now = DateTime.now();
    final id = await _db.into(_db.conversationMessages).insert(
      ConversationMessagesCompanion.insert(
        conversationId: conversationId,
        messageText: text,
        isUser: isUser,
        timestamp: now,
        isError: Value(isError),
      ),
    );
    // Update conversation's updatedAt
    await (_db.update(_db.conversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(ConversationsCompanion(updatedAt: Value(now)));
    return ConversationMessage(
      id: id,
      conversationId: conversationId,
      messageText: text,
      isUser: isUser,
      timestamp: now,
      isError: isError,
    );
  }

  Future<void> setTitle(int conversationId, String title) async {
    await (_db.update(_db.conversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(ConversationsCompanion(title: Value(title)));
  }

  Future<void> autoTitle(int conversationId, String firstUserMessage) async {
    final raw = firstUserMessage.trim();
    final title = raw.length > 40 ? '${raw.substring(0, 40)}...' : raw;
    await setTitle(conversationId, title);
  }

  Future<void> deleteConversation(int conversationId) async {
    await (_db.delete(_db.conversationMessages)
          ..where((m) => m.conversationId.equals(conversationId)))
        .go();
    await (_db.delete(_db.conversations)
          ..where((c) => c.id.equals(conversationId)))
        .go();
  }
}
