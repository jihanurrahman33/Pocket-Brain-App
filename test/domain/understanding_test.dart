import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/core/usecase/usecase.dart';
import 'package:pocket_brain/data/datasources/ai/on_device_ai_runtime.dart';
import 'package:pocket_brain/data/services/ai/parsers/intent_response_parser.dart';
import 'package:pocket_brain/data/services/ai/prompts/intent_prompt.dart';
import 'package:pocket_brain/domain/entities/ask.dart';
import 'package:pocket_brain/domain/entities/assistant.dart';
import 'package:pocket_brain/domain/entities/conversation.dart';
import 'package:pocket_brain/domain/entities/task_item.dart';
import 'package:pocket_brain/domain/entities/user_intent.dart';
import 'package:pocket_brain/domain/repositories/intent_correction_repository.dart';
import 'package:pocket_brain/domain/repositories/memory_repository.dart';
import 'package:pocket_brain/domain/repositories/task_repository.dart';
import 'package:pocket_brain/domain/services/ai_services.dart';
import 'package:pocket_brain/domain/services/task_resolver.dart';
import 'package:pocket_brain/domain/usecases/ask/ask_usecases.dart';
import 'package:pocket_brain/domain/usecases/ask/understand_message.dart';
import 'package:pocket_brain/domain/usecases/settings/settings_usecases.dart';
import 'package:pocket_brain/domain/usecases/tasks/task_usecases.dart';
import 'package:pocket_brain/features/ask/bloc/ask_bloc.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/test_dependencies.dart';

// The test clock is Friday 2026-11-13 10:00.
const _tomorrow = '2026-11-14';

