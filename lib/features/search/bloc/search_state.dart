part of 'search_bloc.dart';

enum SearchStatus { idle, searching, done, failed }

class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.mode = SearchMode.semantic,
    this.filters = const SearchFilters(),
    this.sort = SearchSort.relevance,
    this.results = const [],
    this.recent = const [],
    this.categories = const [],
    this.failure,
  });

  final SearchStatus status;
  final String query;
  final SearchMode mode;
  final SearchFilters filters;
  final SearchSort sort;
  final List<ScoredMemory> results;
  final List<String> recent;
  final List<String> categories;
  final Failure? failure;

  bool get hasCriteria => query.trim().isNotEmpty || !filters.isEmpty;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    SearchMode? mode,
    SearchFilters? filters,
    SearchSort? sort,
    List<ScoredMemory>? results,
    List<String>? recent,
    List<String>? categories,
    Failure? failure,
  }) => SearchState(
    status: status ?? this.status,
    query: query ?? this.query,
    mode: mode ?? this.mode,
    filters: filters ?? this.filters,
    sort: sort ?? this.sort,
    results: results ?? this.results,
    recent: recent ?? this.recent,
    categories: categories ?? this.categories,
    failure: failure,
  );

  @override
  List<Object?> get props => [
    status,
    query,
    mode,
    filters,
    sort,
    results,
    recent,
    categories,
    failure,
  ];
}
