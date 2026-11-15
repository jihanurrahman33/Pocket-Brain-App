import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/user_intent.dart';
import '../../../domain/repositories/task_repository.dart';
import '../../../domain/services/ai_services.dart';
import '../../datasources/ai/on_device_ai_runtime.dart';
import 'parsers/intent_response_parser.dart';
import 'prompts/intent_prompt.dart';

/// Understands messages with Gemma, constrained to the intent JSON schema.
final class GemmaIntentUnderstander implements IntentUnderstander {
  const GemmaIntentUnderstander(this._runtime, this._tasks, this._logger);

  final OnDeviceAiRuntime _runtime;
  final TaskRepository _tasks;
  final AppLogger _logger;

  @override
  bool get isAvailable => _runtime.isUsable(AiModelKind.languageModel);

  @override
  Future<UserIntent?> understand(
    String message, {
    required DateTime now,
    IntentContext context = IntentContext.empty,
    List<IntentExample> examples = const [],
  }) async {
    final open = (await _tasks.getAll()).where((t) => !t.isDone).toList();
    final raw = await _runtime
        .generate(
          IntentPrompt.build(
            message,
            now: now,
            openTasks: open,
            context: context,
            examples: examples,
          ),
        )
        .join();
    final intent = IntentResponseParser.parse(raw);
    if (intent == null) _logger.info('Could not parse the intent from: $raw');
    return intent;
  }
}
