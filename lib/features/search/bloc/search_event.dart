part of 'search_bloc.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

final class SearchStarted extends SearchEvent {
  const SearchStarted();
}

/// Every keystroke; debounced.
final class SearchTextChanged extends SearchEvent {
  const SearchTextChanged(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// Enter pressed: remember the query.
final class SearchSubmitted extends SearchEvent {
  const SearchSubmitted();
}

final class SearchOptionsChanged extends SearchEvent {
  const SearchOptionsChanged({this.mode, this.filters, this.sort});

  final SearchMode? mode;
  final SearchFilters? filters;
  final SearchSort? sort;

  @override
  List<Object?> get props => [mode, filters, sort];
}

final class SearchHistoryCleared extends SearchEvent {
  const SearchHistoryCleared();
}

/// Stored memories changed; re-run the current search.
final class _SearchDataChanged extends SearchEvent {
  const _SearchDataChanged();
}
