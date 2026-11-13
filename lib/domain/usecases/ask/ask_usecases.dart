import '../../../core/error/failure.dart';
import '../../../core/error/guard.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/text_utils.dart';
import '../../entities/ask.dart';
import '../../entities/assistant.dart';
import '../../entities/capture.dart';
import '../../entities/conversation.dart';
import '../../entities/memory.dart';
import '../../entities/search.dart';
import '../../entities/task_item.dart';
import '../../repositories/conversation_repository.dart';
import '../../repositories/memory_repository.dart';
import '../../repositories/task_repository.dart';
import '../../services/ai_services.dart';
import '../../services/assistant_guardrails.dart';
import '../../services/assistant_toolbox.dart';
import '../../services/language_detector.dart';
import '../../services/task_summary.dart';
import '../capture/capture_usecases.dart';
import '../search/search_usecases.dart';
import '../tasks/task_usecases.dart';

typedef SourceQuery = ({String question, String? collectionId});

/// Picks the memories an answer may use. Only memories above a relevance
/// threshold qualify, so weak matches never become "sources".
final class RetrieveAnswerSources implements UseCase<List<Memory>, SourceQuery> {
  const RetrieveAnswerSources(this._search);

  final SearchMemories _search;

  static const maxSources = 5;
  static const relevanceThreshold = 0.28;

  @override
  Future<List<Memory>> call(SourceQuery query) async {
    final result = await _search(
      SearchQuery(
        text: query.question,
        filters: SearchFilters(collectionId: query.collectionId),
        limit: maxSources,
      ),
    );
    return [
      for (final r in result.valueOrNull ?? const <ScoredMemory>[])
        if (r.score >= relevanceThreshold) r.memory,
    ];
  }
}

/// Answers a question from the user's memories only, streaming progress.
///
/// Rules: no relevant memory → the fixed "couldn't find" reply without
/// calling the model; no model → point to the sources; otherwise a grounded,
/// cited answer. Every turn is persisted.
final class AskBrain implements StreamUseCase<AskProgress, AskRequest> {
  AskBrain({
    required ConversationRepository conversations,
    required RetrieveAnswerSources retrieveSources,
    required AnswerGenerator generator,
    required QueryRewriter rewriter,
    required TaskRepository tasks,
    required IdGenerator ids,
    required Clock clock,
  }) : _conversations = conversations,
       _retrieveSources = retrieveSources,
       _generator = generator,
       _rewriter = rewriter,
       _tasks = tasks,
       _ids = ids,
       _clock = clock;

  final ConversationRepository _conversations;
  final RetrieveAnswerSources _retrieveSources;
  final AnswerGenerator _generator;
  final QueryRewriter _rewriter;
  final TaskRepository _tasks;
  final IdGenerator _ids;
  final Clock _clock;

  /// Shown when the model only proposed actions and wrote no answer text.
  static const actionsOnlyReply = "I've prepared this for you. Confirm it below.";

  static const _titleLength = 48;

  /// Short follow-ups ("tell me more") retrieve better with the prior question.
  static const _minStandaloneTerms = 3;

