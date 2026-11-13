import '../entities/task_item.dart';
import 'due_date_parser.dart';
import 'reminder_time_parser.dart';

/// What the user wants from an Ask Brain message, decided deterministically
/// before any retrieval or model call. A small model is unreliable at this
/// (it skipped tools, listed done tasks when asked to complete one), so
/// routing is explicit, tested rules.
sealed class AskIntent {
  const AskIntent();
}

/// "drink water done", "I finished the report", "mark X as complete".
final class CompleteTaskIntent extends AskIntent {
  const CompleteTaskIntent(this.matches, {this.alreadyDone = const []});

  /// Open tasks the message refers to, best match first (may be empty).
  final List<TaskItem> matches;

  /// Finished tasks the message refers to ("buy milk done" twice).
  final List<TaskItem> alreadyDone;
}

/// "What todos do I have?", "What's overdue?".
final class QueryTasksIntent extends AskIntent {
  const QueryTasksIntent(this.filter);

  /// One of `open`, `overdue`, `done`.
  final String filter;
}

/// "I want to sing a song tomorrow", "I need to call mum": a plan, offered
/// as a task the user confirms.
final class PlanTaskIntent extends AskIntent {
  const PlanTaskIntent(this.title);

  /// What to do, without the "I want to" and the day ("Sing a song").
  final String title;
}

/// Anything else: answered from memories (and the model's tools).
final class MemoryQuestionIntent extends AskIntent {
  const MemoryQuestionIntent();
}

abstract final class IntentRouter {
  static final _taskWords = RegExp(
    r'\b(to-?dos?|to do|tasks?|deadlines?|overdue|due|reminders?|kaj|kaaj|kajgulo)\b',
    caseSensitive: false,
  );
  static final _createWords = RegExp(
    r'\b(remind me|add|create|set (a |an )?(reminder|task)|new task|schedule|mone kor\w*)\b',
    caseSensitive: false,
  );
  static final _question = RegExp(
    r'(\?|^\s*(what|which|how many|show|list|any|do i|did i|have i|ki|koyta|kon)\b)',
    caseSensitive: false,
  );

  /// Words that say something *is* finished (not that it should be).
  static final _completion = RegExp(
    r'\b(done|finished|completed|did it|check(ed)? (it )?off|tick(ed)? (it )?off|'
    r'mark(ed)? .* (as )?(done|complete|completed|finished)|'
    r'(check|tick|complete) (the )?.+ (todo|task)|'
    r'korechi|kore felechi|kore fe?lsi|korsi|sesh hoyeche|shesh hoyeche|hoye geche|hoise)\b',
    caseSensitive: false,
  );

  /// Future or intention wording: "I need to finish…" is not "I finished".
  static final _intention = RegExp(
    r'\b(need to|have to|has to|must|will|going to|gonna|want to|should|plan to|'
    r"try to|remind|don't forget|later|tomorrow)\b",
    caseSensitive: false,
  );

  /// "I have drinked water", "I've called mum": past-tense statements that
  /// name an open task count as completion.
  static final _pastStatement = RegExp(
    r"^\s*i(?:'ve| have| had)?\s+(?:already\s+|just\s+)?"
    r'(?:\w+(?:ed|en|t)|drank|ate|wrote|paid|bought|went|sent|took|made|read|did|gave|'
    r'met|spoke|ran|swam|drove|got|brought|told|found|left|sold|won)\b',
    caseSensitive: false,
  );

  /// Irregular past tenses mapped to their base verb, for title matching.
  static const _irregular = {
    'drank': 'drink',
    'drunk': 'drink',
    'ate': 'eat',
    'eaten': 'eat',
    'wrote': 'write',
    'written': 'write',
    'paid': 'pay',
    'bought': 'buy',
    'went': 'go',
    'gone': 'go',
    'sent': 'send',
    'took': 'take',
    'taken': 'take',
    'made': 'make',
    'did': 'do',
    'gave': 'give',
    'given': 'give',
    'met': 'meet',
    'spoke': 'speak',
    'ran': 'run',
    'swam': 'swim',
    'drove': 'drive',
    'got': 'get',
    'brought': 'bring',
    'told': 'tell',
    'found': 'find',
    'left': 'leave',
    'sold': 'sell',
    'won': 'win',
  };

  /// Filler stripped before matching a message against task titles.
  static const _ignored = {
    'i',
    'im',
    'ive',
    'have',
    'had',
    'has',
    'the',
    'a',
    'an',
    'my',
    'is',
    'am',
    'are',
    'it',
    'that',
    'this',
    'with',
    'already',
    'just',
    'now',
    'done',
    'finished',
    'finish',
    'complete',
    'completed',
    'check',
    'checked',
    'tick',
    'ticked',
    'off',
    'mark',
    'marked',
    'as',
    'todo',
    'todos',
    'task',
    'tasks',
    'to',
    'do',
    'please',
    'and',
    'of',
    'for',
    'korechi',
    'sesh',
    'shesh',
    'korsi',
    'kaj',
    'ta',
    'ti',
  };

  /// "I want to …", "I'm going to …", "tomorrow I have to …".
  static final _plan = RegExp(
    r'^\s*(?:(?:today|tonight|tomorrow|on \w+day|\w+day)\s*,?\s+)?'
    r"(?:i'?ll|(?:i|i'm|im|i am)\s+(?:really\s+|also\s+)?"
    r'(?:want to|wanna|need to|have to|has to|got to|gotta|must|should|will|'
    r'am going to|going to|gonna|plan to|would like to|intend to))\s+(.+)$',
    caseSensitive: false,
  );

