import 'dart:async';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import '../../../domain/entities/ai_model.dart';
import 'on_device_ai_runtime.dart';

/// [OnDeviceAiRuntime] backed by LiteRT-LM via `flutter_edge_ai` (Adapter).
///
/// Uses Gemma 4 E2B — the lightest Gemma 4 model, designed for phones with
/// 4–6 GB of RAM — and EmbeddingGemma 2 for semantic search. Models load
/// lazily on first use and stay resident until unloaded.
final class LiteRtAiRuntime implements OnDeviceAiRuntime {
  LiteRtAiRuntime({required ComputeBackend backend}) : _backend = backend;

  static final _llmVariant = LiteRtLmModels.gemma4E2bIt.generic;
  static final _embedderVariant = LiteRtEmbedders.embeddinggemma2Text270m.generic;

  /// Room for several retrieved memories plus an answer, at modest RAM cost.
  static const _contextTokens = 4096;

  /// Registers the engines. Call once at startup.
  static Future<void> initialize() => FlutterEdgeAi.initialize(
    inferenceEngines: [const LiteRtLmEngine()],
    embeddingBackends: [const LiteRtEmbeddingBackend()],
  );

  ComputeBackend _backend;
  final _cancelTokens = <AiModelKind, CancelToken>{};
  final _llm = _LazyResource<InferenceModel>();
  final _embedder = _LazyResource<EmbeddingModel>();

  /// LiteRT-LM runs one generation at a time; requests queue here.
  Future<void> _generationQueue = Future.value();

  @override
  List<AiModelInfo> get models => [
    AiModelInfo(
      kind: AiModelKind.languageModel,
      name: 'Gemma 4 E2B',
      purpose: 'Summaries, tags, task extraction and Ask Brain answers',
      sizeBytes: _llmVariant.file.sizeBytes,
    ),
    AiModelInfo(
      kind: AiModelKind.embedder,
      name: 'EmbeddingGemma 2 Text',
      purpose: 'Semantic search and related memories',
      sizeBytes: _embedderVariant.model.sizeBytes,
    ),
  ];

  @override
  bool isInstalled(AiModelKind kind) => switch (kind) {
    AiModelKind.languageModel => FlutterEdgeAi.hasActiveModel(),
    AiModelKind.embedder => FlutterEdgeAi.hasActiveEmbedder(),
  };

  @override
  bool isLoaded(AiModelKind kind) => switch (kind) {
    AiModelKind.languageModel => _llm.isLoaded,
    AiModelKind.embedder => _embedder.isLoaded,
  };

  @override
  Future<void> install(AiModelKind kind, {required void Function(int percent) onProgress}) async {
    final token = CancelToken();
    _cancelTokens[kind] = token;
    try {
      switch (kind) {
        case AiModelKind.languageModel:
          await FlutterEdgeAi.installModelFromCatalog(_llmVariant)
              .withProgress(onProgress)
              .withCancelToken(token)
              .install();
        case AiModelKind.embedder:
          await FlutterEdgeAi.installEmbedder()
              .fromCatalog(_embedderVariant)
              .withProgress(onProgress)
              .withCancelToken(token)
              .install();
      }
    } on Object {
      if (token.isCancelled) throw const InstallCancelledException();
      rethrow;
    } finally {
      _cancelTokens.remove(kind);
    }
  }

  @override
  void cancelInstall(AiModelKind kind) => _cancelTokens[kind]?.cancel('Cancelled by user');

  @override
  Future<void> uninstall(AiModelKind kind) async {
    await unload(kind);
    switch (kind) {
      case AiModelKind.languageModel:
        await FlutterEdgeAi.uninstallModel(_llmVariant.file.installFilename);
      case AiModelKind.embedder:
        await FlutterEdgeAi.uninstallEmbedder();
    }
  }

  @override
  Future<void> unload(AiModelKind kind) => switch (kind) {
    AiModelKind.languageModel => _llm.release((m) => m.close()),
    AiModelKind.embedder => _embedder.release((e) => e.close()),
  };

  @override
  Future<void> useBackend(ComputeBackend backend) async {
    if (backend == _backend) return;
    _backend = backend;
    await unload(AiModelKind.languageModel);
  }

  @override
  Stream<String> generate(GenerationRequest request) {
    final controller = StreamController<String>();
    final run = _generationQueue.then((_) => _pump(request, controller));
    _generationQueue = run.catchError((Object _) {});
    controller.onCancel = () async {
      if (!controller.isClosed) await controller.close();
    };
    return controller.stream;
  }

  Future<void> _pump(GenerationRequest request, StreamController<String> out) async {
    InferenceModelSession? session;
    try {
      final model = await _llm.obtain(_loadLanguageModel);
      session = await model.openSession(
        systemInstruction: request.systemInstruction,
        temperature: request.temperature,
        maxOutputTokens: request.maxOutputTokens,
      );
      await session.addQueryChunk(Message.text(text: request.prompt, isUser: true));
      await for (final token in session.getResponseAsync()) {
        if (out.isClosed) break;
        out.add(token);
      }
    } on Object catch (e, s) {
      if (!out.isClosed) out.addError(e, s);
    } finally {
      await session?.close();
      if (!out.isClosed) await out.close();
    }
  }

  Future<InferenceModel> _loadLanguageModel() => FlutterEdgeAi.getActiveModel(
    maxTokens: _contextTokens,
    preferredBackend: switch (_backend) {
      ComputeBackend.cpu => PreferredBackend.cpu,
      ComputeBackend.gpu => PreferredBackend.gpu,
    },
    supportImage: false,
    supportAudio: false,
  );

  @override
  Future<List<double>> embed(String text, {required bool isQuery}) async {
    final embedder = await _embedder.obtain(
      () => FlutterEdgeAi.getActiveEmbedder(preferredBackend: PreferredBackend.cpu),
    );
    return embedder.embed(
      EmbeddingInput.text(text),
      taskType: isQuery ? TaskType.retrievalQuery : TaskType.retrievalDocument,
    );
  }

  @override
  Future<int> storageBytes() async => (await FlutterEdgeAi.getStorageInfo()).totalSizeBytes;
}

/// Loads an expensive resource once, even under concurrent requests.
final class _LazyResource<T extends Object> {
  T? _value;
  Future<T>? _loading;

  bool get isLoaded => _value != null;

  Future<T> obtain(Future<T> Function() load) async {
    if (_value case final v?) return v;
    return _loading ??= () async {
      try {
        return _value = await load();
      } finally {
        _loading = null;
      }
    }();
  }

  Future<void> release(Future<void> Function(T value) close) async {
    final value = _value;
    _value = null;
    _loading = null;
    if (value != null) await close(value);
  }
}
