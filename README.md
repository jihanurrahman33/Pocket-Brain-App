<div align="center">

# 🧠 Pocket Brain

**A private, on-device AI memory companion.**
Save anything, forget it safely, and find it again by asking.

[![CI](https://github.com/jihanurrahman33/Pocket-Brain-App/actions/workflows/ci.yml/badge.svg)](https://github.com/jihanurrahman33/Pocket-Brain-App/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter)
![Platforms](https://img.shields.io/badge/platforms-Linux%20%7C%20Android-informational)

</div>

---

Pocket Brain is a Flutter app for saving notes, ideas and links, and getting
them back later — by keyword, by meaning, or by asking a question in plain
language. The AI (Google's **Gemma 4 E2B**) runs **entirely on your device**
through [LiteRT-LM](https://pub.dev/packages/flutter_edge_ai_litertlm). There
is no account, no server and no sync: your memories never leave the device.

## Features

| | |
|---|---|
| **Smart capture** | Write a note, paste a link (the page is summarised) or paste from the clipboard. AI suggests a title, summary, category, tags and tasks — you review and edit everything before saving. |
| **Ask Brain** | Ask questions like *"What was that React project idea I saved?"* Answers use **only** your memories, cite them with clickable source cards, and say *"I couldn't find that"* instead of inventing. |
| **Smart search** | Exact keyword search or semantic search by meaning, with filters for category, type and date. |
| **Smart recall** | Daily digest, weekly recap, "on this day", and forgotten memories worth revisiting. |
| **Organisation** | Collections, categories, tags, favourites, archive, related memories and duplicate detection. |
| **Tasks** | Deadlines found in your notes become suggested tasks; confirmed tasks link back to their memory. |
| **Privacy** | Local SQLite storage, JSON export, one-tap wipe, AI suggestions can be switched off. |
| **Responsive** | Bottom navigation on phones, navigation rail and two-pane layouts on tablets and desktop. |

The app works without downloading any model (offline rules and keyword
search); downloading Gemma unlocks the AI features.

## Quick start

Requirements: Flutter **3.47+**. For Linux desktop also `clang`, `cmake`,
`ninja-build`, `pkg-config` and `libgtk-3-dev`.

```bash
git clone https://github.com/jihanurrahman33/Pocket-Brain-App.git
cd Pocket-Brain-App
flutter pub get
flutter run -d linux      # or: flutter run -d <android-device-id>
```

Then open **Settings → AI models** to download:

| Model | Size | Enables |
|---|---|---|
| Gemma 4 E2B | 2.6 GB | Summaries, tags, task extraction, Ask Brain, weekly recap |
| EmbeddingGemma 2 Text 270M | 165 MB | Semantic search, related memories, duplicate detection |

Gemma 4 E2B is the lightest Gemma 4 model and is designed for phones with
4–6 GB of RAM. See [docs/ai-models.md](docs/ai-models.md) for hardware notes.

## Development

```bash
flutter analyze                             # strict lints, must be clean
dart format --set-exit-if-changed lib test  # formatting
flutter test                                # unit, bloc, widget, layout and architecture tests
```

| Document | What it covers |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Layers, dependency rules, design patterns, data flow |
| [docs/development.md](docs/development.md) | Setup, running, testing, adding a feature, troubleshooting |
| [docs/ai-models.md](docs/ai-models.md) | On-device models, prompts, grounding rules, hardware |
| [docs/responsive-design.md](docs/responsive-design.md) | Window size classes and adaptive layouts |
| [docs/product.md](docs/product.md) | Product vision, screens and roadmap |
| [AGENTS.md](AGENTS.md) | Instructions for AI coding agents working in this repo |

## Architecture at a glance

Clean Architecture with BLoC state management:

```
features/ (BLoC + widgets) ──▶ domain/usecases ──▶ domain/repositories & services (interfaces)
                                                          ▲
                                     data/ (SQLite, LiteRT-LM, HTTP) implements them
app/di/injection.dart is the only place that wires concrete classes together.
```

The domain layer is pure Dart. Layer rules are enforced by tests in
`test/architecture/`. Details in [docs/architecture.md](docs/architecture.md).

## Roadmap

- [x] Capture (notes, links, clipboard), AI review, collections, tasks
- [x] Ask Brain with citations, semantic search, digest and recall
- [ ] Voice capture, image/screenshot understanding, PDF import
- [ ] System notifications for reminders
- [ ] Share-to-app on Android, biometric app lock
- [ ] Optional encrypted backup

See [docs/product.md](docs/product.md) and the
[issue tracker](https://github.com/jihanurrahman33/Pocket-Brain-App/issues).

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) and
our [Code of Conduct](CODE_OF_CONDUCT.md). Security issues: see
[SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE). Gemma models are provided under their own terms; see
[docs/ai-models.md](docs/ai-models.md#licences).
