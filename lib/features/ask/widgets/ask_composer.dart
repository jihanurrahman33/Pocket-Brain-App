import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_header.dart';
import '../bloc/ask_bloc.dart';

/// The question input with scope chips and send/stop control.
class AskComposer extends StatefulWidget {
  const AskComposer({super.key, required this.state});

  final AskState state;

  @override
  State<AskComposer> createState() => _AskComposerState();
}

class _AskComposerState extends State<AskComposer> {
  final _controller = TextEditingController();

  static const _maxLines = 4;
  static const _chipIconSize = 16.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    context.read<AskBloc>().add(AskQuestionSubmitted(question));
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final scheme = Theme.of(context).colorScheme;
    final bloc = context.read<AskBloc>();
    final padding = AppSpacing.pagePadding(context);
    return SafeArea(
      top: false,
      child: ResponsiveCenter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, AppSpacing.sm, padding, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Chip(
                    avatar: Icon(
                      Icons.verified_user_outlined,
                      size: _chipIconSize,
                      color: scheme.onAiContainer,
                    ),
                    label: const Text('Only my memories'),
                    backgroundColor: scheme.aiContainer,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                  PopupMenuButton<String?>(
                    tooltip: state.conversation == null
                        ? 'Limit answers to a collection'
                        : 'Start a new chat to change scope',
                    enabled: state.conversation == null,
                    onSelected: (id) => bloc.add(AskNewConversationRequested(collectionId: id)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(child: Text('All memories')),
                      for (final c in state.collections)
                        PopupMenuItem(value: c.id, child: Text(c.label)),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.folder_outlined, size: _chipIconSize),
                      label: Text(state.collection?.label ?? 'All memories'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (state.failure case final failure?) ...[
                const Gap.xs(),
                Text(failure.message, style: TextStyle(color: scheme.error)),
              ],
              const Gap.sm(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: _maxLines,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: state.messages.isEmpty
                            ? 'What was that idea I saved about…'
                            : 'Ask a follow-up…',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (state.isAnswering)
                    IconButton.filledTonal(
                      tooltip: 'Stop',
                      onPressed: () => bloc.add(const AskStopRequested()),
                      icon: const Icon(Icons.stop_rounded),
                    )
                  else
                    IconButton.filled(
                      tooltip: 'Ask',
                      onPressed: _send,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
