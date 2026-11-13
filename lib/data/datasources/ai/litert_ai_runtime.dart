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
/// 4–6 GB of RAM — or, at [AiQuality.high] on devices with more memory,
/// Gemma 4 E4B; and EmbeddingGemma 2 for semantic search. Models load lazily
/// on first use and stay resident until unloaded.
///
/// Call [restore] once at startup, before use.
final class LiteRtAiRuntime implements OnDeviceAiRuntime {
  LiteRtAiRuntime({
    required ComputeBackend backend,
    required AiQuality quality,
    required ResumableDownloader downloader,
    required Directory modelsDirectory,
  }) : _backend = backend,
       _quality = quality,
       _downloader = downloader,
       _modelsDirectory = modelsDirectory;

  final ResumableDownloader _downloader;

  /// Where model files are downloaded (and resumed from).
  final Directory _modelsDirectory;

  static final _llmVariants = {
    AiQuality.standard: LiteRtLmModels.gemma4E2bIt.generic,
    AiQuality.high: LiteRtLmModels.gemma4E4bIt.generic,
  };
  static final _embedderVariant = LiteRtEmbedders.embeddinggemma2Text270m.generic;

  /// Room for several retrieved memories plus an answer, at modest RAM cost.
  static const _contextTokens = 4096;

  /// Registers the engines. Call once at startup.
  static Future<void> initialize() => FlutterEdgeAi.initialize(
    inferenceEngines: [const LiteRtLmEngine()],
    embeddingBackends: [const LiteRtEmbeddingBackend()],
  );

  ComputeBackend _backend;
  AiQuality _quality;

  /// Language model files registered with the engine (by install filename).
  final _installedLlmFiles = <String>{};

  LiteRtLmVariant get _llmVariant => _llmVariants[_quality]!;

