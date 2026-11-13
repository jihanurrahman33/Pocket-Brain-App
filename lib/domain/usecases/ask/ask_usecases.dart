import '../../../core/error/guard.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/text_utils.dart';
import '../../entities/ask.dart';
import '../../entities/conversation.dart';
import '../../entities/memory.dart';
import '../../entities/search.dart';
import '../../repositories/conversation_repository.dart';
import '../../repositories/memory_repository.dart';
import '../../services/ai_services.dart';
import '../search/search_usecases.dart';

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
    required IdGenerator ids,
    required Clock clock,
  }) : _conversations = conversations,
       _retrieveSources = retrieveSources,
       _generator = generator,
       _ids = ids,
       _clock = clock;

  final ConversationRepository _conversations;
  final RetrieveAnswerSources _retrieveSources;
  final AnswerGenerator _generator;
  final IdGenerator _ids;
  final Clock _clock;

  static const _titleLength = 48;

  /// Short follow-ups ("tell me more") retrieve better with the prior question.
  static const _minStandaloneTerms = 3;

  @override
  Stream<AskProgress> call(AskRequest request) async* {
    final question = request.question.trim();
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

    final asked = _message(conversation.id, ChatRole.user, question);
    await _conversations.saveMessage(asked);
    yield AskQuestionRecorded(asked);

    final sources = await _retrieveSources((
      question: _retrievalText(question, request.history),
      collectionId: conversation.collectionId,
    ));
    yield AskSourcesFound(sources);

    final buffer = StringBuffer();
    await for (final chunk in _answerStream(question, sources, request.history)) {
      if (request.isStopRequested()) break;
      buffer.write(chunk);
      yield AskAnswerUpdated(buffer.toString());
    }

    final text = buffer.toString().trim();
    final grounded = sources.isNotEmpty && !text.contains(AskReplies.notFound);
    final answer = _message(
      conversation.id,
      ChatRole.assistant,
      text.isEmpty ? AskReplies.notFound : text,
      sourceIds: grounded ? [for (final m in sources) m.id] : const [],
      grounded: grounded,
    );
    await _conversations.saveMessage(answer);
    yield AskAnswerCompleted(answer);
  }

  Stream<String> _answerStream(String question, List<Memory> sources, List<ChatMessage> history) {
    if (sources.isEmpty) return Stream.value(AskReplies.notFound);
    if (!_generator.isAvailable) return Stream.value(AskReplies.modelMissing);
    return _generator.generate(
      AnswerPrompt(question: question, sources: sources, history: history),
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
  }) => ChatMessage(
    id: _ids.next(),
    conversationId: conversationId,
    role: role,
    text: text,
    sourceIds: sourceIds,
    grounded: grounded,
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
typedef ConversationTranscript = ({List<ChatMessage> messages, Map<String, Memory> sources});

final class OpenConversation implements UseCase<Result<ConversationTranscript>, String> {
  const OpenConversation(this._conversations, this._memories, this._logger);

  final ConversationRepository _conversations;
  final MemoryRepository _memories;
  final AppLogger _logger;

  @override
  Future<Result<ConversationTranscript>> call(String id) =>
      guard(_logger, 'Open conversation', () async {
        final messages = await _conversations.messages(id);
        final ids = {for (final m in messages) ...m.sourceIds}.toList();
        final sources = await _memories.getByIds(ids);
        return (messages: messages, sources: {for (final m in sources) m.id: m});
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
