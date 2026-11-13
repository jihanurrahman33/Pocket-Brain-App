import 'package:equatable/equatable.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/entities/memory_collection.dart';
import '../../../domain/entities/search.dart';
import '../../../domain/usecases/collections/collection_usecases.dart';
import '../../../domain/usecases/search/search_usecases.dart';

/// What the collection screen shows.
class CollectionView extends Equatable {
  const CollectionView({
    required this.collection,
    required this.memories,
    required this.totalCount,
    this.query = '',
  });

  final MemoryCollection collection;

  /// Memories matching [query] (all of them when it is blank).
  final List<Memory> memories;

  /// How many memories the collection holds, regardless of [query].
  final int totalCount;
  final String query;

  bool get isEmpty => totalCount == 0;

  @override
  List<Object?> get props => [collection, memories, totalCount, query];
}

/// One collection's memories, searchable via the shared search use case.
class CollectionCubit extends AutoRefreshCubit<CollectionView> {
  CollectionCubit({
    required this.collectionId,
    required GetCollectionContents getContents,
    required SearchMemories searchMemories,
    required DeleteCollection deleteCollection,
    required super.changes,
  }) : _getContents = getContents,
       _searchMemories = searchMemories,
       _deleteCollection = deleteCollection;

  final String collectionId;
  final GetCollectionContents _getContents;
  final SearchMemories _searchMemories;
  final DeleteCollection _deleteCollection;
  String _query = '';

  @override
  Future<Result<CollectionView>> fetch() async {
    final contents = await _getContents(collectionId);
    final query = _query;
    switch (contents) {
      case Err(:final failure):
        return Err(failure);
      case Success(value: (:final collection, :final memories)):
        if (query.trim().isEmpty) {
          return Success(
            CollectionView(collection: collection, memories: memories, totalCount: memories.length),
          );
        }
        final matches = await _searchMemories(
          SearchQuery(
            text: query,
            mode: SearchMode.keyword,
            filters: SearchFilters(collectionId: collectionId),
            limit: memories.length,
          ),
        );
        return matches.fold(
          onSuccess: (results) => Success(
            CollectionView(
              collection: collection,
              memories: [for (final r in results) r.memory],
              totalCount: memories.length,
              query: query,
            ),
          ),
          onFailure: Err.new,
        );
    }
  }

  Future<void> search(String query) {
    _query = query;
    return load();
  }

  Future<Failure?> delete() async => (await _deleteCollection(collectionId)).failureOrNull;
}
