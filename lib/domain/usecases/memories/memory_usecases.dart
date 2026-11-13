import 'dart:async';

import 'package:stream_transform/stream_transform.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/guard.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../entities/memory.dart';
import '../../entities/recall.dart';
import '../../entities/search.dart';
import '../../repositories/change_notifier.dart';
import '../../repositories/collection_repository.dart';
import '../../repositories/memory_repository.dart';
import '../../repositories/task_repository.dart';
import '../indexing/indexing_usecases.dart';
import '../search/search_usecases.dart';

/// Emits whenever any observed store changes, so screens can refresh.
final class ObserveDataChanges implements StreamUseCase<void, NoParams> {
  const ObserveDataChanges(this._sources);

  final List<ChangeSource> _sources;

  @override
  Stream<void> call(NoParams _) => switch (_sources) {
    [] => const Stream.empty(),
    [final only] => only.changes,
    [final first, ...final rest] => first.changes.mergeAll(rest.map((s) => s.changes)),
  };
}

final class GetMemories implements UseCase<Result<List<Memory>>, MemoryQuery> {
  const GetMemories(this._memories, this._logger);

  final MemoryRepository _memories;
  final AppLogger _logger;

  @override
  Future<Result<List<Memory>>> call(MemoryQuery query) =>
      guard(_logger, 'Load memories', () => _memories.query(query));
}

final class GetCategories implements UseCase<Result<List<String>>, NoParams> {
  const GetCategories(this._memories, this._logger);

  final MemoryRepository _memories;
  final AppLogger _logger;

  @override
  Future<Result<List<String>>> call(NoParams _) =>
      guard(_logger, 'Load categories', _memories.categories);
}

/// Loads a memory with its related memories, tasks and the collections it
/// can be moved to, and records that the user viewed it.
final class GetMemoryDetails implements UseCase<Result<MemoryDetails>, String> {
  GetMemoryDetails({
    required MemoryRepository memories,
    required MemoryMetadataStore metadata,
    required TaskRepository tasks,
    required CollectionRepository collections,
    required FindSimilarMemories findSimilar,
    required Clock clock,
    required AppLogger logger,
  }) : _memories = memories,
       _metadata = metadata,
       _tasks = tasks,
       _collections = collections,
       _findSimilar = findSimilar,
       _clock = clock,
       _logger = logger;

  final MemoryRepository _memories;
  final MemoryMetadataStore _metadata;
  final TaskRepository _tasks;
  final CollectionRepository _collections;
  final FindSimilarMemories _findSimilar;
  final Clock _clock;
  final AppLogger _logger;

  @override
  Future<Result<MemoryDetails>> call(String id) => guard(_logger, 'Load memory', () async {
    final memory = await _memories.getById(id);
    if (memory == null) throw const FailureException(NotFoundFailure());
    await _metadata.markViewed(id, _clock.now());
    final related = await _findSimilar(
      SimilarityQuery(text: memory.searchableText, vector: memory.embedding, excludeId: memory.id),
    );
    return MemoryDetails(
      memory: memory,
      related: [for (final r in related) r.memory],
      tasks: await _tasks.forMemory(id),
      collections: await _collections.getAll(),
    );
  });
}

/// Base for commands that change one memory (Template Method pattern):
/// subclasses only describe the change.
abstract base class _MemoryCommand<P> implements UseCase<Result<void>, P> {
  const _MemoryCommand(this._memories, this._clock, this._logger);

  final MemoryRepository _memories;
  final Clock _clock;
  final AppLogger _logger;

  String idOf(P params);

  Memory apply(Memory memory, P params);

  /// Hook run after a successful save.
  Future<void> afterSave(Memory memory) async {}

  @override
  Future<Result<void>> call(P params) => guard(_logger, runtimeType.toString(), () async {
    final memory = await _memories.getById(idOf(params));
    if (memory == null) throw const FailureException(NotFoundFailure());
    final updated = apply(memory, params).copyWith(updatedAt: _clock.now());
    await _memories.save(updated);
    await afterSave(updated);
  });
}

final class ToggleFavorite extends _MemoryCommand<String> {
  const ToggleFavorite(super._memories, super._clock, super._logger);

  @override
  String idOf(String params) => params;

  @override
  Memory apply(Memory memory, String _) => memory.copyWith(isFavorite: !memory.isFavorite);
}

final class ToggleArchived extends _MemoryCommand<String> {
  const ToggleArchived(super._memories, super._clock, super._logger);

  @override
  String idOf(String params) => params;

  @override
  Memory apply(Memory memory, String _) => memory.copyWith(isArchived: !memory.isArchived);
}

typedef MoveToCollectionParams = ({String memoryId, String? collectionId});

final class MoveMemoryToCollection extends _MemoryCommand<MoveToCollectionParams> {
  const MoveMemoryToCollection(super._memories, super._clock, super._logger);

  @override
  String idOf(MoveToCollectionParams params) => params.memoryId;

  @override
  Memory apply(Memory memory, MoveToCollectionParams params) =>
      memory.copyWith(collectionId: () => params.collectionId);
}

/// The user's edits to a memory.
class MemoryEdit {
  const MemoryEdit({
    required this.id,
    required this.title,
    required this.content,
    required this.summary,
    required this.category,
    required this.tags,
  });

  final String id;
  final String title;
  final String content;
  final String summary;
  final String category;
  final List<String> tags;
}

/// Applies user edits; the memory is no longer "AI-generated as is" and is
/// re-indexed because its text changed.
final class EditMemory extends _MemoryCommand<MemoryEdit> {
  const EditMemory(super._memories, super._clock, super._logger, this._indexMemory);

  final IndexMemory _indexMemory;

  @override
  String idOf(MemoryEdit params) => params.id;

  @override
  Memory apply(Memory memory, MemoryEdit edit) {
    if (edit.title.trim().isEmpty) {
      throw const FailureException(ValidationFailure('A memory needs a title.'));
    }
    return memory.copyWith(
      title: edit.title.trim(),
      content: edit.content,
      summary: edit.summary.trim(),
      category: edit.category,
      tags: edit.tags,
      aiGenerated: false,
      embedding: () => null,
    );
  }

  @override
  Future<void> afterSave(Memory memory) async {
    unawaited(_indexMemory(memory));
  }
}

final class DeleteMemory implements UseCase<Result<void>, String> {
  const DeleteMemory(this._memories, this._logger);

  final MemoryRepository _memories;
  final AppLogger _logger;

  @override
  Future<Result<void>> call(String id) =>
      guard(_logger, 'Delete memory', () => _memories.delete(id));
}
