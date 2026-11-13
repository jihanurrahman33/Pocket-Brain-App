import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/responsive/window_size.dart';
import '../../../core/theme/app_spacing.dart';
import '../../ask/bloc/ask_bloc.dart';
import '../bloc/search_bloc.dart';
import '../widgets/search_filters_panel.dart';
import '../widgets/search_results.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _useQuery(String query) {
    _controller.text = query;
    context.read<SearchBloc>()
      ..add(SearchTextChanged(query))
      ..add(const SearchSubmitted());
  }

  /// Hands the query to Ask Brain for a conversational answer.
  void _askBrain(String question) {
    context.read<AskBloc>()
      ..add(const AskNewConversationRequested())
      ..add(AskQuestionSubmitted(question));
    context.go(AppRoutes.ask);
  }

  @override
  Widget build(BuildContext context) {
    final twoPane = context.windowSize.hasTwoPanes;
    return BlocBuilder<SearchBloc, SearchState>(
      builder: (context, state) {
        final results = SearchResults(state: state, onUseQuery: _useQuery, onAskBrain: _askBrain);
        final padding = AppSpacing.pagePadding(context);
        final searchField = _SearchField(controller: _controller, state: state);
        return Scaffold(
          appBar: AppBar(title: const Text('Search')),
          body: twoPane
              ? ResponsiveCenter(
                  maxWidth: AppSpacing.wideContentWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            padding,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.xxl,
                          ),
                          children: [
                            searchField,
                            const SizedBox(height: AppSpacing.lg),
                            results,
                          ],
                        ),
                      ),
                      SizedBox(
                        width: AppSpacing.sidePaneWidth - AppSpacing.xl,
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            padding,
                            AppSpacing.xxl,
                          ),
                          children: [SearchFiltersPanel(state: state, vertical: true)],
                        ),
                      ),
                    ],
                  ),
                )
              : ResponsiveListView(
                  children: [
                    searchField,
                    const SizedBox(height: AppSpacing.md),
                    SearchFiltersPanel(state: state, vertical: false),
                    const SizedBox(height: AppSpacing.lg),
                    results,
                  ],
                ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.state});

  final TextEditingController controller;
  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SearchBloc>();
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search words, tags, or describe what you remember',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: state.query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  controller.clear();
                  bloc.add(const SearchTextChanged(''));
                },
              ),
      ),
      onChanged: (q) => bloc.add(SearchTextChanged(q)),
      onSubmitted: (_) => bloc.add(const SearchSubmitted()),
    );
  }
}
