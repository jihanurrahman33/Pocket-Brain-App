import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/core/bloc/load_state.dart';
import 'package:pocket_brain/core/error/result.dart';

/// Each fetch completes when the test says so, to simulate slow I/O.
class _ControlledCubit extends AutoRefreshCubit<String> {
  _ControlledCubit() : super(changes: const Stream.empty());

  final pending = <Completer<Result<String>>>[];

  @override
  Future<Result<String>> fetch() {
    final c = Completer<Result<String>>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  // Regression: overlapping reloads could finish out of order and show
  // stale data.
  test('a slow older load never overwrites a newer one', () async {
    final cubit = _ControlledCubit();
    final older = cubit.load();
    final newer = cubit.load();
    cubit.pending[1].complete(const Success('new'));
    await newer;
    cubit.pending[0].complete(const Success('old'));
    await older;
    expect(cubit.data, 'new');
    await cubit.close();
  });
}
