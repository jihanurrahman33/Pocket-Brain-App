import 'dart:convert';

import '../../../../core/utils/text_utils.dart';
import '../../../../domain/entities/memory_analysis.dart';

/// Parses Gemma's JSON analysis, tolerating code fences and stray prose.
/// Missing or empty fields keep the [fallback]'s values.
abstract final class AnalysisResponseParser {
  static const _maxTitleChars = 80;
  static const _maxTags = 5;

  static MemoryAnalysis parse(String raw, {required MemoryAnalysis fallback}) {
    final json = _extractObject(raw);
    if (json == null) return fallback;

    String text(String key, String otherwise) => switch (json[key]) {
      final String s when s.trim().isNotEmpty => s.trim(),
      _ => otherwise,
    };

    List<String> strings(String key) => switch (json[key]) {
      final List<Object?> list => [
        for (final s in list.whereType<String>())
          if (s.trim().isNotEmpty) s.trim(),
      ],
      _ => const [],
    };

    final tags = [for (final t in strings('tags').take(_maxTags)) t.toLowerCase()];
    return MemoryAnalysis(
      title: TextUtils.truncate(text('title', fallback.title), _maxTitleChars),
      summary: text('summary', fallback.summary),
      category: text('category', fallback.category),
      tags: tags.isEmpty ? fallback.tags : tags,
      people: strings('people'),
      tasks: _tasks(json['tasks']),
      origin: AnalysisOrigin.model,
    );
  }

  static Map<String, Object?>? _extractObject(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(raw.substring(start, end + 1));
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static List<SuggestedTask> _tasks(Object? value) => switch (value) {
    final List<Object?> items => [
      for (final item in items)
        if (item case {'title': final String title} when title.trim().isNotEmpty)
          SuggestedTask(
            title: title.trim(),
            dueAt: switch (item['due']) {
              final String due => DateTime.tryParse(due),
              _ => null,
            },
          ),
    ],
    _ => const [],
  };
}
