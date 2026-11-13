import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_brain/app/app.dart';

/// Pumps the whole app at a given window size.
Future<void> pumpAppAt(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const PocketBrainApp());
  await settle(tester);
}

/// Lets real database I/O finish (it runs outside the fake test clock),
/// then renders the resulting frames and finishes transitions.
Future<void> settle(WidgetTester tester, {int rounds = 4}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Waits (in real time) until [bloc] reaches a state matching [test],
/// instead of sleeping for a fixed duration.
Future<S> untilState<S>(
  BlocBase<S> bloc,
  bool Function(S state) test, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (test(bloc.state)) return bloc.state;
  return bloc.stream.firstWhere(test).timeout(timeout);
}
