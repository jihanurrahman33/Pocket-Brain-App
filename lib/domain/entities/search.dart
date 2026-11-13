import 'package:equatable/equatable.dart';

import 'memory.dart';

enum SearchMode {
  /// Exact words, titles and tags.
  keyword,

  /// By meaning, using embeddings when available.
  semantic,
}

enum SearchSort { relevance, newest }

/// Which slice of the library to list.
enum MemoryFilter { all, recentlyViewed, favorites, archived }

/// Narrows a search. All set fields must match.
class SearchFilters extends Equatable {
  const SearchFilters({this.category, this.source, this.since, this.collectionId});

  final String? category;
  final MemorySource? source;
  final DateTime? since;
  final String? collectionId;

  bool get isEmpty => category == null && source == null && since == null && collectionId == null;

  bool accepts(Memory m) =>
      (category == null || m.category == category) &&
      (source == null || m.source == source) &&
      (since == null || !m.createdAt.isBefore(since!)) &&
      (collectionId == null || m.collectionId == collectionId);

  SearchFilters copyWith({
    String? Function()? category,
    MemorySource? Function()? source,
    DateTime? Function()? since,
  }) => SearchFilters(
    category: category != null ? category() : this.category,
    source: source != null ? source() : this.source,
    since: since != null ? since() : this.since,
    collectionId: collectionId,
  );

  @override
  List<Object?> get props => [category, source, since, collectionId];
}

class SearchQuery extends Equatable {
  const SearchQuery({
    required this.text,
    this.mode = SearchMode.semantic,
    this.filters = const SearchFilters(),
    this.sort = SearchSort.relevance,
    this.limit = 30,
  });

  final String text;
  final SearchMode mode;
  final SearchFilters filters;
  final SearchSort sort;
  final int limit;

  bool get isBlank => text.trim().isEmpty;

  @override
  List<Object?> get props => [text, mode, filters, sort, limit];
}

/// A memory with a relevance or similarity score in [0, 1].
class ScoredMemory extends Equatable {
  const ScoredMemory(this.memory, this.score);

  final Memory memory;
  final double score;

  @override
  List<Object?> get props => [memory, score];
}

/// Criteria for listing the library.
class MemoryQuery extends Equatable {
  const MemoryQuery({this.filter = MemoryFilter.all, this.category, this.collectionId, this.limit});

  final MemoryFilter filter;
  final String? category;
  final String? collectionId;
  final int? limit;

  @override
  List<Object?> get props => [filter, category, collectionId, limit];
}
