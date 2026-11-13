import 'dart:io';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/repositories/model_repository.dart';
import '../datasources/ai/on_device_ai_runtime.dart';

final class OnDeviceModelRepository implements ModelRepository {
  const OnDeviceModelRepository(this._runtime, this._logger);

  final OnDeviceAiRuntime _runtime;
  final AppLogger _logger;

  static const _percent = 100;

  @override
  List<AiModelInfo> get available => _runtime.models;

  @override
  AiModelStatus status(AiModelKind kind) => AiModelStatus(
    info: available.firstWhere((m) => m.kind == kind),
    installed: _runtime.isInstalled(kind),
    loaded: _runtime.isLoaded(kind),
  );

  @override
  Future<Result<void>> install(
    AiModelKind kind, {
    required void Function(double progress) onProgress,
  }) async {
    try {
      await _runtime.install(kind, onProgress: (p) => onProgress(p / _percent));
      return const Success(null);
    } on InstallCancelledException {
      return const Err(CancelledFailure('Download cancelled.'));
    } on Object catch (e, s) {
      _logger.error('Installing $kind failed', e, s);
      return Err(_failureFor(e));
    }
  }

  @override
  void cancelInstall(AiModelKind kind) => _runtime.cancelInstall(kind);

  @override
  Future<Result<void>> uninstall(AiModelKind kind) async {
    try {
      await _runtime.uninstall(kind);
      return const Success(null);
    } on Object catch (e, s) {
      _logger.error('Removing $kind failed', e, s);
      return const Err(ModelFailure('Could not delete the model files.'));
    }
  }

  @override
  Future<void> unloadAll() async {
    for (final kind in AiModelKind.values) {
      await _runtime.unload(kind);
    }
  }

  @override
  Future<void> useBackend(ComputeBackend backend) => _runtime.useBackend(backend);

  @override
  Future<int> storageBytes() async {
    try {
      return await _runtime.storageBytes();
    } on Object catch (e, s) {
      _logger.error('Reading model storage failed', e, s);
      return 0;
    }
  }

  static Failure _failureFor(Object error) {
    final text = error.toString();
    if (error is SocketException || error is HttpException || text.contains('Network')) {
      return const NetworkFailure();
    }
    if (text.contains('ENOSPC') || text.toLowerCase().contains('no space')) {
      return const ModelFailure('Not enough storage space for this model.');
    }
    return const ModelFailure('The model could not be downloaded. Please try again.');
  }
}
