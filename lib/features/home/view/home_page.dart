import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/responsive/responsive_layouts.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/memory_views.dart';
import '../../../core/widgets/section_header.dart';
import '../../../domain/entities/recall.dart';
import '../../model_manager/widgets/model_setup_banner.dart';
import '../bloc/home_cubit.dart';
import '../widgets/home_sections.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Brain'),
        actions: [
          IconButton(
            tooltip: 'Tasks & reminders',
            icon: const Icon(Icons.checklist_rounded),
            onPressed: () => context.push(AppRoutes.tasks),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.capture),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Quick capture'),
      ),
      body: BlocBuilder<HomeCubit, LoadState<HomeOverview>>(
        builder: (context, state) => switch (state) {
          Loading() => const LoadingView(),
          LoadFailed(:final failure) => FailureView(
            failure: failure,
            onRetry: context.read<HomeCubit>().load,
          ),
          Loaded(:final data) => _HomeContent(overview: data),
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.overview});

  final HomeOverview overview;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTwoPane(
      bottomPadding: AppSpacing.fabClearance,
      primary: [
        GreetingHeader(memoryCount: overview.memoryCount),
        const Gap.lg(),
        AskBrainBar(onTap: () => context.go(AppRoutes.ask)),
        const Gap.md(),
        const ModelSetupBanner(),
        SectionHeader(
          'Recent memories',
          actionLabel: overview.recent.isEmpty ? null : 'Library',
          onAction: () => context.go(AppRoutes.brain),
        ),
        if (overview.recent.isEmpty)
          const EmptyState(
            icon: Icons.lightbulb_outline_rounded,
            title: 'Your brain is empty',
            message: 'Tap Quick capture to save a note, idea or link.',
          )
        else
          MemoryTileList(memories: overview.recent),
      ],
      secondary: [
        if (overview.savedThisWeek > 0) WeeklyDigestCard(overview: overview),
        if (overview.openTasks.isNotEmpty) OpenTasksSection(tasks: overview.openTasks),
        if (overview.collections.isNotEmpty) CollectionsSection(collections: overview.collections),
        if (overview.resurfaced.isNotEmpty) ...[
          const SectionHeader('Worth revisiting'),
          MemoryTileList(memories: overview.resurfaced),
        ],
      ],
    );
  }
}
