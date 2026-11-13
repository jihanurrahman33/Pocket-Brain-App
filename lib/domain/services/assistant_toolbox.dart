import '../../core/utils/clock.dart';
import '../../core/utils/id_generator.dart';
import '../entities/assistant.dart';
import '../repositories/task_repository.dart';

/// The tools Ask Brain's model may call during one answer.
///
/// Read-only tools run immediately. Tools that would change data never do:
/// they record an [AssistantAction] proposal that the user must confirm, and
/// tell the model so. A new toolbox is used for every answer.
final class AssistantToolbox {
  AssistantToolbox({required TaskRepository tasks, required IdGenerator ids, required Clock clock})
    : _tasks = tasks,
      _ids = ids,
      _clock = clock;

  final TaskRepository _tasks;
  final IdGenerator _ids;
  final Clock _clock;

  static const createTask = 'create_task';
  static const saveMemory = 'save_memory';
  static const listTasks = 'list_tasks';

  static const _maxListedTasks = 15;
  static const _maxTitleLength = 120;
  static const _maxNoteLength = 4000;
  static final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static const tools = [
    AssistantTool(
      name: createTask,
      description:
          'Propose a task or reminder for the user, e.g. when they say "remind me to…" '
          'or "add a task…". The user confirms before it is created.',
      parameters: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'description': 'What needs doing, short and clear.'},
          'due_date': {
            'type': 'string',
            'description': 'Deadline as YYYY-MM-DD, or an empty string if none was given.',
          },
          'remind': {'type': 'boolean', 'description': 'True when the user asked to be reminded.'},
        },
        'required': ['title', 'due_date', 'remind'],
      },
    ),
    AssistantTool(
      name: saveMemory,
      description:
          'Propose saving a new note when the user asks you to remember something '
          '("remember that…", "note that…"). The user confirms before it is saved.',
      parameters: {
        'type': 'object',
        'properties': {
          'text': {'type': 'string', 'description': 'The note to save, in the user\'s words.'},
        },
        'required': ['text'],
      },
    ),
    AssistantTool(
      name: listTasks,
      description: "List the user's tasks to answer questions about to-dos and deadlines.",
      parameters: {
        'type': 'object',
        'properties': {
          'filter': {
            'type': 'string',
            'enum': ['open', 'overdue', 'done', 'all'],
            'description': 'Which tasks to list.',
          },
        },
        'required': ['filter'],
      },
    ),
  ];

  final _proposals = <AssistantAction>[];
  bool _readUserData = false;

  /// Changes proposed during this answer, in order.
  List<AssistantAction> get proposals => List.unmodifiable(_proposals);

  /// True when the answer is based on data a tool returned (e.g. tasks),
  /// so it is grounded even without matching memories.
  bool get readUserData => _readUserData;

  /// Runs one call. Never throws: problems are returned for the model to read.
  Future<Map<String, Object?>> run(String name, Map<String, Object?> args) async {
    try {
      return switch (name) {
        createTask => _proposeTask(args),
        saveMemory => _proposeNote(args),
        listTasks => await _listTasks(args),
        _ => {'error': 'Unknown tool "$name".'},
      };
    } on Object catch (e) {
      return {'error': 'The tool failed: $e'};
    }
  }

  Map<String, Object?> _proposeTask(Map<String, Object?> args) {
    final title = _string(args['title']);
    if (title.isEmpty) return {'error': 'A task needs a title.'};
    final due = _string(args['due_date']);
    if (due.isNotEmpty && (!_isoDate.hasMatch(due) || DateTime.tryParse(due) == null)) {
      return {'error': 'due_date must be YYYY-MM-DD or empty.'};
    }
    final reminder = args['remind'] == true ? _reminderTime(DateTime.tryParse(due)) : null;
    return _propose(AssistantActionType.createTask, {
      'title': title.length > _maxTitleLength ? title.substring(0, _maxTitleLength) : title,
      'due': due,
      if (reminder != null) 'reminder': reminder.toIso8601String(),
    });
  }

  Map<String, Object?> _proposeNote(Map<String, Object?> args) {
    final text = _string(args['text']);
    if (text.isEmpty) return {'error': 'Nothing to save.'};
    return _propose(AssistantActionType.saveMemory, {
      'text': text.length > _maxNoteLength ? text.substring(0, _maxNoteLength) : text,
    });
  }

  Map<String, Object?> _propose(AssistantActionType type, Map<String, String> args) {
    _proposals.add(AssistantAction(id: _ids.next(), type: type, args: args));
    return {
      'status': 'waiting_for_user_confirmation',
      'note': 'Tell the user you have prepared this and they can confirm it below.',
    };
  }

  Future<Map<String, Object?>> _listTasks(Map<String, Object?> args) async {
    _readUserData = true;
    final now = _clock.now();
    final all = await _tasks.getAll();
    final selected = switch (_string(args['filter'])) {
      'overdue' => all.where((t) => t.isOverdue(now)),
      'done' => all.where((t) => t.isDone),
      'all' => all,
      _ => all.where((t) => !t.isDone),
    };
    return {
      'today': _date(now),
      'tasks': [
        for (final t in selected.take(_maxListedTasks))
          {
            'title': t.title,
            'due': t.dueAt == null ? '' : _date(t.dueAt!),
            'done': t.isDone,
            'overdue': t.isOverdue(now),
          },
      ],
    };
  }

  /// Reminders fire at [reminderHour] on the due date, or tomorrow when
  /// no date was given (or the date has passed).
  static const reminderHour = 9;

  DateTime _reminderTime(DateTime? due) {
    final now = _clock.now();
    final day = due ?? now.add(const Duration(days: 1));
    final at = DateTime(day.year, day.month, day.day, reminderHour);
    return at.isAfter(now) ? at : DateTime(now.year, now.month, now.day + 1, reminderHour);
  }

  static String _string(Object? value) => value is String ? value.trim() : '';

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
