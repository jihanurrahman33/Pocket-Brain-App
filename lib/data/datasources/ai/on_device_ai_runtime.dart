import 'dart:typed_data';

import '../../../domain/entities/ai_model.dart';

/// The parts of the on-device AI pack. Internal to the data layer: the
/// domain and UI only ever see one "Pocket Brain AI" pack.
enum AiModelKind {
  /// Writes summaries, tags, tasks, answers and recaps.
  languageModel,

  /// Turns text into vectors for semantic search.
  embedder,
}

/// One downloadable part of the AI pack.
class AiComponent {
  const AiComponent({required this.kind, required this.sizeBytes});

  final AiModelKind kind;
  final int sizeBytes;
}

/// Parameters for one generation.
class GenerationRequest {
  const GenerationRequest({
    required this.systemInstruction,
    required this.prompt,
    this.maxOutputTokens = 512,
    this.temperature = 0.4,
    this.image,
    this.audio,
    this.jsonSchema,
  });

  final String systemInstruction;
  final String prompt;
  final int maxOutputTokens;
  final double temperature;

  /// Encoded image (PNG/JPEG/…) to look at. Loads the vision encoder.
  final Uint8List? image;

  /// Encoded audio (WAV/MP3/FLAC) to listen to. Loads the audio encoder.
  final Uint8List? audio;

  /// When set, the reply is constrained to this JSON schema where the
  /// engine supports it (otherwise the prompt alone asks for JSON).
  final Map<String, Object?>? jsonSchema;

  bool get hasMedia => image != null || audio != null;
}

/// A function the model may call during a tool chat.
class ToolDefinition {
  const ToolDefinition({required this.name, required this.description, required this.parameters});

  final String name;
  final String description;

  /// JSON schema of the arguments object.
  final Map<String, Object?> parameters;
}

/// Runs one tool call and returns the result the model reads back. Must not
/// throw: report errors as data, e.g. `{'error': '...'}`.
typedef ToolHandler = Future<Map<String, Object?>> Function(String name, Map<String, Object?> args);

/// A chat in which the model may call [tools] before answering.
class ToolChatRequest {
  const ToolChatRequest({
    required this.systemInstruction,
    required this.prompt,
    required this.tools,
    required this.onToolCall,
    this.maxOutputTokens = 600,
    this.maxToolTurns = 4,
  });

  final String systemInstruction;
  final String prompt;
  final List<ToolDefinition> tools;
  final ToolHandler onToolCall;
  final int maxOutputTokens;
  final int maxToolTurns;
}

/// Thrown when an install was cancelled by the user.
final class InstallCancelledException implements Exception {
  const InstallCancelledException();
}

/// Port to the on-device inference engine. The rest of the data layer
/// depends on this interface, never on the engine package directly, so the
/// engine can be swapped (or faked in tests).
abstract interface class OnDeviceAiRuntime {
  /// Pack components in install order (most important first).
  List<AiComponent> get components;

  bool isInstalled(AiModelKind kind);

  bool isLoaded(AiModelKind kind);

  /// Bytes of [kind] already on disk: its full size when installed, the
  /// partial download otherwise. Survives restarts, so progress can resume.
  int downloadedBytes(AiModelKind kind);

  /// Downloads (resuming any partial file) and registers [kind].
  ///
  /// [onProgress] receives the bytes on disk, including a resumed prefix.
  /// Throws [InstallCancelledException] if [cancelInstall] is called; the
  /// partial download is kept so the next install resumes from it.
  Future<void> install(AiModelKind kind, {required void Function(int bytesOnDisk) onProgress});

  void cancelInstall(AiModelKind kind);

  Future<void> uninstall(AiModelKind kind);

  Future<void> unload(AiModelKind kind);

  Future<void> useBackend(ComputeBackend backend);

  /// Streams generated text. Generations run one at a time. Media encoders
  /// are loaded only for requests that carry media and freed afterwards.
  Stream<String> generate(GenerationRequest request);

  /// Streams snapshots of the answer so far ("answer text until now") for a
  /// chat in which the model may call tools. A tool call resets the snapshot
  /// to empty, because text written before a call is not the answer.
  Stream<String> chatWithTools(ToolChatRequest request);

  /// [isQuery] picks the retrieval-query vs. document task prefix.
  Future<List<double>> embed(String text, {required bool isQuery});

  Future<int> storageBytes();
}
