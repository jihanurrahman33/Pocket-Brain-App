import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/recall.dart';
import '../../../domain/entities/task_item.dart';
import '../bloc/tasks_cubit.dart';
import '../widgets/task_tile.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<TasksCubit>();
    final title = await promptText(
      context,
      title: 'New task',
      hint: 'What needs doing?',
      confirmLabel: 'Next',
    );
    if (title == null || title.trim().isEmpty || !context.mounted) return;
    final due = await pickDate(context, helpText: 'Deadline (optional)');
    if (context.mounted) await context.reportFailure(cubit.add(title, due));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tasks & reminders')),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Add task',
      onPressed: () => _add(context),
      child: const Icon(Icons.add_task_rounded),
    ),
    body: BlocBuilder<TasksCubit, LoadState<TaskBoard>>(
      builder: (context, state) => switch (state) {
        Loading() => const LoadingView(),
        LoadFailed(:final failure) => FailureView(
          failure: failure,
          onRetry: context.read<TasksCubit>().load,
        ),
        Loaded(:final data) when data.isEmpty => const EmptyState(
          icon: Icons.task_alt_rounded,
          title: 'No tasks yet',
          message:
              'When you save something like "finish this book before Dec 15", '
              'Pocket Brain suggests a task for you to confirm.',
        ),
        Loaded(:final data) => _TaskBoardView(board: data),
      },
    ),
  );
}

/// Open tasks and completed ones: side by side on wide windows.
class _TaskBoardView extends StatelessWidget {
  const _TaskBoardView({required this.board});

  final TaskBoard board;

  List<Widget> _section(String title, List<TaskItem> tasks) => [
    if (tasks.isNotEmpty) ...[
      SectionHeader('$title (${tasks.length})'),
      Card(
        child: Column(
          children: [
            for (final t in tasks) TaskTile(task: t, source: board.sourceMemories[t.memoryId]),
          ],
        ),
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) => AdaptiveTwoPane(
    bottomPadding: AppSpacing.fabClearance,
    secondaryWidth: AppSpacing.sidePaneWidth + AppSpacing.xxl * 2,
    primary: [
      ..._section('Overdue', board.overdue),
      ..._section('Upcoming', board.upcoming),
      ..._section('Anytime', board.anytime),
    ],
    secondary: _section('Completed', board.completed),
  );
}
