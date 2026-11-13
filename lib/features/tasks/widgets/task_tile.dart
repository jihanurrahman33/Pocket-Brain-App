import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/memory_views.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/entities/task_item.dart';
import '../bloc/tasks_cubit.dart';

enum _TaskAction { remind, clearReminder, delete }

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, this.source});

  final TaskItem task;

  /// The memory the task was extracted from.
  final Memory? source;

  Future<void> _onAction(BuildContext context, _TaskAction action) async {
    final cubit = context.read<TasksCubit>();
    switch (action) {
      case _TaskAction.remind:
        final at = await pickDate(
          context,
          helpText: 'Remind me on',
          initial: task.dueAt,
          withTime: true,
        );
        if (at != null && context.mounted) {
          await context.reportFailure(cubit.setReminder(task, at));
        }
      case _TaskAction.clearReminder:
        await context.reportFailure(cubit.setReminder(task, null));
      case _TaskAction.delete:
        await context.reportFailure(cubit.delete(task));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overdue = task.isOverdue(DateTime.now());
    final details = [
      if (task.dueAt != null) 'Due ${Formatters.friendlyDate(task.dueAt!)}',
      if (task.reminderAt != null) 'Reminder ${Formatters.shortDateTime(task.reminderAt!)}',
    ].join(' · ');
    return ListTile(
      leading: Checkbox(
        value: task.isDone,
        onChanged: (_) => context.reportFailure(context.read<TasksCubit>().toggle(task)),
      ),
      title: Text(
        task.title,
        style: task.isDone
            ? TextStyle(decoration: TextDecoration.lineThrough, color: scheme.outline)
            : null,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details.isNotEmpty)
            Text(details, style: overdue ? TextStyle(color: scheme.error) : null),
          if (source case final memory?)
            InkWell(
              onTap: () => openMemory(context, memory.id),
              child: Text(
                'From: ${memory.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.primary),
              ),
            ),
        ],
      ),
      trailing: PopupMenuButton<_TaskAction>(
        onSelected: (action) => _onAction(context, action),
        itemBuilder: (_) => [
          const PopupMenuItem(value: _TaskAction.remind, child: Text('Set reminder')),
          if (task.reminderAt != null)
            const PopupMenuItem(value: _TaskAction.clearReminder, child: Text('Clear reminder')),
          const PopupMenuItem(value: _TaskAction.delete, child: Text('Delete')),
        ],
      ),
    );
  }
}
