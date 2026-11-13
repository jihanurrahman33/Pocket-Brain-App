import 'dart:typed_data';

import '../entities/ask.dart';
import '../entities/capture.dart';
import '../entities/memory.dart';
import '../entities/memory_analysis.dart';
import 'assistant_toolbox.dart';

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

  /// Streams snapshots of the answer so far. When [toolbox] is given the
  /// model may call its tools; a snapshot may then shrink (text written
  /// before a tool call is not the answer).
  Stream<String> generate(AnswerPrompt prompt, {AssistantToolbox? toolbox});
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

/// Understands images and recordings on the device.
abstract interface class MediaReader {
  /// Whether the AI needed to read media is set up.
  bool get isAvailable;

  /// Reads the text in an image and describes it.
  Future<MediaReading> readImage(String path);

  /// Transcribes speech in a recording.
  Future<MediaReading> transcribe(String path);
}

/// Records voice notes from the microphone.
abstract interface class VoiceRecorder {
  /// Whether recording works on this device.
  Future<bool> isSupported();

  /// Starts recording; throws if the microphone is unavailable.
  Future<void> start();

  /// Stops and returns the path of the finished recording.
  Future<String> stop();

  /// Stops and discards the recording.
  Future<void> cancel();
}
