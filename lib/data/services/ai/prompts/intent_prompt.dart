import 'package:intl/intl.dart';

import '../../../../domain/entities/assistant.dart';
import '../../../../domain/entities/task_item.dart';
import '../../../../domain/entities/user_intent.dart';
import '../../../datasources/ai/on_device_ai_runtime.dart';

/// The understanding prompt: any message → one intent with its details, as
/// JSON constrained by [schema]. Short on purpose: it runs before every
/// non-trivial answer, on 4 GB phones too.
abstract final class IntentPrompt {
  static const _maxTasks = 15;
  static const _maxMessageChars = 500;

  static final schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'intent': {
        'type': 'string',
        'enum': [for (final t in IntentType.values) t.wireName],
      },
      'confidence': {'type': 'number'},
      'title': {'type': 'string'},
      'date': {'type': 'string'},
      'time': {'type': 'string'},
      'task_ref': {'type': 'string'},
      'query': {'type': 'string'},
      'note': {'type': 'string'},
      'filter': {
        'type': 'string',
        'enum': ['', 'open', 'overdue', 'done', 'today', 'tomorrow'],
      },
    },
    // Query, note and time are optional: leaving them out keeps the output
    // (and the wait) short. Dropping the others made the model skip titles.
    'required': ['intent', 'confidence', 'title', 'date', 'task_ref', 'filter'],
  };

  static GenerationRequest build(
    String message, {
    required DateTime now,
    required List<TaskItem> openTasks,
    IntentContext context = IntentContext.empty,
    List<IntentExample> examples = const [],
  }) {
    final day = DateFormat('yyyy-MM-dd');
    String plus(int days) => day.format(DateTime(now.year, now.month, now.day + days));
    final upcoming = [
      for (var i = 1; i <= 8; i++)
        '${DateFormat('EEE').format(DateTime(now.year, now.month, now.day + i))} ${plus(i)}',
    ];
    final friday = (DateTime.friday - now.weekday) % 7 == 0
        ? 7
        : (DateTime.friday - now.weekday) % 7;

    final p = StringBuffer()
      ..writeln('NOW: ${DateFormat('EEEE yyyy-MM-dd HH:mm').format(now)}')
      ..writeln('NEXT DAYS: ${upcoming.join(', ')}');
    if (openTasks.isNotEmpty) {
      p.writeln("USER'S OPEN TASKS: ${openTasks.take(_maxTasks).map((t) => t.title).join('; ')}");
    }
    if (context.recentTasks.isNotEmpty) {
      p.writeln(
        'LAST ANSWER SHOWED: '
        '${[for (final (i, t) in context.recentTasks.indexed) '${i + 1}. ${t.title}'].join('; ')}',
      );
    }
    if (context.pendingProposal case final AssistantAction a
        when a.type == AssistantActionType.createTask) {
      p.writeln(
        'WAITING FOR CONFIRMATION: create task "${a.args['title']}"'
        '${(a.args['due'] ?? '').isEmpty ? '' : ' on ${a.args['due']}'}',
      );
    }
    p.writeln('''
INTENTS: create_task (plan/need/wish/reminder; title=2-5 words, no day/time), complete_task (is done or was done, past tense too: "talked to mum", "went to the gym"; task_ref), reopen_task (not done after all; task_ref), reschedule_task (move; task_ref+date/time), delete_task (remove; task_ref), list_tasks (asks about tasks; filter open/overdue/done/today/tomorrow), save_note (remember a fact; note), ask_memory (asks about anything they saved, read, own or did, incl. facts like codes, places, numbers, birthdays; query=English keywords), small_talk (greeting/thanks/feelings), out_of_scope (world knowledge, or things this app cannot do: play music, alarms, send messages; NOT personal to-dos like "call the plumber", which are create_task), unclear.
English, Bangla, or Bangla in English letters. date YYYY-MM-DD from NEXT DAYS else "". time HH:MM 24h else "". Use "" for unused fields. If WAITING FOR CONFIRMATION and the user changes day/time/title, answer create_task with the full task.
EXAMPLES:
"i want to sing tomorrow" → create_task, title "Sing", date ${plus(1)}
"kal bazar korte hobe" → create_task, title "Bazar", date ${plus(1)}
"finished the report" → complete_task, task_ref "report"
"I didn't call mum yet" → reopen_task, task_ref "call mum"
"move dentist to friday" → reschedule_task, task_ref "dentist", date ${plus(friday)}
"what's due tomorrow?" → list_tasks, filter tomorrow
"my locker code is 4312" → save_note, note "Locker code is 4312"
"where did I park?" → ask_memory, query "park parked location"
"amar passport number koto?" → ask_memory, query "passport number"
"spoke to mom already" → complete_task, task_ref "mom"
"call the electrician monday" → create_task, title "Call the electrician", date ${plus((DateTime.monday - now.weekday) % 7 == 0 ? 7 : (DateTime.monday - now.weekday) % 7)}
"idea: an app for plants" → save_note, note "App idea: plants"
"who won the world cup?" → out_of_scope''');
    for (final e in examples) {
      p.writeln('"${_clean(e.text)}" → ${e.type.wireName} (the user corrected this one)');
    }
    p
      ..writeln()
      ..writeln('MESSAGE: "${_clean(message)}"')
      ..writeln('Reply with the JSON object only.');

    return GenerationRequest(
      systemInstruction:
          'You read messages sent to Pocket Brain, a private memory and task app, '
          'and return what the user wants as JSON. Never answer the message itself.',
      prompt: p.toString(),
      jsonSchema: schema,
      maxOutputTokens: 160,
      temperature: 0,
    );
  }

  static String _clean(String text) {
    final flat = text.replaceAll('"', "'").replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length > _maxMessageChars ? flat.substring(0, _maxMessageChars) : flat;
  }
}
