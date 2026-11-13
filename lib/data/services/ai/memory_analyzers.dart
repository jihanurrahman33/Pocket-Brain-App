import '../../../core/logging/app_logger.dart';
import '../../../core/utils/text_utils.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/entities/memory_analysis.dart';
import '../../../domain/services/ai_services.dart';
import '../../datasources/ai/on_device_ai_runtime.dart';
import 'date_expression_parser.dart';
import 'parsers/analysis_response_parser.dart';
import 'prompts/prompts.dart';

/// Deterministic, offline analysis used before Gemma is downloaded or when
/// it fails. Labelled as "offline rules" in the UI.
final class RuleBasedMemoryAnalyzer implements MemoryAnalyzer {
  const RuleBasedMemoryAnalyzer([this._dates = const DateExpressionParser()]);

  final DateExpressionParser _dates;

  static const _maxTitleChars = 60;
  static const _maxSummaryChars = 200;
  static const _summarySentences = 2;
  static const _tagCount = 4;
  static const untitled = 'Untitled memory';

  static const _categoryHints = <String, List<String>>{
    'Learning': ['learn', 'course', 'tutorial', 'study', 'understand', 'how to'],
    'Work': ['meeting', 'client', 'deadline', 'office', 'manager', 'report'],
    'Ideas': ['idea', 'what if', 'could build', 'startup', 'concept'],
    'Projects': ['project', 'build', 'app', 'repo', 'prototype', 'feature'],
    'Reading list': ['book', 'article', 'read', 'paper', 'blog'],
    'Things to remember': ['remember', 'password', 'birthday', 'address'],
  };

  static final _taskPattern = RegExp(
    r"(?:i need to|i have to|i must|todo:|to do:|remember to|don't forget to)\s+([^.\n!?]+)",
    caseSensitive: false,
  );
  static final _deadlineClause = RegExp(r'\s+(before|by|on|until)\s+.*$', caseSensitive: false);
  static final _sentenceEnd = RegExp(r'(?<=[.!?])\s+');

  @override
  Future<MemoryAnalysis> analyze(String text, {required DateTime now}) async {
    final clean = text.trim();
    final firstLine = clean.split('\n').first.trim();
    final sentences = clean
        .replaceAll('\n', ' ')
        .split(_sentenceEnd)
        .where((s) => s.trim().isNotEmpty);
    return MemoryAnalysis(
      title: TextUtils.truncate(firstLine.isEmpty ? untitled : firstLine, _maxTitleChars),
      summary: TextUtils.truncate(sentences.take(_summarySentences).join(' '), _maxSummaryChars),
      category: categorize(clean),
      tags: TextUtils.topTerms(clean, _tagCount),
      tasks: extractTasks(clean, now: now),
      origin: AnalysisOrigin.rules,
    );
  }

  String categorize(String text) {
    final lower = text.toLowerCase();
    for (final MapEntry(key: category, value: hints) in _categoryHints.entries) {
      if (hints.any(lower.contains)) return category;
    }
    return MemoryCategories.fallback;
  }

  /// Finds sentences like "I need to … before `date`".
  List<SuggestedTask> extractTasks(String text, {required DateTime now}) => [
    for (final match in _taskPattern.allMatches(text))
      if (match[1]!.trim().replaceAll(_deadlineClause, '').trim() case final body
          when body.isNotEmpty)
        SuggestedTask(
          title: '${body[0].toUpperCase()}${body.substring(1)}',
          dueAt: _dates.parse(match[1]!, now: now),
        ),
  ];
}

/// Analysis by Gemma on-device.
final class GemmaMemoryAnalyzer implements MemoryAnalyzer {
  const GemmaMemoryAnalyzer(this._runtime, this._rules);

  final OnDeviceAiRuntime _runtime;

  /// Supplies values for any field the model leaves empty.
  final MemoryAnalyzer _rules;

  @override
  Future<MemoryAnalysis> analyze(String text, {required DateTime now}) async {
    final raw = await _runtime.generate(AnalysisPrompt.build(text, now)).join();
    return AnalysisResponseParser.parse(raw, fallback: await _rules.analyze(text, now: now));
  }
}

/// Uses [_primary] when available and healthy, else [_fallback]
/// (Decorator / Chain of Responsibility).
final class FallbackMemoryAnalyzer implements MemoryAnalyzer {
  const FallbackMemoryAnalyzer({
    required MemoryAnalyzer primary,
    required MemoryAnalyzer fallback,
    required bool Function() isPrimaryAvailable,
    required AppLogger logger,
  }) : _primary = primary,
       _fallback = fallback,
       _isPrimaryAvailable = isPrimaryAvailable,
       _logger = logger;

  final MemoryAnalyzer _primary;
  final MemoryAnalyzer _fallback;
  final bool Function() _isPrimaryAvailable;
  final AppLogger _logger;

  @override
  Future<MemoryAnalysis> analyze(String text, {required DateTime now}) async {
    if (!_isPrimaryAvailable()) return _fallback.analyze(text, now: now);
    try {
      return await _primary.analyze(text, now: now);
    } on Object catch (e, s) {
      _logger.error('Primary analyzer failed; using fallback', e, s);
      return _fallback.analyze(text, now: now);
    }
  }
}
