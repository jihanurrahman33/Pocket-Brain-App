import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/data/datasources/local/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Fakes the last [configureTestDependencies] call installed, for assertions.
late FakeVoiceRecorder testRecorder;
late FakeReminderScheduler testReminders;
late Directory testFilesDirectory;

/// Wires the real app graph with an in-memory database, a fake AI runtime
/// and no network — the same composition root the app uses.
Future<FakeAiRuntime> configureTestDependencies({FakeAiRuntime? runtime}) async {
  SharedPreferences.setMockInitialValues({});
  final ai = runtime ?? FakeAiRuntime();
  testFilesDirectory = Directory.systemTemp.createTempSync('pb_test_files_');
  addTearDown(() {
    if (testFilesDirectory.existsSync()) testFilesDirectory.deleteSync(recursive: true);
  });
  testRecorder = FakeVoiceRecorder(Directory('${testFilesDirectory.path}/recordings'));
  testReminders = FakeReminderScheduler();
  await configureDependencies(
    Infrastructure(
      database: await AppDatabase.inMemory(),
      preferences: await SharedPreferences.getInstance(),
      aiRuntime: ai,
      httpClient: MockClient((_) async => http.Response('', 404)),
      attachmentsDirectory: Directory('${testFilesDirectory.path}/attachments'),
      voiceRecorder: testRecorder,
      reminderScheduler: testReminders,
      exporter: InMemoryExporter(),
      logger: const SilentLogger(),
      clock: FixedClock(),
    ),
  );
  return ai;
}
