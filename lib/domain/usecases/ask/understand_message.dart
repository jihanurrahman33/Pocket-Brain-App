import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../entities/task_item.dart';
import '../../entities/user_intent.dart';
import '../../repositories/intent_correction_repository.dart';
import '../../services/ai_services.dart';
import '../../services/due_date_parser.dart';
import '../../services/intent_router.dart';

typedef UnderstandRequest = ({
  String message,
  List<TaskItem> tasks,
  IntentContext context,
  IntentType? forcedIntent,
});

/// Decides what a message asks for (Understand step of Ask Brain).
///
/// Order: an intent the user chose ("Not what I meant") → the rules fast
/// path for phrasings they handle reliably → the model, constrained to a
/// JSON schema → rules as the fallback. Model dates are cross-checked
/// against the deterministic [DueDateParser].
final class UnderstandMessage implements UseCase<UserIntent, UnderstandRequest> {
  const UnderstandMessage({
    required IntentUnderstander understander,
    required IntentCorrectionRepository corrections,
    required Clock clock,
    required AppLogger logger,
  }) : _understander = understander,
       _corrections = corrections,
       _clock = clock,
       _logger = logger;

  final IntentUnderstander _understander;
  final IntentCorrectionRepository _corrections;
  final Clock _clock;
  final AppLogger _logger;

  /// Below this, a model decision counts as unsure and the user is asked.
  static const minConfidence = 0.45;

  /// Model intents that change data need more certainty than lookups.
  static const minConfidenceForChanges = 0.6;

  static const _changes = {
    IntentType.completeTask,
    IntentType.reopenTask,
    IntentType.rescheduleTask,
    IntentType.deleteTask,
  };

  @override
  Future<UserIntent> call(UnderstandRequest request) async {
    final now = _clock.now();
    final message = request.message;

    if (request.forcedIntent case final forced?) {
      final details = await _modelIntent(request, now);
      String nonEmpty(String? value, String fallback) =>
          (value ?? '').trim().isNotEmpty ? value!.trim() : fallback;
      return UserIntent(
        forced,
        title: nonEmpty(
          details?.title,
          IntentRouter.planTitle(message) ?? IntentRouter.titleFrom(message) ?? message,
        ),
        date: details?.date ?? DueDateParser.parse(message, now: now),
        time: details?.time ?? '',
        taskRef: nonEmpty(details?.taskRef, message),
        query: details?.query ?? '',
        note: nonEmpty(details?.note, message),
        filter: details?.filter ?? '',
        source: IntentSource.correction,
      );
    }

    if (IntentRouter.understand(message, request.tasks, now: now) case final fast?) return fast;

    final model = await _modelIntent(request, now);
    if (model == null) {
      return const UserIntent(IntentType.askMemory, confidence: 0.5, source: IntentSource.fallback);
    }
    final threshold = _changes.contains(model.type) ? minConfidenceForChanges : minConfidence;
    if (model.confidence < threshold && model.type != IntentType.askMemory) {
      return model.copyWith(type: IntentType.unclear);
    }
    return model;
  }

  Future<UserIntent?> _modelIntent(UnderstandRequest request, DateTime now) async {
    if (!_understander.isAvailable) return null;
    try {
      final intent = await _understander.understand(
        request.message,
        now: now,
        context: request.context,
        examples: await _corrections.recent(),
      );
      return intent == null ? null : _checkDate(intent, request.message, now);
    } on Object catch (e, s) {
      _logger.error('Understanding the message failed', e, s);
      return null;
    }
  }

  /// Phrases the parser knows ("tomorrow", "Friday") are computed exactly;
  /// the model's date is kept for the rest ("on the 20th") unless it is in
  /// the past.
  static UserIntent _checkDate(UserIntent intent, String message, DateTime now) {
    final parsed = DueDateParser.parse(message, now: now);
    if (parsed != null) return intent.copyWith(date: () => parsed);
    final today = DateTime(now.year, now.month, now.day);
    if (intent.date case final d? when d.isBefore(today)) return intent.copyWith(date: () => null);
    return intent;
  }
}

/// Remembers what the user said a message meant, so the model learns how
/// this user talks (on device only).
final class RecordIntentCorrection implements UseCase<void, IntentExample> {
  const RecordIntentCorrection(this._corrections);

  final IntentCorrectionRepository _corrections;

  @override
  Future<void> call(IntentExample example) => _corrections.add(example);
}