  @override
  Stream<AskProgress> call(AskRequest request) async* {
    final question = AssistantGuardrails.prepareQuestion(request.question);
    if (question.isEmpty) return;

    var conversation = request.conversation;
    if (conversation == null) {
      conversation = Conversation(
        id: _ids.next(),
        title: TextUtils.truncate(question, _titleLength),
        collectionId: request.collectionId,
        createdAt: _clock.now(),
      );
      await _conversations.save(conversation);
      yield AskConversationStarted(conversation);
    }

    if (request.isRegeneration) {
      // The question is already stored; only the old answer goes.
      if (request.staleAnswerId case final stale?) await _conversations.deleteMessage(stale);
    } else {
      final asked = _message(conversation.id, ChatRole.user, question);
      await _conversations.saveMessage(asked);
      yield AskQuestionRecorded(asked);
    }

    // Fixed, reliable replies for crisis messages and for questions about
    // the assistant itself; these never go to retrieval or the model.
    final fixedReply =
        AssistantGuardrails.safetyReply(question) ??
        AssistantGuardrails.conversationalReply(question);
    if (fixedReply != null) {
      final reply = _message(conversation.id, ChatRole.assistant, fixedReply);
      await _conversations.saveMessage(reply);
      yield AskAnswerCompleted(reply);
      return;
    }

    final sources = await _findSources(question, request.history, conversation.collectionId);
    yield AskSourcesFound(sources);

    final toolbox = AssistantToolbox(tasks: _tasks, ids: _ids, clock: _clock, question: question);
    // Deterministic routing: task questions get real task data up front.
    final preloaded = AssistantGuardrails.asksAboutTasks(question)
        ? await toolbox.preloadTasks(AssistantGuardrails.taskFilterFor(question))
        : null;
    var snapshot = '';
    await for (final text in _answerStream(
      question,
      sources,
      request.history,
      toolbox,
      preloaded,
    )) {
      if (request.isStopRequested()) break;
      snapshot = text;
      yield AskAnswerUpdated(snapshot);
    }

    if (toolbox.listedTasks.isNotEmpty) yield AskTasksFound(toolbox.listedTasks);

    final answer = _finalAnswer(
      conversation.id,
      AssistantGuardrails.cleanAnswer(snapshot, sourceCount: sources.length),
      sources,
      toolbox,
    );
    await _conversations.saveMessage(answer);
    yield AskAnswerCompleted(answer);
  }

  /// Retrieval, with a second try using AI-rewritten English search terms
  /// when the question's own words match nothing (other languages, Bangla
  /// in English letters, vague phrasing).
  Future<List<Memory>> _findSources(
    String question,
    List<ChatMessage> history,
    String? collectionId,
  ) async {
    final text = _retrievalText(question, history);
    final direct = await _retrieveSources((question: text, collectionId: collectionId));
    if (direct.isNotEmpty || !_rewriter.isAvailable) return direct;
    final rewritten = await _rewriter.toSearchQuery(text);
    if (rewritten == null || rewritten.trim().isEmpty) return direct;
    return _retrieveSources((question: rewritten, collectionId: collectionId));
  }

  Stream<String> _answerStream(
    String question,
    List<Memory> sources,
    List<ChatMessage> history,
    AssistantToolbox toolbox,
    List<TaskItem>? preloadedTasks,
  ) {
    // Task questions are answered by the app: the cards show the tasks and
    // the summary is computed, so it is instant and always correct.
    if (preloadedTasks != null) {
      return Stream.value(
        TaskSummary.describe(
          preloadedTasks,
          now: _clock.now(),
          language: LanguageDetector.detect(question),
        ),
      );
    }
    if (!_generator.isAvailable) {
      return Stream.value(sources.isEmpty ? AskReplies.notFound : AskReplies.modelMissing);
    }
    return _generator.generate(
      AnswerPrompt(
        question: question,
        sources: sources,
        history: history,
        today: _clock.now(),
        language: LanguageDetector.detect(question),
        tasks: preloadedTasks,
      ),
      toolbox: toolbox,
    );
  }

