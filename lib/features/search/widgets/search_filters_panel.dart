import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/entities/search.dart';
import '../bloc/search_bloc.dart';

/// Mode, filters and sort. Laid out as a side panel ([vertical]) on wide
/// windows and as a wrapping chip row on small ones.
class SearchFiltersPanel extends StatelessWidget {
  const SearchFiltersPanel({super.key, required this.state, required this.vertical});

  final SearchState state;
  final bool vertical;

  static const _sinceOptions = <int?>[null, 7, 30, 365];

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<SearchBloc>();
    final filters = state.filters;
    void setFilters(SearchFilters f) => bloc.add(SearchOptionsChanged(filters: f));

    final mode = SegmentedButton<SearchMode>(
      segments: const [
        ButtonSegment(
          value: SearchMode.semantic,
          icon: Icon(Icons.auto_awesome_outlined),
          label: Text('Smart'),
        ),
        ButtonSegment(
          value: SearchMode.keyword,
          icon: Icon(Icons.text_fields_rounded),
          label: Text('Exact'),
        ),
      ],
      selected: {state.mode},
      onSelectionChanged: (s) => bloc.add(SearchOptionsChanged(mode: s.first)),
    );
    final pickers = <Widget>[
      _OptionMenu<String>(
        label: filters.category ?? 'Any category',
        active: filters.category != null,
        options: [null, ...state.categories],
        describe: (c) => c ?? 'Any category',
        onSelected: (c) => setFilters(filters.copyWith(category: () => c)),
      ),
      _OptionMenu<MemorySource>(
        label: filters.source?.label ?? 'Any type',
        active: filters.source != null,
        options: [null, ...MemorySource.values],
        describe: (s) => s?.label ?? 'Any type',
        onSelected: (s) => setFilters(filters.copyWith(source: () => s)),
      ),
      _OptionMenu<int>(
        label: filters.since == null ? 'Any time' : 'Recent only',
        active: filters.since != null,
        options: _sinceOptions,
        describe: (days) => days == null ? 'Any time' : 'Last $days days',
        onSelected: (days) => setFilters(
          filters.copyWith(
            since: () => days == null ? null : DateTime.now().subtract(Duration(days: days)),
          ),
        ),
      ),
      _OptionMenu<SearchSort>(
        label: state.sort == SearchSort.newest ? 'Newest first' : 'Most relevant',
        active: false,
        options: SearchSort.values,
        describe: (s) => s == SearchSort.newest ? 'Newest first' : 'Most relevant',
        onSelected: (s) => bloc.add(SearchOptionsChanged(sort: s)),
      ),
    ];

    if (!vertical) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [mode, ...pickers],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Search mode'),
        mode,
        const SectionHeader('Filters'),
        for (final picker in pickers)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: picker,
          ),
      ],
    );
  }
}

class _OptionMenu<T> extends StatelessWidget {
  const _OptionMenu({
    required this.label,
    required this.active,
    required this.options,
    required this.describe,
    required this.onSelected,
  });

  final String label;
  final bool active;
  final List<T?> options;
  final String Function(T?) describe;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      for (final option in options)
        MenuItemButton(onPressed: () => onSelected(option), child: Text(describe(option))),
    ],
    builder: (context, controller, _) => FilterChip(
      label: Text(label, overflow: TextOverflow.ellipsis),
      selected: active,
      onSelected: (_) => controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}
