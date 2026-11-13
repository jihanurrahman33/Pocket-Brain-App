import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/memory_views.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/conversation.dart';
import '../../../domain/entities/memory.dart';
import '../../model_manager/widgets/model_setup_banner.dart';
import '../bloc/ask_bloc.dart';

class AskWelcome extends StatelessWidget {
  const AskWelcome({super.key, required this.state});

  final AskState state;

  static const _iconSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collection = state.collection;
    return ResponsiveListView(
      children: [
        const ModelSetupBanner(),
        const Gap.xl(),
        Icon(Icons.psychology_alt_rounded, size: _iconSize, color: theme.colorScheme.primary),
        const Gap.md(),
        Text(
          'Talk to your memories',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const Gap.sm(),
        Text(
          collection == null
              ? 'Answers come only from what you saved, with sources you can open.'
              : 'Answers come only from ${collection.label}.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const Gap.xl(),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final s in state.suggestions)
              ActionChip(
                label: Text(s),
                onPressed: () => context.read<AskBloc>().add(AskQuestionSubmitted(s)),
              ),
          ],
        ),
      ],
    );
  }
}

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({super.key, required this.state, required this.controller});

  final AskState state;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final padding = AppSpacing.pagePadding(context);
    final lastIndex = state.messages.length - 1;
    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(padding, AppSpacing.lg, padding, AppSpacing.lg),
      children: [
        for (final (i, message) in state.messages.indexed)
          message.isUser
              ? _UserBubble(text: message.text)
              : _AnswerBlock(
                  message: message,
                  sources: state.sourcesOf(message),
                  canRegenerate: i == lastIndex && !state.isAnswering,
                ),
        if (state.streamingText != null) _StreamingAnswer(state: state),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  /// User bubbles never span the full width, like any chat app.
  static const _widthFactor = 0.85;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: FractionallySizedBox(
      widthFactor: _widthFactor,
      alignment: Alignment.centerRight,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + AppSpacing.xxs,
            vertical: AppSpacing.sm + AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppSpacing.lg),
          ),
          child: SelectableText(text),
        ),
      ),
    ),
  );
}

class _AnswerBlock extends StatelessWidget {
  const _AnswerBlock({required this.message, required this.sources, required this.canRegenerate});

  final ChatMessage message;
  final List<Memory> sources;
  final bool canRegenerate;

  static const _actionIconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(message.text, style: theme.textTheme.bodyLarge),
          if (sources.isNotEmpty) ...[
            const Gap.md(),
            Text('Sources from your memories', style: theme.textTheme.labelMedium),
            const Gap.sm(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [for (final (i, m) in sources.indexed) SourceCard(index: i + 1, memory: m)],
            ),
          ],
          Row(
            children: [
              IconButton(
                tooltip: 'Copy answer',
                iconSize: _actionIconSize,
                icon: const Icon(Icons.copy_rounded),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message.text));
                  if (context.mounted) context.showMessage('Answer copied');
                },
              ),
              if (canRegenerate)
                IconButton(
                  tooltip: 'Regenerate',
                  iconSize: _actionIconSize,
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => context.read<AskBloc>().add(const AskRegenerateRequested()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A clickable reference to a memory used in an answer.
class SourceCard extends StatelessWidget {
  const SourceCard({super.key, required this.index, required this.memory});

  final int index;
  final Memory memory;

  static const _width = 220.0;
  static const _badgeRadius = 11.0;
  static const _badgeFontSize = 11.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _width),
      child: Card(
        color: theme.colorScheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openMemory(context, memory.id),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: _badgeRadius,
                  child: Text('$index', style: const TextStyle(fontSize: _badgeFontSize)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memory.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        Formatters.friendlyDate(memory.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamingAnswer extends StatelessWidget {
  const _StreamingAnswer({required this.state});

  final AskState state;

  @override
  Widget build(BuildContext context) {
    final text = state.streamingText ?? '';
    final status = switch (state.phase) {
      AskPhase.retrieving => 'Searching your memories…',
      _ when text.isEmpty => 'Thinking on-device… (the first answer loads the model)',
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: status == null
          ? Text(text, style: Theme.of(context).textTheme.bodyLarge)
          : Row(
              children: [
                const InlineSpinner(),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: Text(status)),
              ],
            ),
    );
  }
}
