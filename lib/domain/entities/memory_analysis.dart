import 'package:equatable/equatable.dart';

/// A task found in captured text, waiting for the user to confirm it.
class SuggestedTask extends Equatable {
  const SuggestedTask({required this.title, this.dueAt, this.selected = true});

  final String title;
  final DateTime? dueAt;

  /// Whether the user wants this task created when the memory is saved.
  final bool selected;

  SuggestedTask toggled() => SuggestedTask(title: title, dueAt: dueAt, selected: !selected);

  @override
  List<Object?> get props => [title, dueAt, selected];
}

/// Who produced an analysis, so the UI can label it honestly.
enum AnalysisOrigin {
  /// The on-device language model.
  model,

  /// Deterministic offline rules.
  rules,

  /// AI suggestions are switched off; only trivial defaults.
  none,
}

/// What was understood about captured text. Only ever a suggestion: the
/// user reviews it before anything is saved.
class MemoryAnalysis extends Equatable {
  const MemoryAnalysis({
    required this.title,
    required this.summary,
    required this.category,
    required this.tags,
    required this.origin,
    this.tasks = const [],
    this.people = const [],
  });

  final String title;
  final String summary;
  final String category;
  final List<String> tags;
  final List<SuggestedTask> tasks;
  final List<String> people;
  final AnalysisOrigin origin;

  bool get byModel => origin == AnalysisOrigin.model;

  @override
  List<Object?> get props => [title, summary, category, tags, tasks, people, origin];
}
