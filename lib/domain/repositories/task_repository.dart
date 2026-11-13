import '../entities/task_item.dart';
import 'change_notifier.dart';

/// Persistence for [TaskItem]s.
abstract interface class TaskRepository implements ChangeSource, Clearable {
  /// Open tasks first, then by due date.
  Future<List<TaskItem>> getAll();

  Future<List<TaskItem>> forMemory(String memoryId);

  /// Inserts or replaces.
  Future<void> save(TaskItem task);

  Future<void> delete(String id);
}
