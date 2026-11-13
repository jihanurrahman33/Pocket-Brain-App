import 'package:equatable/equatable.dart';

/// The on-device models Pocket Brain uses.
enum AiModelKind {
  /// Writes summaries, tags, tasks, answers and recaps.
  languageModel,

  /// Turns text into vectors for semantic search.
  embedder,
}

/// Where inference runs.
enum ComputeBackend {
  cpu('CPU'),
  gpu('GPU');

  const ComputeBackend(this.label);

  final String label;
}

/// Static facts about a downloadable model.
class AiModelInfo extends Equatable {
  const AiModelInfo({
    required this.kind,
    required this.name,
    required this.purpose,
    required this.sizeBytes,
  });

  final AiModelKind kind;
  final String name;
  final String purpose;
  final int sizeBytes;

  @override
  List<Object?> get props => [kind, name, purpose, sizeBytes];
}

/// Install state of one model as seen by the repository.
class AiModelStatus extends Equatable {
  const AiModelStatus({required this.info, required this.installed, required this.loaded});

  final AiModelInfo info;
  final bool installed;

  /// Resident in memory right now.
  final bool loaded;

  @override
  List<Object?> get props => [info, installed, loaded];
}
