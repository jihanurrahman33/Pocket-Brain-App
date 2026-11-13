import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/responsive/window_size.dart';
import '../../../core/theme/app_spacing.dart';
import '../bloc/ask_bloc.dart';
import '../widgets/ask_composer.dart';
import '../widgets/chat_messages.dart';
import '../widgets/conversation_history.dart';

class AskPage extends StatefulWidget {
  const AskPage({super.key});

  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  });

  @override
  Widget build(BuildContext context) {
    final showHistoryPane = context.windowSize >= WindowSize.large;
    return BlocConsumer<AskBloc, AskState>(
      listenWhen: (a, b) =>
          a.messages.length != b.messages.length || a.streamingText != b.streamingText,
      listener: (_, _) => _scrollToEnd(),
      builder: (context, state) {
        final bloc = context.read<AskBloc>();
        return Scaffold(
          appBar: AppBar(
            title: Text(state.conversation?.title ?? 'Ask Brain', overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'New conversation',
                icon: const Icon(Icons.add_comment_outlined),
                onPressed: () => bloc.add(const AskNewConversationRequested()),
              ),
              if (!showHistoryPane)
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'Chat history',
                    icon: const Icon(Icons.history_rounded),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ),
            ],
          ),
          endDrawer: showHistoryPane
              ? null
              : Drawer(child: ConversationHistory(state: state, closeOnSelect: true)),
          body: Row(
            children: [
              if (showHistoryPane) ...[
                SizedBox(
                  width: AppSpacing.sidePaneWidth - AppSpacing.xxl * 2,
                  child: ConversationHistory(state: state, closeOnSelect: false),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: state.isEmpty
                          ? AskWelcome(state: state)
                          : ResponsiveCenter(
                              child: ChatMessageList(state: state, controller: _scroll),
                            ),
                    ),
                    AskComposer(state: state),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
