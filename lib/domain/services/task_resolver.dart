import 'dart:typed_data';

import '../../core/utils/text_utils.dart';
import '../entities/task_item.dart';
import 'ai_services.dart';
import 'intent_router.dart';

/// Finds the task(s) a message refers to (Resolve step): by position in the
/// last answer ("the second one", "it"), by title words ("drink water" ~
/// "drank water"), then by meaning with embeddings ("finished the report" ~
/// "Quarterly report").
final class TaskResolver {
  const TaskResolver(this._embedder);

  final TextEmbedder _embedder;

  /// Minimum cosine similarity for a meaning-based match.
  static const minSimilarity = 0.72;

  /// How far ahead the best meaning match must be to be taken alone.
  static const _clearLead = 0.06;

  static const _ordinals = {
    'first': 0, '1st': 0, '1': 0, 'one': 0, //
    'second': 1, '2nd': 1, '2': 1, 'two': 1,
    'third': 2, '3rd': 2, '3': 2, 'three': 2,
    'fourth': 3, '4th': 3, '4': 3,
    'fifth': 4, '5th': 4, '5': 4,
  };
  static final _pronoun = RegExp(
    r'^\s*(it|that|that one|this|this one|the task|that task|oita|eta|ota)\s*$',
    caseSensitive: false,
  );

  /// Candidates best first; empty when nothing fits.
  Future<List<TaskItem>> resolve(
    String reference,
    List<TaskItem> candidates, {
    List<TaskItem> recent = const [],
  }) async {
    final ref = reference.trim();
    if (candidates.isEmpty) return const [];
    final shown = [for (final t in recent) ...candidates.where((c) => c.id == t.id)];

    // "it" / "that one": the only task the last answer showed.
    if (_pronoun.hasMatch(ref) && shown.length == 1) return shown;
    // "the second one", "2", "the last one".
    if (shown.isNotEmpty) {
      if (RegExp(r'\blast\b', caseSensitive: false).hasMatch(ref) && ref.split(' ').length <= 3) {
        return [shown.last];
      }
      final words = TextUtils.tokenize(ref);
      if (words.length <= 3) {
        for (final w in [...words, ref.toLowerCase()]) {
          if (_ordinals[w] case final i? when i < shown.length) return [shown[i]];
        }
      }
    }

    // The message names most of a title ("drink water done")…
    final byTitle = [
      ...IntentRouter.matchTasks(ref, candidates),
      ...IntentRouter.matchTasks(ref, candidates, done: true),
    ];
    if (byTitle.isNotEmpty) return byTitle;
    // …or a short reference is all in one title ("the dentist").
    final containing = IntentRouter.tasksContaining(ref, candidates);
    if (containing.isNotEmpty) return containing;
    return _byMeaning(ref, candidates);
  }

  Future<List<TaskItem>> _byMeaning(String ref, List<TaskItem> candidates) async {
    if (!_embedder.isAvailable || ref.isEmpty) return const [];
    final query = await _embedder.embed(ref, EmbeddingPurpose.query);
    if (query == null) return const [];
    final scored = <(TaskItem, double)>[];
    for (final task in candidates) {
      final Float32List? vector = await _embedder.embed(task.title, EmbeddingPurpose.document);
      if (vector == null) continue;
      final similarity = TextUtils.cosine(query, vector);
      if (similarity >= minSimilarity) scored.add((task, similarity));
    }
    if (scored.isEmpty) return const [];
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    final best = scored.first.$2;
    return [
      for (final (task, s) in scored)
        if (best - s < _clearLead) task,
    ];
  }
}
