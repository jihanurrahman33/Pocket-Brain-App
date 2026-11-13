import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/core/formatting/formatters.dart';
import 'package:pocket_brain/domain/services/assistant_toolbox.dart';
import 'package:pocket_brain/domain/services/reminder_time_parser.dart';

import '../helpers/fakes.dart';
import '../helpers/test_dependencies.dart';

void main() {
  // 00:02 on Saturday 14 November — the moment the bug was reported.
  final now = DateTime(2026, 11, 14, 0, 2);

  group('ReminderTimeParser', () {
    test('reads relative delays in English and Banglish', () {
      expect(
        ReminderTimeParser.relativeDelay('remind me after 5 minutes'),
        const Duration(minutes: 5),
      );
      expect(ReminderTimeParser.relativeDelay('in 2 hours'), const Duration(hours: 2));
      expect(ReminderTimeParser.relativeDelay('in half an hour'), const Duration(minutes: 30));
      expect(ReminderTimeParser.relativeDelay('in an hour'), const Duration(hours: 1));
      expect(ReminderTimeParser.relativeDelay('10 min later'), const Duration(minutes: 10));
      expect(
        ReminderTimeParser.relativeDelay('5 minute pore pani khete mone koro'),
        const Duration(minutes: 5),
      );
      expect(ReminderTimeParser.relativeDelay('2 ghonta pore'), const Duration(hours: 2));
      expect(ReminderTimeParser.relativeDelay('drink water'), isNull);
    });

    test('reads clock times and rolls past times to tomorrow', () {
      expect(ReminderTimeParser.clockTime('at 6 pm', now: now), DateTime(2026, 11, 14, 18));
      expect(ReminderTimeParser.clockTime('at 6:30pm', now: now), DateTime(2026, 11, 14, 18, 30));
      expect(ReminderTimeParser.clockTime('at 18:45', now: now), DateTime(2026, 11, 14, 18, 45));
      final evening = DateTime(2026, 11, 14, 20);
      expect(ReminderTimeParser.clockTime('at 7 am', now: evening), DateTime(2026, 11, 15, 7));
      expect(ReminderTimeParser.clockTime('read 5 books', now: now), isNull);
    });
  });

  group('create_task reminder times', () {
    setUp(configureTestDependencies);

    AssistantToolbox toolbox(String question) => AssistantToolbox(
      tasks: sl(),
      ids: SequentialIds(),
      clock: FixedClock(now),
      question: question,
    );

    // Regression: "remind me after 5 minutes" became "due today 12:00 AM,
    // reminder 9:00 AM".
    test('"after 5 minutes" reminds in 5 minutes with no deadline', () async {
      final box = toolbox('remind me after 5 minutes that I have to drink water');
      // What the small model actually sent: today's date and remind=true.
      await box.run(AssistantToolbox.createTask, {
        'title': 'Drink water',
        'due_date': '2026-11-14',
        'remind': true,
        'remind_in_minutes': 0,
        'remind_time': '',
      });
      final args = box.proposals.single.args;
      expect(args['reminder'], DateTime(2026, 11, 14, 0, 7).toIso8601String());
      expect(args['due'], '', reason: 'a relative reminder is not a deadline');
    });

    test("the user's words beat the model's arithmetic", () async {
      final box = toolbox('remind me in 2 hours to stretch');
      await box.run(AssistantToolbox.createTask, {
        'title': 'Stretch',
        'due_date': '',
        'remind': true,
        'remind_in_minutes': 20, // wrong
        'remind_time': '',
      });
      expect(box.proposals.single.args['reminder'], DateTime(2026, 11, 14, 2, 2).toIso8601String());
    });

    test("the model's structured fields are used when the text has no time", () async {
      final box = toolbox('remind me to call mum this evening');
      await box.run(AssistantToolbox.createTask, {
        'title': 'Call mum',
        'due_date': '',
        'remind': true,
        'remind_in_minutes': 0,
        'remind_time': '19:00',
      });
      expect(box.proposals.single.args['reminder'], DateTime(2026, 11, 14, 19).toIso8601String());
    });

    test('a deadline day without a time still reminds at 9:00', () async {
      final box = toolbox('remind me to pay rent on the 20th');
      await box.run(AssistantToolbox.createTask, {
        'title': 'Pay rent',
        'due_date': '2026-11-20',
        'remind': true,
        'remind_in_minutes': 0,
        'remind_time': '',
      });
      final args = box.proposals.single.args;
      expect(args['due'], '2026-11-20');
      expect(args['reminder'], DateTime(2026, 11, 20, 9).toIso8601String());
    });
  });

  test('due dates read as days, reminders as day + time', () {
    expect(Formatters.day(DateTime(2026, 11, 14), now: now), 'today');
    expect(Formatters.day(DateTime(2026, 11, 15), now: now), 'tomorrow');
    // intl puts a narrow no-break space (U+202F) before AM/PM.
    expect(
      Formatters.reminder(DateTime(2026, 11, 14, 0, 7), now: now).replaceAll('\u202f', ' '),
      'today at 12:07 AM',
    );
  });
}
