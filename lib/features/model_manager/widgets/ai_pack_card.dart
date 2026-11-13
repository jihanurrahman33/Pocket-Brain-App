import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/ai_model.dart';
import '../bloc/model_bloc.dart';

/// User-facing name of the on-device AI. Which models it contains is an
/// implementation detail that never appears in the UI.
const kAiPackName = 'Pocket Brain AI';

/// Setup, progress and removal of Pocket Brain AI as one unit.
class AiPackCard extends StatelessWidget {
  const AiPackCard({super.key});

  static const _capabilities = [
    (Icons.auto_awesome_outlined, 'Titles, summaries, tags and tasks for what you save'),
    (Icons.psychology_alt_outlined, 'Ask Brain answers from your memories'),
    (Icons.manage_search_rounded, 'Smart search by meaning and related memories'),
  ];

  @override
  Widget build(BuildContext context) => BlocBuilder<ModelBloc, ModelState>(
    builder: (context, state) {
      final theme = Theme.of(context);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.psychology_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kAiPackName, style: theme.textTheme.titleMedium),
                        const Gap.xs(),
                        Text(
                          'Private intelligence that runs entirely on this device.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const Gap.sm(),
                        _StatusChip(state: state),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap.md(),
              for (final (icon, text) in _capabilities)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: AppSpacing.lg + AppSpacing.xxs),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              if (state.progress case final progress?)
                _Progress(state: state, progress: progress)
              else if (state.pack case final pack? when pack.isPartiallyInstalled)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: LinearProgressIndicator(value: pack.downloadedFraction),
                ),
              if (state.failure case final failure?) ...[
                const Gap.sm(),
                Text(failure.message, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const Gap.md(),
              Align(
                alignment: Alignment.centerRight,
                child: _PackAction(state: state),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state, required this.progress});

  final ModelState state;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Progress covers the whole pack, including bytes from earlier sessions.
    final download = state.pack?.totalBytes ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: progress == 0 ? null : progress),
          const Gap.xs(),
          Text(
            'Setting up $kAiPackName… ${(progress * 100).round()}%'
            '${download == 0 ? '' : ' · ${Formatters.bytes((download * progress).round())} '
                      'of ${Formatters.bytes(download)}'}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _PackAction extends StatelessWidget {
  const _PackAction({required this.state});

  final ModelState state;

  Future<void> _confirmRemove(BuildContext context) async {
    final bloc = context.read<ModelBloc>();
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove $kAiPackName?',
      message:
          'Frees ${Formatters.bytes(state.pack?.totalBytes ?? 0)}. Your memories are kept, '
          'and you can set it up again any time.',
      confirmLabel: 'Remove',
    );
    if (confirmed) bloc.add(const ModelUninstallRequested());
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ModelBloc>();
    final pack = state.pack;
    if (pack == null) return const SizedBox.shrink();
    if (state.isDownloading) {
      return TextButton(
        onPressed: () => bloc.add(const ModelInstallCancelled()),
        child: const Text('Cancel'),
      );
    }
    if (pack.isInstalled) {
      return TextButton.icon(
        onPressed: () => _confirmRemove(context),
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Remove'),
      );
    }
    final size = Formatters.bytes(pack.remainingBytes);
    return FilledButton.icon(
      onPressed: () => bloc.add(const ModelInstallRequested()),
      icon: const Icon(Icons.download_rounded),
      label: Text(
        pack.isPartiallyInstalled || state.failure != null
            ? 'Resume setup ($size left)'
            : 'Set up ($size)',
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final ModelState state;

  static const _iconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final pack = state.pack;
    final (label, icon) = switch (pack) {
      _ when state.isDownloading => ('Setting up', Icons.downloading_rounded),
      null => ('Checking…', Icons.hourglass_empty_rounded),
      AiPackStatus(isInstalled: true, isLoaded: true) => ('Active', Icons.bolt_rounded),
      AiPackStatus(isInstalled: true) => ('Ready', Icons.check_circle_outline_rounded),
      AiPackStatus(isPartiallyInstalled: true) => (
        'Paused at ${(pack.downloadedFraction * 100).floor()}%',
        Icons.pause_circle_outline,
      ),
      _ => ('Not set up', Icons.cloud_download_outlined),
    };
    return Chip(
      avatar: Icon(icon, size: _iconSize),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
