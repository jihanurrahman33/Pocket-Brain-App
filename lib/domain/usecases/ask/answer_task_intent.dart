import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/id_generator.dart';
import '../../entities/assistant.dart';
import '../../entities/task_item.dart';
import '../../repositories/task_repository.dart';
import '../../services/assistant_toolbox.dart';
import '../../services/due_date_parser.dart';
import '../../services/intent_router.dart';
import '../../services/language_detector.dart';
import '../../services/task_summary.dart';

/// A task command or question, already classified by [IntentRouter].
typedef TaskIntentRequest = ({
  String question,
  AskIntent intent,
  List<TaskItem> allTasks,
  ReplyLanguage language,
});

/// The reply to a task intent, the tasks to show as cards under it and any
/// change proposed for the user to confirm.
typedef TaskIntentReply = ({String text, List<TaskItem> tasks, List<AssistantAction> actions});

/// Answers task commands and questions from real task data, without the
/// model: completing "drink water" marks exactly that task done (the card
/// under the reply can untick it again), and task questions get a computed
/// summary. Instant and always correct, on any device.
final class AnswerTaskIntent implements UseCase<TaskIntentReply, TaskIntentRequest> {
  const AnswerTaskIntent(this._tasks, this._ids, this._clock);

  final TaskRepository _tasks;
  final IdGenerator _ids;
  final Clock _clock;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const maxCards = 15;

  @override
  Future<TaskIntentReply> call(TaskIntentRequest request) async {
    if (request.intent case PlanTaskIntent(:final title)) return _plan(request, title);
    final (:text, :tasks) = await _answer(request);
    return (text: text, tasks: tasks, actions: const <AssistantAction>[]);
  }

  /// Offers the plan as a task; nothing is created until the user confirms.
  Future<TaskIntentReply> _plan(TaskIntentRequest request, String title) async {
    final bangla = request.language != ReplyLanguage.english;
    final existing = IntentRouter.matchTasks(title, request.allTasks);
    if (existing.isNotEmpty) {
      return (
        text: bangla
            ? '"${existing.first.title}" আগে থেকেই আপনার কাজের তালিকায় আছে।'
            : '"${existing.first.title}" is already on your list.',
        tasks: existing.take(maxCards).toList(),
        actions: const <AssistantAction>[],
      );
    }
    final now = _clock.now();
    final due = DueDateParser.parse(request.question, now: now);
    final toolbox = AssistantToolbox(
      tasks: _tasks,
      ids: _ids,
      clock: _clock,
      question: request.question,
    );
    await toolbox.run(AssistantToolbox.createTask, {
      'title': title,
      'due_date': due == null ? '' : _iso(due),
      'remind': false,
      'remind_in_minutes': 0,
      'remind_time': '',
    });
    final when = due == null ? '' : ' ${_dayPhrase(due, now)}';
    return (
      text: bangla
          ? '"$title" কাজ হিসেবে যোগ করব? নিচে Confirm চাপুন।'
          : 'Add "$title"$when to your tasks? Confirm below.',
      tasks: const <TaskItem>[],
      actions: toolbox.proposals,
    );
  }

  static String _dayPhrase(DateTime due, DateTime now) {
    final days = due.difference(DateTime(now.year, now.month, now.day)).inDays;
    return switch (days) {
      0 => 'for today',
      1 => 'for tomorrow',
      < 7 => 'for ${_weekdays[due.weekday - 1]}',
      _ => 'for ${_weekdays[due.weekday - 1]} ${due.day}/${due.month}',
    };
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<({String text, List<TaskItem> tasks})> _answer(TaskIntentRequest request) async {
    final bangla = request.language != ReplyLanguage.english;
    final now = _clock.now();
    final open = request.allTasks.where((t) => !t.isDone).take(maxCards).toList();
    switch (request.intent) {
      case CompleteTaskIntent(matches: [final task]):
        final done = task.copyWith(isDone: true);
        // Saving through the repository also cancels its reminder.
        await _tasks.save(done);
        return (
          text: bangla
              ? '"${task.title}" কাজটি সম্পন্ন হয়েছে। ভুল হলে নিচে টিক তুলে দিন।'
              : 'Marked "${task.title}" as done. Untick it below if that was a mistake.',
          tasks: [done],
        );
      case CompleteTaskIntent(:final matches) when matches.length > 1:
        return (
          text: bangla
              ? 'কোন কাজটি শেষ করেছেন? নিচে টিক দিন।'
              : 'Which one did you finish? Tick it below.',
          tasks: matches.take(maxCards).toList(),
        );
      case CompleteTaskIntent(alreadyDone: [final task, ...]):
        return (
          text: bangla
              ? '"${task.title}" আগেই সম্পন্ন হয়েছে।'
              : '"${task.title}" is already done.',
          tasks: [task],
        );
      case CompleteTaskIntent():
        if (open.isEmpty) {
          return (
            text: bangla ? 'আপনার কোনো খোলা কাজ নেই।' : 'You have no open tasks.',
            tasks: const <TaskItem>[],
          );
        }
        return (
          text: bangla
              ? 'এই নামে কোনো খোলা কাজ পাইনি। আপনার কাজগুলো নিচে — যেটা শেষ করেছেন টিক দিন।'
              : "I couldn't find an open task matching that. Here are your open tasks; "
                    'tick the one you finished.',
          tasks: open,
        );
      case QueryTasksIntent(:final filter):
        final selected = switch (filter) {
          'overdue' => request.allTasks.where((t) => t.isOverdue(now)),
          'done' => request.allTasks.where((t) => t.isDone),
          _ => open,
        }.take(maxCards).toList();
        return (
          text: _summary(filter, selected, request.allTasks, now, request.language),
          tasks: selected,
        );
      case PlanTaskIntent() || MemoryQuestionIntent():
        throw ArgumentError('Memory questions are answered from memories, not tasks.');
    }
  }

  static String _summary(
    String filter,
    List<TaskItem> tasks,
    List<TaskItem> all,
    DateTime now,
    ReplyLanguage lang,
  ) {
    final bangla = lang != ReplyLanguage.english;
    return switch (filter) {
      'overdue' when tasks.isEmpty =>
        bangla ? 'কোনো কাজের সময় পেরিয়ে যায়নি।' : 'Nothing is overdue.',
      'overdue' =>
        bangla
            ? '${tasks.length} টি কাজের সময় পেরিয়ে গেছে।'
            : '${tasks.length} overdue ${tasks.length == 1 ? 'task' : 'tasks'}.',
      'done' when tasks.isEmpty =>
        bangla ? 'এখনো কোনো কাজ শেষ হয়নি।' : "You haven't completed any tasks yet.",
      'done' =>
        bangla
            ? 'আপনি ${tasks.length} টি কাজ শেষ করেছেন।'
            : 'You completed ${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}.',
      _ => TaskSummary.describe(all, now: now, language: lang),
    };
  }
}
