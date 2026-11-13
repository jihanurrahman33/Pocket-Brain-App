import '../../../core/error/guard.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../repositories/change_notifier.dart';
import '../../repositories/collection_repository.dart';
import '../../repositories/conversation_repository.dart';
import '../../repositories/data_export_repository.dart';
import '../../repositories/memory_repository.dart';
import '../../repositories/preferences_repository.dart';
import '../../repositories/task_repository.dart';

final class GetAiSuggestionsEnabled implements UseCase<bool, NoParams> {
  const GetAiSuggestionsEnabled(this._preferences);

  final PreferencesRepository _preferences;

  @override
  Future<bool> call(NoParams _) async => _preferences.aiSuggestionsEnabled;
}

final class SetAiSuggestionsEnabled implements UseCase<void, bool> {
  const SetAiSuggestionsEnabled(this._preferences);

  final PreferencesRepository _preferences;

  @override
  Future<void> call(bool enabled) => _preferences.setAiSuggestionsEnabled(enabled);
}

/// Exports every memory, collection, task and conversation as one file.
final class ExportData implements UseCase<Result<String>, NoParams> {
  const ExportData({
    required MemoryRepository memories,
    required CollectionRepository collections,
    required TaskRepository tasks,
    required ConversationRepository conversations,
    required DataExportRepository exporter,
    required Clock clock,
    required AppLogger logger,
  }) : _memories = memories,
       _collections = collections,
       _tasks = tasks,
       _conversations = conversations,
       _exporter = exporter,
       _clock = clock,
       _logger = logger;

  final MemoryRepository _memories;
  final CollectionRepository _collections;
  final TaskRepository _tasks;
  final ConversationRepository _conversations;
  final DataExportRepository _exporter;
  final Clock _clock;
  final AppLogger _logger;

  @override
  Future<Result<String>> call(NoParams _) => guard(_logger, 'Export', () async {
    return _exporter.write(
      ExportBundle(
        exportedAt: _clock.now(),
        memories: await _memories.getAll(includeArchived: true),
        collections: await _collections.getAll(),
        tasks: await _tasks.getAll(),
        conversations: await _conversations.getAll(),
      ),
    );
  });
}

/// Permanently deletes all user data. Downloaded models are kept.
///
/// Depends on the [Clearable] abstraction, so new stores are added at the
/// composition root without changing this class (Open/Closed).
final class WipeAllData implements UseCase<Result<void>, NoParams> {
  const WipeAllData(this._stores, this._logger);

  /// Ordered so dependants are cleared before what they reference.
  final List<Clearable> _stores;
  final AppLogger _logger;

  @override
  Future<Result<void>> call(NoParams _) => guard(_logger, 'Wipe data', () async {
    for (final store in _stores) {
      await store.clear();
    }
  });
}
