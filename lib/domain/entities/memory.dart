import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Where a memory came from.
enum MemorySource {
  note('Note'),
  link('Link'),
  clipboard('Clipboard'),
  voice('Voice'),
  image('Image'),
  pdf('PDF');

  const MemorySource(this.label);

  final String label;
}

enum AttachmentKind { image, audio }

/// A file kept with a memory (a photo, screenshot or voice recording).
class Attachment extends Equatable {
  const Attachment({required this.path, required this.kind});

  /// Location inside the app's private storage.
  final String path;
  final AttachmentKind kind;

  @override
  List<Object?> get props => [path, kind];
}

/// The built-in smart categories. Users may also keep their own.
abstract final class MemoryCategories {
  static const fallback = 'Personal';

  static const defaults = <String>[
    'Learning',
    'Work',
    'Personal',
    'Ideas',
    'Projects',
    'Reading list',
    'Things to remember',
  ];
}

/// A single saved item in the user's brain.
///
/// [content] is always the user's original text and is never rewritten by
/// AI. [summary], [category] and [tags] may be AI-suggested; [aiGenerated]
/// records whether AI suggestions were accepted without edits.
class Memory extends Equatable {
  const Memory({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.summary = '',
    this.source = MemorySource.note,
    this.sourceUrl,
    this.category = MemoryCategories.fallback,
    this.tags = const [],
    this.collectionId,
    this.isFavorite = false,
    this.isArchived = false,
    this.lastViewedAt,
    this.aiGenerated = false,
    this.embedding,
    this.attachments = const [],
  });

  final String id;
  final String title;
  final String content;
  final String summary;
  final MemorySource source;
  final String? sourceUrl;
  final String category;
  final List<String> tags;
  final String? collectionId;
  final bool isFavorite;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastViewedAt;
  final bool aiGenerated;

  /// Semantic vector, present once the embedding model has processed it.
  final Float32List? embedding;

  /// Images or recordings this memory was captured from.
  final List<Attachment> attachments;

  Attachment? get image => attachments.where((a) => a.kind == AttachmentKind.image).firstOrNull;

  Attachment? get recording => attachments.where((a) => a.kind == AttachmentKind.audio).firstOrNull;

  /// All text that search and embeddings consider.
  String get searchableText => '$title\n$summary\n${tags.join(' ')}\n$category\n$content';

  /// The summary when present, otherwise the original content.
  String get preview => summary.isNotEmpty ? summary : content;

  bool get hasEmbedding => embedding != null;

  Memory copyWith({
    String? title,
    String? content,
    String? summary,
    String? category,
    List<String>? tags,
    String? Function()? collectionId,
    bool? isFavorite,
    bool? isArchived,
    DateTime? updatedAt,
    DateTime? Function()? lastViewedAt,
    bool? aiGenerated,
    Float32List? Function()? embedding,
  }) => Memory(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    summary: summary ?? this.summary,
    source: source,
    sourceUrl: sourceUrl,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    collectionId: collectionId != null ? collectionId() : this.collectionId,
    isFavorite: isFavorite ?? this.isFavorite,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastViewedAt: lastViewedAt != null ? lastViewedAt() : this.lastViewedAt,
    aiGenerated: aiGenerated ?? this.aiGenerated,
    embedding: embedding != null ? embedding() : this.embedding,
    attachments: attachments,
  );

  @override
  List<Object?> get props => [
    id,
    title,
    content,
    summary,
    source,
    sourceUrl,
    category,
    tags,
    collectionId,
    isFavorite,
    isArchived,
    createdAt,
    updatedAt,
    lastViewedAt,
    aiGenerated,
    hasEmbedding,
    attachments,
  ];
}
