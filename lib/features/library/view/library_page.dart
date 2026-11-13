import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/responsive/window_size.dart';
import '../../../core/theme/app_spacing.dart';
import '../bloc/library_cubit.dart';
import '../widgets/create_collection_action.dart';
import '../widgets/library_filters.dart';
import '../widgets/memory_collection_view.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final twoPane = context.windowSize.hasTwoPanes;
    return BlocBuilder<LibraryCubit, LibraryState>(
      builder: (context, state) {
        final cubit = context.read<LibraryCubit>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('My Brain'),
            actions: [
              IconButton(
                tooltip: 'New collection',
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: () => showCreateCollectionDialog(context),
              ),
              IconButton(
                tooltip: state.layout == LibraryLayout.list ? 'Grid view' : 'List view',
                icon: Icon(
                  state.layout == LibraryLayout.list
                      ? Icons.grid_view_rounded
                      : Icons.view_agenda_outlined,
                ),
                onPressed: cubit.toggleLayout,
              ),
            ],
          ),
          body: twoPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: AppSpacing.sidePaneWidth - AppSpacing.xxl * 2,
                      child: LibrarySidePane(state: state),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: MemoryCollectionView(state: state)),
                  ],
                )
              : MemoryCollectionView(
                  state: state,
                  header: LibraryCompactFilters(state: state),
                ),
        );
      },
    );
  }
}
