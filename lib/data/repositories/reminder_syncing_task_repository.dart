import '../../domain/entities/task_item.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/services/reminder_scheduler.dart';

/// Keeps notifications in step with tasks (Decorator): every save, delete
/// and wipe goes through here, so no use case has to remember to schedule
/// or cancel a reminder.
final class ReminderSyncingTaskRepository implements TaskRepository {
  const ReminderSyncingTaskRepository(this._inner, this._reminders);

  final TaskRepository _inner;
  final ReminderScheduler _reminders;

  @override
  Stream<void> get changes => _inner.changes;

  @override
  Future<List<TaskItem>> getAll() => _inner.getAll();

  @override
  Future<List<TaskItem>> forMemory(String memoryId) => _inner.forMemory(memoryId);

  @override
  Future<void> save(TaskItem task) async {
    await _inner.save(task);
    await _reminders.sync(task);
  }

  @override
  Future<void> delete(String id) async {
    await _inner.delete(id);
    await _reminders.cancel(id);
  }

  @override
  Future<void> clear() async {
    await _inner.clear();
    await _reminders.clear();
  }
}
