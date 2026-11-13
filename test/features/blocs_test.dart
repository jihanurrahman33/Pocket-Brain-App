import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/core/error/failure.dart';
import 'package:pocket_brain/domain/entities/capture.dart';
import 'package:pocket_brain/domain/entities/memory.dart';
import 'package:pocket_brain/domain/entities/memory_analysis.dart';
import 'package:pocket_brain/domain/repositories/conversation_repository.dart';
import 'package:pocket_brain/domain/repositories/memory_repository.dart';
import 'package:pocket_brain/domain/repositories/task_repository.dart';
import 'package:pocket_brain/domain/services/ai_services.dart';
import 'package:pocket_brain/domain/usecases/capture/capture_usecases.dart';
import 'package:pocket_brain/domain/usecases/collections/collection_usecases.dart';
import 'package:pocket_brain/features/ask/bloc/ask_bloc.dart';
import 'package:pocket_brain/features/capture/bloc/capture_bloc.dart';
import 'package:pocket_brain/features/collections/bloc/collection_cubit.dart';
import 'package:pocket_brain/features/search/bloc/search_bloc.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/test_dependencies.dart';

/// An analyzer that crashes, to drive the real use case into failure.
final class _CrashingAnalyzer implements MemoryAnalyzer {
  @override
  Future<MemoryAnalysis> analyze(String text, {required DateTime now}) =>
      Future.error(StateError('model crashed'));
}

void main() {
  setUp(configureTestDependencies);

  const note = CaptureInput(
    text: 'I need to finish reading this book before December 15.',
    source: MemorySource.note,
  );

  group('CaptureBloc', () {
    blocTest<CaptureBloc, CaptureState>(
      'analyzes, then waits for review without saving',
      build: sl.call,
      act: (b) async {
        b.add(const CaptureSubmitted(note));
        await untilState(b, (s) => s is CaptureReviewing);
      },
      expect: () => [isA<CaptureAnalyzing>(), isA<CaptureReviewing>()],
      verify: (_) async => expect(await sl<MemoryRepository>().count(), 0),
    );

    blocTest<CaptureBloc, CaptureState>(
      'saves edits and confirmed tasks',
      build: sl.call,
      act: (b) async {
        b.add(const CaptureSubmitted(note));
        await untilState(b, (s) => s is CaptureReviewing);
        b
          ..add(const CaptureReviewEdited(title: 'Reading goal'))
          ..add(const CaptureConfirmed());
        await untilState(b, (s) => s is CaptureSaved);
      },
      verify: (b) async {
        final saved = b.state as CaptureSaved;
        final memory = await sl<MemoryRepository>().getById(saved.memoryId);
        expect(memory!.title, 'Reading goal');
        expect(memory.content, note.text);
        final tasks = await sl<TaskRepository>().forMemory(memory.id);
        expect(tasks.single.dueAt, DateTime(2026, 12, 15));
      },
    );

    // Regression: a failed analysis used to discard what the user typed.
    blocTest<CaptureBloc, CaptureState>(
      'keeps the typed input when analysis fails',
      build: () => CaptureBloc(
        analyzeCapture: AnalyzeCapture(
          linkReader: sl(),
          analyzer: _CrashingAnalyzer(),
          mediaReader: sl(),
          preferences: sl(),
          findSimilar: sl(),
          clock: FixedClock(),
          logger: const SilentLogger(),
        ),
        saveCapture: sl(),
        getCollections: sl(),
        startRecording: sl(),
        stopRecording: sl(),
        cancelRecording: sl(),
        clock: FixedClock(),
      ),
      act: (b) async {
        b.add(const CaptureSubmitted(note));
        await untilState(b, (s) => s is CaptureEditing && s.failure != null);
      },
      expect: () => [
        const CaptureAnalyzing(note),
        const CaptureEditing(failure: UnexpectedFailure(), input: note),
      ],
    );
  });

  group('AskBloc', () {
    const question = 'What was that React project idea?';

    setUp(() => sl<MemoryRepository>().save(memoryFixture()));

    Future<AskBloc> askOnce() async {
      final bloc = sl<AskBloc>()..add(const AskQuestionSubmitted(question));
      await untilState(bloc, (s) => s.messages.length == 2 && !s.isAnswering);
      return bloc;
    }

    test('answers with sources and returns to idle', () async {
      final bloc = await askOnce();
      expect(bloc.state.sources.keys, ['m1']);
      // The history list refreshes right after the answer completes.
      await untilState(bloc, (s) => s.conversations.length == 1);
      await bloc.close();
    });

    // Regression: regenerate used to leave the old answer and a duplicate
    // question in the database.
    test('regenerate replaces the stored answer instead of duplicating', () async {
      final bloc = await askOnce();
      final firstAnswer = bloc.state.messages.last.id;
      bloc.add(const AskRegenerateRequested());
      await untilState(
        bloc,
        (s) => s.messages.length == 2 && !s.isAnswering && s.messages.last.id != firstAnswer,
      );
      final stored = await sl<ConversationRepository>().messages(bloc.state.conversation!.id);
      expect(stored.map((m) => m.role.name), ['user', 'assistant']);
      expect(stored.last.id, isNot(firstAnswer));
      await bloc.close();
    });

    // Regression: "new chat" + "ask" (the Search hand-off) used to race, so
    // the question landed in the previously open conversation.
    test('a new chat started from Search never writes into the open chat', () async {
      final bloc = await askOnce();
      final first = bloc.state.conversation!.id;
      bloc
        ..add(const AskNewConversationRequested())
        ..add(const AskQuestionSubmitted('react habit tracker'));
      await untilState(
        bloc,
        (s) =>
            s.conversation != null &&
            s.conversation!.id != first &&
            !s.isAnswering &&
            s.messages.length == 2,
      );
      expect(await sl<ConversationRepository>().messages(first), hasLength(2));
      expect(bloc.state.messages.first.text, 'react habit tracker');
      expect(await sl<ConversationRepository>().getAll(), hasLength(2));
      await bloc.close();
    });
  });

  // Regression: in-collection search bypassed the use-case layer.
  test('CollectionCubit searches through SearchMemories within the collection', () async {
    final books = (await sl<CreateCollection>()((name: 'Books', emoji: '📚', isPrivate: false)))
        .valueOrNull!;
    final memories = sl<MemoryRepository>();
    await memories.save(memoryFixture(id: 'in', title: 'Deep Work', collectionId: books.id));
    await memories.save(memoryFixture(id: 'in2', title: 'Atomic Habits', collectionId: books.id));
    await memories.save(memoryFixture(id: 'out', title: 'Deep sea notes'));

    final cubit = sl<CollectionCubit>(param1: books.id);
    await cubit.search('deep');
    expect(cubit.data!.memories.map((m) => m.id), ['in']);
    expect(cubit.data!.totalCount, 2);
    await cubit.close();
  });

  // Regression: search results went stale after edits elsewhere.
  test('SearchBloc refreshes results when memories change', () async {
    await sl<MemoryRepository>().save(memoryFixture());
    final bloc = sl<SearchBloc>()..add(const SearchTextChanged('react'));
    await untilState(bloc, (s) => s.results.length == 1);
    await sl<MemoryRepository>().delete('m1');
    await untilState(bloc, (s) => s.status == SearchStatus.done && s.results.isEmpty);
    await bloc.close();
  });
}
