import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/data/datasources/ai/on_device_ai_runtime.dart';
import 'package:pocket_brain/domain/entities/ask.dart';
import 'package:pocket_brain/domain/entities/search.dart';
import 'package:pocket_brain/domain/repositories/memory_repository.dart';
import 'package:pocket_brain/domain/services/relevance_scorer.dart';
import 'package:pocket_brain/domain/usecases/ask/ask_usecases.dart';
import 'package:pocket_brain/domain/usecases/search/search_usecases.dart';

import '../helpers/fakes.dart';
import '../helpers/test_dependencies.dart';

void main() {
  group('KeywordRelevanceScorer', () {
    const scorer = KeywordRelevanceScorer();

    test('ranks title matches above unrelated memories', () {
      final rag = memoryFixture(title: 'Learning RAG', content: 'retrieval with Node.js');
      final books = memoryFixture(title: 'Books', content: 'Atomic Habits');
      expect(scorer.score('RAG node', rag), greaterThan(scorer.score('RAG node', books)));
    });

    test('blank query scores zero', () {
      expect(scorer.score('  ', memoryFixture()), 0);
    });
  });

  group('use cases (real graph, fake AI)', () {
    late FakeAiRuntime ai;

    setUp(() async {
      ai = await configureTestDependencies();
      await sl<MemoryRepository>().save(memoryFixture());
      await sl<MemoryRepository>().save(
        memoryFixture(id: 'm2', title: 'Books to read', content: 'Deep Work', tags: ['books']),
      );
    });

    test('SearchMemories finds by keyword and respects filters', () async {
      final search = sl<SearchMemories>();
      final hits = (await search(const SearchQuery(text: 'react habit'))).valueOrNull!;
      expect(hits.first.memory.id, 'm1');

      final filtered = await search(
        const SearchQuery(
          text: 'react',
          filters: SearchFilters(category: 'Work'),
        ),
      );
      expect(filtered.valueOrNull, isEmpty);
    });

    Future<List<AskProgress>> ask(String q) => sl<AskBrain>()(AskRequest(question: q)).toList();

    test('AskBrain refuses to invent when nothing matches', () async {
      final events = await ask('What is my passport number?');
      final done = events.whereType<AskAnswerCompleted>().single.message;
      expect(done.text, AskReplies.notFound);
      expect(done.grounded, isFalse);
      expect(ai.requests, isEmpty, reason: 'the model must not be called');
    });

    test('AskBrain points to sources when the model is missing', () async {
      final events = await ask('What was that React project idea?');
      expect(events.whereType<AskSourcesFound>().single.sources.single.id, 'm1');
      expect(events.whereType<AskAnswerCompleted>().single.message.text, AskReplies.modelMissing);
    });

    test('AskBrain streams a grounded, cited answer', () async {
      ai
        ..installed = {AiModelKind.languageModel}
        ..reply = ['A habit ', 'tracker [1].'];
      final events = await ask('What was that React project idea?');
      expect(events.first, isA<AskConversationStarted>());
      final done = events.whereType<AskAnswerCompleted>().single.message;
      expect(done.text, 'A habit tracker [1].');
      expect(done.sourceIds, ['m1']);
      expect(ai.requests.single.prompt, contains('React project idea'));
    });
  });
}
