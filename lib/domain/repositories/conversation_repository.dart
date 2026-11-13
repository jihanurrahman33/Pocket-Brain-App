import '../entities/conversation.dart';
import 'change_notifier.dart';

/// Persistence for Ask Brain conversations.
abstract interface class ConversationRepository implements Clearable {
  /// Newest first.
  Future<List<Conversation>> getAll();

  Future<void> save(Conversation conversation);

  Future<void> delete(String id);

  /// Oldest first.
  Future<List<ChatMessage>> messages(String conversationId);

  Future<void> saveMessage(ChatMessage message);

  Future<void> deleteMessage(String id);
}
