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

/// Parameters for one text generation.
class GenerationRequest {
  const GenerationRequest({
    required this.systemInstruction,
    required this.prompt,
    this.maxOutputTokens = 512,
    this.temperature = 0.4,
  });

  final String systemInstruction;
  final String prompt;
  final int maxOutputTokens;
  final double temperature;
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

  /// Streams generated text. Generations run one at a time.
  Stream<String> generate(GenerationRequest request);

  /// [isQuery] picks the retrieval-query vs. document task prefix.
  Future<List<double>> embed(String text, {required bool isQuery});

  Future<int> storageBytes();
}
