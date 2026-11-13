import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/task_item.dart';
import '../bloc/ask_bloc.dart';

/// Tasks an answer is about, drawn by the app from real data (not written by
/// the model), so they are always accurate and can be ticked off in place.
class TaskResultCards extends StatelessWidget {
  const TaskResultCards({super.key, required this.tasks});

  final List<TaskItem> tasks;

  static const _maxWidth = 520.0;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: _maxWidth),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, task) in tasks.indexed) ...[
            if (i > 0) const Divider(height: 1),
            _TaskRow(task: task),
          ],
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.tasks),
            icon: const Icon(Icons.checklist_rounded, size: AppSpacing.lg + AppSpacing.xxs),
            label: const Text('Open Tasks & reminders'),
          ),
        ],
      ),
    ),
  );
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = task.isOverdue(DateTime.now());
    final details = [
      if (task.dueAt != null)
        overdue
            ? 'Overdue · was due ${Formatters.day(task.dueAt!)}'
            : 'Due ${Formatters.day(task.dueAt!)}',
      if (task.reminderAt != null) 'Reminder ${Formatters.reminder(task.reminderAt!)}',
    ];
    return CheckboxListTile(
      value: task.isDone,
      onChanged: (_) => context.read<AskBloc>().add(AskTaskToggled(task)),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        task.title,
        style: task.isDone
            ? TextStyle(decoration: TextDecoration.lineThrough, color: scheme.outline)
            : null,
      ),
      subtitle: details.isEmpty
          ? null
          : Text(details.join(' · '), style: overdue ? TextStyle(color: scheme.error) : null),
      secondary: overdue ? Icon(Icons.warning_amber_rounded, color: scheme.error) : null,
    );
  }
}
