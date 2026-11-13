import '../../../core/bloc/load_state.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../domain/entities/recall.dart';
import '../../../domain/entities/task_item.dart';
import '../../../domain/usecases/tasks/task_usecases.dart';

/// Use cases for the Tasks screen (Parameter Object).
class TaskActions {
  const TaskActions({
    required this.getBoard,
    required this.addTask,
    required this.toggleTask,
    required this.setReminder,
    required this.deleteTask,
  });

  final GetTaskBoard getBoard;
  final AddTask addTask;
  final ToggleTaskDone toggleTask;
  final SetTaskReminder setReminder;
  final DeleteTask deleteTask;
}

class TasksCubit extends AutoRefreshCubit<TaskBoard> {
  TasksCubit({required TaskActions actions, required super.changes}) : _actions = actions;

  final TaskActions _actions;

  @override
  Future<Result<TaskBoard>> fetch() => _actions.getBoard.run();

  Future<Failure?> add(String title, DateTime? dueAt) async =>
      (await _actions.addTask(NewTask(title: title, dueAt: dueAt))).failureOrNull;

  Future<Failure?> toggle(TaskItem task) async => (await _actions.toggleTask(task)).failureOrNull;

  Future<Failure?> setReminder(TaskItem task, DateTime? at) async =>
      (await _actions.setReminder((task: task, at: at))).failureOrNull;

  Future<Failure?> delete(TaskItem task) async =>
      (await _actions.deleteTask(task.id)).failureOrNull;
}
