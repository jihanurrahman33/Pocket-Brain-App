import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/app_bloc_observer.dart';
import 'app/di/injection.dart';
import 'core/logging/app_logger.dart';
import 'core/usecase/usecase.dart';
import 'data/datasources/ai/litert_ai_runtime.dart';
import 'data/datasources/local/app_database.dart';
import 'data/repositories/prefs_preferences_repository.dart';
import 'domain/usecases/indexing/indexing_usecases.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const logger = DebugAppLogger();
  Bloc.observer = const AppBlocObserver(logger);

  await LiteRtAiRuntime.initialize();
  final preferences = await SharedPreferences.getInstance();
  await configureDependencies(
    Infrastructure(
      database: await AppDatabase.open(),
      preferences: preferences,
      aiRuntime: LiteRtAiRuntime(
        backend: SharedPrefsPreferencesRepository(preferences).computeBackend,
      ),
      httpClient: http.Client(),
    ),
  );

  // Catch up on memories saved before the embedder was installed.
  unawaited(sl<IndexPendingMemories>()(noParams));

  runApp(const PocketBrainApp());
}
