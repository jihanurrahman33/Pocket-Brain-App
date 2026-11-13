import 'package:equatable/equatable.dart';

import 'assistant.dart';

/// An Ask Brain conversation, optionally scoped to one collection.
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    this.collectionId,
  });

  final String id;
  final String title;
  final String? collectionId;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, title, collectionId, createdAt];
}

enum ChatRole { user, assistant }

/// One turn of a [Conversation]. Assistant turns carry the ids of the
/// memories that grounded the answer.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.text,
    required this.createdAt,
    this.sourceIds = const [],
    this.grounded = true,
    this.actions = const [],
  });

  final String id;
  final String conversationId;
  final ChatRole role;
  final String text;
  final List<String> sourceIds;

  /// False when nothing relevant was saved and the answer says so.
  final bool grounded;
  final DateTime createdAt;

  /// Changes the assistant proposed in this answer, awaiting confirmation.
  final List<AssistantAction> actions;

  bool get isUser => role == ChatRole.user;

  ChatMessage withAction(AssistantAction action) => ChatMessage(
    id: id,
    conversationId: conversationId,
    role: role,
    text: text,
    createdAt: createdAt,
    sourceIds: sourceIds,
    grounded: grounded,
    actions: [for (final a in actions) a.id == action.id ? action : a],
  );

  @override
  List<Object?> get props => [
    id,
    conversationId,
    role,
    text,
    sourceIds,
    grounded,
    createdAt,
    actions,
  ];
}
