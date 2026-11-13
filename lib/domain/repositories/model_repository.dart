import '../../core/error/result.dart';
import '../entities/ai_model.dart';

/// Installs and manages the on-device AI pack as a single unit.
abstract interface class ModelRepository {
  AiPackStatus status();

  /// Downloads every missing part of the pack, one after another.
  ///
  /// [onProgress] receives overall progress in [0, 1] across all parts.
  /// Completes with a failure if a download fails or [cancelInstall] is
  /// called; parts that finished stay installed, so a retry resumes.
  Future<Result<void>> install({required void Function(double progress) onProgress});

  void cancelInstall();

  /// Removes every part of the pack.
  Future<Result<void>> uninstall();

  /// Frees memory; the AI reloads on next use.
  Future<void> unloadAll();

  Future<void> useBackend(ComputeBackend backend);

  /// Selects which AI the pack contains. If it is not on the device yet,
  /// [status] reports the pack as not installed and [install] downloads it;
  /// the previous AI keeps working until the new one is ready, then it is
  /// removed.
  Future<void> useQuality(AiQuality quality);

  /// Bytes used by AI files on disk.
  Future<int> storageBytes();
}
