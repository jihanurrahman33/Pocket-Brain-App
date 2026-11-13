# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.
Read this before changing code. Deeper detail lives in `docs/`.

## Project

Pocket Brain is a Flutter app (Linux desktop + Android) that stores personal
notes locally and uses on-device Gemma models via `flutter_edge_ai_litertlm`.
State management is BLoC; dependency injection is `get_it`; storage is SQLite.

## Commands

```bash
flutter pub get
flutter analyze                             # must report "No issues found!"
dart format --set-exit-if-changed lib test  # page width 100 (see analysis_options.yaml)
flutter test                                # all tests must pass
flutter run -d linux                        # run the app
```

Run all three checks (analyze, format, test) before declaring work done.

### Live development with the Dart & Flutter MCP server

Agents that support MCP should use the official Dart and Flutter MCP server
(`dart mcp-server`). For Claude Code, install the plugin:

```bash
claude plugin marketplace add flutter/agent-plugins
claude plugin install dart-flutter@dart-flutter
```

With the app running (`flutter run -d linux`), connect via the `dtd` tool and
hot reload after UI edits / hot restart after changes to `main()`, DI or
initial state, as described in [CLAUDE.md](CLAUDE.md#proactive-flutter-hot-reload).

## Architecture rules (enforced by `test/architecture/layer_rules_test.dart`)

```
lib/
├── core/      shared infrastructure; imports NOTHING from domain/data/features/app
├── domain/    pure Dart: entities, repository interfaces, AI ports, use cases
├── data/      implements domain interfaces (SQLite, LiteRT-LM, HTTP)
├── features/  presentation: <feature>/{bloc,view,widgets}; features/shared for reused UI
└── app/       composition root (di/injection.dart), router, adaptive shell
```

1. `domain/` must not import Flutter, I/O packages, `data/`, `features/` or `app/`.
2. `data/` must not import `features/`, `app/` or `domain/usecases/`.
3. `features/` must not import `data/`, `domain/repositories/` or
   `domain/services/` — blocs depend on **use cases** only.
4. Only `lib/app/di/injection.dart` (and `main.dart`) may name concrete
   implementations. Register every new class there.
5. Only `lib/data/datasources/ai/litert_ai_runtime.dart` may import
   `flutter_edge_ai*`.

## Conventions

- **Use cases**: one operation per `final class` implementing
  `UseCase<Output, Params>` (or `StreamUseCase`). Expected failures are
  returned as `Result<T>` (`Success` / `Err(Failure)`), never thrown to the UI.
  Wrap bodies in `guard(logger, 'Operation', () async { ... })`.
- **Entities** are immutable `Equatable` classes with `copyWith`. Nullable
  fields in `copyWith` use `T? Function()?` so callers can set `null`.
- **Blocs**: `sealed` events and states, `final class` subtypes,
  `bloc_concurrency` transformers. Screens that load one value extend
  `AutoRefreshCubit<T>` and implement `fetch()`.
- **Commands from widgets** return `Future<Failure?>`; show them with
  `context.reportFailure(cubit.someCommand())`.
- **No magic numbers** in UI: use `AppSpacing` and named `static const`s.
- **Responsive**: use `context.windowSize`, `AdaptiveTwoPane`,
  `ResponsiveListView` and `showAdaptiveFormDialog`. New screens must render
  without overflow at 320 px wide — add the route to
  `test/responsive/responsive_layout_test.dart`.
- **Routes** are constants in `core/navigation/app_routes.dart`.
- **Privacy**: never send memory content off the device. The only network
  calls are model downloads and fetching a URL the user chose to save.
- **AI grounding**: Ask Brain must answer only from retrieved memories and
  use `AskReplies.notFound` when nothing relevant exists. Do not weaken this.
- **Never name AI models in user-facing text.** The UI only says
  "Pocket Brain AI"; model details stay in `data/` (enforced by
  `test/data/ai_pack_test.dart`).
- AI output is a *suggestion*: the user's original `Memory.content` is never
  rewritten, and AI-generated text is visually marked (`AiBadge`).

## Testing

- Use `configureTestDependencies()` (`test/helpers/test_dependencies.dart`):
  real object graph, in-memory SQLite, `FakeAiRuntime`, fixed clock.
- Wait for bloc states with `untilState(bloc, predicate)`; do not add fixed
  sleeps.
- Widget tests touching the database must use `pumpAppAt` / `settle` from
  `test/helpers/app_harness.dart` (database I/O runs outside fake time).
- Every bug fix gets a regression test.

## Adding a feature (checklist)

1. Entity / interface changes in `domain/`.
2. Use case(s) in `domain/usecases/<area>/` with unit tests.
3. Implementation in `data/` if a new port is needed.
4. Register everything in `app/di/injection.dart`.
5. Bloc/cubit + view + widgets in `features/<feature>/`; route in `app/router/`.
6. Tests: use case, bloc, and responsive layout entry.
7. Update `docs/` and `CHANGELOG.md` (Unreleased).

## Don'ts

- Don't call `FlutterEdgeAi`, `sqflite` or `http` from blocs or widgets.
- Don't use `print`; use the injected `AppLogger`.
- Don't commit build output, `.vscode/`, model files or exported data.
- Don't bump the database schema without a migration in
  `data/datasources/local/database_schema.dart`.
