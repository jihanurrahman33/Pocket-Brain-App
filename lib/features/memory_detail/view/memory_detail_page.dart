import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/entities/recall.dart';
import '../bloc/memory_detail_cubit.dart';
import '../widgets/edit_memory_form.dart';
import '../widgets/memory_detail_sections.dart';

class MemoryDetailPage extends StatelessWidget {
  const MemoryDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MemoryDetailCubit, LoadState<MemoryDetails>>(
      builder: (context, state) => switch (state) {
        Loading() => const Scaffold(body: LoadingView()),
        LoadFailed(:final failure) => Scaffold(
          appBar: AppBar(),
          body: FailureView(failure: failure),
        ),
        Loaded(:final data) => _MemoryDetailScaffold(details: data),
      },
    );
  }
}

class _MemoryDetailScaffold extends StatelessWidget {
  const _MemoryDetailScaffold({required this.details});

  final MemoryDetails details;

  Memory get memory => details.memory;

  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<MemoryDetailCubit>();
    final edit = await showEditMemoryDialog(context, memory);
    if (edit != null && context.mounted) await context.reportFailure(cubit.edit(edit));
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<MemoryDetailCubit>();
    final router = GoRouter.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this memory?',
      message: 'It will be removed from this device. Linked tasks are kept.',
    );
    if (!confirmed) return;
    final failure = await cubit.delete();
    if (!context.mounted) return;
    if (failure != null) return context.showFailure(failure);
    if (router.canPop()) router.pop();
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: '${memory.title}\n\n${memory.content}'));
    if (context.mounted) context.showMessage('Copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MemoryDetailCubit>();
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: memory.isFavorite ? 'Remove from favorites' : 'Add to favorites',
            icon: Icon(memory.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded),
            onPressed: () => context.reportFailure(cubit.toggleFavorite()),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context),
          ),
          PopupMenuButton<_MenuAction>(
            onSelected: (action) => switch (action) {
              _MenuAction.copy => _copy(context),
              _MenuAction.archive => context.reportFailure(cubit.toggleArchived()),
              _MenuAction.delete => _delete(context),
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: _MenuAction.copy, child: Text('Copy / share text')),
              PopupMenuItem(
                value: _MenuAction.archive,
                child: Text(memory.isArchived ? 'Unarchive' : 'Archive'),
              ),
              const PopupMenuItem(value: _MenuAction.delete, child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: AdaptiveTwoPane(
        primary: [
          MemoryHeader(memory: memory),
          if (memory.summary.isNotEmpty) AiSummaryBox(memory: memory),
          OriginalContent(memory: memory),
        ],
        secondary: [
          CollectionPicker(
            details: details,
            onChanged: (id) => context.reportFailure(cubit.moveToCollection(id)),
          ),
          LinkedTasks(
            tasks: details.tasks,
            onToggle: (task) => context.reportFailure(cubit.toggleTask(task)),
            onAdd: (title, due) => context.reportFailure(cubit.addTask(title, due)),
          ),
          RelatedMemories(memories: details.related),
        ],
      ),
    );
  }
}

enum _MenuAction { copy, archive, delete }
