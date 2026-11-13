import '../../../core/bloc/load_state.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../domain/entities/recall.dart';
import '../../../domain/entities/task_item.dart';
import '../../../domain/usecases/memories/memory_usecases.dart';
import '../../../domain/usecases/tasks/task_usecases.dart';

/// The use cases the detail screen can trigger, grouped so the cubit's
/// constructor stays readable (Parameter Object).
class MemoryDetailActions {
  const MemoryDetailActions({
    required this.getDetails,
    required this.toggleFavorite,
    required this.toggleArchived,
    required this.moveToCollection,
    required this.editMemory,
    required this.deleteMemory,
    required this.addTask,
    required this.toggleTask,
  });

  final GetMemoryDetails getDetails;
  final ToggleFavorite toggleFavorite;
  final ToggleArchived toggleArchived;
  final MoveMemoryToCollection moveToCollection;
  final EditMemory editMemory;
  final DeleteMemory deleteMemory;
  final AddTask addTask;
  final ToggleTaskDone toggleTask;
}

/// One memory with its related memories and tasks.
///
/// Commands return the [Failure] to show, or null on success.
class MemoryDetailCubit extends AutoRefreshCubit<MemoryDetails> {
  MemoryDetailCubit({
    required this.memoryId,
    required MemoryDetailActions actions,
    required super.changes,
  }) : _actions = actions;

  final String memoryId;
  final MemoryDetailActions _actions;

  @override
  Future<Result<MemoryDetails>> fetch() => _actions.getDetails(memoryId);

  Future<Failure?> toggleFavorite() async =>
      (await _actions.toggleFavorite(memoryId)).failureOrNull;

  Future<Failure?> toggleArchived() async =>
      (await _actions.toggleArchived(memoryId)).failureOrNull;

  Future<Failure?> moveToCollection(String? collectionId) async =>
      (await _actions.moveToCollection((memoryId: memoryId, collectionId: collectionId)))
          .failureOrNull;

  Future<Failure?> edit(MemoryEdit edit) async => (await _actions.editMemory(edit)).failureOrNull;

  Future<Failure?> delete() async => (await _actions.deleteMemory(memoryId)).failureOrNull;

  Future<Failure?> addTask(String title, DateTime? dueAt) async =>
      (await _actions.addTask((title: title, dueAt: dueAt, memoryId: memoryId))).failureOrNull;

  Future<Failure?> toggleTask(TaskItem task) async =>
      (await _actions.toggleTask(task)).failureOrNull;
}
