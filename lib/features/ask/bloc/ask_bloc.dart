import 'package:bloc_concurrency/bloc_concurrency.dart';
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
  }) : _askBrain = askBrain,
       _getConversations = getConversations,
       _openConversation = openConversation,
       _deleteConversation = deleteConversation,
       _getSuggestions = getSuggestions,
       _getCollections = getCollections,
       super(const AskState()) {
    on<AskStarted>(_onStarted);
    on<AskConversationSelected>(_onConversationSelected, transformer: restartable());
    on<AskNewConversationRequested>(_onNewConversation);
    on<AskConversationDeleted>(_onConversationDeleted);
    on<AskQuestionSubmitted>(_onQuestionSubmitted, transformer: droppable());
    on<AskRegenerateRequested>(_onRegenerate, transformer: droppable());
    on<AskStopRequested>(_onStop);
  }

  final AskBrain _askBrain;
  final GetConversations _getConversations;
  final OpenConversation _openConversation;
  final DeleteConversation _deleteConversation;
  final GetSuggestedQuestions _getSuggestions;
  final GetCollections _getCollections;
  bool _stopRequested = false;

  Future<void> _onStarted(AskStarted event, Emitter<AskState> emit) async {
    emit(
      state.copyWith(
        conversations: (await _getConversations.run()).valueOrNull,
        collections: (await _getCollections.run()).valueOrNull,
        suggestions: await _getSuggestions.run(),
      ),
    );
  }

  Future<void> _onConversationSelected(
    AskConversationSelected event,
    Emitter<AskState> emit,
  ) async {
    final transcript = await _openConversation(event.conversation.id);
    transcript.fold(
      onSuccess: (t) => emit(
        state.copyWith(
          conversation: () => event.conversation,
          collectionId: () => event.conversation.collectionId,
          messages: t.messages,
          sources: t.sources,
          failure: () => null,
        ),
      ),
      onFailure: (f) => emit(state.copyWith(failure: () => f)),
    );
  }

  Future<void> _onNewConversation(AskNewConversationRequested event, Emitter<AskState> emit) async {
    emit(
      state.copyWith(
        conversation: () => null,
        collectionId: () => event.collectionId,
        messages: const [],
        streamingText: () => null,
        failure: () => null,
        collections: (await _getCollections.run()).valueOrNull,
        suggestions: await _getSuggestions.run(),
      ),
    );
  }

  Future<void> _onConversationDeleted(AskConversationDeleted event, Emitter<AskState> emit) async {
    await _deleteConversation(event.conversationId);
    final wasOpen = state.conversation?.id == event.conversationId;
    emit(
      state.copyWith(
        conversations: (await _getConversations.run()).valueOrNull,
        conversation: wasOpen ? () => null : null,
        messages: wasOpen ? const [] : null,
      ),
    );
  }

  Future<void> _onQuestionSubmitted(AskQuestionSubmitted event, Emitter<AskState> emit) =>
      _ask(event.question, history: state.messages, emit: emit);

  Future<void> _onRegenerate(AskRegenerateRequested event, Emitter<AskState> emit) async {
    final messages = state.messages;
    final lastQuestion = messages.where((m) => m.isUser).lastOrNull;
    if (lastQuestion == null || state.isAnswering) return;
    final history = messages.sublist(0, messages.indexOf(lastQuestion));
    emit(state.copyWith(messages: history));
    await _ask(lastQuestion.text, history: history, emit: emit);
  }

  void _onStop(AskStopRequested event, Emitter<AskState> emit) => _stopRequested = true;

  Future<void> _ask(
    String question, {
    required List<ChatMessage> history,
    required Emitter<AskState> emit,
  }) async {
    if (question.trim().isEmpty || state.isAnswering) return;
    _stopRequested = false;
    emit(state.copyWith(phase: AskPhase.retrieving, streamingText: () => '', failure: () => null));
    final request = AskRequest(
      question: question,
      conversation: state.conversation,
      collectionId: state.collectionId,
      history: history,
      isStopRequested: () => _stopRequested,
    );
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
