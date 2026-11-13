import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formatting/formatters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/memory_views.dart';
import '../../../core/widgets/section_header.dart';
import '../bloc/search_bloc.dart';

/// Results, recent searches or suggestions depending on the search state.
class SearchResults extends StatelessWidget {
  const SearchResults({
    super.key,
    required this.state,
    required this.onUseQuery,
    required this.onAskBrain,
  });

  final SearchState state;
  final ValueChanged<String> onUseQuery;
  final ValueChanged<String> onAskBrain;

  static const _examples = [
    'that article about making money online',
    'react project ideas',
    'books to read',
  ];

  @override
  Widget build(BuildContext context) {
    final query = state.query.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (query.isNotEmpty) _AskBrainCard(query: query, onTap: () => onAskBrain(query)),
        ...switch (state.status) {
          SearchStatus.idle => _idle(context),
          SearchStatus.searching when state.results.isEmpty => const [
            Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: LoadingView()),
          ],
          SearchStatus.failed => [FailureView(failure: state.failure!)],
          _ when state.results.isEmpty => const [
            EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching memories',
              message: 'Try different words, or switch to Smart search.',
            ),
          ],
          _ => _results(context, query),
        },
      ],
    );
  }

  List<Widget> _idle(BuildContext context) => [
    if (state.recent.isNotEmpty) ...[
      SectionHeader(
        'Recent searches',
        actionLabel: 'Clear',
        onAction: () => context.read<SearchBloc>().add(const SearchHistoryCleared()),
      ),
      for (final q in state.recent)
        ListTile(
          leading: const Icon(Icons.history_rounded),
          title: Text(q),
          onTap: () => onUseQuery(q),
        ),
    ],
    const SectionHeader('Try'),
    Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final example in _examples)
          ActionChip(label: Text(example), onPressed: () => onUseQuery(example)),
      ],
    ),
  ];

  List<Widget> _results(BuildContext context, String query) => [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        Formatters.plural(state.results.length, 'result'),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    ),
    for (final r in state.results)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: MemoryTile(
          memory: r.memory,
          snippet: query.isEmpty ? null : TextUtils.excerptAround(query, r.memory.content),
        ),
      ),
  ];
}

class _AskBrainCard extends StatelessWidget {
  const _AskBrainCard({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.psychology_alt_rounded),
        title: Text('Ask Brain: "$query"', maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: const Text('Get a summarized answer with sources'),
        trailing: const Icon(Icons.arrow_forward_rounded),
        onTap: onTap,
      ),
    ),
  );
}
