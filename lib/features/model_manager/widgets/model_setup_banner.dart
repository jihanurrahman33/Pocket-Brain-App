import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../bloc/model_bloc.dart';

/// Invites the user to download Gemma; hidden once it is installed.
class ModelSetupBanner extends StatelessWidget {
  const ModelSetupBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModelBloc, ModelState>(
      buildWhen: (a, b) => a.languageModel != b.languageModel,
      builder: (context, state) {
        final slot = state.languageModel;
        if (slot == null || slot.isInstalled) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final percent = ((slot.progress ?? 0) * 100).round();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md + AppSpacing.xxs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.memory_rounded, color: scheme.onSecondaryContainer),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slot.isDownloading
                                  ? 'Downloading ${slot.info.name}… $percent%'
                                  : 'Enable on-device AI',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (slot.isDownloading)
                              LinearProgressIndicator(value: slot.progress)
                            else
                              Text(
                                'Download ${slot.info.name} '
                                '(${Formatters.bytes(slot.info.sizeBytes)}) for summaries '
                                'and Ask Brain. Your memories never leave this device.',
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!slot.isDownloading) ...[
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.tonal(
                      onPressed: () => context.push(AppRoutes.settings),
                      child: const Text('Set up'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
