import 'package:equatable/equatable.dart';

/// Where inference runs.
enum ComputeBackend {
  cpu('CPU'),
  gpu('GPU');

  const ComputeBackend(this.label);

  final String label;
}

/// The on-device AI as the user sees it: one installable "Pocket Brain AI"
/// pack. Which models it contains is a data-layer detail, so models can be
/// swapped without any change to the domain or the UI.
class AiPackStatus extends Equatable {
  const AiPackStatus({
    required this.totalBytes,
    required this.remainingBytes,
    required this.isInstalled,
    required this.isLoaded,
  });

  /// Download size of the complete pack.
  final int totalBytes;

  /// Bytes still to download. Can be 0 while [isInstalled] is false: a file
  /// that finished downloading but was not yet registered (e.g. the app was
  /// closed while verifying it).
  final int remainingBytes;

  /// Every component is downloaded *and* registered with the engine.
  final bool isInstalled;

  /// Some part of the AI is resident in memory right now.
  final bool isLoaded;

  /// Share of the pack already on disk, in [0, 1].
  double get downloadedFraction => totalBytes == 0 ? 1 : 1 - remainingBytes / totalBytes;

  /// Setup started but did not finish (e.g. it was interrupted).
  bool get isPartiallyInstalled => !isInstalled && remainingBytes < totalBytes;

  @override
  List<Object?> get props => [totalBytes, remainingBytes, isInstalled, isLoaded];
}
