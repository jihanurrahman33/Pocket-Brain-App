import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/assistant.dart';
import '../bloc/ask_bloc.dart';

/// A change the assistant proposed. Nothing happens until the user taps
/// Confirm, in line with "AI suggests, the user decides".
class AssistantActionCard extends StatelessWidget {
  const AssistantActionCard({super.key, required this.messageId, required this.action});

  final String messageId;
  final AssistantAction action;

  static const _maxWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, details) = _describe(action);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: Card(
        color: action.isPending ? theme.colorScheme.aiContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + AppSpacing.xxs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                ],
              ),
              for (final line in details)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(line, style: theme.textTheme.bodyMedium),
                ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: _Buttons(card: this),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (IconData, String, List<String>) _describe(AssistantAction action) {
    final args = action.args;
    return switch (action.type) {
      AssistantActionType.createTask => (
        Icons.add_task_rounded,
        'Create task',
        [
          args['title'] ?? '',
          if (DateTime.tryParse(args['due'] ?? '') case final due?) 'Due ${Formatters.day(due)}',
          if (DateTime.tryParse(args['reminder'] ?? '') case final at?)
            'Reminder ${Formatters.reminder(at)}',
        ],
      ),
      AssistantActionType.saveMemory => (
        Icons.bookmark_add_outlined,
        'Save as a memory',
        [args['text'] ?? ''],
      ),
    };
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({required this.card});

  final AssistantActionCard card;

  @override
  Widget build(BuildContext context) {
    void decide({required bool confirmed}) => context.read<AskBloc>().add(
      AskActionDecided(messageId: card.messageId, actionId: card.action.id, confirmed: confirmed),
    );
    return switch (card.action.status) {
      AssistantActionStatus.proposed => Wrap(
        spacing: AppSpacing.sm,
        children: [
          TextButton(onPressed: () => decide(confirmed: false), child: const Text('Dismiss')),
          FilledButton(onPressed: () => decide(confirmed: true), child: const Text('Confirm')),
        ],
      ),
      AssistantActionStatus.done => const Chip(
        avatar: Icon(Icons.check_circle_rounded, size: AppSpacing.lg),
        label: Text('Done'),
      ),
      AssistantActionStatus.dismissed => const Chip(label: Text('Dismissed')),
    };
  }
}
