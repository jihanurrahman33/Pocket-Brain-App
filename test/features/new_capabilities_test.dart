import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/core/usecase/usecase.dart';
import 'package:pocket_brain/data/datasources/ai/on_device_ai_runtime.dart';
import 'package:pocket_brain/data/datasources/local/database_schema.dart';
import 'package:pocket_brain/data/services/ai/media_reader.dart';
import 'package:pocket_brain/data/services/notifications/local_notification_scheduler.dart';
import 'package:pocket_brain/domain/entities/ask.dart';
import 'package:pocket_brain/domain/entities/assistant.dart';
import 'package:pocket_brain/domain/entities/capture.dart';
import 'package:pocket_brain/domain/entities/memory.dart';
import 'package:pocket_brain/domain/entities/task_item.dart';
import 'package:pocket_brain/domain/repositories/memory_repository.dart';
import 'package:pocket_brain/domain/repositories/task_repository.dart';
import 'package:pocket_brain/domain/services/assistant_toolbox.dart';
import 'package:pocket_brain/domain/usecases/ask/ask_usecases.dart';
import 'package:pocket_brain/domain/usecases/capture/capture_usecases.dart';
import 'package:pocket_brain/domain/usecases/memories/memory_usecases.dart';
import 'package:pocket_brain/domain/usecases/tasks/task_usecases.dart';
import 'package:pocket_brain/features/capture/bloc/capture_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/test_dependencies.dart';

File _image() =>
    File('${testFilesDirectory.path}/receipt.png')
      ..writeAsBytesSync([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]);

