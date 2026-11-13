import '../../../domain/entities/ai_model.dart';

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
  List<AiModelInfo> get models;

  bool isInstalled(AiModelKind kind);

  bool isLoaded(AiModelKind kind);

  /// [onProgress] receives 0–100. Throws [InstallCancelledException] if
  /// [cancelInstall] is called meanwhile.
  Future<void> install(AiModelKind kind, {required void Function(int percent) onProgress});

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
