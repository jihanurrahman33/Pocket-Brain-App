import 'dart:convert';
import 'dart:typed_data';

import '../../domain/entities/conversation.dart';
import '../../domain/entities/memory.dart';
import '../../domain/entities/memory_collection.dart';
import '../../domain/entities/task_item.dart';

/// Converts between database rows and domain entities (Mapper pattern), so
/// entities stay free of persistence concerns.
typedef Row = Map<String, Object?>;

DateTime _date(Object? ms) => DateTime.fromMillisecondsSinceEpoch(ms! as int);

DateTime? _optionalDate(Object? ms) => ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

bool _bool(Object? v) => v == 1;

int _int(bool v) => v ? 1 : 0;

List<String> _stringList(Object? json) =>
    (jsonDecode(json! as String) as List<Object?>).cast<String>();

abstract final class MemoryMapper {
  static Memory fromRow(Row row) {
    final blob = row['embedding'] as Uint8List?;
    return Memory(
      id: row['id']! as String,
      title: row['title']! as String,
      content: row['content']! as String,
      summary: row['summary']! as String,
      source: MemorySource.values.asNameMap()[row['source']] ?? MemorySource.note,
      sourceUrl: row['source_url'] as String?,
      category: row['category']! as String,
      tags: _stringList(row['tags']),
      collectionId: row['collection_id'] as String?,
      isFavorite: _bool(row['is_favorite']),
      isArchived: _bool(row['is_archived']),
      createdAt: _date(row['created_at']),
      updatedAt: _date(row['updated_at']),
      lastViewedAt: _optionalDate(row['last_viewed_at']),
      aiGenerated: _bool(row['ai_generated']),
      embedding: blob == null ? null : vectorFromBytes(blob),
    );
  }

  static Row toRow(Memory m) => {
    'id': m.id,
    'title': m.title,
    'content': m.content,
    'summary': m.summary,
    'source': m.source.name,
    'source_url': m.sourceUrl,
    'category': m.category,
    'tags': jsonEncode(m.tags),
    'collection_id': m.collectionId,
    'is_favorite': _int(m.isFavorite),
    'is_archived': _int(m.isArchived),
    'created_at': m.createdAt.millisecondsSinceEpoch,
    'updated_at': m.updatedAt.millisecondsSinceEpoch,
    'last_viewed_at': m.lastViewedAt?.millisecondsSinceEpoch,
    'ai_generated': _int(m.aiGenerated),
    'embedding': m.embedding == null ? null : vectorToBytes(m.embedding!),
  };

  /// Copies so the vector owns aligned memory.
  static Float32List vectorFromBytes(Uint8List bytes) =>
      Float32List.view(Uint8List.fromList(bytes).buffer);

  static Uint8List vectorToBytes(Float32List v) =>
      v.buffer.asUint8List(v.offsetInBytes, v.lengthInBytes);
}

abstract final class CollectionMapper {
  static MemoryCollection fromRow(Row row) => MemoryCollection(
    id: row['id']! as String,
    name: row['name']! as String,
    emoji: row['emoji']! as String,
    isPrivate: _bool(row['is_private']),
    createdAt: _date(row['created_at']),
    memoryCount: (row['memory_count'] as int?) ?? 0,
  );

  static Row toRow(MemoryCollection c) => {
    'id': c.id,
    'name': c.name,
    'emoji': c.emoji,
    'is_private': _int(c.isPrivate),
    'created_at': c.createdAt.millisecondsSinceEpoch,
  };
}

abstract final class TaskMapper {
  static TaskItem fromRow(Row row) => TaskItem(
    id: row['id']! as String,
    title: row['title']! as String,
    dueAt: _optionalDate(row['due_at']),
    reminderAt: _optionalDate(row['reminder_at']),
    isDone: _bool(row['is_done']),
    memoryId: row['memory_id'] as String?,
    createdAt: _date(row['created_at']),
  );

  static Row toRow(TaskItem t) => {
    'id': t.id,
    'title': t.title,
    'due_at': t.dueAt?.millisecondsSinceEpoch,
    'reminder_at': t.reminderAt?.millisecondsSinceEpoch,
    'is_done': _int(t.isDone),
    'memory_id': t.memoryId,
    'created_at': t.createdAt.millisecondsSinceEpoch,
  };
}

abstract final class ConversationMapper {
  static Conversation fromRow(Row row) => Conversation(
    id: row['id']! as String,
    title: row['title']! as String,
    collectionId: row['collection_id'] as String?,
    createdAt: _date(row['created_at']),
  );

  static Row toRow(Conversation c) => {
    'id': c.id,
    'title': c.title,
    'collection_id': c.collectionId,
    'created_at': c.createdAt.millisecondsSinceEpoch,
  };

  static ChatMessage messageFromRow(Row row) => ChatMessage(
    id: row['id']! as String,
    conversationId: row['conversation_id']! as String,
    role: ChatRole.values.byName(row['role']! as String),
    text: row['text']! as String,
    sourceIds: _stringList(row['source_ids']),
    grounded: _bool(row['grounded']),
    createdAt: _date(row['created_at']),
  );

  static Row messageToRow(ChatMessage m) => {
    'id': m.id,
    'conversation_id': m.conversationId,
    'role': m.role.name,
    'text': m.text,
    'source_ids': jsonEncode(m.sourceIds),
    'grounded': _int(m.grounded),
    'created_at': m.createdAt.millisecondsSinceEpoch,
  };
}
