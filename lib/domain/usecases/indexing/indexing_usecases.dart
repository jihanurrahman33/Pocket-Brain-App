import 'dart:typed_data';

import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../entities/memory.dart';
import '../../repositories/memory_repository.dart';
import '../../services/ai_services.dart';

/// Computes and stores the semantic vector of one memory.
///
/// Never throws, so callers may run it in the background. Returns null when
/// the embedder is unavailable or indexing failed; search still works by
/// keywords in that case.
final class IndexMemory implements UseCase<Float32List?, Memory> {
  const IndexMemory(this._embedder, this._metadata, this._logger);

  final TextEmbedder _embedder;
  final MemoryMetadataStore _metadata;
  final AppLogger _logger;

  @override
  Future<Float32List?> call(Memory memory) async {
    try {
      final vector = await _embedder.embed(memory.searchableText, EmbeddingPurpose.document);
      if (vector != null) await _metadata.setEmbedding(memory.id, vector);
      return vector;
    } on Object catch (e, s) {
      _logger.error('Indexing ${memory.id} failed', e, s);
      return null;
    }
  }
}

/// Embeds memories saved before the embedder was installed.
final class IndexPendingMemories implements UseCase<int, NoParams> {
  IndexPendingMemories({
    required TextEmbedder embedder,
    required MemoryMetadataStore metadata,
    required IndexMemory indexMemory,
    required AppLogger logger,
  }) : _embedder = embedder,
       _metadata = metadata,
       _indexMemory = indexMemory,
       _logger = logger;

  final TextEmbedder _embedder;
  final MemoryMetadataStore _metadata;
  final IndexMemory _indexMemory;
  final AppLogger _logger;
  bool _running = false;

  /// Returns how many memories were indexed.
  @override
  Future<int> call(NoParams _) async {
    if (_running || !_embedder.isAvailable) return 0;
    _running = true;
    var indexed = 0;
    try {
      for (final memory in await _metadata.withoutEmbedding()) {
        if (await _indexMemory(memory) != null) indexed++;
      }
      if (indexed > 0) _logger.info('Indexed $indexed memories');
    } on Object catch (e, s) {
      _logger.error('Background indexing failed', e, s);
    } finally {
      _running = false;
    }
    return indexed;
  }
}