void main() {
  late FakeAiRuntime ai;

  setUp(() async {
    ai = await configureTestDependencies(
      runtime: FakeAiRuntime(installed: {AiModelKind.languageModel}),
    );
  });

  group('Image + OCR capture', () {
    test('reads the image, labels AI text, and keeps the original file', () async {
      final image = _image();
      final draft = (await sl<AnalyzeCapture>()(
        CaptureInput(
          text: 'Groceries',
          source: MemorySource.image,
          media: CapturedMedia(path: image.path, kind: AttachmentKind.image),
        ),
      )).valueOrNull!;

      expect(ai.requests.first.image, isNotNull, reason: 'the image went to the model');
      expect(draft.reading!.extractedText, contains('MILK 2.49'));
      expect(draft.content, startsWith('Groceries'));
      expect(draft.content, contains('Text in image:\nMILK 2.49'));

      final saved = (await sl<SaveCapture>()(
        SaveCaptureRequest(
          content: draft.content,
          source: draft.source,
          title: 'Receipt',
          summary: '',
          category: 'Personal',
          tags: const [],
          tasks: const [],
          acceptedAiAsIs: false,
          media: draft.media,
        ),
      )).valueOrNull!;
      final kept = saved.image!;
      expect(File(kept.path).existsSync(), isTrue);
      expect(image.existsSync(), isTrue, reason: "the user's own file is copied, never moved");

      expect((await sl<DeleteMemory>()(saved.id)).isSuccess, isTrue);
      expect(File(kept.path).existsSync(), isFalse, reason: 'deleting a memory deletes its files');
    });

    test('without the AI, the image is still saved with the note', () async {
      ai.installed = {};
      final draft = (await sl<AnalyzeCapture>()(
        CaptureInput(
          text: 'Whiteboard',
          source: MemorySource.image,
          media: CapturedMedia(path: _image().path, kind: AttachmentKind.image),
        ),
      )).valueOrNull!;
      expect(draft.reading, isNull);
      expect(draft.media, isNotNull);
      expect(ai.requests, isEmpty);
    });

    test('parses image readings robustly', () {
      expect(
        GemmaMediaReader.parseImageReading('Sure! {"text": "Hi", "description": "A sign"}')
            .extractedText,
        'Hi',
      );
      expect(GemmaMediaReader.parseImageReading('no json').description, 'no json');
    });
  });

  test('Voice capture: record, transcribe, review', () async {
    final bloc = sl<CaptureBloc>()..add(const CaptureRecordingStarted());
    await untilState(bloc, (s) => s is CaptureRecording);
    bloc.add(const CaptureRecordingStopped());
    final review = await untilState(bloc, (s) => s is CaptureReviewing) as CaptureReviewing;
    expect(review.review.draft.source, MemorySource.voice);
    expect(review.review.draft.content, contains('call the dentist'));
    // One request transcribes; the transcript is then analysed as text.
    expect(ai.requests.where((r) => r.audio != null), hasLength(1));

    final recording = review.review.draft.media!.path;
    bloc.add(const CaptureConfirmed());
    final saved = await untilState(bloc, (s) => s is CaptureSaved) as CaptureSaved;
    final memory = await sl<MemoryRepository>().getById(saved.memoryId);
    expect(memory!.recording, isNotNull);
    expect(File(recording).existsSync(), isFalse, reason: 'temporary recordings are moved');
    await bloc.close();
  });

  group('Ask Brain tools', () {
    Future<AskAnswerCompleted> ask(String question) async => (await sl<AskBrain>()(
      AskRequest(question: question),
    ).toList()).whereType<AskAnswerCompleted>().single;

    test('a create_task call becomes a proposal, not a task', () async {
      ai
        ..toolCalls = [
          (
            AssistantToolbox.createTask,
            {'title': 'Finish the book', 'due_date': '2026-12-15', 'remind': true},
          ),
        ]
        ..reply = ['I can add that for you.'];
      final answer = (await ask('Remind me to finish the book by December 15')).message;

      expect(answer.actions.single.type, AssistantActionType.createTask);
      expect(answer.actions.single.isPending, isTrue);
      expect(answer.actions.single.args['reminder'], '2026-12-15T09:00:00.000');
      expect(await sl<TaskRepository>().getAll(), isEmpty, reason: 'nothing happens unconfirmed');
      expect(ai.toolResults.single['status'], 'waiting_for_user_confirmation');

      // Confirming creates the task with its reminder and schedules it.
      final done = (await sl<ConfirmAssistantAction>()((
        message: answer,
        actionId: answer.actions.single.id,
      ))).valueOrNull!;
      expect(done.actions.single.status, AssistantActionStatus.done);
      final task = (await sl<TaskRepository>().getAll()).single;
      expect(task.title, 'Finish the book');
      expect(testReminders.scheduled[task.id], DateTime(2026, 12, 15, 9));
    });

    test('dismissing changes nothing', () async {
      ai.toolCalls = [
        (AssistantToolbox.saveMemory, {'text': 'Locker code is 4312'}),
      ];
      final answer = (await ask('Remember that my locker code is 4312')).message;
      final dismissed = (await sl<DismissAssistantAction>()((
        message: answer,
        actionId: answer.actions.single.id,
      ))).valueOrNull!;
      expect(dismissed.actions.single.status, AssistantActionStatus.dismissed);
      expect(await sl<MemoryRepository>().count(), 0);
    });

    test('list_tasks answers are grounded in real tasks', () async {
      await sl<AddTask>()(NewTask(title: 'Pay rent', dueAt: DateTime(2026, 11, 1)));
      ai
        ..toolCalls = [
          (AssistantToolbox.listTasks, {'filter': 'overdue'}),
        ]
        ..reply = ['Pay rent is overdue.'];
      // Not worded as a task question, so the model decides to call the tool.
      final answer = (await ask('Is there anything I forgot to pay?')).message;
      expect(answer.text, 'Pay rent is overdue.');
      expect(answer.grounded, isTrue);
      final listed = ai.toolResults.single['tasks']! as List<Object?>;
      expect((listed.single! as Map)['title'], 'Pay rent');
    });

    // The app, not the model, draws listed tasks as cards.
    test('listed tasks are shown as cards and survive reopening the chat', () async {
      await sl<AddTask>()(NewTask(title: 'Pay rent', dueAt: DateTime(2026, 11, 1)));
      ai
        ..toolCalls = [
          (AssistantToolbox.listTasks, {'filter': 'open'}),
        ]
        ..reply = ['You have **1** open task.'];
      final events = await sl<AskBrain>()(const AskRequest(question: 'What todos do I have?'))
          .toList();
      final found = events.whereType<AskTasksFound>().single.tasks;
      expect(found.single.title, 'Pay rent');
      final answer = events.whereType<AskAnswerCompleted>().single.message;
      expect(answer.taskIds, [found.single.id]);
      expect(answer.text, 'You have 1 open task: 1 overdue.');

      final reopened = (await sl<OpenConversation>()(answer.conversationId)).valueOrNull!;
      expect(reopened.tasks.keys, [found.single.id]);
      expect(reopened.messages.last.taskIds, [found.single.id]);
    });

    test('never invents: no memories and no tool data means "not found"', () async {
      ai.reply = ['Paris is the capital of France.'];
      final answer = (await ask('What is the capital of France?')).message;
      expect(answer.text, AskReplies.notFound);
      expect(answer.grounded, isFalse);
    });

    test('bad tool arguments are reported to the model, not thrown', () async {
      final toolbox = AssistantToolbox(tasks: sl(), ids: SequentialIds(), clock: FixedClock());
      expect(
        (await toolbox.run(AssistantToolbox.createTask, {
          'title': 'x',
          'due_date': 'soon',
        }))['error'],
        isNotNull,
      );
      expect((await toolbox.run('format_disk', {}))['error'], isNotNull);
      expect(toolbox.proposals, isEmpty);
    });
  });

  group('Reminders', () {
    test('task writes keep notifications in sync', () async {
      final task = (await sl<AddTask>()(
        NewTask(title: 'Call mum', reminderAt: DateTime(2026, 11, 14, 9)),
      )).valueOrNull!;
      expect(testReminders.scheduled[task.id], DateTime(2026, 11, 14, 9));

      await sl<ToggleTaskDone>()(task);
      expect(testReminders.scheduled, isEmpty, reason: 'done tasks do not remind');

      final other = (await sl<AddTask>()(
        NewTask(title: 'Dentist', reminderAt: DateTime(2026, 11, 20, 9)),
      )).valueOrNull!;
      await sl<DeleteTask>()(other.id);
      expect(testReminders.scheduled, isEmpty);
    });

    test('start-up sync restores scheduled reminders', () async {
      await sl<TaskRepository>().save(
        TaskItem(id: 't1', title: 'Gym', createdAt: testNow, reminderAt: DateTime(2026, 11, 15, 7)),
      );
      testReminders.scheduled.clear(); // e.g. lost after a reboot
      await sl<SyncReminders>()(noParams);
      expect(testReminders.scheduled.keys, ['t1']);
    });

    test('notification ids are stable across launches', () {
      expect(
        LocalNotificationReminderScheduler.notificationIdFor('task-123'),
        LocalNotificationReminderScheduler.notificationIdFor('task-123'),
      );
      expect(LocalNotificationReminderScheduler.notificationIdFor('a'), isNonNegative);
    });
  });

  test('database v1 → latest migration keeps data and adds columns', () async {
    sqfliteFfiInit();
    final path = '${testFilesDirectory.path}/v1.db';
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE collections (id TEXT PRIMARY KEY, name TEXT, emoji TEXT, is_private INTEGER, created_at INTEGER)',
          );
          await db.execute(
            "CREATE TABLE memories (id TEXT PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL, summary TEXT NOT NULL DEFAULT '', source TEXT NOT NULL, source_url TEXT, category TEXT NOT NULL, tags TEXT NOT NULL DEFAULT '[]', collection_id TEXT, is_favorite INTEGER NOT NULL DEFAULT 0, is_archived INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, last_viewed_at INTEGER, ai_generated INTEGER NOT NULL DEFAULT 0, embedding BLOB)",
          );
          await db.execute(
            "CREATE TABLE messages (id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, role TEXT NOT NULL, text TEXT NOT NULL, source_ids TEXT NOT NULL DEFAULT '[]', grounded INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL)",
          );
          await db.insert('memories', {
            'id': 'old',
            'title': 'Old',
            'content': 'kept',
            'source': 'note',
            'category': 'Personal',
            'created_at': 0,
            'updated_at': 0,
          });
        },
      ),
    );
    await v1.close();

    final v2 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onUpgrade: DatabaseSchema.migrate,
      ),
    );
    final row = (await v2.query('memories')).single;
    expect(row['content'], 'kept');
    expect(row['attachments'], '[]');
    final columns = await v2.rawQuery('PRAGMA table_info(messages)');
    expect(columns.map((c) => c['name']), containsAll(['actions', 'task_ids']));
    await v2.close();
  });
}
