import 'package:flutter_test/flutter_test.dart';

import '../helpers/intent_eval.dart';

/// CI gate for the rules fast path: whenever the rules claim a message they
/// must be right, because the model never sees it. Everything they do not
/// claim goes to the model (measured by `integration_test/intent_eval_test.dart`).
void main() {
  test('the rules fast path is precise on the labelled set', () async {
    final set = IntentEvalSet.load();
    final claimed = <EvalOutcome>[];
    final report = await evaluate(set, (text) async => rulesOnly(text, set));
    for (final o in report.outcomes) {
      if (o.predicted != null) claimed.add(o);
    }
    final wrong = claimed.where((o) => !o.intentCorrect).toList();
    final precision = 1 - wrong.length / claimed.length;
    // ignore: avoid_print
    print(
      'Rules fast path: claims ${claimed.length}/${report.outcomes.length} messages, '
      'precision ${(precision * 100).toStringAsFixed(1)}%',
    );
    expect(
      wrong.map(
        (o) => '"${o.item.text}": ${o.item.intent.wireName} ≠ ${o.predicted!.type.wireName}',
      ),
      isEmpty,
    );
  });

  test('every labelled item is well formed', () {
    final set = IntentEvalSet.load();
    expect(set.items.length, greaterThanOrEqualTo(150));
    final texts = set.items.map((i) => i.text.toLowerCase()).toList();
    expect(texts.toSet(), hasLength(texts.length), reason: 'no duplicates');
  });
}
