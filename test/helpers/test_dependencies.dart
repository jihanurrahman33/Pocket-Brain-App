import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/data/datasources/local/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Wires the real app graph with an in-memory database, a fake AI runtime
/// and no network — the same composition root the app uses.
Future<FakeAiRuntime> configureTestDependencies({FakeAiRuntime? runtime}) async {
  SharedPreferences.setMockInitialValues({});
  final ai = runtime ?? FakeAiRuntime();
  await configureDependencies(
    Infrastructure(
      database: await AppDatabase.inMemory(),
      preferences: await SharedPreferences.getInstance(),
      aiRuntime: ai,
      httpClient: MockClient((_) async => http.Response('', 404)),
      exporter: InMemoryExporter(),
      logger: const SilentLogger(),
      clock: FixedClock(),
    ),
  );
  return ai;
}
