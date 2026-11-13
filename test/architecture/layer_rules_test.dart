import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture fitness tests: they fail the build if a layer imports
/// something it must not depend on. See docs/architecture.md.
void main() {
  final importPattern = RegExp(r'''^import\s+'([^']+)';''', multiLine: true);

  /// `lib/<layer>/...` folders each file under [dir] imports.
  Map<String, Set<String>> importsUnder(String dir) {
    final result = <String, Set<String>>{};
    for (final file in Directory(dir).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      result[file.path] = {
        for (final m in importPattern.allMatches(source))
          _layerOf(m[1]!, from: file.parent.path) ?? m[1]!,
      };
    }
    return result;
  }

  void expectNoImports(String dir, bool Function(String import) forbidden, String rule) {
    final violations = [
      for (final MapEntry(key: file, value: imports) in importsUnder(dir).entries)
        for (final i in imports)
          if (forbidden(i)) '$file → $i',
    ];
    expect(violations, isEmpty, reason: rule);
  }

  test('core depends on no app layer', () {
    expectNoImports(
      'lib/core',
      (i) => const {'domain', 'data', 'features', 'app'}.contains(i),
      'core is shared infrastructure and must not know about the app',
    );
  });

  test('domain is pure Dart and depends only on core', () {
    expectNoImports(
      'lib/domain',
      (i) =>
          const {'data', 'features', 'app'}.contains(i) ||
          i.startsWith('package:flutter/') ||
          i.startsWith('package:flutter_bloc') ||
          i.startsWith('package:sqflite') ||
          i.startsWith('package:flutter_edge_ai') ||
          i.startsWith('package:http'),
      'domain must not depend on Flutter, I/O packages or outer layers',
    );
  });

  test('data never depends on presentation or use cases', () {
    expectNoImports(
      'lib/data',
      (i) => const {'features', 'app', 'domain/usecases'}.contains(i),
      'data implements domain interfaces only',
    );
  });

  test('presentation reaches data only through the composition root', () {
    expectNoImports(
      'lib/features',
      (i) =>
          i == 'data' || i.startsWith('package:flutter_edge_ai') || i.startsWith('package:sqflite'),
      'features talk to use cases, never to data sources',
    );
  });

  test('presentation uses use cases, not repositories or services', () {
    expectNoImports(
      'lib/features',
      (i) => i == 'domain/repositories' || i == 'domain/services',
      'blocs and widgets depend on use cases (Dependency Inversion)',
    );
  });
}

/// Maps a relative import to its top-level layer, e.g. `domain`,
/// `domain/usecases`, `data`, `features`. Returns null for package imports.
String? _layerOf(String import, {required String from}) {
  if (import.startsWith('package:') || import.startsWith('dart:')) return null;
  final resolved = File('$from/$import').absolute.uri.normalizePath().path;
  final lib = Directory('lib').absolute.uri.path;
  if (!resolved.startsWith(lib)) return null;
  final parts = resolved.substring(lib.length).split('/');
  if (parts.first == 'domain' && parts.length > 2) return 'domain/${parts[1]}';
  return parts.first;
}
