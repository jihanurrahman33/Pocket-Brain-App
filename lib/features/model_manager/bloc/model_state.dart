part of 'model_bloc.dart';

/// The Pocket Brain AI pack as shown in the UI.
class ModelState extends Equatable {
  const ModelState({
    this.pack,
    this.progress,
    this.backend = ComputeBackend.cpu,
    this.storageBytes = 0,
    this.failure,
  });

  /// Null until the first refresh.
  final AiPackStatus? pack;

  /// Overall download progress in [0, 1]; null when not downloading.
  final double? progress;
  final ComputeBackend backend;
  final int storageBytes;

  /// Why the last download or removal failed.
  final Failure? failure;

  bool get isDownloading => progress != null;

  bool get isReady => pack?.isInstalled ?? false;

  ModelState downloading(double progress) =>
      ModelState(pack: pack, progress: progress, backend: backend, storageBytes: storageBytes);

  @override
  List<Object?> get props => [pack, progress, backend, storageBytes, failure];
}
