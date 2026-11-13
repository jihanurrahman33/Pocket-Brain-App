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
    required this.isLoaded,
  });

  /// Download size of the complete pack.
  final int totalBytes;

  /// Bytes still to download; 0 when fully installed.
  final int remainingBytes;

  /// Some part of the AI is resident in memory right now.
  final bool isLoaded;

  bool get isInstalled => remainingBytes == 0;

  /// Some, but not all, components are present (e.g. an interrupted setup).
  bool get isPartiallyInstalled => remainingBytes > 0 && remainingBytes < totalBytes;

  @override
  List<Object?> get props => [totalBytes, remainingBytes, isLoaded];
}
