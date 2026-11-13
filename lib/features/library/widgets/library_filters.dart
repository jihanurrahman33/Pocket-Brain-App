import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/memory_collection.dart';
import '../../../domain/entities/search.dart';
import '../bloc/library_cubit.dart';
import 'create_collection_action.dart';

const _filters = [
  (MemoryFilter.all, 'All memories', Icons.all_inbox_rounded),
  (MemoryFilter.recentlyViewed, 'Recently viewed', Icons.history_rounded),
  (MemoryFilter.favorites, 'Favorites', Icons.star_outline_rounded),
  (MemoryFilter.archived, 'Archived', Icons.archive_outlined),
];

/// Collections and filters as a vertical navigation pane (wide windows).
class LibrarySidePane extends StatelessWidget {
  const LibrarySidePane({super.key, required this.state});

  final LibraryState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LibraryCubit>();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
      children: [
        for (final (filter, label, icon) in _filters)
          ListTile(
            leading: Icon(icon),
            title: Text(label),
            selected: state.filter == filter && state.category == null,
            shape: const StadiumBorder(),
            onTap: () => cubit.selectFilter(filter),
          ),
        if (state.categories.isNotEmpty) ...[
          const SectionHeader('Categories'),
          for (final c in state.categories)
            ListTile(
              dense: true,
              title: Text(c),
              selected: state.category == c,
              shape: const StadiumBorder(),
              onTap: () => cubit.selectCategory(state.category == c ? null : c),
            ),
        ],
        SectionHeader(
          'Collections',
          actionLabel: 'New',
          onAction: () => showCreateCollectionDialog(context),
        ),
        for (final c in state.collections) _CollectionListTile(collection: c),
      ],
    );
  }
}

class _CollectionListTile extends StatelessWidget {
  const _CollectionListTile({required this.collection});

  final MemoryCollection collection;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Text(collection.emoji, style: Theme.of(context).textTheme.titleMedium),
    title: Text(collection.name, overflow: TextOverflow.ellipsis),
    trailing: Text('${collection.memoryCount}'),
    shape: const StadiumBorder(),
    onTap: () => context.push(AppRoutes.collection(collection.id)),
  );
}

/// Collections strip plus filter chips (compact and medium windows).
class LibraryCompactFilters extends StatelessWidget {
  const LibraryCompactFilters({super.key, required this.state});

  final LibraryState state;

  static const _stripHeight = 92.0;
  static const _cardWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LibraryCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.collections.isNotEmpty) ...[
          SizedBox(
            height: _stripHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.collections.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => SizedBox(
                width: _cardWidth,
                child: _CollectionCard(collection: state.collections[i]),
              ),
            ),
          ),
          const Gap.md(),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (filter, label, _) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: state.filter == filter && state.category == null,
                    onSelected: (_) => cubit.selectFilter(filter),
                  ),
                ),
              for (final c in state.categories)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(c),
                    selected: state.category == c,
                    onSelected: (selected) => cubit.selectCategory(selected ? c : null),
                  ),
                ),
            ],
          ),
        ),
        const Gap.md(),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});

  final MemoryCollection collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.collection(collection.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(collection.emoji, style: theme.textTheme.titleLarge),
              Text(
                collection.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text('${collection.memoryCount} memories', style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
