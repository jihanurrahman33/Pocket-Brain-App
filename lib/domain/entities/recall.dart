import 'package:equatable/equatable.dart';

import 'memory.dart';
import 'memory_collection.dart';
import 'task_item.dart';

/// How often a topic (tag) appeared in a period.
class TopicCount extends Equatable {
  const TopicCount(this.topic, this.count);

  final String topic;
  final int count;

  @override
  List<Object?> get props => [topic, count];
}

/// Everything the Home screen shows.
class HomeOverview extends Equatable {
  const HomeOverview({
    required this.memoryCount,
    required this.recent,
    required this.resurfaced,
    required this.collections,
    required this.savedThisWeek,
    required this.weekTopics,
    required this.openTasks,
  });

  final int memoryCount;
  final List<Memory> recent;

  /// "On this day" memories followed by forgotten ones.
  final List<Memory> resurfaced;
  final List<MemoryCollection> collections;
  final int savedThisWeek;
  final List<TopicCount> weekTopics;
  final List<TaskItem> openTasks;

  bool get isEmpty => memoryCount == 0;

  @override
  List<Object?> get props => [
    memoryCount,
    recent,
    resurfaced,
    collections,
    savedThisWeek,
    weekTopics,
    openTasks,
  ];
}

/// The Daily Digest screen's content.
class Digest extends Equatable {
  const Digest({
    required this.today,
    required this.week,
    required this.topics,
    required this.onThisDay,
    required this.revisit,
    required this.openTasks,
  });

  final List<Memory> today;
  final List<Memory> week;
  final List<TopicCount> topics;
  final List<Memory> onThisDay;
  final List<Memory> revisit;
  final List<TaskItem> openTasks;

  @override
  List<Object?> get props => [today, week, topics, onThisDay, revisit, openTasks];
}

/// Tasks grouped for the Tasks & Reminders screen.
class TaskBoard extends Equatable {
  const TaskBoard({
    required this.overdue,
    required this.upcoming,
    required this.anytime,
    required this.completed,
    required this.sourceMemories,
  });

  final List<TaskItem> overdue;
  final List<TaskItem> upcoming;

  /// Open tasks without a deadline.
  final List<TaskItem> anytime;
  final List<TaskItem> completed;

  /// The memory each task came from, by memory id.
  final Map<String, Memory> sourceMemories;

  bool get isEmpty => overdue.isEmpty && upcoming.isEmpty && anytime.isEmpty && completed.isEmpty;

  @override
  List<Object?> get props => [overdue, upcoming, anytime, completed, sourceMemories];
}

/// A memory with everything its detail screen needs.
class MemoryDetails extends Equatable {
  const MemoryDetails({
    required this.memory,
    required this.related,
    required this.tasks,
    required this.collections,
  });

  final Memory memory;
  final List<Memory> related;
  final List<TaskItem> tasks;
  final List<MemoryCollection> collections;

  MemoryCollection? get collection =>
      collections.where((c) => c.id == memory.collectionId).firstOrNull;

  @override
  List<Object?> get props => [memory, related, tasks, collections];
}
