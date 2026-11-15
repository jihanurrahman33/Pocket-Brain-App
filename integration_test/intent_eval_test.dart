// Measures how well Ask Brain understands messages, on the real on-device
// model. Run on the desktop with the AI set up (close the app first, so two
// models do not compete for memory):
//
//   flutter test integration_test/intent_eval_test.dart -d linux
//
// Writes build/intent_eval/report.md. Set EVAL_MODEL_ONLY=1 to bypass the
// rules fast path and score the model alone.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pocket_brain/core/logging/app_logger.dart';
import 'package:pocket_brain/data/datasources/ai/litert_ai_runtime.dart';
import 'package:pocket_brain/data/datasources/ai/on_device_ai_runtime.dart';
import 'package:pocket_brain/data/datasources/ai/resumable_downloader.dart';
import 'package:pocket_brain/data/repositories/prefs_preferences_repository.dart';
import 'package:pocket_brain/data/services/ai/intent_understander.dart';
import 'package:pocket_brain/domain/entities/task_item.dart';
import 'package:pocket_brain/domain/entities/user_intent.dart';
import 'package:pocket_brain/domain/repositories/intent_correction_repository.dart';
import 'package:pocket_brain/domain/repositories/task_repository.dart';
import 'package:pocket_brain/domain/usecases/ask/understand_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/intent_eval.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('intent understanding on the real model', (tester) async {
    const logger = DebugAppLogger();
    await LiteRtAiRuntime.initialize();
    final prefs = SharedPrefsPreferencesRepository(await SharedPreferences.getInstance());
    final support = await getApplicationSupportDirectory();
    final runtime = LiteRtAiRuntime(
      backend: prefs.computeBackend,
      quality: prefs.aiQuality,
      downloader: ResumableDownloader(http.Client(), logger),
      modelsDirectory: Directory(p.join(support.path, 'ai_models')),
    );
    await runtime.restore();
    if (!runtime.isUsable(AiModelKind.languageModel)) {
      markTestSkipped('Set up Pocket Brain AI in the app first.');
      return;
    }

    final set = IntentEvalSet.load();
    final understander = GemmaIntentUnderstander(runtime, _Tasks(set.tasks), logger);
    final modelOnly = Platform.environment['EVAL_MODEL_ONLY'] == '1';
    final pipeline = UnderstandMessage(
      understander: understander,
      corrections: const _NoCorrections(),
      clock: FixedClock(set.now),
      logger: logger,
    );

    final report = await evaluate(
      set,
      (text) => modelOnly
          ? understander.understand(text, now: set.now)
          : pipeline((
              message: text,
              tasks: set.tasks,
              context: IntentContext.empty,
              forcedIntent: null,
            )),
    );

    final title = modelOnly ? 'Intent evaluation (model only)' : 'Intent evaluation';
    final out = File('build/intent_eval/${modelOnly ? 'report_model_only' : 'report'}.md')
      ..createSync(recursive: true)
      ..writeAsStringSync(report.toMarkdown(title));
    // ignore: avoid_print
    print(
      'INTENT EVAL: intent ${(report.intentAccuracy * 100).toStringAsFixed(1)}%, '
      'with details ${(report.fullAccuracy * 100).toStringAsFixed(1)}%, '
      'median ${report.medianLatency.inMilliseconds} ms → ${out.path}',
    );
    await runtime.unload(AiModelKind.languageModel);
  }, timeout: const Timeout(Duration(minutes: 90)));
}

final class _Tasks implements TaskRepository {
  _Tasks(this._tasks);

  final List<TaskItem> _tasks;

  @override
  Future<List<TaskItem>> getAll() async => _tasks;

  @override
  Future<List<TaskItem>> forMemory(String memoryId) async => const [];

  @override
  Future<void> save(TaskItem task) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> clear() async {}

  @override
  Stream<void> get changes => const Stream.empty();
}

final class _NoCorrections implements IntentCorrectionRepository {
  const _NoCorrections();

  @override
  Future<List<IntentExample>> recent({int limit = 8}) async => const [];

  @override
  Future<void> add(IntentExample example) async {}

  @override
  Future<void> clear() async {}
}
