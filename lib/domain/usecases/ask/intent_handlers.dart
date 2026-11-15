import '../../../core/utils/clock.dart';
import '../../../core/utils/id_generator.dart';
import '../../entities/assistant.dart';
import '../../entities/task_item.dart';
import '../../entities/user_intent.dart';
import '../../repositories/task_repository.dart';
import '../../services/assistant_toolbox.dart';
import '../../services/intent_router.dart';
import '../../services/language_detector.dart';
import '../../services/reminder_time_parser.dart';
import '../../services/task_resolver.dart';
import '../../services/task_summary.dart';

/// One understood message, ready to be carried out.
typedef IntentRequest = ({
  String question,
  UserIntent intent,
  List<TaskItem> allTasks,
  IntentContext context,
  ReplyLanguage language,
});

/// What Ask Brain says back: text, task cards and proposed changes.
typedef IntentReply = ({String text, List<TaskItem> tasks, List<AssistantAction> actions});

/// Carries out one kind of intent (Strategy). Handlers are deterministic:
/// the model has already turned the message into data.
abstract interface class IntentHandler {
  IntentType get type;

  Future<IntentReply> handle(IntentRequest request);
}

/// Finds the handler for an intent (Registry). [IntentType.askMemory] is
/// not here: it is answered from memories by `AskBrain`.
final class IntentHandlers {
  IntentHandlers(List<IntentHandler> handlers) : _byType = {for (final h in handlers) h.type: h};

  /// The default set, sharing one repository, clock and resolver.
  factory IntentHandlers.standard({
    required TaskRepository tasks,
    required TaskResolver resolver,
    required IdGenerator ids,
    required Clock clock,
  }) => IntentHandlers([
    CreateTaskHandler(tasks, ids, clock),
    CompleteTaskHandler(tasks, resolver),
    ReopenTaskHandler(tasks, resolver),
    RescheduleTaskHandler(resolver, ids, clock),
    DeleteTaskHandler(resolver, ids),
    ListTasksHandler(clock),
    SaveNoteHandler(tasks, ids, clock),
    const SmallTalkHandler(),
    const OutOfScopeHandler(),
    UnclearHandler(tasks, ids, clock),
  ]);

  final Map<IntentType, IntentHandler> _byType;

  IntentHandler? operator [](IntentType type) => _byType[type];
}

const _maxCards = 15;
const _noActions = <AssistantAction>[];
const _noTasks = <TaskItem>[];

bool _bn(IntentRequest r) => r.language != ReplyLanguage.english;

IntentReply _say(String text, {List<TaskItem> tasks = _noTasks}) =>
    (text: text, tasks: tasks, actions: _noActions);

List<TaskItem> _open(IntentRequest r) => r.allTasks.where((t) => !t.isDone).toList();

/// Text to look tasks up by: the reference the model extracted, else the
/// whole message.
String _reference(IntentRequest r) =>
    r.intent.taskRef.trim().isEmpty ? r.question : r.intent.taskRef;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String _dayPhrase(DateTime due, DateTime now) {
  final days = due.difference(DateTime(now.year, now.month, now.day)).inDays;
  return switch (days) {
    0 => 'today',
    1 => 'tomorrow',
    < 7 => _weekdays[due.weekday - 1],
    _ => '${_weekdays[due.weekday - 1]} ${due.day}/${due.month}',
  };
}

/// When nothing matched: say so and show what could be meant.
IntentReply _noMatch(IntentRequest r, List<TaskItem> options, String verb) {
  if (options.isEmpty) {
    return _say(_bn(r) ? 'আপনার কোনো খোলা কাজ নেই।' : 'You have no open tasks.');
  }
  return _say(
    _bn(r)
        ? 'কোন কাজটি বোঝাচ্ছেন বুঝতে পারিনি। আপনার কাজগুলো নিচে দেওয়া হলো।'
        : "I couldn't tell which task you mean. Here are your tasks — $verb the right one.",
    tasks: options.take(_maxCards).toList(),
  );
}

IntentReply _which(IntentRequest r, List<TaskItem> matches) => _say(
  _bn(r) ? 'কোন কাজটি? নিচ থেকে বেছে নিন।' : 'Which one do you mean? Pick it below.',
  tasks: matches.take(_maxCards).toList(),
);

final class CreateTaskHandler implements IntentHandler {
  const CreateTaskHandler(this._tasks, this._ids, this._clock);

  final TaskRepository _tasks;
  final IdGenerator _ids;
  final Clock _clock;

  @override
  IntentType get type => IntentType.createTask;

