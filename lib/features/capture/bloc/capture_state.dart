part of 'capture_bloc.dart';

/// The capture flow as a state machine (State pattern via sealed classes).
sealed class CaptureState extends Equatable {
  const CaptureState();

  @override
  List<Object?> get props => [];
}

/// Typing. After a failed submit, [failure] says why and [input] holds
/// what the user typed so it can be restored.
final class CaptureEditing extends CaptureState {
  const CaptureEditing({this.failure, this.input});

  final Failure? failure;
  final CaptureInput? input;

  @override
  List<Object?> get props => [failure, input];
}

/// Recording a voice note.
final class CaptureRecording extends CaptureState {
  const CaptureRecording({required this.startedAt, this.note = ''});

  final DateTime startedAt;
  final String note;

  @override
  List<Object?> get props => [startedAt, note];
}

final class CaptureAnalyzing extends CaptureState {
  const CaptureAnalyzing(this.input);

  final CaptureInput input;

  @override
  List<Object?> get props => [input];
}

final class CaptureReviewing extends CaptureState {
  const CaptureReviewing(this.review, {this.isSaving = false, this.failure});

  final CaptureReview review;
  final bool isSaving;
  final Failure? failure;

  @override
  List<Object?> get props => [review, isSaving, failure];
}

final class CaptureSaved extends CaptureState {
  const CaptureSaved(this.memoryId);

  final String memoryId;

  @override
  List<Object?> get props => [memoryId];
}

/// The editable review form, seeded from the AI's [CaptureDraft].
class CaptureReview extends Equatable {
  const CaptureReview({
    required this.draft,
    required this.title,
    required this.summary,
    required this.category,
    required this.tags,
    required this.tasks,
    required this.collections,
    this.collectionId,
    this.edited = false,
  });

  factory CaptureReview.fromDraft(CaptureDraft draft, List<MemoryCollection> collections) =>
      CaptureReview(
        draft: draft,
        title: draft.analysis.title,
        summary: draft.analysis.summary,
        category: draft.analysis.category,
        tags: draft.analysis.tags,
        tasks: draft.analysis.tasks,
        collections: collections,
      );

  final CaptureDraft draft;
  final String title;
  final String summary;
  final String category;
  final List<String> tags;
  final List<SuggestedTask> tasks;
  final String? collectionId;
  final List<MemoryCollection> collections;

  /// Whether the user changed any suggestion.
  final bool edited;

  MemoryAnalysis get analysis => draft.analysis;

  /// Default categories plus the suggested one if it is custom.
  List<String> get categoryOptions => {...MemoryCategories.defaults, category}.toList();

  CaptureReview withEdits({
    String? title,
    String? summary,
    String? category,
    List<String>? tags,
    ({String? id})? collection,
  }) => CaptureReview(
    draft: draft,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    tasks: tasks,
    collections: collections,
    collectionId: collection != null ? collection.id : collectionId,
    edited: true,
  );

  CaptureReview toggleTask(int index) => CaptureReview(
    draft: draft,
    title: title,
    summary: summary,
    category: category,
    tags: tags,
    tasks: [for (final (i, t) in tasks.indexed) i == index ? t.toggled() : t],
    collections: collections,
    collectionId: collectionId,
    edited: edited,
  );

  SaveCaptureRequest toRequest() => SaveCaptureRequest(
    content: draft.content,
    source: draft.source,
    url: draft.url,
    title: title,
    summary: summary,
    category: category,
    tags: tags,
    tasks: tasks,
    collectionId: collectionId,
    acceptedAiAsIs: analysis.byModel && !edited,
    media: draft.media,
  );

  @override
  List<Object?> get props => [
    draft,
    title,
    summary,
    category,
    tags,
    tasks,
    collectionId,
    collections,
    edited,
  ];
}
