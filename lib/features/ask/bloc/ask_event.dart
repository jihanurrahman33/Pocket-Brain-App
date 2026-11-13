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
