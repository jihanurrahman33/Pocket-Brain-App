import '../../../core/error/guard.dart';
import '../../../core/error/result.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/usecase/usecase.dart';
import '../../../core/utils/clock.dart';
import '../../entities/memory.dart';
import '../../entities/recall.dart';
import '../../entities/search.dart';
import '../../repositories/collection_repository.dart';
import '../../repositories/memory_repository.dart';
import '../../repositories/task_repository.dart';
import '../../services/ai_services.dart';

/// Smart-recall rules shared by Home and the Digest.
final class RecallPolicy {
  const RecallPolicy(this._memories);

  final MemoryRepository _memories;

  /// A memory is "forgotten" after this long without being opened.
  static const forgottenAfter = Duration(days: 14);
  static const week = Duration(days: 7);

  /// Memories saved on this calendar day in earlier years.
  Future<List<Memory>> onThisDay(DateTime now) async => [
    for (final m in await _memories.getAll())
      if (m.createdAt.year < now.year &&
          m.createdAt.month == now.month &&
          m.createdAt.day == now.day)
        m,
  ];

  Future<List<Memory>> forgotten(DateTime now, {required int limit}) =>
      _memories.notViewedSince(now.subtract(forgottenAfter), limit: limit);

  /// Memories saved in the last seven days including today.
  Future<List<Memory>> thisWeek(DateTime now) => _memories.savedBetween(
    now.startOfDay.subtract(week - const Duration(days: 1)),
    now.add(const Duration(minutes: 1)),
  );

  /// Tags ranked by how often they appear.
  static List<TopicCount> topTopics(List<Memory> memories, {required int limit}) {
    final counts = <String, int>{};
    for (final m in memories) {
      for (final t in m.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(limit)) TopicCount(e.key, e.value)];
  }
}

final class GetHomeOverview implements UseCase<Result<HomeOverview>, NoParams> {
  const GetHomeOverview({
    required MemoryRepository memories,
    required CollectionRepository collections,
    required TaskRepository tasks,
    required RecallPolicy recall,
    required Clock clock,
    required AppLogger logger,
  }) : _memories = memories,
       _collections = collections,
       _tasks = tasks,
       _recall = recall,
       _clock = clock,
       _logger = logger;

  final MemoryRepository _memories;
  final CollectionRepository _collections;
  final TaskRepository _tasks;
  final RecallPolicy _recall;
  final Clock _clock;
  final AppLogger _logger;

  static const recentLimit = 6;
  static const forgottenLimit = 3;
  static const collectionLimit = 6;
  static const taskLimit = 3;
  static const topicLimit = 4;

  @override
  Future<Result<HomeOverview>> call(NoParams _) => guard(_logger, 'Load home', () async {
    final now = _clock.now();
    final week = await _recall.thisWeek(now);
    final tasks = await _tasks.getAll();
    final collections = await _collections.getAll();
    return HomeOverview(
      memoryCount: await _memories.count(),
      recent: await _memories.query(const MemoryQuery(limit: recentLimit)),
      resurfaced: [
        ...await _recall.onThisDay(now),
        ...await _recall.forgotten(now, limit: forgottenLimit),
      ],
      collections: collections.take(collectionLimit).toList(),
      savedThisWeek: week.length,
      weekTopics: RecallPolicy.topTopics(week, limit: topicLimit),
      openTasks: tasks.where((t) => !t.isDone).take(taskLimit).toList(),
    );
  });
}

final class GetDigest implements UseCase<Result<Digest>, NoParams> {
  const GetDigest({
    required TaskRepository tasks,
    required RecallPolicy recall,
    required Clock clock,
    required AppLogger logger,
  }) : _tasks = tasks,
       _recall = recall,
       _clock = clock,
       _logger = logger;

  final TaskRepository _tasks;
  final RecallPolicy _recall;
  final Clock _clock;
  final AppLogger _logger;

  static const topicLimit = 6;
  static const revisitLimit = 5;

  @override
  Future<Result<Digest>> call(NoParams _) => guard(_logger, 'Load digest', () async {
    final now = _clock.now();
    final week = await _recall.thisWeek(now);
    final tasks = await _tasks.getAll();
    return Digest(
      today: week.where((m) => m.createdAt.isSameDay(now)).toList(),
      week: week,
      topics: RecallPolicy.topTopics(week, limit: topicLimit),
      onThisDay: await _recall.onThisDay(now),
      revisit: await _recall.forgotten(now, limit: revisitLimit),
      openTasks: tasks.where((t) => !t.isDone).toList(),
    );
  });
}

final class WriteWeeklyRecap implements UseCase<Result<String>, List<Memory>> {
  const WriteWeeklyRecap(this._writer, this._logger);

  final RecapWriter _writer;
  final AppLogger _logger;

  @override
  Future<Result<String>> call(List<Memory> week) =>
      guard(_logger, 'Write recap', () => _writer.write(week));
}
