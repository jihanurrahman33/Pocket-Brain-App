import '../entities/conversation.dart';
import '../entities/memory.dart';
import '../entities/memory_collection.dart';
import '../entities/task_item.dart';

/// A snapshot of the user's data for export.
class ExportBundle {
  const ExportBundle({
    required this.exportedAt,
    required this.memories,
    required this.collections,
    required this.tasks,
    required this.conversations,
  });

  final DateTime exportedAt;
  final List<Memory> memories;
  final List<MemoryCollection> collections;
  final List<TaskItem> tasks;
  final List<Conversation> conversations;
}

/// Writes exports somewhere the user can reach them.
abstract interface class DataExportRepository {
  /// Returns a human-readable location of the written file.
  Future<String> write(ExportBundle bundle);
}
