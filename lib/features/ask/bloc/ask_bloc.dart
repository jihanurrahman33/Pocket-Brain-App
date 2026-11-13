import 'package:bloc_concurrency/bloc_concurrency.dart' show sequential;
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/load_state.dart';
import '../../../core/error/failure.dart';
import '../../../domain/entities/ask.dart';
import '../../../domain/entities/conversation.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/entities/memory_collection.dart';
import '../../../domain/usecases/ask/ask_usecases.dart';
import '../../../domain/usecases/collections/collection_usecases.dart';

part 'ask_event.dart';
part 'ask_state.dart';

/// Conversations with your memories. Answers come only from retrieved
/// memories, shown as source cards under each answer.
class AskBloc extends Bloc<AskEvent, AskState> {
  AskBloc({
    required AskBrain askBrain,
    required GetConversations getConversations,
    required OpenConversation openConversation,
    required DeleteConversation deleteConversation,
    required GetSuggestedQuestions getSuggestions,
    required GetCollections getCollections,
    required ConfirmAssistantAction confirmAction,
    required DismissAssistantAction dismissAction,
  }) : _askBrain = askBrain,
       _confirmAction = confirmAction,
       _dismissAction = dismissAction,
       _getConversations = getConversations,
       _openConversation = openConversation,
       _deleteConversation = deleteConversation,
       _getSuggestions = getSuggestions,
       _getCollections = getCollections,
       super(const AskState()) {
    // Every event that reads or replaces the conversation runs strictly in
    // order, so e.g. "new chat" then "ask" can never interleave. Stop has its
    // own concurrent handler so it can interrupt a running answer.
    on<AskEvent>(_dispatch, transformer: sequential());
    on<AskStopRequested>((_, _) => _stopRequested = true);
  }

  final AskBrain _askBrain;
  final GetConversations _getConversations;
  final OpenConversation _openConversation;
  final DeleteConversation _deleteConversation;
  final GetSuggestedQuestions _getSuggestions;
  final GetCollections _getCollections;
  final ConfirmAssistantAction _confirmAction;
  final DismissAssistantAction _dismissAction;
  bool _stopRequested = false;

  Future<void> _dispatch(AskEvent event, Emitter<AskState> emit) => switch (event) {
    AskStarted() => _onStarted(emit),
    AskConversationSelected(:final conversation) => _onConversationSelected(conversation, emit),
    AskNewConversationRequested(:final collectionId) => _onNewConversation(collectionId, emit),
    AskConversationDeleted(:final conversationId) => _onConversationDeleted(conversationId, emit),
    AskQuestionSubmitted(:final question) => _onQuestionSubmitted(question, emit),
    AskRegenerateRequested() => _onRegenerate(emit),
    AskActionDecided(:final messageId, :final actionId, :final confirmed) => _onActionDecided(
      messageId,
      actionId,
      confirmed: confirmed,
      emit: emit,
    ),
    // Handled immediately by its own concurrent handler.
    AskStopRequested() => Future.value(),
  };

  Future<void> _onStarted(Emitter<AskState> emit) async {
    emit(
      state.copyWith(
        conversations: (await _getConversations.run()).valueOrNull,
        collections: (await _getCollections.run()).valueOrNull,
        suggestions: await _getSuggestions.run(),
      ),
    );
  }

  Future<void> _onConversationSelected(Conversation conversation, Emitter<AskState> emit) async {
    final transcript = await _openConversation(conversation.id);
    transcript.fold(
      onSuccess: (t) => emit(
        state.copyWith(
          conversation: () => conversation,
          collectionId: () => conversation.collectionId,
          messages: t.messages,
          sources: t.sources,
          failure: () => null,
        ),
      ),
      onFailure: (f) => emit(state.copyWith(failure: () => f)),
    );
  }

