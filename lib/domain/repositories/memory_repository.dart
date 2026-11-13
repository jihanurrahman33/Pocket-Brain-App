import 'dart:typed_data';

import '../entities/memory.dart';
import '../entities/search.dart';
import 'change_notifier.dart';

/// Persistence for [Memory] entities.
abstract interface class MemoryRepository implements ChangeSource, Clearable {
  Future<void> save(Memory memory);

  Future<Memory?> getById(String id);

  /// Memories in the same order as [ids]; missing ids are skipped.
  Future<List<Memory>> getByIds(List<String> ids);

  Future<List<Memory>> query(MemoryQuery query);

  /// Every memory, newest first.
  Future<List<Memory>> getAll({bool includeArchived = false});

  /// Non-archived memories with `from <= createdAt < to`, newest first.
  Future<List<Memory>> savedBetween(DateTime from, DateTime to);

  /// Non-archived memories created before [cutoff] and not opened since.
  Future<List<Memory>> notViewedSince(DateTime cutoff, {required int limit});

  Future<int> count();

  /// Categories in use, most used first.
  Future<List<String>> categories();

  Future<void> delete(String id);
}

/// Bookkeeping that should not notify listeners (no visible change).
abstract interface class MemoryMetadataStore {
  Future<void> markViewed(String id, DateTime at);

  Future<void> setEmbedding(String id, Float32List vector);

  Future<List<Memory>> withoutEmbedding();
}
