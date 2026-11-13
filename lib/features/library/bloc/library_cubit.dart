import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/entities/memory_collection.dart';
import '../../../domain/entities/search.dart';
import '../../../domain/usecases/collections/collection_usecases.dart';
import '../../../domain/usecases/memories/memory_usecases.dart';

enum LibraryLayout { list, grid }

class LibraryState extends Equatable {
  const LibraryState({
    this.isLoading = true,
    this.filter = MemoryFilter.all,
    this.category,
    this.layout = LibraryLayout.list,
    this.memories = const [],
    this.collections = const [],
    this.categories = const [],
    this.failure,
  });

  final bool isLoading;
  final MemoryFilter filter;
  final String? category;
  final LibraryLayout layout;
  final List<Memory> memories;
  final List<MemoryCollection> collections;
  final List<String> categories;
  final Failure? failure;

  LibraryState copyWith({
    bool? isLoading,
    MemoryFilter? filter,
    String? Function()? category,
    LibraryLayout? layout,
    List<Memory>? memories,
    List<MemoryCollection>? collections,
    List<String>? categories,
    Failure? Function()? failure,
  }) => LibraryState(
    isLoading: isLoading ?? this.isLoading,
    filter: filter ?? this.filter,
    category: category != null ? category() : this.category,
    layout: layout ?? this.layout,
    memories: memories ?? this.memories,
    collections: collections ?? this.collections,
    categories: categories ?? this.categories,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [
    isLoading,
    filter,
    category,
    layout,
    memories,
    collections,
    categories,
    failure,
  ];
}

/// The "Brain" tab: every saved memory, filterable, plus collections.
class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit({
    required GetMemories getMemories,
    required GetCollections getCollections,
    required GetCategories getCategories,
    required CreateCollection createCollection,
    required Stream<void> changes,
  }) : _getMemories = getMemories,
       _getCollections = getCollections,
       _getCategories = getCategories,
       _createCollection = createCollection,
       super(const LibraryState()) {
    _subscription = changes.listen((_) => load());
  }

  final GetMemories _getMemories;
  final GetCollections _getCollections;
  final GetCategories _getCategories;
  final CreateCollection _createCollection;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    final memories = await _getMemories(
      MemoryQuery(filter: state.filter, category: state.category),
    );
    final collections = await _getCollections.run();
    final categories = await _getCategories.run();
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: false,
        memories: memories.valueOrNull,
        collections: collections.valueOrNull,
        categories: categories.valueOrNull,
        failure: () => memories.failureOrNull,
      ),
    );
  }

  Future<void> selectFilter(MemoryFilter filter) async {
    emit(state.copyWith(filter: filter, category: () => null));
    await load();
  }

  Future<void> selectCategory(String? category) async {
    emit(state.copyWith(category: () => category, filter: MemoryFilter.all));
    await load();
  }

  void toggleLayout() => emit(
    state.copyWith(
      layout: state.layout == LibraryLayout.list ? LibraryLayout.grid : LibraryLayout.list,
    ),
  );

  /// Returns the failure to show, or null on success.
  Future<Failure?> createCollection(String name) async {
    final result = await _createCollection((
      name: name,
      emoji: MemoryCollection.defaultEmoji,
      isPrivate: false,
    ));
    return result.failureOrNull;
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