  Future<void> _onNewConversation(String? collectionId, Emitter<AskState> emit) async {
    // Reset first so nothing can observe a half-switched conversation.
    emit(
      state.copyWith(
        conversation: () => null,
        collectionId: () => collectionId,
        messages: const [],
        sources: const {},
        streamingText: () => null,
        failure: () => null,
      ),
    );
    emit(
      state.copyWith(
        collections: (await _getCollections.run()).valueOrNull,
        suggestions: await _getSuggestions.run(),
      ),
    );
  }

  Future<void> _onConversationDeleted(String conversationId, Emitter<AskState> emit) async {
    await _deleteConversation(conversationId);
    final wasOpen = state.conversation?.id == conversationId;
    emit(
      state.copyWith(
        conversations: (await _getConversations.run()).valueOrNull,
        conversation: wasOpen ? () => null : null,
        messages: wasOpen ? const [] : null,
      ),
    );
  }

  Future<void> _onQuestionSubmitted(String question, Emitter<AskState> emit) async {
    if (question.trim().isEmpty) return;
    await _ask(
      AskRequest(
        question: question,
        conversation: state.conversation,
        collectionId: state.collectionId,
        history: state.messages,
        isStopRequested: () => _stopRequested,
      ),
      emit,
    );
  }

  /// Answers the last question again, replacing (not duplicating) the
  /// stored answer.
  Future<void> _onRegenerate(Emitter<AskState> emit) async {
    final conversation = state.conversation;
    final messages = state.messages;
    final questionIndex = messages.lastIndexWhere((m) => m.isUser);
    if (conversation == null || questionIndex < 0) return;
    final staleAnswer = messages.skip(questionIndex + 1).where((m) => !m.isUser).firstOrNull;
    emit(state.copyWith(messages: messages.sublist(0, questionIndex + 1)));
    await _ask(
      AskRequest.regenerate(
        question: messages[questionIndex].text,
        conversation: conversation,
        staleAnswerId: staleAnswer?.id,
        history: messages.sublist(0, questionIndex),
        isStopRequested: () => _stopRequested,
      ),
      emit,
    );
  }

  /// Carries out (or declines) a change the assistant proposed.
  Future<void> _onActionDecided(
    String messageId,
    String actionId, {
    required bool confirmed,
    required Emitter<AskState> emit,
  }) async {
    final message = state.messages.where((m) => m.id == messageId).firstOrNull;
    if (message == null) return;
    final decision = (message: message, actionId: actionId);
    final result = confirmed ? await _confirmAction(decision) : await _dismissAction(decision);
    result.fold(
      onSuccess: (updated) => emit(
        state.copyWith(
          messages: [for (final m in state.messages) m.id == updated.id ? updated : m],
          failure: () => null,
        ),
      ),
      onFailure: (f) => emit(state.copyWith(failure: () => f)),
    );
  }

  Future<void> _ask(AskRequest request, Emitter<AskState> emit) async {
    _stopRequested = false;
    emit(state.copyWith(phase: AskPhase.retrieving, streamingText: () => '', failure: () => null));
    try {
      await emit.forEach<AskProgress>(_askBrain(request), onData: _reduce);
      emit(state.copyWith(conversations: (await _getConversations.run()).valueOrNull));
    } on Object {
      emit(
        state.copyWith(
          phase: AskPhase.idle,
          streamingText: () => null,
          failure: () => const ModelFailure('The on-device model could not answer. Try again.'),
        ),
      );
    }
  }

  /// Folds one progress event into the state (pure reducer).
  AskState _reduce(AskProgress progress) => switch (progress) {
    AskConversationStarted(:final conversation) => state.copyWith(conversation: () => conversation),
    AskQuestionRecorded(:final message) => state.copyWith(messages: [...state.messages, message]),
    AskSourcesFound(:final sources) => state.copyWith(
      phase: AskPhase.generating,
      sources: {...state.sources, for (final m in sources) m.id: m},
    ),
    AskAnswerUpdated(:final text) => state.copyWith(streamingText: () => text),
    AskAnswerCompleted(:final message) => state.copyWith(
      phase: AskPhase.idle,
      streamingText: () => null,
      messages: [...state.messages, message],
    ),
  };
}
