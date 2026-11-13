import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/search.dart';
import '../../../domain/usecases/memories/memory_usecases.dart';
import '../../../domain/usecases/search/search_usecases.dart';

part 'search_event.dart';
part 'search_state.dart';

/// Debounces keystrokes and cancels stale searches.
EventTransformer<E> debounceRestartable<E>(Duration duration) =>
    (events, mapper) => restartable<E>().call(events.debounce(duration), mapper);

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    required SearchMemories searchMemories,
    required GetRecentSearches getRecentSearches,
    required RecordSearch recordSearch,
    required ClearSearchHistory clearHistory,
    required GetCategories getCategories,
    required Stream<void> changes,
  }) : _searchMemories = searchMemories,
       _getRecentSearches = getRecentSearches,
       _recordSearch = recordSearch,
       _clearHistory = clearHistory,
       _getCategories = getCategories,
       super(const SearchState()) {
    on<SearchStarted>(_onStarted);
    on<SearchTextChanged>(_onTextChanged, transformer: debounceRestartable(debounce));
    on<SearchSubmitted>(_onSubmitted);
    on<SearchOptionsChanged>(_onOptionsChanged, transformer: restartable());
    on<SearchHistoryCleared>(_onHistoryCleared);
    on<_SearchDataChanged>((_, emit) => _search(emit), transformer: restartable());
    // Edits and deletions elsewhere must not leave stale results on screen.
    _changes = changes.listen((_) => add(const _SearchDataChanged()));
  }

  late final StreamSubscription<void> _changes;

  @override
  Future<void> close() async {
    await _changes.cancel();
    return super.close();
  }

  static const debounce = Duration(milliseconds: 300);

  final SearchMemories _searchMemories;
  final GetRecentSearches _getRecentSearches;
  final RecordSearch _recordSearch;
  final ClearSearchHistory _clearHistory;
  final GetCategories _getCategories;

  Future<void> _onStarted(SearchStarted event, Emitter<SearchState> emit) async {
    emit(
      state.copyWith(
        recent: (await _getRecentSearches.run()).valueOrNull,
        categories: (await _getCategories.run()).valueOrNull,
      ),
    );
  }

  Future<void> _onTextChanged(SearchTextChanged event, Emitter<SearchState> emit) async {
    emit(state.copyWith(query: event.text));
    await _search(emit);
  }

  Future<void> _onSubmitted(SearchSubmitted event, Emitter<SearchState> emit) async {
    await _recordSearch(state.query);
    emit(state.copyWith(recent: (await _getRecentSearches.run()).valueOrNull));
  }

  Future<void> _onOptionsChanged(SearchOptionsChanged event, Emitter<SearchState> emit) async {
    emit(state.copyWith(mode: event.mode, filters: event.filters, sort: event.sort));
    await _search(emit);
  }

  Future<void> _onHistoryCleared(SearchHistoryCleared event, Emitter<SearchState> emit) async {
    await _clearHistory.run();
    emit(state.copyWith(recent: const []));
  }

  Future<void> _search(Emitter<SearchState> emit) async {
    if (!state.hasCriteria) {
      emit(state.copyWith(status: SearchStatus.idle, results: const []));
      return;
    }
    emit(state.copyWith(status: SearchStatus.searching));
    final result = await _searchMemories(
      SearchQuery(text: state.query, mode: state.mode, filters: state.filters, sort: state.sort),
    );
    emit(
      result.fold(
        onSuccess: (results) => state.copyWith(status: SearchStatus.done, results: results),
        onFailure: (f) => state.copyWith(status: SearchStatus.failed, failure: f),
      ),
    );
  }
}
