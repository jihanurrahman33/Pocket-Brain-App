# Development guide

## Prerequisites

- Flutter **3.47+** (Dart 3.13+)
- **Linux desktop** (per the [Flutter Linux setup](https://docs.flutter.dev/platform-integration/linux/setup)):
  ```bash
  sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev
  ```
- **Android:** Android SDK with a device or emulator on API 30+ (required by
  LiteRT-LM). A physical device with 6 GB+ RAM is recommended for Gemma.

The first build downloads LiteRT-LM native libraries through a Dart build
hook (cached under `~/.cache/flutter_gemma/native/`). Log lines prefixed
`ERROR: flutter_edge_ai:` during that step are informational.

## AI coding agents (optional)

The official [Dart and Flutter MCP server](https://docs.flutter.dev/ai/get-started)
lets agents analyze code, run tests and hot reload the running app. For
Claude Code:

```bash
claude plugin marketplace add flutter/agent-plugins
claude plugin install dart-flutter@dart-flutter
```

Other agents: see the Flutter docs page above. Project rules for agents are
in [AGENTS.md](../AGENTS.md) and [CLAUDE.md](../CLAUDE.md).

## Run

```bash
flutter pub get
flutter run -d linux
flutter run -d <android-device-id>
```

Data lives in the platform's application-support directory
(`~/.local/share/com.pocketbrain.pocket_brain/` on Linux).

## Quality gates

These run in CI on every push and pull request:

```bash
flutter analyze                             # strict analyzer + lints, zero issues
dart format --set-exit-if-changed lib test  # formatting (page width 100)
flutter test                                # all tests
```

## Tests

| Folder | What it tests |
|---|---|
| `test/domain/` | Use cases against the real object graph with fakes |
| `test/data/` | Parsers, analyzers, HTML extraction, fallbacks |
| `test/features/` | Blocs and cubits, including regression tests |
| `test/core/` | Shared presentation infrastructure |
| `test/responsive/` | Every screen at 320–1440 px, adaptive navigation |
| `test/architecture/` | Layer dependency rules |

Helpers in `test/helpers/`:

- `configureTestDependencies()` builds the app's real dependency graph with
  an in-memory database, `FakeAiRuntime`, a fixed clock and no network.
- `untilState(bloc, predicate)` waits for a state instead of sleeping.
- `pumpAppAt(tester, size)` and `settle(tester)` render the whole app; the
  database runs real async I/O, which `settle` lets complete.

Run one file or test:

```bash
flutter test test/features/blocs_test.dart
flutter test --plain-name "regenerate"
```

## Adding a feature

1. Model it in `domain/` (entities, interfaces) and write the use case.
2. Unit-test the use case with `configureTestDependencies()`.
3. Implement any new interface in `data/`.
4. Register everything in `lib/app/di/injection.dart`.
5. Add the bloc/cubit, page and widgets under `lib/features/<name>/`, and the
   route in `lib/app/router/app_router.dart` + `core/navigation/app_routes.dart`.
6. Add the route to `test/responsive/responsive_layout_test.dart`.
7. Update docs and `CHANGELOG.md`.

## Database changes

Edit `lib/data/datasources/local/database_schema.dart`: increment
`DatabaseSchema.version` and add a migration step in `migrate()`. Never
change `create()` in a way that existing installs cannot reach through
`migrate()`.

## Troubleshooting

| Problem | Fix |
|---|---|
| `No Linux desktop project configured` | `flutter create --platforms=linux .` |
| CMake / GTK errors | Install the Linux prerequisites above |
| App slow or killed while answering | Gemma needs ~3 GB free RAM; close other apps, use **Settings → Free memory**, or try the GPU backend |
| GPU backend crashes or fails | Switch back to CPU in **Settings → Compute backend** |
| AI download interrupted | It resumes from the bytes on disk; tap **Resume setup** (or relaunch if setup was in progress) |
| `Disk quota exceeded` / tests hang | `/tmp` is full — on many distros it is RAM-backed (tmpfs). Remove stale `/tmp/com.bbflight.background_downloader*` files from older builds |
| `pumpAndSettle timed out` in a widget test | Use `settle(tester)` from `app_harness.dart` |