  @override
  Future<IntentReply> handle(IntentRequest r) async {
    final title = _cleanTitle(r);
    if (title.isEmpty) {
      return _say(_bn(r) ? 'কী কাজ যোগ করব?' : 'What should the task be?');
    }
    final existing = IntentRouter.matchTasks(title, r.allTasks);
    final sameTitle = existing.where((t) => t.title.toLowerCase() == title.toLowerCase());
    // Re-proposing the pending card with new details ("make it 6 pm") is fine.
    final followUp = r.context.pendingProposal?.type == AssistantActionType.createTask;
    if (sameTitle.isNotEmpty && !followUp) {
      return _say(
        _bn(r)
            ? '"${sameTitle.first.title}" আগে থেকেই আপনার কাজের তালিকায় আছে।'
            : '"${sameTitle.first.title}" is already on your list.',
        tasks: sameTitle.toList(),
      );
    }
    final now = _clock.now();
    final toolbox = AssistantToolbox(tasks: _tasks, ids: _ids, clock: _clock, question: r.question);
    final due = r.intent.date;
    await toolbox.run(AssistantToolbox.createTask, {
      'title': title,
      'due_date': due == null ? '' : _iso(due),
      'remind': false,
      'remind_in_minutes': 0,
      'remind_time': r.intent.time,
    });
    if (toolbox.proposals.isEmpty) return _say('What should the task be?');
    final when = due == null ? '' : ' for ${_dayPhrase(due, now)}';
    return (
      text: _bn(r)
          ? '"$title" কাজ হিসেবে যোগ করব? নিচে Confirm চাপুন।'
          : 'Add "$title"$when to your tasks? Confirm below.',
      tasks: _noTasks,
      actions: toolbox.proposals,
    );
  }

  static String _cleanTitle(IntentRequest r) {
    // The model's title, else one made from the message itself.
    final raw = r.intent.title.trim().isNotEmpty
        ? r.intent.title.trim()
        : (IntentRouter.planTitle(r.question) ?? IntentRouter.titleFrom(r.question) ?? '');
    final title = raw.replaceAll(RegExp(r'[\s.!]+$'), '');
    return title.isEmpty ? '' : title[0].toUpperCase() + title.substring(1);
  }
}

final class CompleteTaskHandler implements IntentHandler {
  const CompleteTaskHandler(this._tasks, this._resolver);

  final TaskRepository _tasks;
  final TaskResolver _resolver;

  @override
  IntentType get type => IntentType.completeTask;

  @override
  Future<IntentReply> handle(IntentRequest r) async {
    final open = _open(r);
    final matches = await _resolver.resolve(_reference(r), open, recent: r.context.recentTasks);
    switch (matches) {
      case [final task]:
        final done = task.copyWith(isDone: true);
        // Saving through the repository also cancels its reminder.
        await _tasks.save(done);
        return _say(
          _bn(r)
              ? '"${task.title}" কাজটি সম্পন্ন হয়েছে। ভুল হলে নিচে টিক তুলে দিন।'
              : 'Marked "${task.title}" as done. Untick it below if that was a mistake.',
          tasks: [done],
        );
      case [_, _, ...]:
        return _which(r, matches);
      default:
        final finished = await _resolver.resolve(
          _reference(r),
          r.allTasks.where((t) => t.isDone).toList(),
        );
        if (finished.isNotEmpty) {
          return _say(
            _bn(r)
                ? '"${finished.first.title}" আগেই সম্পন্ন হয়েছে।'
                : '"${finished.first.title}" is already done.',
            tasks: [finished.first],
          );
        }
        return _noMatch(r, open, 'tick');
    }
  }
}

final class ReopenTaskHandler implements IntentHandler {
  const ReopenTaskHandler(this._tasks, this._resolver);

  final TaskRepository _tasks;
  final TaskResolver _resolver;

  @override
  IntentType get type => IntentType.reopenTask;

  @override
  Future<IntentReply> handle(IntentRequest r) async {
    final done = r.allTasks.where((t) => t.isDone).toList();
    final matches = await _resolver.resolve(_reference(r), done, recent: r.context.recentTasks);
    switch (matches) {
      case [final task]:
        final reopened = task.copyWith(isDone: false);
        await _tasks.save(reopened);
        return _say(
          _bn(r) ? '"${task.title}" আবার খোলা হয়েছে।' : 'Reopened "${task.title}".',
          tasks: [reopened],
        );
      case [_, _, ...]:
        return _which(r, matches);
      default:
        return done.isEmpty
            ? _say(_bn(r) ? 'কোনো সম্পন্ন কাজ নেই।' : 'You have no completed tasks.')
            : _say(
                _bn(r)
                    ? 'কোন কাজটি বোঝাচ্ছেন বুঝতে পারিনি।'
                    : "I couldn't tell which task you mean. Here are your completed tasks — "
                          'untick the right one.',
                tasks: done.take(_maxCards).toList(),
              );
    }
  }
}

