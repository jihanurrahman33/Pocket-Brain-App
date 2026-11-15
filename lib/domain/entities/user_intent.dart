import 'package:equatable/equatable.dart';

import 'assistant.dart';
import 'task_item.dart';

/// Everything Ask Brain can be asked to do. The understanding step maps any
/// message, in any wording or language, onto exactly one of these; tested
/// code then carries it out. The model never changes data itself.
enum IntentType {
  createTask('create_task', 'Make it a task'),
  completeTask('complete_task', 'Mark a task done'),
  reopenTask('reopen_task', 'Reopen a task'),
  rescheduleTask('reschedule_task', 'Change a task’s date or time'),
  deleteTask('delete_task', 'Delete a task'),
  listTasks('list_tasks', 'Show my tasks'),
  saveNote('save_note', 'Save it as a note'),
  askMemory('ask_memory', 'Answer from my memories'),
  smallTalk('small_talk', 'Just chatting'),
  outOfScope('out_of_scope', 'Something else'),
  unclear('unclear', 'Not sure');

  const IntentType(this.wireName, this.label);

  /// The name used in model output and in the evaluation set.
  final String wireName;

  /// How the choice reads in "Not what I meant".
  final String label;

  static IntentType? fromWire(String? name) => values.where((t) => t.wireName == name).firstOrNull;

  /// Choices offered when the user corrects an answer.
  static const correctable = [
    createTask,
    completeTask,
    reopenTask,
    rescheduleTask,
    deleteTask,
    listTasks,
    saveNote,
    askMemory,
  ];
}

/// Where an intent came from, for evaluation and logs.
enum IntentSource { rules, model, correction, fallback }

/// One understood message: what the user wants plus the details ("slots").
class UserIntent extends Equatable {
  const UserIntent(
    this.type, {
    this.confidence = 1,
    this.title = '',
    this.date,
    this.time = '',
    this.taskRef = '',
    this.query = '',
    this.note = '',
    this.filter = '',
    this.source = IntentSource.rules,
  });

  final IntentType type;

  /// 0–1; low values are treated as [IntentType.unclear].
  final double confidence;

  /// The task to create, in a few words ("Sing a song").
  final String title;

  /// The day the user named, at midnight; null when none.
  final DateTime? date;

  /// A clock time "HH:MM" the user named, or empty.
  final String time;

  /// How the user referred to an existing task ("the report", "2", "it").
  final String taskRef;

  /// English search keywords, for questions about memories.
  final String query;

  /// Text to save, for notes.
  final String note;

  /// For task lists: open, overdue, done, today, tomorrow or empty.
  final String filter;
  final IntentSource source;

  UserIntent copyWith({
    IntentType? type,
    DateTime? Function()? date,
    IntentSource? source,
    double? confidence,
  }) => UserIntent(
    type ?? this.type,
    confidence: confidence ?? this.confidence,
    title: title,
    date: date != null ? date() : this.date,
    time: time,
    taskRef: taskRef,
    query: query,
    note: note,
    filter: filter,
    source: source ?? this.source,
  );

  @override
  List<Object?> get props => [type, confidence, title, date, time, taskRef, query, note, filter];

  @override
  String toString() =>
      'UserIntent(${type.wireName}, ${confidence.toStringAsFixed(2)}, title: $title, '
      'date: $date, time: $time, ref: $taskRef, query: $query, filter: $filter, $source)';
}

/// What the conversation already shows, so follow-ups resolve: "the second
/// one", "it", "make it 6 pm", "no, tomorrow".
class IntentContext extends Equatable {
  const IntentContext({this.recentTasks = const [], this.pendingProposal, this.previousQuestion});

  /// Tasks shown as cards in the last answer, in order.
  final List<TaskItem> recentTasks;

  /// A proposal from the last answer the user has not decided yet.
  final AssistantAction? pendingProposal;

  final String? previousQuestion;

  static const empty = IntentContext();

  @override
  List<Object?> get props => [recentTasks, pendingProposal, previousQuestion];
}

/// A message and the intent the user said it meant ("Not what I meant").
/// Kept on the device and shown to the model as examples.
class IntentExample extends Equatable {
  const IntentExample(this.text, this.type);

  final String text;
  final IntentType type;

  @override
  List<Object?> get props => [text, type];
}
