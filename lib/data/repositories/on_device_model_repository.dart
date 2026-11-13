import 'dart:io';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/repositories/model_repository.dart';
import '../datasources/ai/on_device_ai_runtime.dart';

/// Presents the runtime's separate model components as one AI pack.
///
/// Installation downloads every missing component in order and reports one
/// progress value for the whole pack, counting bytes already on disk, so an
/// interrupted setup continues from where it stopped — also across restarts.
final class OnDeviceModelRepository implements ModelRepository {
  OnDeviceModelRepository(this._runtime, this._logger);

  final OnDeviceAiRuntime _runtime;
  final AppLogger _logger;

  /// The component currently downloading, so cancel can target it.
  AiModelKind? _installing;
  bool _cancelRequested = false;

  List<AiComponent> get _missing => [
    for (final c in _runtime.components)
      if (!_runtime.isInstalled(c.kind)) c,
  ];

  int get _totalBytes => _runtime.components.fold(0, (sum, c) => sum + c.sizeBytes);

  /// Bytes of the whole pack already on disk (installed or partial).
  int get _bytesOnDisk => _runtime.components.fold(
    0,
    (sum, c) => sum + _runtime.downloadedBytes(c.kind).clamp(0, c.sizeBytes),
  );

  @override
  AiPackStatus status() {
    final installed = _missing.isEmpty;
    return AiPackStatus(
      totalBytes: _totalBytes,
      remainingBytes: installed ? 0 : (_totalBytes - _bytesOnDisk).clamp(0, _totalBytes),
      // Registered with the engine — downloaded bytes alone are not enough.
      isInstalled: installed,
      isLoaded: _runtime.components.any((c) => _runtime.isLoaded(c.kind)),
    );
  }

  @override
  Future<Result<void>> install({required void Function(double progress) onProgress}) async {
    final total = _totalBytes;
    _cancelRequested = false;
    try {
      for (final component in _missing) {
        if (_cancelRequested) throw const InstallCancelledException();
        _installing = component.kind;
        // Everything on disk except the component now downloading.
        final otherBytes = _bytesOnDisk - _runtime.downloadedBytes(component.kind);
        onProgress((otherBytes + _runtime.downloadedBytes(component.kind)) / total);
        await _runtime.install(
          component.kind,
          onProgress: (bytes) => onProgress((otherBytes + bytes) / total),
        );
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