final class RescheduleTaskHandler implements IntentHandler {
  const RescheduleTaskHandler(this._resolver, this._ids, this._clock);

  final TaskResolver _resolver;
  final IdGenerator _ids;
  final Clock _clock;

  @override
  IntentType get type => IntentType.rescheduleTask;

  @override
  Future<IntentReply> handle(IntentRequest r) async {
    final open = _open(r);
    final matches = await _resolver.resolve(_reference(r), open, recent: r.context.recentTasks);
    if (matches.length > 1) return _which(r, matches);
    if (matches.isEmpty) return _noMatch(r, open, 'open');
    final task = matches.single;
    final now = _clock.now();
    final due = r.intent.date;
    final reminder =
        ReminderTimeParser.parse(r.question, now: now, day: due ?? task.dueAt) ??
        (r.intent.time.isEmpty
            ? null
            : ReminderTimeParser.clockTime('at ${r.intent.time}', now: now, day: due));
    if (due == null && reminder == null) {
      return _say(
        _bn(r) ? 'কবে করতে চান?' : 'When should "${task.title}" be instead?',
        tasks: [task],
      );
    }
    final action = AssistantAction(
      id: _ids.next(),
      type: AssistantActionType.rescheduleTask,
      args: {
        'taskId': task.id,
        'title': task.title,
        if (due != null) 'due': _iso(due),
        if (reminder != null) 'reminder': reminder.toIso8601String(),
      },
    );
    final when = due != null ? ' to ${_dayPhrase(due, now)}' : '';
    return (
      text: _bn(r)
          ? '"${task.title}" এর সময় বদলাব? নিচে Confirm চাপুন।'
          : 'Move "${task.title}"$when? Confirm below.',
      tasks: [task],
      actions: [action],
    );
  }
}

final class DeleteTaskHandler implements IntentHandler {
  const DeleteTaskHandler(this._resolver, this._ids);

  final TaskResolver _resolver;
  final IdGenerator _ids;

  @override
  IntentType get type => IntentType.deleteTask;

  @override
  Future<IntentReply> handle(IntentRequest r) async {
    final matches = await _resolver.resolve(
      _reference(r),
      r.allTasks,
      recent: r.context.recentTasks,
    );
    if (matches.length > 1) return _which(r, matches);
    if (matches.isEmpty) return _noMatch(r, _open(r), 'open');
    final task = matches.single;
    return (
      text: _bn(r)
          ? '"${task.title}" মুছে ফেলব? নিচে Confirm চাপুন।'
          : 'Delete "${task.title}"? Confirm below.',
      tasks: [task],
      actions: [
        AssistantAction(
          id: _ids.next(),
          type: AssistantActionType.deleteTask,
          args: {'taskId': task.id, 'title': task.title},
        ),
      ],
    );
  }
}

final class ListTasksHandler implements IntentHandler {
  const ListTasksHandler(this._clock);

  final Clock _clock;

  @override
  IntentType get type => IntentType.listTasks;

  @override
  Future<IntentReply> handle(IntentRequest r) async {
    final now = _clock.now();
    final today = DateTime(now.year, now.month, now.day);
    bool dueOn(TaskItem t, int days) =>
        t.dueAt != null &&
        DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day).difference(today).inDays == days;
    final open = _open(r);
    final bn = _bn(r);
    switch (r.intent.filter) {
      case 'overdue':
        final tasks = open.where((t) => t.isOverdue(now)).take(_maxCards).toList();
        return _say(
          tasks.isEmpty
              ? (bn ? 'কোনো কাজের সময় পেরিয়ে যায়নি।' : 'Nothing is overdue.')
              : (bn
                    ? '${tasks.length} টি কাজের সময় পেরিয়ে গেছে।'
                    : '${tasks.length} overdue ${tasks.length == 1 ? 'task' : 'tasks'}.'),
          tasks: tasks,
        );
      case 'done':
        final tasks = r.allTasks.where((t) => t.isDone).take(_maxCards).toList();
        return _say(
          tasks.isEmpty
              ? (bn ? 'এখনো কোনো কাজ শেষ হয়নি।' : "You haven't completed any tasks yet.")
              : (bn
                    ? 'আপনি ${tasks.length} টি কাজ শেষ করেছেন।'
                    : 'You completed ${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}.'),
          tasks: tasks,
        );
      case final day && ('today' || 'tomorrow'):
        final offset = day == 'today' ? 0 : 1;
        // Today also includes what is overdue: it still needs doing.
        final tasks = open
            .where((t) => dueOn(t, offset) || (offset == 0 && t.isOverdue(now)))
            .take(_maxCards)
            .toList();
        final word = bn ? (offset == 0 ? 'আজ' : 'আগামীকাল') : day;
        return _say(
          tasks.isEmpty
              ? (bn ? '$word কোনো কাজ নেই।' : 'Nothing is due $word.')
              : (bn
                    ? '$word ${tasks.length} টি কাজ আছে।'
                    : 'You have ${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'} for $word.'),
          tasks: tasks,
        );
      default:
        return _say(
          TaskSummary.describe(r.allTasks, now: now, language: r.language),
          tasks: open.take(_maxCards).toList(),
        );
    }
  }
}

