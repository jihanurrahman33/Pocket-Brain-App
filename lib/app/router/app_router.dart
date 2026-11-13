import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/app_routes.dart';
import '../../features/ask/view/ask_page.dart';
import '../../features/capture/view/capture_page.dart';
import '../../features/collections/bloc/collection_cubit.dart';
import '../../features/collections/view/collection_page.dart';
import '../../features/digest/bloc/digest_cubit.dart';
import '../../features/digest/view/digest_page.dart';
import '../../features/home/view/home_page.dart';
import '../../features/library/view/library_page.dart';
import '../../features/memory_detail/bloc/memory_detail_cubit.dart';
import '../../features/memory_detail/view/memory_detail_page.dart';
import '../../features/search/view/search_page.dart';
import '../../features/settings/bloc/settings_cubit.dart';
import '../../features/settings/view/settings_page.dart';
import '../../features/tasks/bloc/tasks_cubit.dart';
import '../../features/tasks/view/tasks_page.dart';
import '../di/injection.dart';
import 'app_shell.dart';

/// The five tabs, in navigation order.
const _tabs = <(String, Widget)>[
  (AppRoutes.home, HomePage()),
  (AppRoutes.brain, LibraryPage()),
  (AppRoutes.capture, CapturePage()),
  (AppRoutes.ask, AskPage()),
  (AppRoutes.search, SearchPage()),
];

GoRouter createRouter() => GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        for (final (path, page) in _tabs)
          StatefulShellBranch(
            routes: [GoRoute(path: path, builder: (_, _) => page)],
          ),
      ],
    ),
    GoRoute(
      path: AppRoutes.memoryPattern,
      builder: (_, state) {
        final id = state.pathParameters[AppRoutes.idParam]!;
        return BlocProvider(
          // Keyed so opening a related memory creates a fresh cubit.
          key: ValueKey(id),
          create: (_) => sl<MemoryDetailCubit>(param1: id)..load(),
          child: const MemoryDetailPage(),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.collectionPattern,
      builder: (_, state) {
        final id = state.pathParameters[AppRoutes.idParam]!;
        return BlocProvider(
          key: ValueKey(id),
          create: (_) => sl<CollectionCubit>(param1: id)..load(),
          child: const CollectionPage(),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.digest,
      builder: (_, _) =>
          BlocProvider(create: (_) => sl<DigestCubit>()..load(), child: const DigestPage()),
    ),
    GoRoute(
      path: AppRoutes.tasks,
      builder: (_, _) =>
          BlocProvider(create: (_) => sl<TasksCubit>()..load(), child: const TasksPage()),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (_, _) =>
          BlocProvider(create: (_) => sl<SettingsCubit>()..load(), child: const SettingsPage()),
    ),
  ],
);
