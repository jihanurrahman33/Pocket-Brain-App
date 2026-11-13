import '../../core/utils/clock.dart';
import '../entities/task_item.dart';
import 'language_detector.dart';

/// A one-sentence summary of a task list, computed from the data so it is
/// always correct (a small model miscounted even two tasks).
abstract final class TaskSummary {
  static String describe(
    List<TaskItem> tasks, {
    required DateTime now,
    ReplyLanguage language = ReplyLanguage.english,
  }) {
    final open = tasks.where((t) => !t.isDone).toList();
    final today = now.startOfDay;
    int dueIn(int days) => open
        .where((t) => t.dueAt != null && t.dueAt!.startOfDay.difference(today).inDays == days)
        .length;
    final overdue = open.where((t) => t.isOverdue(now)).length;
    final dueToday = dueIn(0);
    final dueTomorrow = dueIn(1);
    final done = tasks.length - open.length;

    return language == ReplyLanguage.english
        ? _english(open.length, overdue, dueToday, dueTomorrow, done)
        : _bangla(open.length, overdue, dueToday, dueTomorrow, done);
  }

  static String _english(int open, int overdue, int today, int tomorrow, int done) {
    if (open == 0) {
      return done == 0 ? 'You have no tasks.' : 'All done! You completed ${_n(done, 'task')}.';
    }
    final parts = [
      if (overdue > 0) '$overdue overdue',
      if (today > 0) '$today due today',
      if (tomorrow > 0) '$tomorrow due tomorrow',
    ];
    return 'You have ${_n(open, 'open task')}${parts.isEmpty ? '' : ': ${parts.join(', ')}'}.';
  }

  static String _bangla(int open, int overdue, int today, int tomorrow, int done) {
    if (open == 0) {
      return done == 0 ? 'আপনার কোনো কাজ নেই।' : 'সব কাজ শেষ! আপনি $done টি কাজ শেষ করেছেন।';
    }
    final parts = [
      if (overdue > 0) '$overdue টির সময় পেরিয়ে গেছে',
      if (today > 0) '$today টি আজ',
      if (tomorrow > 0) '$tomorrow টি আগামীকাল',
    ];
    return 'আপনার $open টি কাজ বাকি${parts.isEmpty ? '' : ' — ${parts.join(', ')}'}।';
  }

  static String _n(int count, String noun) => count == 1 ? '1 $noun' : '$count ${noun}s';
}
