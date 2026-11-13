part of 'capture_bloc.dart';

sealed class CaptureEvent extends Equatable {
  const CaptureEvent();

  @override
  List<Object?> get props => [];
}

final class CaptureStarted extends CaptureEvent {
  const CaptureStarted();
}

/// The user finished typing or pasting; run analysis.
final class CaptureSubmitted extends CaptureEvent {
  const CaptureSubmitted(this.input);

  final CaptureInput input;

  @override
  List<Object?> get props => [input];
}

/// The user edited a suggestion on the review screen. Only non-null fields
/// change.
final class CaptureReviewEdited extends CaptureEvent {
  const CaptureReviewEdited({this.title, this.summary, this.category, this.tags, this.collection});

  final String? title;
  final String? summary;
  final String? category;
  final List<String>? tags;

  /// Wrapped so "no collection" can be distinguished from "unchanged".
  final ({String? id})? collection;

  CaptureReview apply(CaptureReview review) => review.withEdits(
    title: title,
    summary: summary,
    category: category,
    tags: tags,
    collection: collection,
  );

  @override
  List<Object?> get props => [title, summary, category, tags, collection];
}

final class CaptureTaskToggled extends CaptureEvent {
  const CaptureTaskToggled(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

final class CaptureConfirmed extends CaptureEvent {
  const CaptureConfirmed();
}

final class CaptureDiscarded extends CaptureEvent {
  const CaptureDiscarded();
}
