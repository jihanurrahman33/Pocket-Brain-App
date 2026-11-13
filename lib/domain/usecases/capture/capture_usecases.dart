import 'dart:async';

import '../../../core/error/failure.dart';
import '../../../core/error/guard.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/id_generator.dart';
import '../../entities/capture.dart';
import '../../entities/memory.dart';
import '../../entities/memory_analysis.dart';
import '../../entities/task_item.dart';
import '../../repositories/memory_repository.dart';
import '../../repositories/preferences_repository.dart';
import '../../repositories/task_repository.dart';
import '../../services/ai_services.dart';
import '../indexing/indexing_usecases.dart';
import '../search/search_usecases.dart';

/// Turns raw input into a reviewable [CaptureDraft]. Nothing is saved.
final class AnalyzeCapture implements UseCase<Result<CaptureDraft>, CaptureInput> {
  AnalyzeCapture({
    required LinkReader linkReader,
    required MemoryAnalyzer analyzer,
    required PreferencesRepository preferences,
    required FindSimilarMemories findSimilar,
    required Clock clock,
    required AppLogger logger,
  }) : _linkReader = linkReader,
       _analyzer = analyzer,
       _preferences = preferences,
       _findSimilar = findSimilar,
       _clock = clock,
       _logger = logger;

  final LinkReader _linkReader;
  final MemoryAnalyzer _analyzer;
  final PreferencesRepository _preferences;
  final FindSimilarMemories _findSimilar;
  final Clock _clock;
  final AppLogger _logger;

  static const _similarLimit = 3;

  @override
  Future<Result<CaptureDraft>> call(CaptureInput input) async {
    if (input.isEmpty) {
      return const Err(ValidationFailure('Write something or paste a link first.'));
    }
    return guard(_logger, 'Analyze capture', () async {
      final content = await _resolveContent(input);
      final analysis = _preferences.aiSuggestionsEnabled
          ? await _analyzer.analyze(content, now: _clock.now())
          : _plainAnalysis(content);
      final similar = await _findSimilar(SimilarityQuery(text: content, limit: _similarLimit));
      return CaptureDraft(
        content: content,
        source: input.source,
        url: input.url?.trim(),
        analysis: analysis,
        similar: similar,
      );
    });
  }

  /// For links, prepends the page title and appends readable page text so
  /// the AI can summarise the article.
  Future<String> _resolveContent(CaptureInput input) async {
    final text = input.text.trim();
    final url = input.url?.trim();
    if (input.source != MemorySource.link || url == null || url.isEmpty) return text;
    final page = await _linkReader.read(url);
    final parts = [?page?.title, if (text.isNotEmpty) text, ?page?.text];
    return parts.isEmpty ? url : parts.join('\n\n');
  }

  static MemoryAnalysis _plainAnalysis(String content) => MemoryAnalysis(
    title: content.split('\n').first.trim(),
    summary: '',
    category: MemoryCategories.fallback,
    tags: const [],
    origin: AnalysisOrigin.none,
  );
}

/// Persists a reviewed capture, its confirmed tasks and (in the
/// background) its embedding.
final class SaveCapture implements UseCase<Result<Memory>, SaveCaptureRequest> {
  SaveCapture({
    required MemoryRepository memories,
    required TaskRepository tasks,
    required IndexMemory indexMemory,
    required IdGenerator ids,
    required Clock clock,
    required AppLogger logger,
  }) : _memories = memories,
       _tasks = tasks,
       _indexMemory = indexMemory,
       _ids = ids,
       _clock = clock,
       _logger = logger;

  final MemoryRepository _memories;
  final TaskRepository _tasks;
  final IndexMemory _indexMemory;
  final IdGenerator _ids;
  final Clock _clock;
  final AppLogger _logger;

  static const untitled = 'Untitled memory';

  @override
  Future<Result<Memory>> call(SaveCaptureRequest request) =>
      guard(_logger, 'Save capture', () async {
        final now = _clock.now();
        final title = request.title.trim();
        final memory = Memory(
          id: _ids.next(),
          title: title.isEmpty ? untitled : title,
          content: request.content,
          summary: request.summary.trim(),
          source: request.source,
          sourceUrl: request.url,
          category: request.category,
          tags: request.tags,
          collectionId: request.collectionId,
          createdAt: now,
          updatedAt: now,
          aiGenerated: request.acceptedAiAsIs,
        );
        await _memories.save(memory);
        for (final task in request.tasks.where((t) => t.selected)) {
          await _tasks.save(
            TaskItem(
              id: _ids.next(),
              title: task.title,
              dueAt: task.dueAt,
              memoryId: memory.id,
              createdAt: now,
            ),
          );
        }
        // Background: search works by keywords until the vector is ready.
        unawaited(_indexMemory(memory));
        return memory;
      });
}
