import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/formatting/formatters.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/section_header.dart';
import '../../shared/widgets/memory_views.dart';
import '../bloc/digest_cubit.dart';

class DigestPage extends StatelessWidget {
  const DigestPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Brain digest')),
    body: BlocBuilder<DigestCubit, LoadState<DigestView>>(
      builder: (context, state) => switch (state) {
        Loading() => const LoadingView(),
        LoadFailed(:final failure) => FailureView(
          failure: failure,
          onRetry: context.read<DigestCubit>().load,
        ),
        Loaded(:final data) => _DigestContent(view: data),
      },
    ),
  );
}

class _DigestContent extends StatelessWidget {
  const _DigestContent({required this.view});

  final DigestView view;

  @override
  Widget build(BuildContext context) {
    final digest = view.digest;
    return AdaptiveTwoPane(
      primary: [
        _RecapCard(view: view),
        if (digest.topics.isNotEmpty) ...[
          const SectionHeader('Important topics this week'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final t in digest.topics) Chip(label: Text('#${t.topic} · ${t.count}')),
            ],
          ),
        ],
        SectionHeader('Saved today (${digest.today.length})'),
        if (digest.today.isEmpty)
          Text('Nothing yet today.', style: Theme.of(context).textTheme.bodySmall)
        else
          MemoryTileList(memories: digest.today),
      ],
      secondary: [
        if (digest.openTasks.isNotEmpty) ...[
          SectionHeader(
            'Unfinished action items',
            actionLabel: 'Open tasks',
            onAction: () => context.push(AppRoutes.tasks),
          ),
          Card(
            child: Column(
              children: [
                for (final t in digest.openTasks.take(5))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.radio_button_unchecked_rounded),
                    title: Text(t.title),
                    subtitle: t.dueAt == null ? null : Text('Due ${Formatters.day(t.dueAt!)}'),
                  ),
              ],
            ),
          ),
        ],
        if (digest.onThisDay.isNotEmpty) ...[
          const SectionHeader('On this day'),
          MemoryTileList(memories: digest.onThisDay),
        ],
        if (digest.revisit.isNotEmpty) ...[
          const SectionHeader('Worth revisiting'),
          MemoryTileList(memories: digest.revisit),
        ],
      ],
    );
  }
}

class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.view});

  final DigestView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final week = view.digest.week;
    return Card(
      color: theme.colorScheme.aiContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Weekly recap', style: theme.textTheme.titleMedium)),
                if (view.recap != null) const AiBadge(),
              ],
            ),
            const Gap.sm(),
            if (view.isWritingRecap)
              const LinearProgressIndicator()
            else
              Text(
                view.recap ??
                    'You saved ${Formatters.plural(week.length, 'memory', 'memories')} in the last 7 days.',
              ),
            const Gap.sm(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: week.isEmpty || view.isWritingRecap
                    ? null
                    : context.read<DigestCubit>().writeRecap,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(view.recap == null ? 'Connect the ideas' : 'Regenerate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
