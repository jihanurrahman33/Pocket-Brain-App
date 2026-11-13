import '../entities/memory.dart';
import '../entities/recall.dart';

/// Ranks tags by how often they appear in a set of memories.
abstract final class TopicRanker {
  static List<TopicCount> rank(List<Memory> memories, {required int limit}) {
    final counts = <String, int>{};
    for (final m in memories) {
      for (final tag in m.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(limit)) TopicCount(e.key, e.value)];
  }
}
