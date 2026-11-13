import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/app_bloc_observer.dart';
import 'app/di/injection.dart';
import 'core/logging/app_logger.dart';
import 'core/usecase/usecase.dart';
import 'data/datasources/ai/litert_ai_runtime.dart';
import 'data/datasources/ai/resumable_downloader.dart';
import 'data/datasources/local/app_database.dart';
import 'data/repositories/prefs_preferences_repository.dart';
import 'domain/usecases/indexing/indexing_usecases.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const logger = DebugAppLogger();
  Bloc.observer = const AppBlocObserver(logger);

  await LiteRtAiRuntime.initialize();
  final preferences = await SharedPreferences.getInstance();
  final httpClient = http.Client();
  final appSupport = await getApplicationSupportDirectory();
  await configureDependencies(
    Infrastructure(
      database: await AppDatabase.open(),
      preferences: preferences,
      aiRuntime: LiteRtAiRuntime(
        backend: SharedPrefsPreferencesRepository(preferences).computeBackend,
        downloader: ResumableDownloader(httpClient, logger),
        modelsDirectory: Directory(p.join(appSupport.path, 'ai_models')),
      ),
      httpClient: httpClient,
    ),
  );

  // Catch up on memories saved before the embedder was installed.
  unawaited(sl<IndexPendingMemories>()(noParams));

  runApp(const PocketBrainApp());
}
