part of 'model_bloc.dart';

/// The Pocket Brain AI pack as shown in the UI.
class ModelState extends Equatable {
  const ModelState({
    this.pack,
    this.progress,
    this.backend = ComputeBackend.cpu,
    this.quality = AiQuality.standard,
    this.qualities = const [AiQuality.standard],
    this.storageBytes = 0,
    this.failure,
  });

  /// Null until the first refresh.
  final AiPackStatus? pack;

  /// Overall download progress in [0, 1]; null when not downloading.
  final double? progress;
  final ComputeBackend backend;
  final AiQuality quality;

  /// Qualities this device can run; more than one means the user may choose.
  final List<AiQuality> qualities;
  final int storageBytes;

  /// Why the last download or removal failed.
  final Failure? failure;

  bool get isDownloading => progress != null;

  bool get isReady => pack?.isInstalled ?? false;

  ModelState downloading(double progress) => ModelState(
    pack: pack,
    progress: progress,
    backend: backend,
    quality: quality,
    qualities: qualities,
    storageBytes: storageBytes,
  );

  @override
  List<Object?> get props => [pack, progress, backend, quality, qualities, storageBytes, failure];
}
