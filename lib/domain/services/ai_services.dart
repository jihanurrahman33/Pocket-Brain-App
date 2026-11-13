import 'dart:typed_data';

import '../entities/ask.dart';
import '../entities/memory.dart';
import '../entities/memory_analysis.dart';

/// Ports for AI capabilities (Interface Segregation: each consumer depends
/// only on the capability it uses). Implementations live in the data layer.

/// Suggests a title, summary, category, tags and tasks for captured text.
abstract interface class MemoryAnalyzer {
  Future<MemoryAnalysis> analyze(String text, {required DateTime now});
}

/// Writes an answer grounded only in the given memories.
abstract interface class AnswerGenerator {
  /// Whether a language model is installed.
  bool get isAvailable;

  /// Streams answer text in chunks.
  Stream<String> generate(AnswerPrompt prompt);
}

/// Writes a short recap connecting a set of memories.
abstract interface class RecapWriter {
  Future<String> write(List<Memory> memories);
}

enum EmbeddingPurpose { query, document }

/// Turns text into a semantic vector.
abstract interface class TextEmbedder {
  bool get isAvailable;

  /// Null when unavailable or failed; callers fall back to keywords.
  Future<Float32List?> embed(String text, EmbeddingPurpose purpose);
}

/// Readable content of a web page.
class LinkContent {
  const LinkContent({this.title, this.text});

  final String? title;
  final String? text;
}

/// Fetches a saved link so it can be summarised.
abstract interface class LinkReader {
  Future<LinkContent?> read(String url);
}
