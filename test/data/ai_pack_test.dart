import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/core/error/failure.dart';
import 'package:pocket_brain/data/datasources/ai/on_device_ai_runtime.dart';
import 'package:pocket_brain/data/repositories/on_device_model_repository.dart';
import 'package:pocket_brain/domain/repositories/preferences_repository.dart';
import 'package:pocket_brain/features/model_manager/bloc/model_bloc.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/test_dependencies.dart';

void main() {
  const total = FakeAiRuntime.languageModelBytes + FakeAiRuntime.embedderBytes;

  group('OnDeviceModelRepository (one AI pack)', () {
    test('installs every component as one download with monotonic progress', () async {
      final runtime = FakeAiRuntime();
      final repo = OnDeviceModelRepository(runtime, const SilentLogger());
      expect(repo.status().remainingBytes, total);

      final progress = <double>[];
      final result = await repo.install(onProgress: progress.add);

      expect(result.isSuccess, isTrue);
      expect(runtime.installOrder, [AiModelKind.languageModel, AiModelKind.embedder]);
      expect(repo.status().isInstalled, isTrue);
      expect(progress.last, 1);
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
      // Weighted by size: the language model is ~87% of the pack.
      expect(progress, contains(closeTo(FakeAiRuntime.languageModelBytes / total, 1e-9)));
    });

    test('a retry resumes by downloading only what is missing', () async {
      final runtime = FakeAiRuntime(failOn: AiModelKind.embedder);
      final repo = OnDeviceModelRepository(runtime, const SilentLogger());

      final failed = await repo.install(onProgress: (_) {});
      expect(failed.failureOrNull, isA<ModelFailure>());
      expect(repo.status().isPartiallyInstalled, isTrue);
      // The language model is done and part of the embedder is on disk too.
      expect(repo.status().remainingBytes, lessThan(FakeAiRuntime.embedderBytes));

      runtime
        ..failOn = null
        ..installOrder.clear();
      expect((await repo.install(onProgress: (_) {})).isSuccess, isTrue);
      expect(runtime.installOrder, [AiModelKind.embedder]);
    });

    // The reported bug: progress restarted from 0 after an interruption.
    test('progress continues from the bytes already on disk', () async {
      final runtime = FakeAiRuntime()..partialBytes[AiModelKind.languageModel] = 1482;
      final repo = OnDeviceModelRepository(runtime, const SilentLogger());
      expect(repo.status().isPartiallyInstalled, isTrue);
      expect(repo.status().downloadedFraction, closeTo(1482 / total, 1e-9));

      final progress = <double>[];
      await repo.install(onProgress: progress.add);
      expect(progress.first, closeTo(1482 / total, 1e-9));
      expect(progress.every((p) => p >= 1482 / total - 1e-9), isTrue);
    });

    // Regression: a file that finished downloading but was never registered
    // (app closed while verifying) was reported as installed, so setup never
    // finished.
    test('a downloaded but unregistered file is not "installed"', () async {
      final runtime = FakeAiRuntime(installed: {AiModelKind.embedder})
        ..partialBytes[AiModelKind.languageModel] = FakeAiRuntime.languageModelBytes;
      final repo = OnDeviceModelRepository(runtime, const SilentLogger());
      expect(repo.status().remainingBytes, 0);
      expect(repo.status().isInstalled, isFalse);
      expect(repo.status().isPartiallyInstalled, isTrue);

      expect((await repo.install(onProgress: (_) {})).isSuccess, isTrue);
      expect(runtime.installOrder, [AiModelKind.languageModel]);
      expect(repo.status().isInstalled, isTrue);
    });

    test('cancel stops the whole download', () async {
      final repo = OnDeviceModelRepository(FakeAiRuntime(), const SilentLogger());
      final pending = repo.install(onProgress: (_) {});
      repo.cancelInstall();
      expect((await pending).failureOrNull, isA<CancelledFailure>());
      expect(repo.status().isInstalled, isFalse);
    });

    test('uninstall removes every component', () async {
      final runtime = FakeAiRuntime(installed: AiModelKind.values.toSet());
      final repo = OnDeviceModelRepository(runtime, const SilentLogger());
      expect((await repo.uninstall()).isSuccess, isTrue);
      expect(repo.status().remainingBytes, total);
    });
  });

  test('ModelBloc shows one download from start to ready', () async {
    await configureTestDependencies();
    final bloc = sl<ModelBloc>()..add(const ModelStarted());
    await untilState(bloc, (s) => s.pack != null);
    expect(bloc.state.isReady, isFalse);

    final seen = <ModelState>[];
    final sub = bloc.stream.listen(seen.add);
    bloc.add(const ModelInstallRequested());
    await untilState(bloc, (s) => s.isReady && !s.isDownloading);
    await sub.cancel();

    expect(seen.where((s) => s.isDownloading), isNotEmpty);
    expect(bloc.state.failure, isNull);
    await bloc.close();
  });

  // The reported bug: after a restart the setup did not continue by itself.
  test('an interrupted setup resumes automatically on the next launch', () async {
    final runtime = FakeAiRuntime()..partialBytes[AiModelKind.languageModel] = 1300;
    await configureTestDependencies(runtime: runtime);
    await sl<PreferencesRepository>().setAiSetupRequested(true);

    final bloc = sl<ModelBloc>()..add(const ModelStarted());
    await untilState(bloc, (s) => s.isReady && !s.isDownloading);
    expect(runtime.installOrder.first, AiModelKind.languageModel);
    expect(sl<PreferencesRepository>().aiSetupRequested, isFalse);
    await bloc.close();
  });

  test('a cancelled setup does not resume on its own, but keeps its bytes', () async {
    final runtime = FakeAiRuntime()..partialBytes[AiModelKind.languageModel] = 1300;
    await configureTestDependencies(runtime: runtime);

    final bloc = sl<ModelBloc>()..add(const ModelStarted());
    await untilState(bloc, (s) => s.pack != null);
    expect(runtime.installOrder, isEmpty);
    expect(bloc.state.pack!.isPartiallyInstalled, isTrue);
    await bloc.close();
  });

  // Product rule: model names are an implementation detail. Swapping models
  // must never require UI copy changes, so user-facing code never names them.
  test('presentation and domain never name the underlying models', () {
    final modelNames = RegExp('gemma|litert|embeddinggemma', caseSensitive: false);
    final stringLiteral = RegExp(r''''[^']*'|"[^"]*"''');
    final offenders = <String>[];
    for (final dir in ['lib/features', 'lib/domain']) {
      for (final file in Directory(dir).listSync(recursive: true).whereType<File>()) {
        final lines = file.readAsLinesSync();
        for (final (i, line) in lines.indexed) {
          if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('import')) continue;
          for (final literal in stringLiteral.allMatches(line)) {
            if (modelNames.hasMatch(literal[0]!)) offenders.add('${file.path}:${i + 1}');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
