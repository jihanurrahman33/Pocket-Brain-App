import 'package:equatable/equatable.dart';

import 'memory.dart';
import 'memory_analysis.dart';
import 'search.dart';

/// Raw input from the capture screen.
class CaptureInput extends Equatable {
  const CaptureInput({required this.text, required this.source, this.url});

  final String text;
  final MemorySource source;
  final String? url;

  bool get isEmpty => text.trim().isEmpty && (url == null || url!.trim().isEmpty);

  @override
  List<Object?> get props => [text, source, url];
}

/// The result of analysing a capture: the content to save, AI suggestions
/// and already-saved memories on the same topic.
class CaptureDraft extends Equatable {
  const CaptureDraft({
    required this.content,
    required this.source,
    required this.analysis,
    this.url,
    this.similar = const [],
  });

  /// Similarity at which an existing memory is treated as a duplicate.
  static const duplicateThreshold = 0.9;

  /// The user's text, plus readable page text for links.
  final String content;
  final MemorySource source;
  final String? url;
  final MemoryAnalysis analysis;
  final List<ScoredMemory> similar;

  ScoredMemory? get likelyDuplicate =>
      similar.where((s) => s.score >= duplicateThreshold).firstOrNull;

  @override
  List<Object?> get props => [content, source, url, analysis, similar];
}

/// Everything needed to persist a reviewed capture.
class SaveCaptureRequest extends Equatable {
  const SaveCaptureRequest({
    required this.content,
    required this.source,
    required this.title,
    required this.summary,
    required this.category,
    required this.tags,
    required this.tasks,
    required this.acceptedAiAsIs,
    this.url,
    this.collectionId,
  });

  final String content;
  final MemorySource source;
  final String? url;
  final String title;
  final String summary;
  final String category;
  final List<String> tags;
  final String? collectionId;

  /// Only selected tasks are created.
  final List<SuggestedTask> tasks;

  /// True when model suggestions were saved without user edits.
  final bool acceptedAiAsIs;

  @override
  List<Object?> get props => [
    content,
    source,
    url,
    title,
    summary,
    category,
    tags,
    collectionId,
    tasks,
    acceptedAiAsIs,
  ];
}
