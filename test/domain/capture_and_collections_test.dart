import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/core/error/failure.dart';
import 'package:pocket_brain/core/usecase/usecase.dart';
import 'package:pocket_brain/domain/entities/capture.dart';
import 'package:pocket_brain/domain/entities/memory.dart';
import 'package:pocket_brain/domain/entities/memory_analysis.dart';
import 'package:pocket_brain/domain/repositories/memory_repository.dart';
import 'package:pocket_brain/domain/repositories/task_repository.dart';
import 'package:pocket_brain/domain/usecases/capture/capture_usecases.dart';
import 'package:pocket_brain/domain/usecases/collections/collection_usecases.dart';
import 'package:pocket_brain/domain/usecases/settings/settings_usecases.dart';
import 'package:pocket_brain/domain/usecases/tasks/task_usecases.dart';

import '../helpers/fakes.dart';
import '../helpers/test_dependencies.dart';

void main() {
  setUp(configureTestDependencies);

  test('AnalyzeCapture rejects empty input', () async {
    final result = await sl<AnalyzeCapture>()(
      const CaptureInput(text: '  ', source: MemorySource.note),
    );
    expect(result.failureOrNull, isA<ValidationFailure>());
  });

  test('AnalyzeCapture uses offline rules without a model', () async {
    final draft = (await sl<AnalyzeCapture>()(
      const CaptureInput(
        text: 'I need to finish reading this book before December 15.',
        source: MemorySource.note,
      ),
    )).valueOrNull!;
    expect(draft.analysis.origin, AnalysisOrigin.rules);
    expect(draft.analysis.tasks.single.dueAt, DateTime(2026, 12, 15));
  });

  test('SaveCapture keeps the original text and creates only selected tasks', () async {
    final saved = (await sl<SaveCapture>()(
      const SaveCaptureRequest(
        content: 'original words',
        source: MemorySource.note,
        title: '  ',
        summary: 's',
        category: 'Personal',
        tags: [],
        acceptedAiAsIs: false,
        tasks: [
          SuggestedTask(title: 'keep'),
          SuggestedTask(title: 'drop', selected: false),
        ],
      ),
    )).valueOrNull!;
    final stored = await sl<MemoryRepository>().getById(saved.id);
    expect(stored!.content, 'original words');
    expect(stored.title, SaveCapture.untitled);
    expect((await sl<TaskRepository>().getAll()).map((t) => t.title), ['keep']);
  });

  test('CreateCollection validates names and duplicates', () async {
    final create = sl<CreateCollection>();
    expect((await create((name: '', emoji: '📁', isPrivate: false))).failureOrNull,
        isA<ValidationFailure>());
    expect((await create((name: 'Books', emoji: '📚', isPrivate: false))).isSuccess, isTrue);
    expect((await create((name: 'books', emoji: '📚', isPrivate: false))).failureOrNull,
        isA<ValidationFailure>());
  });

  test('GetTaskBoard groups tasks by due date', () async {
    final add = sl<AddTask>();
    await add((title: 'late', dueAt: DateTime(2026, 11, 1), memoryId: null));
    await add((title: 'soon', dueAt: DateTime(2026, 11, 20), memoryId: null));
    await add((title: 'whenever', dueAt: null, memoryId: null));
    final board = (await sl<GetTaskBoard>()(noParams)).valueOrNull!;
    expect(board.overdue.single.title, 'late');
    expect(board.upcoming.single.title, 'soon');
    expect(board.anytime.single.title, 'whenever');
  });

  test('WipeAllData clears every store', () async {
    await sl<MemoryRepository>().save(memoryFixture());
    await sl<AddTask>()((title: 't', dueAt: null, memoryId: 'm1'));
    expect((await sl<WipeAllData>()(noParams)).isSuccess, isTrue);
    expect(await sl<MemoryRepository>().count(), 0);
    expect(await sl<TaskRepository>().getAll(), isEmpty);
  });
}
