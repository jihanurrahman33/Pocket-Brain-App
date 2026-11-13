import 'package:pocket_brain/core/logging/app_logger.dart';
import 'package:pocket_brain/core/utils/clock.dart';
import 'package:pocket_brain/core/utils/id_generator.dart';
import 'package:pocket_brain/data/datasources/ai/on_device_ai_runtime.dart';
import 'package:pocket_brain/domain/entities/ai_model.dart';
import 'package:pocket_brain/domain/entities/memory.dart';
import 'package:pocket_brain/domain/repositories/data_export_repository.dart';

/// A fixed point in time for deterministic tests.
final testNow = DateTime(2026, 11, 13, 10);

final class FixedClock implements Clock {
  FixedClock([DateTime? now]) : _now = now ?? testNow;

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);
}

final class SequentialIds implements IdGenerator {
  var _next = 0;

  @override
  String next() => 'id-${_next++}';
}

final class SilentLogger implements AppLogger {
  const SilentLogger();

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {}

  @override
  void info(String message) {}
}

/// An AI runtime with configurable install state and canned output.
final class FakeAiRuntime implements OnDeviceAiRuntime {
  FakeAiRuntime({this.installed = const {}, this.reply = const ['Answer [1].'], this.failOn});

  static const languageModelBytes = 2600;
  static const embedderBytes = 400;

  Set<AiModelKind> installed;
  List<String> reply;

  /// Installing this component throws, to simulate a failed download.
  AiModelKind? failOn;
  final requests = <GenerationRequest>[];
  final installOrder = <AiModelKind>[];
  final _cancelled = <AiModelKind>{};

  /// Bytes on disk for components not yet installed (a paused download).
  final partialBytes = <AiModelKind, int>{};

  @override
  List<AiComponent> get components => const [
    AiComponent(kind: AiModelKind.languageModel, sizeBytes: languageModelBytes),
    AiComponent(kind: AiModelKind.embedder, sizeBytes: embedderBytes),
  ];

  @override
  bool isInstalled(AiModelKind kind) => installed.contains(kind);

  @override
  bool isLoaded(AiModelKind kind) => false;

  int _size(AiModelKind kind) => components.firstWhere((c) => c.kind == kind).sizeBytes;

  @override
  int downloadedBytes(AiModelKind kind) =>
      installed.contains(kind) ? _size(kind) : partialBytes[kind] ?? 0;

  /// Downloads in thirds, resuming from [partialBytes] like the real runtime.
  @override
  Future<void> install(
    AiModelKind kind, {
    required void Function(int bytesOnDisk) onProgress,
  }) async {
    installOrder.add(kind);
    final size = _size(kind);
    var bytes = partialBytes[kind] ?? 0;
    onProgress(bytes);
    while (bytes < size) {
      await Future<void>.delayed(Duration.zero);
      if (_cancelled.remove(kind)) throw const InstallCancelledException();
      if (kind == failOn && bytes >= size ~/ 2) throw StateError('connection reset');
      bytes = (bytes + (size / 3).ceil()).clamp(0, size);
      partialBytes[kind] = bytes;
      onProgress(bytes);
    }
    partialBytes.remove(kind);
    installed = {...installed, kind};
  }

  @override
  void cancelInstall(AiModelKind kind) => _cancelled.add(kind);

  @override
  Future<void> uninstall(AiModelKind kind) async {
    installed = installed.where((k) => k != kind).toSet();
    partialBytes.remove(kind);
  }

  @override
  Future<void> unload(AiModelKind kind) async {}

  @override
  Future<void> useBackend(ComputeBackend backend) async {}

  @override
  Stream<String> generate(GenerationRequest request) {
    requests.add(request);
    return Stream.fromIterable(reply);
  }

  @override
  Future<List<double>> embed(String text, {required bool isQuery}) async => [1, 0, 0];

  @override
  Future<int> storageBytes() async => 0;
}

final class InMemoryExporter implements DataExportRepository {
  ExportBundle? last;

  @override
  Future<String> write(ExportBundle bundle) async {
    last = bundle;
    return '/tmp/export.json';
  }
}

Memory memoryFixture({
  String id = 'm1',
  String title = 'React project idea',
  String content = 'Build a habit tracker app with React and Supabase.',
  List<String> tags = const ['react', 'ideas'],
  String category = 'Ideas',
  DateTime? createdAt,
  String? collectionId,
}) {
  final at = createdAt ?? testNow;
  return Memory(
    id: id,
    title: title,
    content: content,
    tags: tags,
    category: category,
    createdAt: at,
    updatedAt: at,
    collectionId: collectionId,
  );
}
