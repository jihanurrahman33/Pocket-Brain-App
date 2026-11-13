import '../../core/error/result.dart';
import '../entities/ai_model.dart';

/// Downloads, removes and manages the on-device models.
abstract interface class ModelRepository {
  List<AiModelInfo> get available;

  AiModelStatus status(AiModelKind kind);

  /// Downloads (or re-activates) a model.
  ///
  /// [onProgress] receives values in [0, 1]. Completes with a failure if
  /// the download fails or is cancelled via [cancelInstall].
  Future<Result<void>> install(
    AiModelKind kind, {
    required void Function(double progress) onProgress,
  });

  void cancelInstall(AiModelKind kind);

  Future<Result<void>> uninstall(AiModelKind kind);

  /// Frees memory; models reload on next use.
  Future<void> unloadAll();

  Future<void> useBackend(ComputeBackend backend);

  /// Bytes used by model files on disk.
  Future<int> storageBytes();
}