  /// Reads which language models are installed. Call once at startup.
  Future<void> restore() async {
    final installed = await FlutterEdgeAi.listInstalledModels();
    _installedLlmFiles
      ..clear()
      ..addAll(
        installed.where((id) => _llmVariants.values.any((v) => v.file.installFilename == id)),
      );
  }

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
    AiModelKind.languageModel =>
      FlutterEdgeAi.hasActiveModel() &&
          _installedLlmFiles.contains(_llmVariant.file.installFilename),
    AiModelKind.embedder => FlutterEdgeAi.hasActiveEmbedder(),
  };

  @override
  bool isUsable(AiModelKind kind) => switch (kind) {
    AiModelKind.languageModel => FlutterEdgeAi.hasActiveModel(),
    AiModelKind.embedder => FlutterEdgeAi.hasActiveEmbedder(),
  };

  @override
  Future<void> useQuality(AiQuality quality) async {
    if (quality == _quality) return;
    _quality = quality;
    // A partial download of the quality just left is not needed any more.
    for (final variant in _llmVariants.values) {
      if (variant != _llmVariant) await ResumableDownloader.deletePartial(_llmSpec(variant));
    }
  }

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
        _installedLlmFiles.add(_llmVariant.file.installFilename);
        await _removeOtherLanguageModels();
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
    switch (kind) {
      case AiModelKind.languageModel:
        for (final variant in _llmVariants.values) {
          await _uninstallLanguageModel(variant);
        }
      case AiModelKind.embedder:
        if (FlutterEdgeAi.hasActiveEmbedder()) await FlutterEdgeAi.uninstallEmbedder();
        await ResumableDownloader.deleteAll(_specFor(kind));
    }
  }

  /// After a quality switch, frees the space of the model no longer used.
  Future<void> _removeOtherLanguageModels() async {
    // The resident instance may be the old model.
    await unload(AiModelKind.languageModel);
    for (final variant in _llmVariants.values) {
      if (variant != _llmVariant) await _uninstallLanguageModel(variant);
    }
  }

  Future<void> _uninstallLanguageModel(LiteRtLmVariant variant) async {
    final name = variant.file.installFilename;
    if (_installedLlmFiles.remove(name)) await FlutterEdgeAi.uninstallModel(name);
    await ResumableDownloader.deleteAll(_llmSpec(variant));
  }

  ModelArtifact _artifactFor(AiModelKind kind) => switch (kind) {
    AiModelKind.languageModel => _llmVariant.file,
    AiModelKind.embedder => _embedderVariant.model,
  };

  DownloadSpec _specFor(AiModelKind kind) => _spec(_artifactFor(kind));

  DownloadSpec _llmSpec(LiteRtLmVariant variant) => _spec(variant.file);

  DownloadSpec _spec(ModelArtifact artifact) {
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
  Stream<String> generate(GenerationRequest request) =>
      _serialized((out) => _runGeneration(request, out));

  @override
  Stream<String> chatWithTools(ToolChatRequest request) =>
      _serialized((out) => _runToolChat(request, out));

  /// Runs one generation at a time (LiteRT-LM serves one session at once)
  /// and adapts it to a cancellable stream.
  Stream<String> _serialized(Future<void> Function(StreamController<String> out) body) {
    final controller = StreamController<String>();
    final run = _generationQueue.then((_) async {
      try {
        await body(controller);
      } on Object catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
      } finally {
        if (!controller.isClosed) await controller.close();
      }
    });
    _generationQueue = run.catchError((Object _) {});
    controller.onCancel = () async {
      if (!controller.isClosed) await controller.close();
    };
    return controller.stream;
  }

  Future<void> _runGeneration(GenerationRequest request, StreamController<String> out) async {
    final model = await _languageModel(image: request.image != null, audio: request.audio != null);
    InferenceModelSession? session;
    try {
      session = await model.openSession(
        systemInstruction: request.systemInstruction,
        temperature: request.temperature,
        maxOutputTokens: request.maxOutputTokens,
        enableVisionModality: request.image != null ? true : null,
        enableAudioModality: request.audio != null ? true : null,
        responseFormat: _supportedFormat(model, request.jsonSchema),
      );
      await session.addQueryChunk(
        Message(
          text: request.prompt,
          isUser: true,
          imageBytes: request.image,
          audioBytes: request.audio,
        ),
      );
      await for (final token in session.getResponseAsync()) {
        if (out.isClosed) break;
        out.add(token);
      }
    } finally {
      await session?.close();
      // Media encoders are large: free them right away. The next text-only
      // request reloads the lighter text model.
      if (request.hasMedia) await unload(AiModelKind.languageModel);
    }
  }

  /// The schema as an engine-enforced format, or null when this model or
  /// platform cannot enforce it (the prompt still asks for JSON).
  ResponseFormat? _supportedFormat(InferenceModel model, Map<String, Object?>? schema) {
    if (schema == null) return null;
    final format = ResponseFormat.jsonSchema(schema);
    return model.refusalFor(format) == null ? format : null;
  }

  Future<void> _runToolChat(ToolChatRequest request, StreamController<String> out) async {
    final model = await _languageModel();
    final chat = await model.openChat(
      systemInstruction: request.systemInstruction,
      maxOutputTokens: request.maxOutputTokens,
      supportsFunctionCalls: true,
      tools: [
        for (final t in request.tools)
          Tool(name: t.name, description: t.description, parameters: t.parameters),
      ],
    );
    try {
      await chat.addQueryChunk(Message(text: request.prompt, isUser: true));
      final answer = StringBuffer();
      await for (final response in chat.generateChatResponseWithTools(
        onToolCall: (call) {
          // Text written before a call is not the answer: reset the snapshot.
          answer.clear();
          if (!out.isClosed) out.add('');
          return request.onToolCall(call.name, Map<String, Object?>.from(call.args));
        },
        maxToolTurns: request.maxToolTurns,
      )) {
        if (response is TextResponse && !out.isClosed) {
          answer.write(response.token);
          out.add(answer.toString());
        }
      }
    } finally {
      await chat.close();
    }
  }

  bool _loadedWithImage = false;
  bool _loadedWithAudio = false;

  /// The language model with at least the requested encoders, reloading
  /// when the resident instance lacks one.
  Future<InferenceModel> _languageModel({bool image = false, bool audio = false}) async {
    final missingEncoder = (image && !_loadedWithImage) || (audio && !_loadedWithAudio);
    if (_llm.isLoaded && missingEncoder) await unload(AiModelKind.languageModel);
    return _llm.obtain(() async {
      final model = await FlutterEdgeAi.getActiveModel(
        maxTokens: _contextTokens,
        preferredBackend: switch (_backend) {
          ComputeBackend.cpu => PreferredBackend.cpu,
          ComputeBackend.gpu => PreferredBackend.gpu,
        },
        supportImage: image,
        supportAudio: audio,
      );
      _loadedWithImage = image;
      _loadedWithAudio = audio;
      return model;
    });
  }

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