  /// Applies the grounding rule: an answer must rest on retrieved memories
  /// or on data a tool returned. Otherwise it is replaced with the fixed
  /// "couldn't find" reply, whatever the model wrote.
  ChatMessage _finalAnswer(
    String conversationId,
    String text,
    List<Memory> sources,
    AssistantToolbox toolbox,
  ) {
    final proposals = toolbox.proposals;
    final hasEvidence = sources.isNotEmpty || toolbox.readUserData;
    final String reply;
    if (!hasEvidence && proposals.isEmpty) {
      reply = AskReplies.notFound;
    } else if (text.isEmpty) {
      reply = proposals.isNotEmpty ? actionsOnlyReply : AskReplies.notFound;
    } else {
      reply = text;
    }
    // A partial answer that cites real memories is grounded; only the bare
    // fixed sentence means nothing was found.
    final nothingFound = reply.trim() == AskReplies.notFound;
    final cites = sources.isNotEmpty && !nothingFound;
    return _message(
      conversationId,
      ChatRole.assistant,
      reply,
      sourceIds: cites ? [for (final m in sources) m.id] : const [],
      grounded: hasEvidence && !nothingFound,
      actions: proposals,
      taskIds: [for (final t in toolbox.listedTasks) t.id],
    );
  }

  static String _retrievalText(String question, List<ChatMessage> history) {
    if (TextUtils.tokenize(question).length >= _minStandaloneTerms) return question;
    final previous = history.where((m) => m.isUser).lastOrNull;
    return previous == null ? question : '${previous.text} $question';
  }

  ChatMessage _message(
    String conversationId,
    ChatRole role,
    String text, {
    List<String> sourceIds = const [],
    bool grounded = true,
    List<AssistantAction> actions = const [],
    List<String> taskIds = const [],
  }) => ChatMessage(
    id: _ids.next(),
    conversationId: conversationId,
    role: role,
    text: text,
    sourceIds: sourceIds,
    grounded: grounded,
    actions: actions,
    taskIds: taskIds,
    createdAt: _clock.now(),
  );
}

final class GetConversations implements UseCase<Result<List<Conversation>>, NoParams> {
  const GetConversations(this._conversations, this._logger);

  final ConversationRepository _conversations;
  final AppLogger _logger;

  @override
  Future<Result<List<Conversation>>> call(NoParams _) =>
      guard(_logger, 'Load conversations', _conversations.getAll);
}

/// A conversation's messages and the memories they cite.
/// A conversation's messages with the memories and tasks they reference.
/// Deleted tasks or memories are simply left out.
typedef ConversationTranscript = ({
  List<ChatMessage> messages,
  Map<String, Memory> sources,
  Map<String, TaskItem> tasks,
});

final class OpenConversation implements UseCase<Result<ConversationTranscript>, String> {
  const OpenConversation(this._conversations, this._memories, this._tasks, this._logger);

  final ConversationRepository _conversations;
  final MemoryRepository _memories;
  final TaskRepository _tasks;
  final AppLogger _logger;

  @override
  Future<Result<ConversationTranscript>> call(String id) =>
      guard(_logger, 'Open conversation', () async {
        final messages = await _conversations.messages(id);
        final memoryIds = {for (final m in messages) ...m.sourceIds}.toList();
        final sources = await _memories.getByIds(memoryIds);
        final taskIds = {for (final m in messages) ...m.taskIds};
        final tasks = taskIds.isEmpty ? const <TaskItem>[] : await _tasks.getAll();
        return (
          messages: messages,
          sources: {for (final m in sources) m.id: m},
          tasks: {
            for (final t in tasks)
              if (taskIds.contains(t.id)) t.id: t,
          },
        );
      });
}

final class DeleteConversation implements UseCase<Result<void>, String> {
  const DeleteConversation(this._conversations, this._logger);

  final ConversationRepository _conversations;
  final AppLogger _logger;

  @override
  Future<Result<void>> call(String id) =>
      guard(_logger, 'Delete conversation', () => _conversations.delete(id));
}

/// Prompt ideas based on what the user actually saved.
final class GetSuggestedQuestions implements UseCase<List<String>, NoParams> {
  const GetSuggestedQuestions(this._memories);

  final MemoryRepository _memories;

  static const _sampleSize = 20;
  static const _maxSuggestions = 4;
  static const starterQuestions = [
    'What did I save this week?',
    'What books did I want to read?',
    'Show me my business ideas',
  ];

