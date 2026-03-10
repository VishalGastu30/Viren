import 'package:drift/drift.dart';

class AssistantMemories extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Which conversation this memory came from
  IntColumn get conversationId => integer()();
  // The compressed summary — max 80 words
  TextColumn get summary => text()();
  // When this memory was created
  DateTimeColumn get createdAt => dateTime()();
}
