import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/utils/text_utils.dart';
import '../entities/memory.dart';

/// Scores how relevant a memory is to a query, in [0, 1] (Strategy pattern).
///
/// New ranking approaches are added as new strategies without touching the
/// search use case (Open/Closed).
abstract interface class RelevanceScorer {
  double score(String query, Memory memory, {Float32List? queryVector});
}

/// Exact-word relevance: phrase hits and title hits count more.
final class KeywordRelevanceScorer implements RelevanceScorer {
  const KeywordRelevanceScorer();

  static const _titleWeight = 1.5;
  static const _bodyWeight = 1.0;
  static const _prefixWeight = 0.6;
  static const _phraseBonus = 0.3;
  static const _minPrefixLength = 3;

  @override
  double score(String query, Memory memory, {Float32List? queryVector}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return 0;
    final text = memory.searchableText.toLowerCase();
    final terms = TextUtils.tokenize(q).toSet();
    if (terms.isEmpty) return text.contains(q) ? 1 : 0;

    final words = TextUtils.tokenize(text).toSet();
    final titleWords = TextUtils.tokenize(memory.title).toSet();
    var hits = 0.0;
    for (final term in terms) {
      if (titleWords.contains(term)) {
        hits += _titleWeight;
      } else if (words.contains(term)) {
        hits += _bodyWeight;
      } else if (term.length >= _minPrefixLength && words.any((w) => w.startsWith(term))) {
        hits += _prefixWeight;
      }
    }
    var score = hits / (terms.length * _titleWeight);
    if (text.contains(q)) score += _phraseBonus;
    return math.min(1, score);
  }
}

/// Meaning-based relevance: blends embedding similarity with keywords, and
/// degrades to softened keyword matching when vectors are missing.
final class HybridRelevanceScorer implements RelevanceScorer {
  const HybridRelevanceScorer([this._keywords = const KeywordRelevanceScorer()]);

  final RelevanceScorer _keywords;

  /// EmbeddingGemma similarities for related text sit roughly in 0.3–0.8;
  /// this band is stretched onto 0–1 before mixing.
  static const _similarityFloor = 0.3;
  static const _similarityRange = 0.5;
  static const _semanticWeight = 0.7;
  static const _overlapBoost = 2.0;

  @override
  double score(String query, Memory memory, {Float32List? queryVector}) {
    final keyword = _keywords.score(query, memory);
    final vector = memory.embedding;
    if (queryVector != null && vector != null) {
      final similarity = TextUtils.cosine(queryVector, vector);
      final semantic = ((similarity - _similarityFloor) / _similarityRange).clamp(0.0, 1.0);
      return math.max(keyword, _semanticWeight * semantic + (1 - _semanticWeight) * keyword);
    }
    final overlap = TextUtils.tokenOverlap(query, memory.searchableText);
    return math.max(keyword, math.min(1, overlap * _overlapBoost));
  }
}

/// How alike two memories (or a text and a memory) are, in [0, 1].
abstract interface class SimilarityScorer {
  double similarity(String text, Float32List? vector, Memory other);
}

final class DefaultSimilarityScorer implements SimilarityScorer {
  const DefaultSimilarityScorer();

  static const _overlapBoost = 2.2;

  @override
  double similarity(String text, Float32List? vector, Memory other) {
    if (vector != null && other.embedding != null) {
      return TextUtils.cosine(vector, other.embedding!).clamp(0.0, 1.0);
    }
    final overlap = TextUtils.tokenOverlap(text, other.searchableText);
    return math.min(1, overlap * _overlapBoost);
  }
}
