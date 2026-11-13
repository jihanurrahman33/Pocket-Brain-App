import 'package:equatable/equatable.dart';

/// A user-created group of memories, e.g. "Books to Read".
class MemoryCollection extends Equatable {
  const MemoryCollection({
    required this.id,
    required this.name,
    required this.emoji,
    required this.createdAt,
    this.isPrivate = false,
    this.memoryCount = 0,
  });

  static const defaultEmoji = '📁';

  final String id;
  final String name;
  final String emoji;
  final bool isPrivate;
  final DateTime createdAt;

  /// Number of non-archived memories inside.
  final int memoryCount;

  String get label => '$emoji $name';

  @override
  List<Object?> get props => [id, name, emoji, isPrivate, createdAt, memoryCount];
}
