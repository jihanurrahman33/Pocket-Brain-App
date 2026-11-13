import 'dart:math' as math;
import 'dart:typed_data';

/// Pure text and vector helpers shared by search and analysis.
abstract final class TextUtils {
  static const _stopWords = {
    'a',
    'about',
    'after',
    'all',
    'also',
    'am',
    'an',
    'and',
    'any',
    'are',
    'as',
    'at',
    'be',
    'because',
    'been',
    'before',
    'but',
    'by',
    'can',
    'could',
    'did',
    'do',
    'does',
    'find',
    'for',
    'from',
    'get',
    'got',
    'had',
    'has',
    'have',
    'he',
    'her',
    'him',
    'his',
    'how',
    'i',
    'if',
    'in',
    'into',
    'is',
    'it',
    'its',
    'just',
    'like',
    'me',
    'more',
    'my',
    'need',
    'no',
    'not',
    'now',
    'of',
    'on',
    'one',
    'or',
    'our',
    'out',
    'over',
    'remember',
    'saved',
    'she',
    'should',
    'show',
    'so',
    'some',
    'tell',
    'than',
    'that',
    'the',
    'their',
    'them',
    'then',
    'there',
    'these',
    'they',
    'thing',
    'things',
    'this',
    'those',
    'to',
    'up',
    'us',
    'very',
    'want',
    'was',
    'we',
    'were',
    'what',
    'when',
    'where',
    'which',
    'who',
    'why',
    'will',
    'with',
    'would',
    'you',
    'your',
  };

  static final _wordPattern = RegExp(r"[a-z0-9][a-z0-9+#.\-']*");
  static final _trailingPunctuation = RegExp(r"[.\-']+$");
  static final _whitespace = RegExp(r'\s+');
  static final _digitsOnly = RegExp(r'^\d+$');

  /// Lower-cased word tokens without stop words.
  static List<String> tokenize(String text) => _wordPattern
      .allMatches(text.toLowerCase())
      .map((m) => m[0]!.replaceAll(_trailingPunctuation, ''))
      .where((w) => w.length > 1 && !_stopWords.contains(w))
      .toList();

  /// Collapses whitespace and shortens to [max] chars at a word boundary.
  static String truncate(String text, int max) {
    final t = text.trim().replaceAll(_whitespace, ' ');
    if (t.length <= max) return t;
    final cut = t.substring(0, max);
    final space = cut.lastIndexOf(' ');
    return '${space > max * 0.6 ? cut.substring(0, space) : cut}…';
  }

  /// The [count] most frequent meaningful words in [text].
  static List<String> topTerms(String text, int count) {
    const minTermLength = 4;
    final counts = <String, int>{};
    for (final t in tokenize(text)) {
      if (t.length < minTermLength || _digitsOnly.hasMatch(t)) continue;
      counts[t] = (counts[t] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(count).map((e) => e.key).toList();
  }

  /// Jaccard overlap of two texts' token sets, in [0, 1].
  static double tokenOverlap(String a, String b) {
    final sa = tokenize(a).toSet();
    final sb = tokenize(b).toSet();
    if (sa.isEmpty || sb.isEmpty) return 0;
    return sa.intersection(sb).length / sa.union(sb).length;
  }

  /// Cosine similarity of two equal-length vectors, in [-1, 1].
  static double cosine(Float32List a, Float32List b) {
    if (a.length != b.length || a.isEmpty) return 0;
    var dot = 0.0, normA = 0.0, normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  /// A short excerpt of [text] around the first occurrence of any token of
  /// [query], or null when none occurs.
  static String? excerptAround(String query, String text, {int radius = 80}) {
    final flat = text.replaceAll(_whitespace, ' ');
    final lower = flat.toLowerCase();
    for (final term in tokenize(query)) {
      final index = lower.indexOf(term);
      if (index < 0) continue;
      final start = math.max(0, index - radius ~/ 2);
      final end = math.min(flat.length, index + radius * 3 ~/ 2);
      return '${start > 0 ? '…' : ''}${flat.substring(start, end)}'
          '${end < flat.length ? '…' : ''}';
    }
    return null;
  }
}
