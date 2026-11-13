import 'dart:io';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/repositories/model_repository.dart';
import '../datasources/ai/on_device_ai_runtime.dart';

/// Presents the runtime's separate model components as one AI pack.
///
/// Installation downloads every missing component in order and reports a
/// single, size-weighted progress value, so the UI shows one download no
/// matter how many models the pack contains.
final class OnDeviceModelRepository implements ModelRepository {
  OnDeviceModelRepository(this._runtime, this._logger);

  final OnDeviceAiRuntime _runtime;
  final AppLogger _logger;

  static const _percent = 100;

  /// The component currently downloading, so cancel can target it.
  AiModelKind? _installing;
  bool _cancelRequested = false;

  List<AiComponent> get _missing => [
    for (final c in _runtime.components)
      if (!_runtime.isInstalled(c.kind)) c,
  ];

  @override
  AiPackStatus status() {
    final components = _runtime.components;
    return AiPackStatus(
      totalBytes: components.fold(0, (sum, c) => sum + c.sizeBytes),
      remainingBytes: _missing.fold(0, (sum, c) => sum + c.sizeBytes),
      isLoaded: components.any((c) => _runtime.isLoaded(c.kind)),
    );
  }

  @override
  Future<Result<void>> install({required void Function(double progress) onProgress}) async {
    final missing = _missing;
    final total = missing.fold(0, (sum, c) => sum + c.sizeBytes);
    var completedBytes = 0;
    _cancelRequested = false;
    try {
      for (final component in missing) {
        if (_cancelRequested) throw const InstallCancelledException();
        _installing = component.kind;
        await _runtime.install(
          component.kind,
          onProgress: (percent) => onProgress(
            total == 0 ? 1 : (completedBytes + component.sizeBytes * percent / _percent) / total,
          ),
        );
        completedBytes += component.sizeBytes;
      }
      onProgress(1);
      return const Success(null);
    } on InstallCancelledException {
      return const Err(CancelledFailure('Download cancelled.'));
    } on Object catch (e, s) {
      _logger.error('Installing AI component $_installing failed', e, s);
      return Err(_failureFor(e));
    } finally {
      _installing = null;
    }
  }

  @override
  void cancelInstall() {
    _cancelRequested = true;
    if (_installing case final kind?) _runtime.cancelInstall(kind);
  }

  @override
  Future<Result<void>> uninstall() async {
    try {
      for (final component in _runtime.components) {
        if (_runtime.isInstalled(component.kind)) await _runtime.uninstall(component.kind);
      }
      return const Success(null);
    } on Object catch (e, s) {
      _logger.error('Removing the AI pack failed', e, s);
      return const Err(ModelFailure('Could not delete the AI files.'));
    }
  }

  @override
  Future<void> unloadAll() async {
    for (final component in _runtime.components) {
      await _runtime.unload(component.kind);
    }
  }

  @override
  Future<void> useBackend(ComputeBackend backend) => _runtime.useBackend(backend);

  @override
  Future<int> storageBytes() async {
    try {
      return await _runtime.storageBytes();
    } on Object catch (e, s) {
      _logger.error('Reading AI storage failed', e, s);
      return 0;
    }
  }

  static Failure _failureFor(Object error) {
    final text = error.toString();
    if (error is SocketException || error is HttpException || text.contains('Network')) {
      return const NetworkFailure();
    }
    if (text.contains('ENOSPC') || text.toLowerCase().contains('no space')) {
      return const ModelFailure('Not enough storage space for Pocket Brain AI.');
    }
    return const ModelFailure('Pocket Brain AI could not be downloaded. Please try again.');
  }
}
