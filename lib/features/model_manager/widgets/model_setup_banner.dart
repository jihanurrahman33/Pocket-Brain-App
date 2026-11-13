import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/section_header.dart';
import '../bloc/model_bloc.dart';
import 'ai_pack_card.dart';

/// Invites the user to set up Pocket Brain AI; hidden once it is ready.
class ModelSetupBanner extends StatelessWidget {
  const ModelSetupBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModelBloc, ModelState>(
      builder: (context, state) {
        final pack = state.pack;
        if (pack == null || pack.isInstalled) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final progress = state.progress;
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
                      Icon(Icons.psychology_rounded, color: scheme.onSecondaryContainer),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              progress == null
                                  ? 'Turn on $kAiPackName'
                                  : 'Setting up $kAiPackName… ${(progress * 100).round()}%',
                              style: theme.textTheme.titleSmall,
                            ),
                            const Gap.xs(),
                            if (progress != null)
                              LinearProgressIndicator(value: progress == 0 ? null : progress)
                            else
                              Text(
                                'A one-time ${Formatters.bytes(pack.remainingBytes)} download '
                                'for summaries, smart search and Ask Brain. Runs privately '
                                'on this device.',
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (progress == null) ...[
                    const Gap.sm(),
                    FilledButton.tonal(
                      onPressed: () => context.push(AppRoutes.settings),
                      child: Text(pack.isPartiallyInstalled ? 'Finish setup' : 'Set up'),
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
