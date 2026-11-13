import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/memory_collection.dart';
import '../../../domain/entities/recall.dart';
import '../../../domain/entities/task_item.dart';

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, required this.memoryCount});

  final int memoryCount;

  static String greetingFor(DateTime now) => switch (now.hour) {
    < 5 => 'Good night',
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(greetingFor(DateTime.now()), style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          memoryCount == 0
              ? 'Save something and forget it safely.'
              : '${Formatters.plural(memoryCount, 'memory', 'memories')}, safely kept on this device.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The large "Ask your brain" entry point.
class AskBrainBar extends StatelessWidget {
  const AskBrainBar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    return Material(
      color: scheme.primaryContainer,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xxs),
          child: Row(
            children: [
              Icon(Icons.psychology_alt_rounded, color: scheme.onPrimaryContainer),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Ask your brain anything…',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: scheme.onPrimaryContainer),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: scheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class WeeklyDigestCard extends StatelessWidget {
  const WeeklyDigestCard({super.key, required this.overview});

  final HomeOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topics = overview.weekTopics.map((t) => t.topic);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.md),
          leading: const Icon(Icons.auto_stories_rounded),
          title: const Text('Your brain digest'),
          subtitle: Text(
            'You saved ${Formatters.plural(overview.savedThisWeek, 'memory', 'memories')} this week'
            '${topics.isEmpty ? '.' : ' about ${topics.join(', ')}.'}',
            style: theme.textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push(AppRoutes.digest),
        ),
      ),
    );
  }
}

class OpenTasksSection extends StatelessWidget {
  const OpenTasksSection({super.key, required this.tasks});

  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SectionHeader(
        'To do',
        actionLabel: 'All tasks',
        onAction: () => context.push(AppRoutes.tasks),
      ),
      Card(
        child: Column(
          children: [
            for (final t in tasks)
              ListTile(
                dense: true,
                leading: const Icon(Icons.radio_button_unchecked_rounded),
                title: Text(t.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: t.dueAt == null ? null : Text('Due ${Formatters.day(t.dueAt!)}'),
                onTap: () => context.push(AppRoutes.tasks),
              ),
          ],
        ),
      ),
    ],
  );
}

class CollectionsSection extends StatelessWidget {
  const CollectionsSection({super.key, required this.collections});

  final List<MemoryCollection> collections;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(
        'Collections',
        actionLabel: 'See all',
        onAction: () => context.go(AppRoutes.brain),
      ),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final c in collections)
            ActionChip(
              avatar: Text(c.emoji),
              label: Text('${c.name} · ${c.memoryCount}'),
              onPressed: () => context.push(AppRoutes.collection(c.id)),
            ),
        ],
      ),
    ],
  );
}
