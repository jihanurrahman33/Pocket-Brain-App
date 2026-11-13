import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pocket_brain/app/app.dart';
import 'package:pocket_brain/app/di/injection.dart';
import 'package:pocket_brain/core/navigation/app_routes.dart';
import 'package:pocket_brain/domain/entities/task_item.dart';
import 'package:pocket_brain/domain/repositories/memory_repository.dart';
import 'package:pocket_brain/domain/repositories/task_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/test_dependencies.dart';

/// Window sizes covering every Material window size class.
const _sizes = {
  'phone': Size(390, 844),
  'small phone': Size(320, 640),
  'tablet': Size(800, 1100),
  'laptop': Size(1024, 768),
  'desktop': Size(1440, 900),
};

const _routes = [
  AppRoutes.home,
  AppRoutes.brain,
  AppRoutes.capture,
  AppRoutes.ask,
  AppRoutes.search,
  AppRoutes.tasks,
  AppRoutes.digest,
  AppRoutes.settings,
];

Future<void> _seed() async {
  final memories = sl<MemoryRepository>();
  for (var i = 0; i < 6; i++) {
    await memories.save(
      memoryFixture(
        id: 'm$i',
        title: 'A fairly long memory title number $i that should ellipsize nicely',
        tags: const ['react', 'ideas', 'learning'],
      ),
    );
  }
  await sl<TaskRepository>().save(
    TaskItem(id: 't1', title: 'Finish the book', createdAt: testNow, dueAt: DateTime(2026, 12, 15)),
  );
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const PocketBrainApp());
  await _settle(tester);
}

/// Lets real database I/O finish (it runs outside the fake test clock),
/// then renders the resulting frames and finishes page transitions.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUp(() async {
    await configureTestDependencies();
    await _seed();
  });

  testWidgets('phones get a bottom bar, wider windows a rail', (tester) async {
    await _pumpAt(tester, _sizes['phone']!);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await _pumpAt(tester, _sizes['desktop']!);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    testWidgets('every screen lays out without overflow on $name', (tester) async {
      await _pumpAt(tester, size);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      for (final route in [..._routes, AppRoutes.memory('m0')]) {
        router.go(route);
        await _settle(tester);
        // Overflow or layout errors surface as exceptions here.
        expect(tester.takeException(), isNull, reason: '$route at $name');
      }
    });
  }
}
