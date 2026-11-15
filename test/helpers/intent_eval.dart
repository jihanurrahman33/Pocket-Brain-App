import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pocket_brain/domain/entities/task_item.dart';
import 'package:pocket_brain/domain/entities/user_intent.dart';
import 'package:pocket_brain/domain/services/ai_services.dart';
import 'package:pocket_brain/domain/services/intent_router.dart';
import 'package:pocket_brain/domain/services/task_resolver.dart';

/// The labelled set in `test/fixtures/intent_eval_set.json` and a scorer,
/// shared by the rules gate (unit test) and the real-model evaluation
/// (`integration_test/intent_eval_test.dart`).
final class IntentEvalSet {
  IntentEvalSet._(this.now, this.tasks, this.items);

  factory IntentEvalSet.load([String path = 'test/fixtures/intent_eval_set.json']) {
    final json = jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
    final now = DateTime.parse(json['now']! as String);
    final today = DateTime(now.year, now.month, now.day);
    final tasks = [
      for (final (i, t) in (json['tasks']! as List).cast<Map<String, Object?>>().indexed)
        TaskItem(
          id: 't$i',
          title: t['title']! as String,
          createdAt: now,
          isDone: t['done'] == true,
          dueAt: t['due'] is int ? today.add(Duration(days: t['due']! as int)) : null,
        ),
    ];
    final items = [
      for (final i in (json['items']! as List).cast<Map<String, Object?>>())
        EvalItem(
          text: i['text']! as String,
          intent: IntentType.fromWire(i['intent']! as String)!,
          title: i['title'] as String?,
          date: i['date'] is int ? today.add(Duration(days: i['date']! as int)) : null,
          ref: i['ref'] as String?,
          filter: i['filter'] as String?,
        ),
    ];
    return IntentEvalSet._(now, tasks, items);
  }

  final DateTime now;
  final List<TaskItem> tasks;
  final List<EvalItem> items;
}

final class EvalItem {
  const EvalItem({
    required this.text,
    required this.intent,
    this.title,
    this.date,
    this.ref,
    this.filter,
  });

  final String text;
  final IntentType intent;
  final String? title;
  final DateTime? date;
  final String? ref;
  final String? filter;
}

final class EvalOutcome {
  EvalOutcome(this.item, this.predicted, this.elapsed, this.slotErrors);

  final EvalItem item;
  final UserIntent? predicted;
  final Duration elapsed;
  final List<String> slotErrors;

  bool get intentCorrect => predicted?.type == item.intent;
  bool get fullyCorrect => intentCorrect && slotErrors.isEmpty;
}

final class EvalReport {
  EvalReport(this.outcomes);

  final List<EvalOutcome> outcomes;

  double get intentAccuracy => _share((o) => o.intentCorrect);
  double get fullAccuracy => _share((o) => o.fullyCorrect);

  double _share(bool Function(EvalOutcome) test) =>
      outcomes.isEmpty ? 0 : outcomes.where(test).length / outcomes.length;

  Duration get medianLatency {
    final sorted = [for (final o in outcomes) o.elapsed]..sort();
    return sorted.isEmpty ? Duration.zero : sorted[sorted.length ~/ 2];
  }

  String toMarkdown(String title) {
    final b = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln('- Messages: ${outcomes.length}')
      ..writeln('- Intent accuracy: ${(intentAccuracy * 100).toStringAsFixed(1)}%')
      ..writeln('- Intent + details accuracy: ${(fullAccuracy * 100).toStringAsFixed(1)}%')
      ..writeln('- Median time per message: ${medianLatency.inMilliseconds} ms')
      ..writeln()
      ..writeln('| Intent | Correct | Total |')
      ..writeln('|---|---|---|');
    for (final type in IntentType.values) {
      final of = outcomes.where((o) => o.item.intent == type).toList();
      if (of.isEmpty) continue;
      b.writeln('| ${type.wireName} | ${of.where((o) => o.intentCorrect).length} | ${of.length} |');
    }
    final wrong = outcomes.where((o) => !o.fullyCorrect).toList();
    if (wrong.isNotEmpty) {
      b
        ..writeln()
        ..writeln('## Misunderstood')
        ..writeln()
        ..writeln('| Message | Expected | Got | Problems |')
        ..writeln('|---|---|---|---|');
      for (final o in wrong) {
        b.writeln(
          '| ${o.item.text.replaceAll('|', '/')} | ${o.item.intent.wireName} | '
          '${o.predicted?.type.wireName ?? '(none)'} | ${o.slotErrors.join('; ')} |',
        );
      }
    }
    return b.toString();
  }
}

/// Scores [understand] on every item of [set].
Future<EvalReport> evaluate(
  IntentEvalSet set,
  Future<UserIntent?> Function(String text) understand,
) async {
  const resolver = TaskResolver(_NoEmbedder());
  final outcomes = <EvalOutcome>[];
  for (final item in set.items) {
    final watch = Stopwatch()..start();
    final predicted = await understand(item.text);
    watch.stop();
    final errors = <String>[];
    if (predicted != null && predicted.type == item.intent) {
      if (item.title case final expected?) {
        final words = expected.toLowerCase().split(' ');
        final got = predicted.title.toLowerCase();
        if (!words.every(got.contains)) errors.add('title "${predicted.title}"');
      }
      if (item.date case final expected? when predicted.date != expected) {
        errors.add('date ${predicted.date}');
      }
      if (item.filter case final expected?
          when (predicted.filter.isEmpty ? 'open' : predicted.filter) != expected) {
        errors.add('filter "${predicted.filter}"');
      }
      if (item.ref case final expected?) {
        final ref = predicted.taskRef.isEmpty ? item.text : predicted.taskRef;
        final found = await resolver.resolve(ref, set.tasks);
        if (found.length != 1 || found.single.title != expected) {
          errors.add('task "${found.map((t) => t.title).join(', ')}" from "$ref"');
        }
      }
    }
    outcomes.add(EvalOutcome(item, predicted, watch.elapsed, errors));
  }
  return EvalReport(outcomes);
}

/// The rules fast path alone, as `UnderstandMessage` uses it.
UserIntent? rulesOnly(String text, IntentEvalSet set) =>
    IntentRouter.understand(text, set.tasks, now: set.now);

final class _NoEmbedder implements TextEmbedder {
  const _NoEmbedder();

  @override
  bool get isAvailable => false;

  @override
  Future<Float32List?> embed(String text, EmbeddingPurpose purpose) async => null;
}
