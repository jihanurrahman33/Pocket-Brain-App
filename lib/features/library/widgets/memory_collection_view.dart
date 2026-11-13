import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/memory_views.dart';
import '../bloc/library_cubit.dart';

/// The library's memories as a list or a responsive grid.
class MemoryCollectionView extends StatelessWidget {
  const MemoryCollectionView({super.key, required this.state, this.header});

  final LibraryState state;

  /// Scrolls with the content (used for filters on small windows).
  final Widget? header;

  static const _gridTileMaxWidth = 280.0;
  static const _gridTileAspectRatio = 0.95;

  @override
  Widget build(BuildContext context) {
    final padding = AppSpacing.pagePadding(context);
    return CustomScrollView(
      slivers: [
        if (header != null)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(padding, AppSpacing.sm, padding, 0),
            sliver: SliverToBoxAdapter(child: header),
          ),
        ..._content(context, padding),
      ],
    );
  }

  List<Widget> _content(BuildContext context, double padding) {
    if (state.isLoading) {
      return const [SliverFillRemaining(child: LoadingView())];
    }
    if (state.failure case final failure?) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: FailureView(failure: failure, onRetry: context.read<LibraryCubit>().load),
        ),
      ];
    }
    if (state.memories.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Nothing here yet',
            message: 'Memories you save will appear here.',
          ),
        ),
      ];
    }
    final insets = EdgeInsets.fromLTRB(padding, AppSpacing.sm, padding, AppSpacing.xxl);
    return [
      SliverPadding(
        padding: insets,
        sliver: state.layout == LibraryLayout.grid
            ? SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: _gridTileMaxWidth,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: _gridTileAspectRatio,
                ),
                itemCount: state.memories.length,
                itemBuilder: (_, i) => MemoryCard(memory: state.memories[i]),
              )
            : SliverList.separated(
                itemCount: state.memories.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) =>
                    ResponsiveCenter(child: MemoryTile(memory: state.memories[i])),
              ),
      ),
    ];
  }
}
