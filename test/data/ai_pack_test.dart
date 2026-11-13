import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/core/error/failure.dart';
import 'package:pocket_brain/data/datasources/ai/on_device_ai_runtime.dart';
import 'package:pocket_brain/data/repositories/on_device_model_repository.dart';
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
      expect(repo.status().remainingBytes, FakeAiRuntime.embedderBytes);

      runtime
        ..failOn = null
        ..installOrder.clear();
      expect((await repo.install(onProgress: (_) {})).isSuccess, isTrue);
      expect(runtime.installOrder, [AiModelKind.embedder]);
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
    final bloc = sl<ModelBloc>()..add(const ModelRefreshRequested());
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