  @override
  Future<List<String>> call(NoParams _) async {
    final recent = await _memories.query(const MemoryQuery(limit: _sampleSize));
    if (recent.isEmpty) return starterQuestions;
    final tags = {for (final m in recent) ...m.tags}.take(2);
    final categories = {for (final m in recent) m.category}.take(2);
    return [
      for (final t in tags) 'Summarize everything I saved about $t',
      for (final c in categories) 'What are my ${c.toLowerCase()} notes about?',
      starterQuestions.first,
    ].take(_maxSuggestions).toList();
  }
}

/// Which proposed action of which answer the user decided on.
typedef ActionDecision = ({ChatMessage message, String actionId});

/// Carries out an action Ask Brain proposed, after the user confirmed it,
/// and records that it was done.
final class ConfirmAssistantAction implements UseCase<Result<ChatMessage>, ActionDecision> {
  ConfirmAssistantAction({
    required ConversationRepository conversations,
    required AddTask addTask,
    required SaveCapture saveCapture,
    required MemoryAnalyzer analyzer,
    required Clock clock,
    required AppLogger logger,
  }) : _conversations = conversations,
       _addTask = addTask,
       _saveCapture = saveCapture,
       _analyzer = analyzer,
       _clock = clock,
       _logger = logger;

  final ConversationRepository _conversations;
  final AddTask _addTask;
  final SaveCapture _saveCapture;
  final MemoryAnalyzer _analyzer;
  final Clock _clock;
  final AppLogger _logger;

  @override
  Future<Result<ChatMessage>> call(ActionDecision decision) async {
    final action = decision.message.actions.where((a) => a.id == decision.actionId).firstOrNull;
    if (action == null) return const Err(NotFoundFailure());
    if (!action.isPending) return Success(decision.message);

    final outcome = switch (action.type) {
      AssistantActionType.createTask => await _createTask(action),
      AssistantActionType.saveMemory => await _saveMemory(action),
    };
    if (outcome case Err(:final failure)) return Err(failure);
    return guard(_logger, 'Record confirmed action', () async {
      final updated = decision.message.withAction(action.withStatus(AssistantActionStatus.done));
      await _conversations.saveMessage(updated);
      return updated;
    });
  }

  Future<Result<void>> _createTask(AssistantAction action) async {
    final result = await _addTask(
      NewTask(
        title: action.args['title'] ?? '',
        dueAt: DateTime.tryParse(action.args['due'] ?? ''),
        reminderAt: DateTime.tryParse(action.args['reminder'] ?? ''),
      ),
    );
    return result.fold(onSuccess: (_) => const Success(null), onFailure: Err.new);
  }

  Future<Result<void>> _saveMemory(AssistantAction action) async {
    final text = action.args['text'] ?? '';
    final analysis = await _analyzer.analyze(text, now: _clock.now());
    final result = await _saveCapture(
      SaveCaptureRequest(
        content: text,
        source: MemorySource.note,
        title: analysis.title,
        summary: analysis.summary,
        category: analysis.category,
        tags: analysis.tags,
        tasks: const [],
        acceptedAiAsIs: analysis.byModel,
      ),
    );
    return result.fold(onSuccess: (_) => const Success(null), onFailure: Err.new);
  }
}

/// Declines a proposed action; nothing changes except its status.
final class DismissAssistantAction implements UseCase<Result<ChatMessage>, ActionDecision> {
  const DismissAssistantAction(this._conversations, this._logger);

  final ConversationRepository _conversations;
  final AppLogger _logger;

  @override
  Future<Result<ChatMessage>> call(ActionDecision decision) =>
      guard(_logger, 'Dismiss action', () async {
        final action = decision.message.actions.firstWhere((a) => a.id == decision.actionId);
        final updated = decision.message.withAction(
          action.withStatus(AssistantActionStatus.dismissed),
        );
        await _conversations.saveMessage(updated);
        return updated;
      });
}
