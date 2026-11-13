part of 'ask_bloc.dart';

enum AskPhase { idle, retrieving, generating }

class AskState extends Equatable {
  const AskState({
    this.conversations = const [],
    this.conversation,
    this.collectionId,
    this.collections = const [],
    this.messages = const [],
    this.sources = const {},
    this.tasks = const {},
    this.phase = AskPhase.idle,
    this.streamingText,
    this.suggestions = const [],
    this.failure,
  });

  final List<Conversation> conversations;

  /// Null until the first question of a new chat is asked.
  final Conversation? conversation;

  /// When set, answers only use memories from this collection.
  final String? collectionId;
  final List<MemoryCollection> collections;
  final List<ChatMessage> messages;

  /// Memories cited anywhere in this conversation, by id.
  final Map<String, Memory> sources;

  /// Tasks shown as cards in answers, by id.
  final Map<String, TaskItem> tasks;
  final AskPhase phase;

  /// The answer being generated right now.
  final String? streamingText;
  final List<String> suggestions;
  final Failure? failure;

  bool get isAnswering => phase != AskPhase.idle;

  bool get isEmpty => messages.isEmpty && streamingText == null;

  MemoryCollection? get collection => collections.where((c) => c.id == collectionId).firstOrNull;

  List<Memory> sourcesOf(ChatMessage message) => [for (final id in message.sourceIds) ?sources[id]];

  List<TaskItem> tasksOf(ChatMessage message) => [for (final id in message.taskIds) ?tasks[id]];

  AskState copyWith({
    List<Conversation>? conversations,
    Conversation? Function()? conversation,
    String? Function()? collectionId,
    List<MemoryCollection>? collections,
    List<ChatMessage>? messages,
    Map<String, Memory>? sources,
    Map<String, TaskItem>? tasks,
    AskPhase? phase,
    String? Function()? streamingText,
    List<String>? suggestions,
    Failure? Function()? failure,
  }) => AskState(
    conversations: conversations ?? this.conversations,
    conversation: conversation != null ? conversation() : this.conversation,
    collectionId: collectionId != null ? collectionId() : this.collectionId,
    collections: collections ?? this.collections,
    messages: messages ?? this.messages,
    sources: sources ?? this.sources,
    tasks: tasks ?? this.tasks,
    phase: phase ?? this.phase,
    streamingText: streamingText != null ? streamingText() : this.streamingText,
    suggestions: suggestions ?? this.suggestions,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [
    conversations,
    conversation,
    collectionId,
    collections,
    messages,
    sources,
    tasks,
    phase,
    streamingText,
    suggestions,
    failure,
  ];
}
