import '../../domain/entities/conversation.dart';
import '../../domain/entities/memory.dart';
import '../../domain/entities/memory_collection.dart';
import '../../domain/entities/task_item.dart';
import '../../domain/repositories/data_export_repository.dart';

/// Converts an [ExportBundle] to portable JSON. Embeddings are derived data
/// and are not exported.
abstract final class ExportMapper {
  static const formatVersion = 1;

  static Map<String, Object?> toJson(ExportBundle b) => {
    'format': 'pocket-brain-export',
    'version': formatVersion,
    'exportedAt': b.exportedAt.toIso8601String(),
    'memories': b.memories.map(_memory).toList(),
    'collections': b.collections.map(_collection).toList(),
    'tasks': b.tasks.map(_task).toList(),
    'conversations': b.conversations.map(_conversation).toList(),
  };

  static Map<String, Object?> _memory(Memory m) => {
    'id': m.id,
    'title': m.title,
    'content': m.content,
    'summary': m.summary,
    'source': m.source.name,
    'sourceUrl': m.sourceUrl,
    'category': m.category,
    'tags': m.tags,
    'collectionId': m.collectionId,
    'isFavorite': m.isFavorite,
    'isArchived': m.isArchived,
    'aiGenerated': m.aiGenerated,
    'createdAt': m.createdAt.toIso8601String(),
    'updatedAt': m.updatedAt.toIso8601String(),
  };

  static Map<String, Object?> _collection(MemoryCollection c) => {
    'id': c.id,
    'name': c.name,
    'emoji': c.emoji,
    'isPrivate': c.isPrivate,
    'createdAt': c.createdAt.toIso8601String(),
  };

  static Map<String, Object?> _task(TaskItem t) => {
    'id': t.id,
    'title': t.title,
    'dueAt': t.dueAt?.toIso8601String(),
    'reminderAt': t.reminderAt?.toIso8601String(),
    'isDone': t.isDone,
    'memoryId': t.memoryId,
    'createdAt': t.createdAt.toIso8601String(),
  };

  static Map<String, Object?> _conversation(Conversation c) => {
    'id': c.id,
    'title': c.title,
    'collectionId': c.collectionId,
    'createdAt': c.createdAt.toIso8601String(),
  };
}
