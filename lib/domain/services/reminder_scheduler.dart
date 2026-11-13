import '../entities/task_item.dart';
import '../repositories/change_notifier.dart';

/// Delivers task reminders as local notifications.
///
/// Implementations differ per platform (OS-scheduled on Android, in-app
/// timers on Linux desktop); callers only describe what should fire.
abstract interface class ReminderScheduler implements Clearable {
  /// Schedules (or reschedules) [task]'s reminder, or cancels it when the
  /// task is done or has no future reminder.
  Future<void> sync(TaskItem task);

  Future<void> cancel(String taskId);

  /// Replaces every scheduled reminder with those of [tasks]; used at start.
  Future<void> syncAll(List<TaskItem> tasks);

  /// Ids of tasks whose notification the user tapped.
  Stream<String> get openedTaskIds;
}
