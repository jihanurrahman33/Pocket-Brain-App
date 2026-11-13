import 'package:equatable/equatable.dart';

import 'conversation.dart';
import 'memory.dart';

/// Fixed replies, so the app never invents memories.
abstract final class AskReplies {
  static const notFound = "I couldn't find that in your saved memories.";

  static const modelMissing =
      'The on-device AI model is not downloaded yet, so I can only point you '
      'to the most relevant memories below. Download Gemma 4 in Settings → '
      'AI models to get written answers.';
}

/// A question for Ask Brain.
class AskRequest extends Equatable {
  const AskRequest({
    required this.question,
    this.conversation,
    this.collectionId,
    this.history = const [],
    this.isStopRequested = _never,
  }) : staleAnswerId = null,
       isRegeneration = false;

  /// Answers the latest question of [conversation] again. The question is
  /// already stored, so it is not saved twice; [staleAnswerId], if any, is
  /// deleted and replaced by the new answer.
  const AskRequest.regenerate({
    required this.question,
    required Conversation this.conversation,
    required this.staleAnswerId,
    this.history = const [],
    this.isStopRequested = _never,
  }) : collectionId = null,
       isRegeneration = true;

  static bool _never() => false;

  final String question;

  /// Null starts a new conversation.
  final Conversation? conversation;

  /// Limits retrieval to one collection for new conversations.
  final String? collectionId;

  /// Earlier turns, for follow-up questions.
  final List<ChatMessage> history;

  /// Polled while streaming; true stops generation early.
  final bool Function() isStopRequested;

  /// True when re-answering a question that is already stored.
  final bool isRegeneration;

  /// The previous answer to replace when regenerating.
  final String? staleAnswerId;

  @override
  List<Object?> get props => [
    question,
    conversation,
    collectionId,
    history,
    isRegeneration,
    staleAnswerId,
  ];
}

/// Progress events emitted while Ask Brain answers (Observer pattern).
sealed class AskProgress extends Equatable {
  const AskProgress();

  @override
  List<Object?> get props => [];
}

final class AskConversationStarted extends AskProgress {
  const AskConversationStarted(this.conversation);

  final Conversation conversation;

  @override
  List<Object?> get props => [conversation];
}

final class AskQuestionRecorded extends AskProgress {
  const AskQuestionRecorded(this.message);

  final ChatMessage message;

  @override
  List<Object?> get props => [message];
}

final class AskSourcesFound extends AskProgress {
  const AskSourcesFound(this.sources);

  final List<Memory> sources;

  @override
  List<Object?> get props => [sources];
}

/// The answer text generated so far.
final class AskAnswerUpdated extends AskProgress {
  const AskAnswerUpdated(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

final class AskAnswerCompleted extends AskProgress {
  const AskAnswerCompleted(this.message);

  final ChatMessage message;

  @override
  List<Object?> get props => [message];
}

/// Input to the language model for one answer.
class AnswerPrompt extends Equatable {
  const AnswerPrompt({required this.question, required this.sources, this.history = const []});

  final String question;
  final List<Memory> sources;
  final List<ChatMessage> history;

  @override
  List<Object?> get props => [question, sources, history];
}
