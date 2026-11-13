import 'package:equatable/equatable.dart';

import '../../core/utils/clock.dart';

/// An actionable item, usually extracted from a memory and confirmed by the
/// user.
class TaskItem extends Equatable {
  const TaskItem({
    required this.id,
    required this.title,
    required this.createdAt,
    this.dueAt,
    this.reminderAt,
    this.isDone = false,
    this.memoryId,
  });

  final String id;
  final String title;
  final DateTime? dueAt;
  final DateTime? reminderAt;
  final bool isDone;

  /// The memory this task was extracted from, if any.
  final String? memoryId;
  final DateTime createdAt;

  /// Open and due before today.
  bool isOverdue(DateTime now) => !isDone && dueAt != null && dueAt!.isBefore(now.startOfDay);

  TaskItem copyWith({bool? isDone, DateTime? Function()? reminderAt}) => TaskItem(
    id: id,
    title: title,
    dueAt: dueAt,
    reminderAt: reminderAt != null ? reminderAt() : this.reminderAt,
    isDone: isDone ?? this.isDone,
    memoryId: memoryId,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, title, dueAt, reminderAt, isDone, memoryId, createdAt];
}
