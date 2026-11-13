import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/app_bloc_observer.dart';
import 'app/di/injection.dart';
import 'core/logging/app_logger.dart';
import 'core/usecase/usecase.dart';
import 'core/utils/clock.dart';
import 'core/utils/id_generator.dart';
import 'data/datasources/ai/litert_ai_runtime.dart';
import 'data/datasources/ai/resumable_downloader.dart';
import 'data/datasources/local/app_database.dart';
import 'data/repositories/prefs_preferences_repository.dart';
import 'data/services/audio/voice_recorders.dart';
import 'data/services/notifications/local_notification_scheduler.dart';
import 'domain/services/ai_services.dart';
import 'domain/usecases/indexing/indexing_usecases.dart';
import 'domain/usecases/tasks/task_usecases.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const logger = DebugAppLogger();
  Bloc.observer = const AppBlocObserver(logger);

  await LiteRtAiRuntime.initialize();
  final preferences = await SharedPreferences.getInstance();
  final httpClient = http.Client();
  final appSupport = await getApplicationSupportDirectory();
  final reminders = LocalNotificationReminderScheduler(
    plugin: FlutterLocalNotificationsPlugin(),
    preferences: preferences,
    clock: const SystemClock(),
    logger: logger,
  );
  await reminders.initialize();
  final savedPreferences = SharedPrefsPreferencesRepository(preferences);
  final aiRuntime = LiteRtAiRuntime(
    backend: savedPreferences.computeBackend,
    quality: savedPreferences.aiQuality,
    downloader: ResumableDownloader(httpClient, logger),
    modelsDirectory: Directory(p.join(appSupport.path, 'ai_models')),
  );
  await aiRuntime.restore();
  await configureDependencies(
    Infrastructure(
      database: await AppDatabase.open(),
      preferences: preferences,
      aiRuntime: aiRuntime,
      httpClient: httpClient,
      attachmentsDirectory: Directory(p.join(appSupport.path, 'attachments')),
      reminderScheduler: reminders,
      voiceRecorder: _voiceRecorderForPlatform(
        Directory(p.join((await getApplicationCacheDirectory()).path, 'recordings')),
      ),
    ),
  );

  // Catch up on memories saved before the embedder was installed.
  unawaited(sl<IndexPendingMemories>()(noParams));
  // Re-create notifications lost to a reboot or reinstall; show missed ones.
  unawaited(sl<SyncReminders>()(noParams));

  runApp(const PocketBrainApp());
}

/// Desktop Linux records with the system's PipeWire/ALSA tools; mobile uses
/// the platform plugin (with its permission prompt).
VoiceRecorder _voiceRecorderForPlatform(Directory directory) => Platform.isLinux
    ? CommandLineVoiceRecorder(directory, const UuidIdGenerator())
    : PluginVoiceRecorder(directory, const UuidIdGenerator());
