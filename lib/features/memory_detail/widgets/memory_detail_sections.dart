import 'package:flutter/material.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/entities/recall.dart';
import '../../../domain/entities/task_item.dart';
import '../../shared/widgets/memory_source_icon.dart';
import '../../shared/widgets/memory_views.dart';

class MemoryHeader extends StatelessWidget {
  const MemoryHeader({super.key, required this.memory});

  final Memory memory;

  /// Edits within this window count as part of creation.
  static const _editGrace = Duration(minutes: 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final edited = memory.updatedAt.difference(memory.createdAt) > _editGrace;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(memory.title, style: theme.textTheme.headlineSmall),
        const Gap.sm(),
        Wrap(
          spacing: AppSpacing.xs + AppSpacing.xxs,
          runSpacing: AppSpacing.xs + AppSpacing.xxs,
          children: [
            Chip(
              avatar: Icon(memory.source.icon, size: AppSpacing.lg),
              label: Text(memory.source.label),
              visualDensity: VisualDensity.compact,
            ),
            Chip(label: Text(memory.category), visualDensity: VisualDensity.compact),
            for (final tag in memory.tags)
              Chip(label: Text('#$tag'), visualDensity: VisualDensity.compact),
            if (memory.isArchived)
              const Chip(label: Text('Archived'), visualDensity: VisualDensity.compact),
          ],
        ),
        const Gap.xs(),
        Text(
          'Saved ${Formatters.fullDateTime(memory.createdAt)}'
          '${edited ? ' · edited ${Formatters.friendlyDate(memory.updatedAt)}' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}

/// AI-written content, visually distinct from the user's own words.
class AiSummaryBox extends StatelessWidget {
  const AiSummaryBox({super.key, required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md + AppSpacing.xxs),
        decoration: BoxDecoration(
          color: scheme.aiContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AiBadge(label: memory.aiGenerated ? 'AI summary' : 'Summary · reviewed by you'),
            const Gap.sm(),
            SelectableText(memory.summary),
          ],
        ),
      ),
    );
  }
}

class OriginalContent extends StatelessWidget {
  const OriginalContent({super.key, required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Original'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (memory.sourceUrl case final url?) ...[
                  Row(
                    children: [
                      const Icon(Icons.link_rounded, size: AppSpacing.lg),
                      const SizedBox(width: AppSpacing.xs + AppSpacing.xxs),
                      Expanded(
                        child: SelectableText(
                          url,
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.xl),
                ],
                SelectableText(memory.content, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CollectionPicker extends StatelessWidget {
  const CollectionPicker({super.key, required this.details, required this.onChanged});

  final MemoryDetails details;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader('Collection'),
      DropdownButtonFormField<String?>(
        initialValue: details.memory.collectionId,
        isExpanded: true,
        items: [
          const DropdownMenuItem(child: Text('Not in a collection')),
          for (final c in details.collections)
            DropdownMenuItem(
              value: c.id,
              child: Text(c.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    ],
  );
}

class LinkedTasks extends StatelessWidget {
  const LinkedTasks({super.key, required this.tasks, required this.onToggle, required this.onAdd});

  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onToggle;
  final void Function(String title, DateTime? dueAt) onAdd;

  Future<void> _add(BuildContext context) async {
    final title = await promptText(
      context,
      title: 'New task',
      hint: 'What needs doing?',
      confirmLabel: 'Next',
    );
    if (title == null || title.trim().isEmpty || !context.mounted) return;
    final due = await pickDate(context, helpText: 'Deadline (optional)');
    onAdd(title, due);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader('Tasks & dates', actionLabel: 'Add task', onAction: () => _add(context)),
      if (tasks.isEmpty)
        Text('No tasks linked to this memory.', style: Theme.of(context).textTheme.bodySmall)
      else
        Card(
          child: Column(
            children: [
              for (final task in tasks)
                CheckboxListTile(
                  value: task.isDone,
                  onChanged: (_) => onToggle(task),
                  title: Text(task.title),
                  subtitle: task.dueAt == null ? null : Text('Due ${Formatters.day(task.dueAt!)}'),
                ),
            ],
          ),
        ),
    ],
  );
}

class RelatedMemories extends StatelessWidget {
  const RelatedMemories({super.key, required this.memories});

  final List<Memory> memories;

  @override
  Widget build(BuildContext context) => memories.isEmpty
      ? const SizedBox.shrink()
      : Column(
          children: [
            const SectionHeader('Related memories'),
            MemoryTileList(memories: memories),
          ],
        );
}
