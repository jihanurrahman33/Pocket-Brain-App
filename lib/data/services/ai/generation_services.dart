import 'dart:typed_data';

import '../../../core/logging/app_logger.dart';
import '../../../core/utils/text_utils.dart';
import '../../../domain/entities/ask.dart';
import '../../../domain/entities/memory.dart';
import '../../../domain/services/ai_services.dart';
import '../../../domain/services/topic_ranker.dart';
import '../../datasources/ai/on_device_ai_runtime.dart';
import 'prompts/prompts.dart';

/// Ask Brain answers from Gemma.
final class GemmaAnswerGenerator implements AnswerGenerator {
  const GemmaAnswerGenerator(this._runtime);

  final OnDeviceAiRuntime _runtime;

  @override
  bool get isAvailable => _runtime.isInstalled(AiModelKind.languageModel);

  @override
  Stream<String> generate(AnswerPrompt prompt) =>
      _runtime.generate(AnswerPromptBuilder.build(prompt));
}

/// Factual recap without a model.
final class RuleBasedRecapWriter implements RecapWriter {
  const RuleBasedRecapWriter();

  static const _topicCount = 3;

  @override
  Future<String> write(List<Memory> memories) async {
    if (memories.isEmpty) return 'You have not saved anything this week yet.';
    final topics = TopicRanker.rank(memories, limit: _topicCount).map((t) => t.topic);
    final n = memories.length;
    return 'You saved $n ${n == 1 ? 'memory' : 'memories'} this week'
        '${topics.isEmpty ? '.' : ', mostly about ${topics.join(', ')}.'}';
  }
}

/// A narrative recap from Gemma.
final class GemmaRecapWriter implements RecapWriter {
  const GemmaRecapWriter(this._runtime);

  final OnDeviceAiRuntime _runtime;

  @override
  Future<String> write(List<Memory> memories) async =>
      (await _runtime.generate(RecapPrompt.build(memories)).join()).trim();
}

/// Uses Gemma when installed and there is something to recap; otherwise,
/// or on failure, the rule-based writer (Decorator).
final class FallbackRecapWriter implements RecapWriter {
  const FallbackRecapWriter({
    required RecapWriter primary,
    required RecapWriter fallback,
    required bool Function() isPrimaryAvailable,
    required AppLogger logger,
  }) : _primary = primary,
       _fallback = fallback,
       _isPrimaryAvailable = isPrimaryAvailable,
       _logger = logger;

  final RecapWriter _primary;
  final RecapWriter _fallback;
  final bool Function() _isPrimaryAvailable;
  final AppLogger _logger;

  @override
  Future<String> write(List<Memory> memories) async {
    if (memories.isEmpty || !_isPrimaryAvailable()) return _fallback.write(memories);
    try {
      return await _primary.write(memories);
    } on Object catch (e, s) {
      _logger.error('Recap generation failed; using fallback', e, s);
      return _fallback.write(memories);
    }
  }
}

/// Semantic vectors from EmbeddingGemma.
final class EmbeddingGemmaTextEmbedder implements TextEmbedder {
  const EmbeddingGemmaTextEmbedder(this._runtime, this._logger);

  final OnDeviceAiRuntime _runtime;
  final AppLogger _logger;

  static const _maxInputChars = 2000;

  @override
  bool get isAvailable => _runtime.isInstalled(AiModelKind.embedder);

  @override
  Future<Float32List?> embed(String text, EmbeddingPurpose purpose) async {
    if (!isAvailable) return null;
    try {
      final vector = await _runtime.embed(
        TextUtils.truncate(text, _maxInputChars),
        isQuery: purpose == EmbeddingPurpose.query,
      );
      return Float32List.fromList(vector);
    } on Object catch (e, s) {
      _logger.error('Embedding failed', e, s);
      return null;
    }
  }
}
