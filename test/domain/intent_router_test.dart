import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/domain/entities/task_item.dart';
import 'package:pocket_brain/domain/services/due_date_parser.dart';
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

  // Regression (real use): "i want to sing a song tomorrow" got "I couldn't
  // find that in your saved memories".
  group('plans become proposed tasks', () {
    for (final (message, title) in [
      ('i want to sing a song tomorrow', 'Sing a song'),
      ('I need to buy eggs', 'Buy eggs'),
      ("I'm going to visit grandma on Friday", 'Visit grandma'),
      ("I'll pay the electricity bill tonight", 'Pay the electricity bill'),
      ('tomorrow I have to submit the assignment', 'Submit the assignment'),
      ('I have to call the bank at 5 pm', 'Call the bank'),
      ('i gotta clean my room please', 'Clean my room'),
    ]) {
      test('"$message" → "$title"', () {
        final intent = classify(message);
        expect(intent, isA<PlanTaskIntent>(), reason: message);
        expect((intent as PlanTaskIntent).title, title);
      });
    }

    for (final message in [
      'I want to know what I saved about RAG', // a question in disguise
      'what do I need to do tomorrow?',
      'remind me after 5 minutes that i have to drink water', // model fills reminder
      'I want to be happy',
      'I finished the quarterly report',
    ]) {
      test('"$message" is not a plan', () {
        expect(classify(message), isNot(isA<PlanTaskIntent>()));
      });
    }
  });

  group('DueDateParser', () {
    final now = DateTime(2026, 11, 14, 22, 30); // a Saturday
    for (final (text, day) in [
      ('sing tomorrow', DateTime(2026, 11, 15)),
      ('tonight', DateTime(2026, 11, 14)),
      ('day after tomorrow', DateTime(2026, 11, 16)),
      ('on Friday', DateTime(2026, 11, 20)),
      ('next monday', DateTime(2026, 11, 16)),
      ('saturday', DateTime(2026, 11, 21)), // today is Saturday → next week
      ('kal gaan gaibo', DateTime(2026, 11, 15)),
    ]) {
      test('"$text"', () => expect(DueDateParser.parse(text, now: now), day));
    }
    test('no day named', () => expect(DueDateParser.parse('sing a song', now: now), isNull));
  });
}
