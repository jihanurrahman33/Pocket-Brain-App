import 'package:equatable/equatable.dart';

import 'memory.dart';
import 'memory_analysis.dart';
import 'search.dart';

/// An image or recording picked on the capture screen, still at its
/// temporary location.
class CapturedMedia extends Equatable {
  const CapturedMedia({required this.path, required this.kind});

  final String path;
  final AttachmentKind kind;

  @override
  List<Object?> get props => [path, kind];
}

/// Raw input from the capture screen.
class CaptureInput extends Equatable {
  const CaptureInput({required this.text, required this.source, this.url, this.media});

  final String text;
  final MemorySource source;
  final String? url;

  /// An image to read or a recording to transcribe.
  final CapturedMedia? media;

  bool get isEmpty => text.trim().isEmpty && (url == null || url!.trim().isEmpty) && media == null;

  @override
  List<Object?> get props => [text, source, url, media];
}

/// What the AI read from an image or heard in a recording.
class MediaReading extends Equatable {
  const MediaReading({this.extractedText = '', this.description = ''});

  /// Text visible in an image, or the transcript of a recording.
  final String extractedText;

  /// A short description of an image (empty for recordings).
  final String description;

  bool get isEmpty => extractedText.trim().isEmpty && description.trim().isEmpty;

  @override
  List<Object?> get props => [extractedText, description];
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
    this.media,
    this.reading,
  });

  /// Similarity at which an existing memory is treated as a duplicate.
  static const duplicateThreshold = 0.9;

  /// The user's text, plus readable page text for links.
  final String content;
  final MemorySource source;
  final String? url;
  final MemoryAnalysis analysis;
  final List<ScoredMemory> similar;

  /// The picked image or recording, kept with the memory on save.
  final CapturedMedia? media;

  /// What the AI read or heard; null when there was no media or no AI.
  final MediaReading? reading;

  ScoredMemory? get likelyDuplicate =>
      similar.where((s) => s.score >= duplicateThreshold).firstOrNull;

  @override
  List<Object?> get props => [content, source, url, analysis, similar, media, reading];
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
    this.media,
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

  /// Copied into the app's storage and attached to the memory.
  final CapturedMedia? media;

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
    media,
  ];
}
