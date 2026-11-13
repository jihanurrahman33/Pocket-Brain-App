import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../ask/bloc/ask_bloc.dart';
import '../../shared/widgets/memory_views.dart';
import '../bloc/collection_cubit.dart';

class CollectionPage extends StatelessWidget {
  const CollectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollectionCubit, LoadState<CollectionView>>(
      builder: (context, state) => switch (state) {
        Loading() => const Scaffold(body: LoadingView()),
        LoadFailed(:final failure) => Scaffold(
          appBar: AppBar(),
          body: FailureView(failure: failure),
        ),
        Loaded(:final data) => _CollectionScaffold(view: data),
      },
    );
  }
}

class _CollectionScaffold extends StatelessWidget {
  const _CollectionScaffold({required this.view});

  final CollectionView view;

  static const _gridTileMaxWidth = 280.0;
  static const _gridAspectRatio = 0.95;

  void _ask(BuildContext context) {
    context.read<AskBloc>().add(AskNewConversationRequested(collectionId: view.collection.id));
    context.go(AppRoutes.ask);
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<CollectionCubit>();
    final router = GoRouter.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete "${view.collection.name}"?',
      message: 'The memories inside are kept; they just leave this collection.',
    );
    if (!confirmed) return;
    final failure = await cubit.delete();
    if (!context.mounted) return;
    if (failure != null) return context.showFailure(failure);
    if (router.canPop()) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final collection = view.collection;
    final padding = AppSpacing.pagePadding(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(collection.label, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Ask this collection',
            icon: const Icon(Icons.psychology_alt_outlined),
            onPressed: () => _ask(context),
          ),
          IconButton(
            tooltip: 'Delete collection',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: AppSpacing.wideContentWidth,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, AppSpacing.sm, padding, AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: ResponsiveCenter(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search in ${collection.name}',
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: context.read<CollectionCubit>().search,
                  ),
                ),
              ),
            ),
            if (view.memories.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: view.isEmpty
                    ? const EmptyState(
                        icon: Icons.folder_open_rounded,
                        title: 'Empty collection',
                        message:
                            'Choose this collection when capturing, or move memories here '
                            'from their detail page.',
                      )
                    : const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No matches',
                        message: 'Nothing in this collection matches that search.',
                      ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 0, padding, AppSpacing.xxl),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: _gridTileMaxWidth,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: _gridAspectRatio,
                  ),
                  itemCount: view.memories.length,
                  itemBuilder: (_, i) => MemoryCard(memory: view.memories[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
