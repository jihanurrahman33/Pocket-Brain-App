part of 'ask_bloc.dart';

sealed class AskEvent extends Equatable {
  const AskEvent();

  @override
  List<Object?> get props => [];
}

final class AskStarted extends AskEvent {
  const AskStarted();
}

final class AskConversationSelected extends AskEvent {
  const AskConversationSelected(this.conversation);

  final Conversation conversation;

  @override
  List<Object?> get props => [conversation];
}

/// Starts a fresh chat, optionally limited to one collection.
final class AskNewConversationRequested extends AskEvent {
  const AskNewConversationRequested({this.collectionId});

  final String? collectionId;

  @override
  List<Object?> get props => [collectionId];
}

final class AskConversationDeleted extends AskEvent {
  const AskConversationDeleted(this.conversationId);

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

final class AskQuestionSubmitted extends AskEvent {
  const AskQuestionSubmitted(this.question);

  final String question;

  @override
  List<Object?> get props => [question];
}

final class AskRegenerateRequested extends AskEvent {
  const AskRegenerateRequested();
}

final class AskStopRequested extends AskEvent {
  const AskStopRequested();
}

/// The user ticked a task card in an answer.
final class AskTaskToggled extends AskEvent {
  const AskTaskToggled(this.task);

  final TaskItem task;

  @override
  List<Object?> get props => [task];
}

/// The user confirmed or dismissed a change the assistant proposed.
final class AskActionDecided extends AskEvent {
  const AskActionDecided({
    required this.messageId,
    required this.actionId,
    required this.confirmed,
  });

  final String messageId;
  final String actionId;
  final bool confirmed;

  @override
  List<Object?> get props => [messageId, actionId, confirmed];
}
