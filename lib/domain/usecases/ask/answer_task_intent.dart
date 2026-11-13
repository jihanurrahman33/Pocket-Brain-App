import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../entities/task_item.dart';
import '../../repositories/task_repository.dart';
import '../../services/intent_router.dart';
import '../../services/language_detector.dart';
import '../../services/task_summary.dart';

/// A task command or question, already classified by [IntentRouter].
typedef TaskIntentRequest = ({AskIntent intent, List<TaskItem> allTasks, ReplyLanguage language});

/// The reply to a task intent and the tasks to show as cards under it.
typedef TaskIntentReply = ({String text, List<TaskItem> tasks});

/// Answers task commands and questions from real task data, without the
/// model: completing "drink water" marks exactly that task done (the card
/// under the reply can untick it again), and task questions get a computed
/// summary. Instant and always correct, on any device.
final class AnswerTaskIntent implements UseCase<TaskIntentReply, TaskIntentRequest> {
  const AnswerTaskIntent(this._tasks, this._clock);

  final TaskRepository _tasks;
  final Clock _clock;

  static const maxCards = 15;

  @override
  Future<TaskIntentReply> call(TaskIntentRequest request) async {
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
      case MemoryQuestionIntent():
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
