import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/core/error/failure.dart';
import 'package:pocket_brain/core/usecase/usecase.dart';
import 'package:pocket_brain/data/datasources/ai/on_device_ai_runtime.dart';
import 'package:pocket_brain/data/services/system/proc_meminfo_device_memory.dart';
import 'package:pocket_brain/domain/entities/ai_model.dart';
import 'package:pocket_brain/domain/repositories/preferences_repository.dart';
import 'package:pocket_brain/domain/usecases/models/model_usecases.dart';
import 'package:pocket_brain/features/model_manager/bloc/model_bloc.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/test_dependencies.dart';

const _gb = 1024 * 1024 * 1024;

void main() {
  FakeAiRuntime installedRuntime() =>
      FakeAiRuntime(installed: {AiModelKind.languageModel, AiModelKind.embedder});

  group('AI quality tiers', () {
    test('4–6 GB phones are offered only the standard AI', () async {
      await configureTestDependencies(deviceMemoryBytes: 6 * _gb);
      expect(await sl<GetAvailableAiQualities>()(noParams), [AiQuality.standard]);
      final result = await sl<ChangeAiQuality>()(AiQuality.high);
      expect(result.failureOrNull, isA<ModelFailure>());
      expect(sl<PreferencesRepository>().aiQuality, AiQuality.standard);
    });

    test('an "8 GB" device (reporting ~7.5 GB) may choose higher quality', () async {
      await configureTestDependencies(deviceMemoryBytes: (7.5 * _gb).round());
      expect(await sl<GetAvailableAiQualities>()(noParams), [AiQuality.standard, AiQuality.high]);
    });

    test('unknown memory keeps the safe default', () async {
      expect(await const GetAvailableAiQualities(FakeDeviceMemory(null))(noParams), [
        AiQuality.standard,
      ]);
    });

    test('switching downloads the new AI while the old one keeps answering', () async {
      final ai = await configureTestDependencies(
        runtime: installedRuntime(),
        deviceMemoryBytes: 12 * _gb,
      );
      final bloc = sl<ModelBloc>()..add(const ModelStarted());
      await untilState(bloc, (s) => s.isReady);
      expect(bloc.state.qualities, contains(AiQuality.high));

      bloc.add(const ModelQualityChanged(AiQuality.high));
      // The download starts by itself; meanwhile the standard model is usable.
      await untilState(bloc, (s) => s.isDownloading);
      expect(ai.isUsable(AiModelKind.languageModel), isTrue);
      await untilState(bloc, (s) => s.isReady && !s.isDownloading);

      expect(bloc.state.quality, AiQuality.high);
      expect(ai.quality, AiQuality.high);
      expect(ai.usableOnly, isEmpty, reason: 'the old model was replaced');
      expect(sl<PreferencesRepository>().aiQuality, AiQuality.high);
      await bloc.close();
    });
  });

  group('ProcMeminfoDeviceMemory', () {
    test('reads MemTotal', () async {
      final dir = Directory.systemTemp.createTempSync('pb_meminfo_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/meminfo')
        ..writeAsStringSync('MemTotal:        7864320 kB\nMemFree:          123 kB\n');
      expect(await ProcMeminfoDeviceMemory(file.path).totalBytes(), 7864320 * 1024);
      expect(await ProcMeminfoDeviceMemory('${dir.path}/missing').totalBytes(), isNull);
    });
  });
}
