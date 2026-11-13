import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../domain/entities/ai_model.dart';
import '../bloc/model_bloc.dart';

/// Download / cancel / delete controls for one model.
class ModelCard extends StatelessWidget {
  const ModelCard({super.key, required this.slot});

  final ModelSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = slot.info;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  info.kind == AiModelKind.languageModel
                      ? Icons.memory_rounded
                      : Icons.hub_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.name, style: theme.textTheme.titleSmall),
                      Text(
                        '${Formatters.bytes(info.sizeBytes)} · ${info.purpose}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _StatusChip(slot: slot),
                    ],
                  ),
                ),
              ],
            ),
            if (slot.progress case final progress?) ...[
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(value: progress == 0 ? null : progress),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${(progress * 100).round()}% of ${Formatters.bytes(info.sizeBytes)}',
                style: theme.textTheme.labelSmall,
              ),
            ],
            if (slot.failure case final failure?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(failure.message, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: _ModelAction(slot: slot),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelAction extends StatelessWidget {
  const _ModelAction({required this.slot});

  final ModelSlot slot;

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<ModelBloc>();
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete ${slot.info.name}?',
      message: 'Frees ${Formatters.bytes(slot.info.sizeBytes)}. You can download it again later.',
    );
    if (confirmed) bloc.add(ModelUninstallRequested(slot.info.kind));
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ModelBloc>();
    final kind = slot.info.kind;
    if (slot.isDownloading) {
      return TextButton(
        onPressed: () => bloc.add(ModelInstallCancelled(kind)),
        child: const Text('Cancel'),
      );
    }
    if (slot.isInstalled) {
      return TextButton.icon(
        onPressed: () => _confirmDelete(context),
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Delete model'),
      );
    }
    return FilledButton.icon(
      onPressed: () => bloc.add(ModelInstallRequested(kind)),
      icon: const Icon(Icons.download_rounded),
      label: Text(slot.failure == null ? 'Download' : 'Retry download'),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.slot});

  final ModelSlot slot;

  static const _iconSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (slot) {
      ModelSlot(isDownloading: true) => ('Downloading', Icons.downloading_rounded),
      ModelSlot(failure: _?) => ('Error', Icons.error_outline_rounded),
      ModelSlot(status: AiModelStatus(installed: true, loaded: true)) => (
        'Loaded',
        Icons.bolt_rounded,
      ),
      ModelSlot(isInstalled: true) => ('Ready', Icons.check_circle_outline_rounded),
      _ => ('Not downloaded', Icons.cloud_download_outlined),
    };
    return Chip(
      avatar: Icon(icon, size: _iconSize),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
