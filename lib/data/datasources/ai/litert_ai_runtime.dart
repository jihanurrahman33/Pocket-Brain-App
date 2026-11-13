import 'dart:async';
import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart' hide DownloadCancelledException;
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:path/path.dart' as p;

import '../../../domain/entities/ai_model.dart';
import 'on_device_ai_runtime.dart';
import 'resumable_downloader.dart';

/// [OnDeviceAiRuntime] backed by LiteRT-LM via `flutter_edge_ai` (Adapter).
///
/// Uses Gemma 4 E2B — the lightest Gemma 4 model, designed for phones with
/// 4–6 GB of RAM — and EmbeddingGemma 2 for semantic search. Models load
/// lazily on first use and stay resident until unloaded.
final class LiteRtAiRuntime implements OnDeviceAiRuntime {
  LiteRtAiRuntime({
    required ComputeBackend backend,
    required ResumableDownloader downloader,
    required Directory modelsDirectory,
  }) : _backend = backend,
       _downloader = downloader,
       _modelsDirectory = modelsDirectory;

  final ResumableDownloader _downloader;

  /// Where model files are downloaded (and resumed from).
  final Directory _modelsDirectory;

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
  final _cancelled = <AiModelKind>{};
  final _llm = _LazyResource<InferenceModel>();
  final _embedder = _LazyResource<EmbeddingModel>();

  /// LiteRT-LM runs one generation at a time; requests queue here.
  Future<void> _generationQueue = Future.value();

  @override
  List<AiComponent> get components => [
    AiComponent(kind: AiModelKind.languageModel, sizeBytes: _llmVariant.file.sizeBytes),
    AiComponent(kind: AiModelKind.embedder, sizeBytes: _embedderVariant.model.sizeBytes),
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
  int downloadedBytes(AiModelKind kind) => isInstalled(kind)
      ? _artifactFor(kind).sizeBytes
      : ResumableDownloader.bytesOnDisk(_specFor(kind));

  @override
  Future<void> install(
    AiModelKind kind, {
    required void Function(int bytesOnDisk) onProgress,
  }) async {
    _cancelled.remove(kind);
    final File file;
    try {
      file = await _downloader.download(
        _specFor(kind),
        onProgress: onProgress,
        isCancelled: () => _cancelled.contains(kind),
      );
    } on DownloadCancelledException {
      throw const InstallCancelledException();
    } finally {
      _cancelled.remove(kind);
    }
    // The verified file is registered in place (no copy).
    switch (kind) {
      case AiModelKind.languageModel:
        await FlutterEdgeAi.installModel(
          modelType: _llmVariant.modelType,
          fileType: _llmVariant.fileType,
        ).fromFile(file.path).install();
      case AiModelKind.embedder:
        await FlutterEdgeAi.installEmbedder()
            .modelFromFile(file.path, filename: _embedderVariant.model.installFilename)
            .install();
    }
  }

  @override
  void cancelInstall(AiModelKind kind) => _cancelled.add(kind);

  @override
  Future<void> uninstall(AiModelKind kind) async {
    await unload(kind);
    if (isInstalled(kind)) {
      switch (kind) {
        case AiModelKind.languageModel:
          await FlutterEdgeAi.uninstallModel(_llmVariant.file.installFilename);
        case AiModelKind.embedder:
          await FlutterEdgeAi.uninstallEmbedder();
      }
    }
    await ResumableDownloader.deleteAll(_specFor(kind));
  }

  ModelArtifact _artifactFor(AiModelKind kind) => switch (kind) {
    AiModelKind.languageModel => _llmVariant.file,
    AiModelKind.embedder => _embedderVariant.model,
  };

  DownloadSpec _specFor(AiModelKind kind) {
    final artifact = _artifactFor(kind);
    return DownloadSpec(
      url: Uri.parse(artifact.url),
      target: File(p.join(_modelsDirectory.path, artifact.installFilename)),
      expectedBytes: artifact.sizeBytes,
      sha256: artifact.sha256,
    );
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
