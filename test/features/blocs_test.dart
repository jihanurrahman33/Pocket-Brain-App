import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/domain/entities/capture.dart';
import 'package:pocket_brain/domain/entities/memory.dart';
import 'package:pocket_brain/domain/repositories/memory_repository.dart';
import 'package:pocket_brain/domain/repositories/task_repository.dart';
import 'package:pocket_brain/features/ask/bloc/ask_bloc.dart';
import 'package:pocket_brain/features/capture/bloc/capture_bloc.dart';

import '../helpers/fakes.dart';
import '../helpers/test_dependencies.dart';

void main() {
  setUp(configureTestDependencies);

  const note = CaptureInput(
    text: 'I need to finish reading this book before December 15.',
    source: MemorySource.note,
  );

  blocTest<CaptureBloc, CaptureState>(
    'analyzes, then waits for review without saving',
    build: sl.call,
    act: (b) => b.add(const CaptureSubmitted(note)),
    wait: const Duration(milliseconds: 100),
    expect: () => [isA<CaptureAnalyzing>(), isA<CaptureReviewing>()],
    verify: (_) async => expect(await sl<MemoryRepository>().count(), 0),
  );

  blocTest<CaptureBloc, CaptureState>(
    'saves edits and confirmed tasks',
    build: sl.call,
    act: (b) async {
      b.add(const CaptureSubmitted(note));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b
        ..add(const CaptureReviewEdited(title: 'Reading goal'))
        ..add(const CaptureConfirmed());
    },
    wait: const Duration(milliseconds: 150),
    verify: (b) async {
      final saved = b.state as CaptureSaved;
      final memory = await sl<MemoryRepository>().getById(saved.memoryId);
      expect(memory!.title, 'Reading goal');
      expect(memory.content, note.text);
      expect((await sl<TaskRepository>().forMemory(memory.id)).single.dueAt, DateTime(2026, 12, 15));
    },
  );

  blocTest<AskBloc, AskState>(
    'answers with sources and returns to idle',
    setUp: () => sl<MemoryRepository>().save(memoryFixture()),
    build: sl.call,
    act: (b) => b.add(const AskQuestionSubmitted('What was that React project idea?')),
    wait: const Duration(milliseconds: 150),
    verify: (b) {
      expect(b.state.isAnswering, isFalse);
      expect(b.state.messages, hasLength(2));
      expect(b.state.sources.keys, ['m1']);
      expect(b.state.conversations, hasLength(1));
    },
  );
}
