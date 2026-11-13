import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/core/navigation/app_routes.dart';
import 'package:pocket_brain/domain/entities/capture.dart';
import 'package:pocket_brain/domain/entities/memory.dart';
import 'package:pocket_brain/domain/usecases/collections/collection_usecases.dart';
import 'package:pocket_brain/features/ask/bloc/ask_bloc.dart';
import 'package:pocket_brain/features/capture/widgets/capture_input_form.dart';

import '../helpers/app_harness.dart';
import '../helpers/test_dependencies.dart';

void main() {
  setUp(configureTestDependencies);

  // Regression: "All memories" had a null value, which PopupMenuButton
  // treats as "cancelled", so the scope could never be reset.
  testWidgets('Ask scope can be switched back to All memories', (tester) async {
    await tester.runAsync(
      () => sl<CreateCollection>()((name: 'Books', emoji: '📚', isPrivate: false)),
    );
    await pumpAppAt(tester, const Size(1440, 900));
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(AppRoutes.ask);
    await settle(tester);

    final bloc = BlocProvider.of<AskBloc>(tester.element(find.byType(Scaffold).first));
    final books = bloc.state.collections.single;
    bloc.add(AskNewConversationRequested(collectionId: books.id));
    await settle(tester);
    expect(bloc.state.collectionId, books.id);

    await tester.tap(find.byKey(const Key('ask-scope-menu')));
    await settle(tester);
    await tester.tap(find.text('All memories').last);
    await settle(tester);
    expect(bloc.state.collectionId, isNull);
  });

  // Regression: the form must show restored text after a failed analysis.
  testWidgets('capture form restores the previous input', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CaptureInputForm(
            initialInput: CaptureInput(text: 'my precious note', source: MemorySource.note),
          ),
        ),
      ),
    );
    expect(find.text('my precious note'), findsOneWidget);
  });
}
