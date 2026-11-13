import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/memory_views.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/services/relevance_scorer.dart';
import '../../../domain/usecases/collections/collection_usecases.dart';
import '../../ask/bloc/ask_bloc.dart';
import '../bloc/collection_cubit.dart';

class CollectionPage extends StatelessWidget {
  const CollectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollectionCubit, LoadState<CollectionContents>>(
      builder: (context, state) => switch (state) {
        Loading() => const Scaffold(body: LoadingView()),
        LoadFailed(:final failure) => Scaffold(
          appBar: AppBar(),
          body: FailureView(failure: failure),
        ),
        Loaded(:final data) => _CollectionScaffold(contents: data),
      },
    );
  }
}

class _CollectionScaffold extends StatefulWidget {
  const _CollectionScaffold({required this.contents});

  final CollectionContents contents;

  @override
  State<_CollectionScaffold> createState() => _CollectionScaffoldState();
}

class _CollectionScaffoldState extends State<_CollectionScaffold> {
  static const _scorer = KeywordRelevanceScorer();
  static const _minScore = 0.2;
  static const _gridTileMaxWidth = 280.0;
  static const _gridAspectRatio = 0.95;

  String _query = '';

  List<Memory> get _visible => _query.trim().isEmpty
      ? widget.contents.memories
      : [
          for (final m in widget.contents.memories)
            if (_scorer.score(_query, m) > _minScore) m,
        ];

  void _ask() {
    context.read<AskBloc>().add(
      AskNewConversationRequested(collectionId: widget.contents.collection.id),
    );
    context.go(AppRoutes.ask);
  }

  Future<void> _delete() async {
    final cubit = context.read<CollectionCubit>();
    final router = GoRouter.of(context);
    final collection = widget.contents.collection;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete "${collection.name}"?',
      message: 'The memories inside are kept; they just leave this collection.',
    );
    if (!confirmed) return;
    final failure = await cubit.delete();
    if (!mounted) return;
    if (failure != null) return context.showFailure(failure);
    if (router.canPop()) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.contents.collection;
    final visible = _visible;
    final padding = AppSpacing.pagePadding(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(collection.label, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Ask this collection',
            icon: const Icon(Icons.psychology_alt_outlined),
            onPressed: _ask,
          ),
          IconButton(
            tooltip: 'Delete collection',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _delete,
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
                    onChanged: (q) => setState(() => _query = q),
                  ),
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: widget.contents.memories.isEmpty
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
                  itemCount: visible.length,
                  itemBuilder: (_, i) => MemoryCard(memory: visible[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