  /// Wanting to *know* something is a question, not a plan.
  static final _notAPlan = RegExp(
    r'^(know|see|find|ask|check|understand|remember|recall|look up|search|learn what|'
    r'be|feel|die|sleep now)\b',
    caseSensitive: false,
  );

  static const _shortMessageWords = 3;
  static const _maxPlanTitle = 80;

  /// Minimum share of a task's title words found in the message.
  static const matchThreshold = 0.6;

  static AskIntent classify(String message, List<TaskItem> openTasks) {
    final text = message.trim();
    final isQuestion = _question.hasMatch(text);
    final matches = matchTasks(text, openTasks);
    final finished = matchTasks(text, openTasks, done: true);

    final mentionsTasks = _taskWords.hasMatch(text);
    final saysDone =
        _completion.hasMatch(text) ||
        (_pastStatement.hasMatch(text) && (matches.isNotEmpty || finished.isNotEmpty));
    final completes =
        saysDone &&
        !isQuestion &&
        !_createWords.hasMatch(text) &&
        !_intention.hasMatch(text) &&
        // "I'm done with Atomic Habits" (no task named, no task words) is a
        // statement about life, not a task command.
        (matches.isNotEmpty || finished.isNotEmpty || mentionsTasks);
    if (completes) {
      return CompleteTaskIntent(matches, alreadyDone: matches.isEmpty ? finished : const []);
    }

    // A question about tasks, or a bare "my todos" / "tasks".
    final short = text.split(RegExp(r'\s+')).length <= _shortMessageWords;
    if (mentionsTasks && !_createWords.hasMatch(text) && (isQuestion || short)) {
      return QueryTasksIntent(_filterFor(text));
    }

    // "Remind me…" / "add a task…" stay with the model, which fills in
    // reminder details; a plain plan becomes a proposed task here.
    if (!isQuestion && !_createWords.hasMatch(text)) {
      if (planTitle(text) case final title?) return PlanTaskIntent(title);
    }
    return const MemoryQuestionIntent();
  }

  /// The task in a plan statement, or null when [text] is not one.
  static String? planTitle(String text) {
    final what = _plan.firstMatch(text)?[1];
    if (what == null || _notAPlan.hasMatch(what.trim())) return null;
    final title = what
        .replaceAll(DueDateParser.phrase, ' ')
        .replaceAll(ReminderTimeParser.phrases, ' ')
        .replaceAll(RegExp(r'\b(please|pls)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s,]+|[\s,.!]+$'), '')
        .trim();
    if (title.isEmpty || title.split(' ').length > 12) return null;
    final capped = title.length > _maxPlanTitle ? title.substring(0, _maxPlanTitle) : title;
    return capped[0].toUpperCase() + capped.substring(1);
  }

  static String _filterFor(String text) {
    final q = text.toLowerCase();
    if (q.contains('overdue') || q.contains('late')) return 'overdue';
    // Only questions *about* finished tasks list them, e.g. "what have I done?"
    if (RegExp(r'\b(what|which|how many)\b.*\b(done|completed|finished)\b').hasMatch(q)) {
      return 'done';
    }
    return 'open';
  }

  /// Open tasks whose title the message mentions, best first. Tolerates
  /// verb forms and typos ("drinked" ~ "drink") by matching word stems.
  static List<TaskItem> matchTasks(String message, List<TaskItem> tasks, {bool done = false}) {
    final words = _words(message);
    if (words.isEmpty) return const [];
    final scored = <(TaskItem, double)>[];
    for (final task in tasks.where((t) => t.isDone == done)) {
      final titleWords = _words(task.title);
      if (titleWords.isEmpty) continue;
      final hits = titleWords.where((t) => words.any((w) => _sameStem(t, w))).length;
      final score = hits / titleWords.length;
      if (score >= matchThreshold) scored.add((task, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    if (scored.isEmpty) return const [];
    // Keep only the best-scoring tasks; weaker partial matches are noise.
    final best = scored.first.$2;
    return [
      for (final (task, score) in scored)
        if (score == best) task,
    ];
  }

  static List<String> _words(String text) => [
    for (final w in RegExp(r"[a-z0-9']+").allMatches(text.toLowerCase()).map((m) => m[0]!))
      if (!_ignored.contains(w.replaceAll("'", '')) && w.length > 1) w,
  ];

  /// "drink" ~ "drinked" ~ "drinking", "call" ~ "called", "email" ~ "emails".
  static bool _sameStem(String a, String b) {
    if (a == b) return true;
    final sa = _stem(a), sb = _stem(b);
    if (sa == sb) return true;
    const minPrefix = 4;
    final shorter = sa.length <= sb.length ? sa : sb;
    final longer = sa.length <= sb.length ? sb : sa;
    return shorter.length >= minPrefix && longer.startsWith(shorter);
  }

  static String _stem(String word) {
    if (_irregular[word] case final base?) return base;
    for (final suffix in ['ing', 'ed', 'es', 's']) {
      if (word.length > suffix.length + 2 && word.endsWith(suffix)) {
        return word.substring(0, word.length - suffix.length);
      }
    }
    return word;
  }
}
