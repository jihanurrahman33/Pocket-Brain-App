import '../../../core/error/failure.dart';
import '../../../core/error/guard.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/id_generator.dart';
import '../../entities/recall.dart';
import '../../entities/task_item.dart';
import '../../repositories/memory_repository.dart';
import '../../repositories/task_repository.dart';

/// Groups tasks into overdue / upcoming / anytime / completed and attaches
/// the memories they came from.
final class GetTaskBoard implements UseCase<Result<TaskBoard>, NoParams> {
  const GetTaskBoard(this._tasks, this._memories, this._clock, this._logger);

  final TaskRepository _tasks;
  final MemoryRepository _memories;
  final Clock _clock;
  final AppLogger _logger;

  @override
  Future<Result<TaskBoard>> call(NoParams _) => guard(_logger, 'Load tasks', () async {
    final now = _clock.now();
    final all = await _tasks.getAll();
    final open = all.where((t) => !t.isDone).toList();
    final sources = await _memories.getByIds({for (final t in all) ?t.memoryId}.toList());
    return TaskBoard(
      overdue: open.where((t) => t.isOverdue(now)).toList(),
      upcoming: open.where((t) => t.dueAt != null && !t.isOverdue(now)).toList(),
      anytime: open.where((t) => t.dueAt == null).toList(),
      completed: all.where((t) => t.isDone).toList(),
      sourceMemories: {for (final m in sources) m.id: m},
    );
  });
}

typedef NewTask = ({String title, DateTime? dueAt, String? memoryId});

final class AddTask implements UseCase<Result<TaskItem>, NewTask> {
  const AddTask(this._tasks, this._ids, this._clock, this._logger);

  final TaskRepository _tasks;
  final IdGenerator _ids;
  final Clock _clock;
  final AppLogger _logger;

  @override
  Future<Result<TaskItem>> call(NewTask params) async {
    final title = params.title.trim();
    if (title.isEmpty) return const Err(ValidationFailure('Describe the task.'));
    return guard(_logger, 'Add task', () async {
      final task = TaskItem(
        id: _ids.next(),
        title: title,
        dueAt: params.dueAt,
        memoryId: params.memoryId,
        createdAt: _clock.now(),
      );
      await _tasks.save(task);
      return task;
    });
  }
}

final class ToggleTaskDone implements UseCase<Result<void>, TaskItem> {
  const ToggleTaskDone(this._tasks, this._logger);

  final TaskRepository _tasks;
  final AppLogger _logger;

  @override
  Future<Result<void>> call(TaskItem task) =>
      guard(_logger, 'Toggle task', () => _tasks.save(task.copyWith(isDone: !task.isDone)));
}

typedef ReminderChange = ({TaskItem task, DateTime? at});

final class SetTaskReminder implements UseCase<Result<void>, ReminderChange> {
  const SetTaskReminder(this._tasks, this._logger);

  final TaskRepository _tasks;
  final AppLogger _logger;

  @override
  Future<Result<void>> call(ReminderChange params) => guard(
    _logger,
    'Set reminder',
    () => _tasks.save(params.task.copyWith(reminderAt: () => params.at)),
  );
}

final class DeleteTask implements UseCase<Result<void>, String> {
  const DeleteTask(this._tasks, this._logger);

  final TaskRepository _tasks;
  final AppLogger _logger;

  @override
  Future<Result<void>> call(String id) => guard(_logger, 'Delete task', () => _tasks.delete(id));
}
