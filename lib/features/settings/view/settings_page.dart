import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/ai_model.dart';
import '../../model_manager/bloc/model_bloc.dart';
import '../../model_manager/widgets/ai_pack_card.dart';
import '../bloc/settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: const AdaptiveTwoPane(
      secondaryWidth: AppSpacing.sidePaneWidth + AppSpacing.xxl * 2,
      primary: [_ModelSettings()],
      secondary: [_PrivacySettings(), _AboutSection()],
    ),
  );
}

class _ModelSettings extends StatelessWidget {
  const _ModelSettings();

  @override
  Widget build(BuildContext context) => BlocBuilder<ModelBloc, ModelState>(
    builder: (context, state) {
      final bloc = context.read<ModelBloc>();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('On-device AI'),
          const AiPackCard(),
          const SectionHeader('Advanced'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  title: Text('Processing'),
                  subtitle: Text(
                    'CPU works on every device. GPU is faster where your device supports it.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<ComputeBackend>(
                      segments: [
                        for (final b in ComputeBackend.values)
                          ButtonSegment(value: b, label: Text(b.label)),
                      ],
                      selected: {state.backend},
                      onSelectionChanged: (s) => bloc.add(ModelBackendChanged(s.first)),
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('AI storage used'),
                  subtitle: Text(Formatters.bytes(state.storageBytes)),
                  trailing: TextButton(
                    onPressed: () => bloc.add(const ModelUnloadRequested()),
                    child: const Text('Free memory'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _PrivacySettings extends StatelessWidget {
  const _PrivacySettings();

  Future<void> _export(BuildContext context) async {
    final result = await context.read<SettingsCubit>().export();
    if (!context.mounted) return;
    result.fold(
      onSuccess: (path) => context.showMessage('Exported to $path'),
      onFailure: context.showFailure,
    );
  }

  Future<void> _wipe(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete all data?',
      message:
          'Every memory, collection, task and conversation on this device will be '
          'permanently deleted. Downloaded AI models are kept. Consider exporting first.',
      confirmLabel: 'Delete everything',
    );
    if (!confirmed) return;
    final result = await cubit.wipe();
    if (!context.mounted) return;
    result.fold(
      onSuccess: (_) => context.showMessage('All data deleted'),
      onFailure: context.showFailure,
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader('Privacy & data'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('AI suggestions on capture'),
                  subtitle: const Text(
                    'Titles, summaries, tags and tasks. You always review first.',
                  ),
                  value: state.aiSuggestionsEnabled,
                  onChanged: context.read<SettingsCubit>().setAiSuggestions,
                ),
                const ListTile(
                  leading: Icon(Icons.cloud_off_rounded),
                  title: Text('Local-only storage'),
                  subtitle: Text('Memories live in an on-device database. Nothing is synced.'),
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Export all memories'),
                  subtitle: const Text('Saves a JSON file to your Downloads folder'),
                  enabled: !state.isBusy,
                  onTap: () => _export(context),
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: error),
                  title: Text('Delete all local data', style: TextStyle(color: error)),
                  enabled: !state.isBusy,
                  onTap: () => _wipe(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader('About'),
      Card(
        child: ListTile(
          leading: Icon(Icons.psychology_alt_rounded),
          title: Text('Pocket Brain'),
          subtitle: Text(
            'Your personal memory companion. Save anything and find it later, '
            'powered by AI that runs entirely on your device.',
          ),
        ),
      ),
    ],
  );
}
