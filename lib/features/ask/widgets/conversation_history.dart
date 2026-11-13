import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../bloc/ask_bloc.dart';

/// Past conversations; a side pane on large windows, a drawer elsewhere.
class ConversationHistory extends StatelessWidget {
  const ConversationHistory({super.key, required this.state, required this.closeOnSelect});

  final AskState state;

  /// True inside a drawer, which should close after a selection.
  final bool closeOnSelect;

  static const _deleteIconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AskBloc>();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text('Conversations', style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: state.conversations.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text('Your past questions will appear here.'),
                  )
                : ListView(
                    children: [
                      for (final c in state.conversations)
                        ListTile(
                          selected: c.id == state.conversation?.id,
                          leading: const Icon(Icons.chat_bubble_outline_rounded),
                          title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(Formatters.friendlyDate(c.createdAt)),
                          onTap: () {
                            bloc.add(AskConversationSelected(c));
                            if (closeOnSelect) Navigator.pop(context);
                          },
                          trailing: IconButton(
                            tooltip: 'Delete conversation',
                            icon: const Icon(Icons.delete_outline_rounded, size: _deleteIconSize),
                            onPressed: () => bloc.add(AskConversationDeleted(c.id)),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