final class SaveNoteHandler implements IntentHandler {
  const SaveNoteHandler(this._tasks, this._ids, this._clock);

  final TaskRepository _tasks;
  final IdGenerator _ids;
  final Clock _clock;

  @override
  IntentType get type => IntentType.saveNote;

  @override
  Future<IntentReply> handle(IntentRequest r) async {
    final text = r.intent.note.trim().isNotEmpty
        ? r.intent.note.trim()
        : r.question.replaceFirst(
            RegExp(
              r'^\s*(please\s+)?(remember|note|save|mone rakho|mone rekho)( that| this)?[:,]?\s*',
              caseSensitive: false,
            ),
            '',
          );
    final toolbox = AssistantToolbox(tasks: _tasks, ids: _ids, clock: _clock);
    await toolbox.run(AssistantToolbox.saveMemory, {'text': text});
    return (
      text: _bn(r)
          ? 'এটি নোট হিসেবে সেভ করব? নিচে Confirm চাপুন।'
          : 'Save this as a note? Confirm below.',
      tasks: _noTasks,
      actions: toolbox.proposals,
    );
  }
}

final class SmallTalkHandler implements IntentHandler {
  const SmallTalkHandler();

  @override
  IntentType get type => IntentType.smallTalk;

  @override
  Future<IntentReply> handle(IntentRequest r) async => _say(
    _bn(r)
        ? 'আমি আপনার মেমরি সহকারী। কিছু মনে রাখতে বলুন, কাজ যোগ করুন, বা সেভ করা কিছু জিজ্ঞেস করুন।'
        : "I'm here! Tell me something to remember, add a task, or ask about anything you saved.",
  );
}

final class OutOfScopeHandler implements IntentHandler {
  const OutOfScopeHandler();

  @override
  IntentType get type => IntentType.outOfScope;

  @override
  Future<IntentReply> handle(IntentRequest r) async => _say(
    _bn(r)
        ? 'আমি শুধু এই ডিভাইসে আপনার সেভ করা তথ্য থেকে উত্তর দিই, তাই এটি বলতে পারছি না।'
        : "I only know what you've saved on this device, so I can't answer that. "
              'I can save notes, manage your tasks, and answer from your memories.',
  );
}

/// Unsure what the user wants: offer the two likely actions instead of a
/// dead end. Both are proposals; nothing happens without a tap.
final class UnclearHandler implements IntentHandler {
  const UnclearHandler(this._tasks, this._ids, this._clock);

  final TaskRepository _tasks;
  final IdGenerator _ids;
  final Clock _clock;

  @override
  IntentType get type => IntentType.unclear;

  @override
  Future<IntentReply> handle(IntentRequest r) async {
    final toolbox = AssistantToolbox(tasks: _tasks, ids: _ids, clock: _clock, question: r.question);
    final title = r.intent.title.isNotEmpty
        ? r.intent.title
        : (IntentRouter.planTitle(r.question) ?? r.question);
    final due = r.intent.date;
    await toolbox.run(AssistantToolbox.createTask, {
      'title': title,
      'due_date': due == null ? '' : _iso(due),
      'remind': false,
      'remind_in_minutes': 0,
      'remind_time': r.intent.time,
    });
    await toolbox.run(AssistantToolbox.saveMemory, {'text': r.question});
    return (
      text: _bn(r)
          ? 'ঠিক বুঝতে পারিনি। এটি কাজ হিসেবে যোগ করব, নাকি নোট হিসেবে সেভ করব?'
          : "I'm not sure what you'd like. Should I add it as a task or save it as a note?",
      tasks: _noTasks,
      actions: toolbox.proposals,
    );
  }
}
