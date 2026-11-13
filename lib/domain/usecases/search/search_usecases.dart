import 'dart:typed_data';

import '../../../core/error/guard.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../entities/memory.dart';
import '../../entities/search.dart';
import '../../repositories/memory_repository.dart';
import '../../repositories/search_history_repository.dart';
import '../../services/ai_services.dart';
import '../../services/relevance_scorer.dart';

/// Finds memories by words or by meaning.
///
/// The ranking strategy is chosen per [SearchMode] from [scorers], so new
/// modes plug in without changing this class.
final class SearchMemories implements UseCase<Result<List<ScoredMemory>>, SearchQuery> {
  SearchMemories({
    required MemoryRepository memories,
    required TextEmbedder embedder,
    required Map<SearchMode, RelevanceScorer> scorers,
    required AppLogger logger,
  }) : _memories = memories,
       _embedder = embedder,
       _scorers = scorers,
       _logger = logger;

  final MemoryRepository _memories;
  final TextEmbedder _embedder;
  final Map<SearchMode, RelevanceScorer> _scorers;
  final AppLogger _logger;

  /// Results scoring below this are noise.
  static const minimumScore = 0.12;

  @override
  Future<Result<List<ScoredMemory>>> call(SearchQuery query) => guard(_logger, 'Search', () async {
    final candidates = (await _memories.getAll()).where(query.filters.accepts).toList();
    final List<ScoredMemory> results;
    if (query.isBlank) {
      results = [for (final m in candidates) ScoredMemory(m, 0)];
    } else {
      results = await _rank(query, candidates);
    }
    if (query.sort == SearchSort.newest) {
      results.sort((a, b) => b.memory.createdAt.compareTo(a.memory.createdAt));
    }
    return results.take(query.limit).toList();
  });

  Future<List<ScoredMemory>> _rank(SearchQuery query, List<Memory> candidates) async {
    final scorer = _scorers[query.mode]!;
    final Float32List? queryVector = query.mode == SearchMode.semantic
        ? await _embedder.embed(query.text, EmbeddingPurpose.query)
        : null;
    final scored = [
      for (final m in candidates)
        ScoredMemory(m, scorer.score(query.text, m, queryVector: queryVector)),
    ].where((s) => s.score > minimumScore).toList()..sort((a, b) => b.score.compareTo(a.score));
    return scored;
  }
}

/// Parameters for [FindSimilarMemories].
class SimilarityQuery {
  const SimilarityQuery({required this.text, this.vector, this.excludeId, this.limit = 4});

  final String text;
  final Float32List? vector;
  final String? excludeId;
  final int limit;
}

/// Memories about the same topic as some text — powers "related memories",
/// "you already saved…" and duplicate detection.
final class FindSimilarMemories implements UseCase<List<ScoredMemory>, SimilarityQuery> {
  const FindSimilarMemories({required MemoryRepository memories, required SimilarityScorer scorer})
    : _memories = memories,
      _scorer = scorer;

  final MemoryRepository _memories;
  final SimilarityScorer _scorer;

  static const minimumSimilarity = 0.45;

  @override
  Future<List<ScoredMemory>> call(SimilarityQuery query) async {
    final scored = <ScoredMemory>[];
    for (final m in await _memories.getAll()) {
      if (m.id == query.excludeId) continue;
      final score = _scorer.similarity(query.text, query.vector, m);
      if (score >= minimumSimilarity) scored.add(ScoredMemory(m, score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(query.limit).toList();
  }
}

final class GetRecentSearches implements UseCase<Result<List<String>>, NoParams> {
  const GetRecentSearches(this._history, this._logger);

  final SearchHistoryRepository _history;
  final AppLogger _logger;

  static const limit = 8;

  @override
  Future<Result<List<String>>> call(NoParams _) =>
      guard(_logger, 'Load recent searches', () => _history.recent(limit: limit));
}

final class RecordSearch implements UseCase<Result<void>, String> {
  const RecordSearch(this._history, this._clock, this._logger);

  final SearchHistoryRepository _history;
  final Clock _clock;
  final AppLogger _logger;

  @override
  Future<Result<void>> call(String query) => guard(_logger, 'Record search', () async {
    final q = query.trim();
    if (q.isNotEmpty) await _history.add(q, _clock.now());
  });
}

final class ClearSearchHistory implements UseCase<Result<void>, NoParams> {
  const ClearSearchHistory(this._history, this._logger);

  final SearchHistoryRepository _history;
  final AppLogger _logger;

  @override
  Future<Result<void>> call(NoParams _) => guard(_logger, 'Clear search history', _history.clear);
}
