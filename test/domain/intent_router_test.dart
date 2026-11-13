import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/domain/entities/task_item.dart';
import 'package:pocket_brain/domain/services/intent_router.dart';

import '../helpers/fakes.dart';

TaskItem _task(String id, String title, {bool done = false}) =>
    TaskItem(id: id, title: title, createdAt: testNow, isDone: done);

void main() {
  final tasks = [
    _task('water', 'drink water'),
    _task('google', 'Important meeting with Google'),
    _task('report', 'Finish the quarterly report'),
    _task('mum', 'Call mum'),
    _task('old', 'Buy milk', done: true),
  ];

  AskIntent classify(String message) => IntentRouter.classify(message, tasks);

  group('completing a task (phrases from real use)', () {
    for (final message in [
      'drink water done',
      'check the drink water todo im done with that',
      'i have drinked water',
      'I drank water', // irregular past + exact title words
      'mark drink water as done',
      'done with drink water',
      'drink water korechi',
      'I called mum',
      'finished the quarterly report',
    ]) {
      test('"$message"', () {
        final intent = classify(message);
        expect(intent, isA<CompleteTaskIntent>(), reason: message);
      });
    }

    test('picks the task the message names', () {
      expect((classify('drink water done') as CompleteTaskIntent).matches.single.id, 'water');
      expect((classify('I called mum') as CompleteTaskIntent).matches.single.id, 'mum');
      expect(
        (classify(
          'check the drink water todo im done with that',
        ) as CompleteTaskIntent).matches.single.id,
        'water',
      );
    });

    test('a completed task is never completed again, but recognised', () {
      final intent = classify('buy milk done') as CompleteTaskIntent;
      expect(intent.matches, isEmpty);
      expect(intent.alreadyDone.single.id, 'old');
    });
  });

  group('not a completion', () {
    for (final message in [
      'I need to finish the quarterly report', // intention
      'remind me after 5 minutes that i have to drink water', // creation
      'add a task to drink water',
      'did I drink water today?', // question
      "I'm done with Atomic Habits", // no task named, no task words
      'what todos i have now?',
    ]) {
      test('"$message"', () => expect(classify(message), isNot(isA<CompleteTaskIntent>())));
    }
  });

  group('asking about tasks', () {
    for (final (message, filter) in [
      ('todos?', 'open'),
      ('what todos i have now?', 'open'),
      ("What's overdue?", 'overdue'),
      ('my tasks', 'open'),
      ('amar ki kaj ache?', 'open'),
      ('what tasks have I completed?', 'done'),
    ]) {
      test('"$message" → $filter', () {
        final intent = classify(message);
        expect(intent, isA<QueryTasksIntent>(), reason: message);
        expect((intent as QueryTasksIntent).filter, filter);
      });
    }
  });

  group('memory questions', () {
    for (final message in [
      'tell me about book i forgot',
      'What was that React project idea?',
      'ami ekta boi portesilam eta kobe sesh hobe?',
      'remind me to call the dentist next Friday',
    ]) {
      test('"$message"', () => expect(classify(message), isA<MemoryQuestionIntent>()));
    }
  });
}
