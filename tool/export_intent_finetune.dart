// Exports the labelled intent set as JSONL for fine-tuning a small
// function-calling router (e.g. FunctionGemma 270M, also in the LiteRT-LM
// catalog). Each line is one chat whose answer is a single function call.
//
//   dart run tool/export_intent_finetune.dart [out.jsonl]
//
// Pure Dart: no Flutter needed.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final source = File('test/fixtures/intent_eval_set.json');
  final out = File(args.isEmpty ? 'build/intent_finetune.jsonl' : args.first)
    ..createSync(recursive: true);
  final json = jsonDecode(source.readAsStringSync()) as Map<String, Object?>;
  final now = DateTime.parse(json['now']! as String);
  String day(int offset) =>
      DateTime(now.year, now.month, now.day + offset).toIso8601String().substring(0, 10);

  final lines = <String>[];
  for (final item in (json['items']! as List).cast<Map<String, Object?>>()) {
    final arguments = <String, Object?>{
      if (item['title'] case final String title) 'title': title,
      if (item['date'] case final int offset) 'date': day(offset),
      if (item['ref'] case final String ref) 'task_ref': ref,
      if (item['filter'] case final String filter) 'filter': filter,
    };
    lines.add(
      jsonEncode({
        'messages': [
          {'role': 'developer', 'content': 'Today is ${day(0)}. Route the message to one function.'},
          {'role': 'user', 'content': item['text']},
        ],
        'tool_call': {'name': item['intent'], 'arguments': arguments},
      }),
    );
  }
  out.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('Wrote ${lines.length} examples to ${out.path}');
}
