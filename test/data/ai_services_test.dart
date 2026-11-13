import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/data/services/ai/date_expression_parser.dart';
import 'package:pocket_brain/data/services/ai/memory_analyzers.dart';
import 'package:pocket_brain/data/services/ai/parsers/analysis_response_parser.dart';
import 'package:pocket_brain/data/services/web/http_link_reader.dart';
import 'package:pocket_brain/domain/entities/memory_analysis.dart';
import 'package:pocket_brain/domain/services/ai_services.dart';

import '../helpers/fakes.dart';

final class _ThrowingAnalyzer implements MemoryAnalyzer {
  @override
  Future<MemoryAnalysis> analyze(String text, {required DateTime now}) =>
      Future.error(StateError('model crashed'));
}

void main() {
  group('DateExpressionParser', () {
    const parser = DateExpressionParser();
    final now = DateTime(2026, 11, 13);

    test('parses month-first, day-first, ISO and relative dates', () {
      expect(parser.parse('before December 15', now: now), DateTime(2026, 12, 15));
      expect(parser.parse('on 3rd Jan', now: now), DateTime(2027, 1, 3));
      expect(parser.parse('due 2026-12-01', now: now), DateTime(2026, 12, 1));
      expect(parser.parse('tomorrow', now: now), DateTime(2026, 11, 14));
    });

    test('rolls past dates into next year and ignores nonsense', () {
      expect(parser.parse('by March 2', now: now), DateTime(2027, 3, 2));
      expect(parser.parse('sometime', now: now), isNull);
    });
  });

  test('RuleBasedMemoryAnalyzer extracts a titled task with deadline', () async {
    final a = await const RuleBasedMemoryAnalyzer().analyze(
      'Learning RAG\nI need to finish reading this book before December 15.',
      now: testNow,
    );
    expect(a.title, 'Learning RAG');
    expect(a.category, 'Learning');
    expect(a.tasks.single.title, 'Finish reading this book');
  });

  group('AnalysisResponseParser', () {
    const fallback = MemoryAnalysis(
      title: 'fb',
      summary: 'fb summary',
      category: 'Personal',
      tags: ['x'],
      origin: AnalysisOrigin.rules,
    );

    test('parses fenced JSON', () {
      final a = AnalysisResponseParser.parse(
        '```json\n{"title":"Learning RAG","summary":"s","category":"Learning",'
        '"tags":["RAG","AI"],"tasks":[{"title":"Read","due":"2026-12-15"}]}\n```',
        fallback: fallback,
      );
      expect(a.origin, AnalysisOrigin.model);
      expect(a.tags, ['rag', 'ai']);
      expect(a.tasks.single.dueAt, DateTime(2026, 12, 15));
    });

    test('falls back on garbage and on empty fields', () {
      expect(AnalysisResponseParser.parse('no json', fallback: fallback), fallback);
      final partial = AnalysisResponseParser.parse('{"title":""}', fallback: fallback);
      expect(partial.title, 'fb');
      expect(partial.tags, ['x']);
    });
  });

  test('FallbackMemoryAnalyzer recovers when the model fails', () async {
    final analyzer = FallbackMemoryAnalyzer(
      primary: _ThrowingAnalyzer(),
      fallback: const RuleBasedMemoryAnalyzer(),
      isPrimaryAvailable: () => true,
      logger: const SilentLogger(),
    );
    final a = await analyzer.analyze('An idea for an app', now: testNow);
    expect(a.origin, AnalysisOrigin.rules);
  });

  test('HtmlContentExtractor reads title and paragraphs', () {
    final page = HtmlContentExtractor.extract(
      '<html><title>Make &amp; Earn</title><p>${'Long paragraph text. ' * 4}</p><p>short</p></html>',
    );
    expect(page.title, 'Make & Earn');
    expect(page.text, startsWith('Long paragraph'));
  });
}
