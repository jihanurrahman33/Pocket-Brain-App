import '../../../core/error/failure.dart';
import '../../../core/error/guard.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/id_generator.dart';
import '../../entities/memory.dart';
import '../../entities/memory_collection.dart';
import '../../entities/search.dart';
import '../../repositories/collection_repository.dart';
import '../../repositories/memory_repository.dart';

final class GetCollections implements UseCase<Result<List<MemoryCollection>>, NoParams> {
  const GetCollections(this._collections, this._logger);

  final CollectionRepository _collections;
  final AppLogger _logger;

  @override
  Future<Result<List<MemoryCollection>>> call(NoParams _) =>
      guard(_logger, 'Load collections', _collections.getAll);
}

/// A collection with its memories.
typedef CollectionContents = ({MemoryCollection collection, List<Memory> memories});

final class GetCollectionContents implements UseCase<Result<CollectionContents>, String> {
  const GetCollectionContents(this._collections, this._memories, this._logger);

  final CollectionRepository _collections;
  final MemoryRepository _memories;
  final AppLogger _logger;

  @override
  Future<Result<CollectionContents>> call(String id) => guard(_logger, 'Load collection', () async {
    final collection = await _collections.getById(id);
    if (collection == null) throw const FailureException(NotFoundFailure());
    final memories = await _memories.query(MemoryQuery(collectionId: id));
    return (collection: collection, memories: memories);
  });
}

typedef NewCollection = ({String name, String emoji, bool isPrivate});

final class CreateCollection implements UseCase<Result<MemoryCollection>, NewCollection> {
  const CreateCollection(this._collections, this._ids, this._clock, this._logger);

  final CollectionRepository _collections;
  final IdGenerator _ids;
  final Clock _clock;
  final AppLogger _logger;

  static const maxNameLength = 40;

  @override
  Future<Result<MemoryCollection>> call(NewCollection params) async {
    final name = params.name.trim();
    if (name.isEmpty) return const Err(ValidationFailure('Give the collection a name.'));
    if (name.length > maxNameLength) {
      return const Err(
        ValidationFailure('Collection names are limited to $maxNameLength characters.'),
      );
    }
    return guard(_logger, 'Create collection', () async {
      final existing = await _collections.getAll();
      if (existing.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
        throw FailureException(ValidationFailure('You already have "$name".'));
      }
      final collection = MemoryCollection(
        id: _ids.next(),
        name: name,
        emoji: params.emoji,
        isPrivate: params.isPrivate,
        createdAt: _clock.now(),
      );
      await _collections.save(collection);
      return collection;
    });
  }
}

final class DeleteCollection implements UseCase<Result<void>, String> {
  const DeleteCollection(this._collections, this._logger);

  final CollectionRepository _collections;
  final AppLogger _logger;

  @override
  Future<Result<void>> call(String id) =>
      guard(_logger, 'Delete collection', () => _collections.delete(id));
}
