import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/ask/bloc/ask_bloc.dart';
import '../features/capture/bloc/capture_bloc.dart';
import '../features/home/bloc/home_cubit.dart';
import '../features/library/bloc/library_cubit.dart';
import '../features/model_manager/bloc/model_bloc.dart';
import '../features/search/bloc/search_bloc.dart';
import 'di/injection.dart';
import 'router/app_router.dart';

/// Root widget. Blocs for the five tabs live as long as the app, so each
/// tab keeps its state while you switch between them.
class PocketBrainApp extends StatefulWidget {
  const PocketBrainApp({super.key});

  @override
  State<PocketBrainApp> createState() => _PocketBrainAppState();
}

class _PocketBrainAppState extends State<PocketBrainApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(lazy: false, create: (_) => sl<ModelBloc>()..add(const ModelStarted())),
      BlocProvider(create: (_) => sl<HomeCubit>()..load()),
      BlocProvider(create: (_) => sl<LibraryCubit>()..load()),
      BlocProvider(create: (_) => sl<CaptureBloc>()),
      BlocProvider(create: (_) => sl<AskBloc>()..add(const AskStarted())),
      BlocProvider(create: (_) => sl<SearchBloc>()..add(const SearchStarted())),
    ],
    child: MaterialApp.router(
      title: 'Pocket Brain',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: _router,
    ),
  );
}
