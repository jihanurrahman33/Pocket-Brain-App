import '../entities/memory_collection.dart';
import 'change_notifier.dart';

/// Persistence for [MemoryCollection]s.
abstract interface class CollectionRepository implements ChangeSource, Clearable {
  /// All collections with memory counts, sorted by name.
  Future<List<MemoryCollection>> getAll();

  Future<MemoryCollection?> getById(String id);

  Future<void> save(MemoryCollection collection);

  /// Deletes the collection; its memories are kept.
  Future<void> delete(String id);
}