void main() {
  group('IntentResponseParser', () {
    test('reads a full intent', () {
      final intent = IntentResponseParser.parse(
        FakeAiRuntime.intentJson('create_task', title: 'Go hiking', date: _tomorrow, time: '7:30'),
      )!;
      expect(intent.type, IntentType.createTask);
      expect(intent.title, 'Go hiking');
      expect(intent.date, DateTime(2026, 11, 14));
      expect(intent.time, '07:30');
      expect(intent.source, IntentSource.model);
    });

    test('tolerates code fences and rejects garbage', () {
      expect(
        IntentResponseParser.parse('```json\n{"intent": "list_tasks", "filter": "today"}\n```')
            ?.filter,
        'today',
      );
      expect(IntentResponseParser.parse('{"intent": "fly_to_moon"}'), isNull);
      expect(IntentResponseParser.parse('no json here'), isNull);
      final bad = IntentResponseParser.parse(
        '{"intent": "create_task", "date": "next week", "time": "25:99", "filter": "x"}',
      )!;
      expect(bad.date, isNull);
      expect(bad.time, isEmpty);
      expect(bad.filter, isEmpty);
    });
  });

  group('IntentPrompt', () {
    test('carries the calendar, the conversation and user corrections', () {
      final now = DateTime(2026, 11, 13, 10);
      final task = TaskItem(id: 't', title: 'Call mum', createdAt: now);
      final request = IntentPrompt.build(
        'the first one',
        now: now,
        openTasks: [task],
        context: IntentContext(recentTasks: [task]),
        examples: const [IntentExample('gym time', IntentType.createTask)],
      );
      expect(request.jsonSchema, isNotNull);
      expect(request.prompt, contains('NEXT DAYS: Sat 2026-11-14'));
      expect(request.prompt, contains('LAST ANSWER SHOWED: 1. Call mum'));
      expect(request.prompt, contains('"gym time" → create_task'));
      expect(request.prompt, contains('MESSAGE: "the first one"'));
    });
  });

  group('UnderstandMessage', () {
    late FakeAiRuntime ai;

    setUp(() async {
      ai = await configureTestDependencies(
        runtime: FakeAiRuntime(installed: {AiModelKind.languageModel}),
      );
    });

    Future<UserIntent> understand(String message, {IntentType? forced}) => sl<UnderstandMessage>()((
      message: message,
      tasks: const [],
      context: IntentContext.empty,
      forcedIntent: forced,
    ));

    test('reliable phrasings skip the model (fast path)', () async {
      expect((await understand('what todos do I have?')).type, IntentType.listTasks);
      expect(ai.intentRequests, isEmpty);
    });

    test('anything else is understood by the model', () async {
      ai.intentReply = FakeAiRuntime.intentJson('create_task', title: 'Go hiking', date: _tomorrow);
      final intent = await understand("I'd love to go hiking tomorrow");
      expect(intent.type, IntentType.createTask);
      expect(intent.title, 'Go hiking');
      expect(intent.source, IntentSource.model);
    });

    test('unsure changes become "unclear" instead of guesses', () async {
      ai.intentReply = FakeAiRuntime.intentJson('delete_task', confidence: 0.5, taskRef: 'gym');
      expect((await understand('gym thing')).type, IntentType.unclear);
      // A low-confidence lookup is harmless and kept.
      ai.intentReply = FakeAiRuntime.intentJson('ask_memory', confidence: 0.3);
      expect((await understand('hmm the thing')).type, IntentType.askMemory);
    });

    test('dates: known phrases are computed exactly; past model dates dropped', () async {
      ai.intentReply = FakeAiRuntime.intentJson('create_task', title: 'Gym', date: '2026-11-20');
      expect((await understand('gym tomorrow please')).date, DateTime(2026, 11, 14));
      ai.intentReply = FakeAiRuntime.intentJson('create_task', title: 'Gym', date: '2026-01-01');
      expect((await understand('gym on the first')).date, isNull);
    });

    test('a corrected intent wins over everything', () async {
      final intent = await understand('what todos do I have?', forced: IntentType.saveNote);
      expect(intent.type, IntentType.saveNote);
      expect(intent.source, IntentSource.correction);
    });

    test('a failed or unavailable model falls back safely', () async {
      ai.intentReply = 'not json';
      expect((await understand('blah blah')).type, IntentType.askMemory);
      ai.installed = {};
      expect((await understand('blah blah')).type, IntentType.askMemory);
    });
  });

  group('AskBrain end to end with understood intents', () {
    late FakeAiRuntime ai;

    setUp(() async {
      ai = await configureTestDependencies(
        runtime: FakeAiRuntime(installed: {AiModelKind.languageModel}),
      );
    });

    Future<List<AskProgress>> say(String q, {List<ChatMessage> history = const []}) =>
        sl<AskBrain>()(AskRequest(question: q, history: history)).toList();
    ChatMessage answerOf(List<AskProgress> events) =>
        events.whereType<AskAnswerCompleted>().single.message;
    Future<TaskItem> add(String title, {DateTime? due}) async =>
        (await sl<AddTask>()(NewTask(title: title, dueAt: due))).valueOrNull!;

    test('any wording of a plan becomes a confirmable task', () async {
      ai.intentReply = FakeAiRuntime.intentJson('create_task', title: 'Go hiking', date: _tomorrow);
      final answer = answerOf(await say("I'd really love to go hiking tomorrow"));
      expect(answer.text, 'Add "Go hiking" for tomorrow to your tasks? Confirm below.');
      expect(answer.actions.single.args, containsPair('due', _tomorrow));
      expect(ai.otherRequests, isEmpty, reason: 'one understanding call, no answer call');
    });

    test('reschedule is proposed, and Confirm moves the task', () async {
      final task = await add('Dentist appointment', due: DateTime(2026, 11, 16));
      ai.intentReply = FakeAiRuntime.intentJson(
        'reschedule_task',
        taskRef: 'dentist',
        date: '2026-11-20',
      );
      final answer = answerOf(await say('push the dentist thing to next friday'));
      final action = answer.actions.single;
      expect(action.type, AssistantActionType.rescheduleTask);
      expect(action.args['due'], '2026-11-20');
      await sl<ConfirmAssistantAction>()((message: answer, actionId: action.id));
      final moved = (await sl<TaskRepository>().getAll()).single;
      expect(moved.id, task.id);
      expect(moved.dueAt, DateTime(2026, 11, 20));
    });

    test('delete needs Confirm', () async {
      await add('Gym session');
      ai.intentReply = FakeAiRuntime.intentJson('delete_task', taskRef: 'gym');
      final answer = answerOf(await say('get rid of the gym one'));
      expect(await sl<TaskRepository>().getAll(), hasLength(1), reason: 'not yet');
      await sl<ConfirmAssistantAction>()((message: answer, actionId: answer.actions.single.id));
      expect(await sl<TaskRepository>().getAll(), isEmpty);
    });

    test('follow-ups resolve against the last answer ("the second one")', () async {
      await add('Buy milk');
      await add('Call mum');
      final list = await say('my todos');
      final shown = list.whereType<AskTasksFound>().single.tasks;
      ai.intentReply = FakeAiRuntime.intentJson('complete_task', taskRef: 'the second one');
      final answer = answerOf(
        await say(
          'done with the second one',
          history: [list.whereType<AskQuestionRecorded>().single.message, answerOf(list)],
        ),
      );
      expect(answer.text, startsWith('Marked "${shown[1].title}" as done'));
    });

    test('reopen, today list, small talk and out of scope', () async {
      final milk = await add('Buy milk', due: DateTime(2026, 11, 13));
      await sl<TaskRepository>().save(milk.copyWith(isDone: true));
      ai.intentReply = FakeAiRuntime.intentJson('reopen_task', taskRef: 'milk');
      expect(answerOf(await say("actually I haven't bought milk")).text, 'Reopened "Buy milk".');

      ai.intentReply = FakeAiRuntime.intentJson('list_tasks', filter: 'today');
      expect(answerOf(await say('anything for today')).text, 'You have 1 task for today.');

      ai.intentReply = FakeAiRuntime.intentJson('small_talk');
      expect(answerOf(await say('feeling good')).text, startsWith("I'm here!"));

      ai.intentReply = FakeAiRuntime.intentJson('out_of_scope');
      expect(
        answerOf(await say('weather in Dhaka')).text,
        contains("I only know what you've saved"),
      );
    });

    // Real model output: "where did I park?" was filed under out_of_scope.
    test('a personal question misfiled as out-of-scope still finds the memory', () async {
      await sl<MemoryRepository>().save(
        memoryFixture(
          title: 'parking spot',
          content: 'I parked the car on level 3 spot B12.',
          tags: const ['parking'],
        ),
      );
      ai
        ..intentReply = FakeAiRuntime.intentJson('out_of_scope')
        ..reply = ['You parked on level 3, spot B12 [1].'];
      final answer = answerOf(await say('where did I park the car?'));
      expect(answer.text, contains('level 3'));
      expect(answer.sourceIds, hasLength(1));
    });

    test('out-of-scope with no matching memory gets the polite reply', () async {
      ai.intentReply = FakeAiRuntime.intentJson('out_of_scope');
      expect(answerOf(await say('who won the world cup?')).text, contains('I only know'));
    });

    test('"not done" reopens a finished task without the model', () async {
      final milk = await add('Buy milk');
      await sl<TaskRepository>().save(milk.copyWith(isDone: true));
      final answer = answerOf(await say('buy milk is not done actually'));
      expect(answer.text, 'Reopened "Buy milk".');
      expect(ai.requests, isEmpty);
    });

    test('"what do I have to do tomorrow?" lists tomorrow only', () async {
      await add('Gym', due: DateTime(2026, 11, 14));
      await add('Dentist', due: DateTime(2026, 11, 20));
      final events = await say('what do I have to do tomorrow?');
      expect(answerOf(events).text, 'You have 1 task for tomorrow.');
      expect(events.whereType<AskTasksFound>().single.tasks.single.title, 'Gym');
    });

    // Real use: "give me a form for input and save my bajar list" became the
    // task "Bajar list form" due tomorrow (a day nobody mentioned).
    test('"save my bajar list" asks what to save, then saves the next message', () async {
      ai.intentReply = FakeAiRuntime.intentJson(
        'create_task',
        title: 'Bajar list form',
        date: _tomorrow,
      );
      final first = await say('give me a form for input and save my bajar list');
      final ask = answerOf(first);
      expect(ask.text, AskReplies.noteContentPrompt);
      expect(ask.actions, isEmpty);

      ai.intentReply = FakeAiRuntime.intentJson('small_talk');
      final second = answerOf(
        await say(
          'rice, eggs, onions, 2kg potatoes',
          history: [first.whereType<AskQuestionRecorded>().single.message, ask],
        ),
      );
      expect(second.actions.single.type, AssistantActionType.saveMemory);
      expect(second.actions.single.args['text'], 'rice, eggs, onions, 2kg potatoes');
    });

    test('saying "never mind" after the prompt does not save it', () async {
      ai.intentReply = FakeAiRuntime.intentJson('small_talk');
      final first = await say('save my bajar list');
      final answer = answerOf(
        await say(
          'never mind',
          history: [first.whereType<AskQuestionRecorded>().single.message, answerOf(first)],
        ),
      );
      expect(answer.actions, isEmpty);
    });

    test('a date the user never said is dropped', () async {
      ai.intentReply = FakeAiRuntime.intentJson(
        'create_task',
        title: 'Water plants',
        date: _tomorrow,
      );
      final answer = answerOf(await say('please handle the plants somehow'));
      expect(answer.actions.single.args['due'], isEmpty);
    });

    test('unclear messages offer a task or a note, never a dead end', () async {
      ai.intentReply = FakeAiRuntime.intentJson('unclear', confidence: 0.2);
      final answer = answerOf(await say('the blue notebook'));
      expect(answer.text, contains('add it as a task or save it as a note'));
      expect(answer.actions.map((a) => a.type), [
        AssistantActionType.createTask,
        AssistantActionType.saveMemory,
      ]);
    });

    test('"Not what I meant" redoes the answer and teaches the model', () async {
      ai.intentReply = FakeAiRuntime.intentJson('small_talk');
      final bloc = sl<AskBloc>()..add(const AskQuestionSubmitted('gym at 7 tomorrow'));
      await untilState(bloc, (s) => s.messages.length == 2 && !s.isAnswering);

      bloc.add(const AskIntentCorrected(IntentType.createTask));
      await untilState(bloc, (s) => s.messages.length == 2 && s.messages.last.actions.isNotEmpty);
      expect(bloc.state.messages.last.actions.single.type, AssistantActionType.createTask);
      expect(await sl<IntentCorrectionRepository>().recent(), [
        const IntentExample('gym at 7 tomorrow', IntentType.createTask),
      ]);

      bloc.add(const AskQuestionSubmitted('swim at 8'));
      await untilState(bloc, (s) => s.messages.length == 4 && !s.isAnswering);
      expect(ai.intentRequests.last.prompt, contains('"gym at 7 tomorrow" → create_task'));
      await bloc.close();
    });
  });

  group('TaskResolver', () {
    final now = DateTime(2026, 11, 13);
    final report = TaskItem(id: 'r', title: 'Quarterly report for finance', createdAt: now);
    final milk = TaskItem(id: 'm', title: 'Buy milk', createdAt: now);

    test('by meaning when the words differ', () async {
      final resolver = TaskResolver(_KeywordEmbedder());
      expect(await resolver.resolve('the Q4 numbers doc', [report, milk]), [report]);
      expect(await resolver.resolve('walk the dog', [report, milk]), isEmpty);
    });

    test('pronouns and ordinals use what was just shown', () async {
      final resolver = TaskResolver(_KeywordEmbedder());
      expect(await resolver.resolve('it', [report, milk], recent: [milk]), [milk]);
      expect(await resolver.resolve('the first one', [report, milk], recent: [milk, report]), [
        milk,
      ]);
      expect(await resolver.resolve('last', [report, milk], recent: [milk, report]), [report]);
    });
  });

  test('wiping all data also forgets corrections', () async {
    await configureTestDependencies();
    await sl<IntentCorrectionRepository>().add(const IntentExample('x', IntentType.saveNote));
    await sl<WipeAllData>()(noParams);
    expect(await sl<IntentCorrectionRepository>().recent(), isEmpty);
  });
}

/// Maps texts about reports/finance close together, everything else apart.
final class _KeywordEmbedder implements TextEmbedder {
  @override
  bool get isAvailable => true;

  @override
  Future<Float32List?> embed(String text, EmbeddingPurpose purpose) async {
    final t = text.toLowerCase();
    final finance = ['report', 'q4', 'numbers', 'finance', 'doc'].any(t.contains);
    final groceries = ['milk', 'buy'].any(t.contains);
    return Float32List.fromList([
      finance ? 1 : 0,
      groceries ? 1 : 0,
      (!finance && !groceries) ? 1 : 0,
    ]);
  }
}
