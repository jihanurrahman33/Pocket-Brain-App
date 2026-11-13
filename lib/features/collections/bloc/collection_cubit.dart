import '../../../core/bloc/load_state.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../domain/usecases/collections/collection_usecases.dart';

/// One collection's memories. In-collection search is a pure view concern
/// and lives in the page.
class CollectionCubit extends AutoRefreshCubit<CollectionContents> {
  CollectionCubit({
    required this.collectionId,
    required GetCollectionContents getContents,
    required DeleteCollection deleteCollection,
    required super.changes,
  }) : _getContents = getContents,
       _deleteCollection = deleteCollection;

  final String collectionId;
  final GetCollectionContents _getContents;
  final DeleteCollection _deleteCollection;

  @override
  Future<Result<CollectionContents>> fetch() => _getContents(collectionId);

  Future<Failure?> delete() async => (await _deleteCollection(collectionId)).failureOrNull;
}
