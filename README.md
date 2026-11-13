# Pocket Brain

A personal memory companion: save anything, find it later, and ask questions
about what you saved. All AI runs **on-device** with Gemma 4 E2B via
[`flutter_edge_ai_litertlm`](https://pub.dev/packages/flutter_edge_ai_litertlm);
memories never leave the device.

## Run

```bash
flutter pub get
flutter run -d linux     # or: flutter run -d android
flutter test
```

The app works without any model (offline rules for suggestions, keyword
search). For AI features open **Settings → AI models** and download:

| Model | Size | Used for |
|---|---|---|
| Gemma 4 E2B | 2.6 GB | Summaries, tags, task extraction, Ask Brain, weekly recap |
| EmbeddingGemma 2 Text 270M | 165 MB | Semantic search, related memories, duplicate detection |

Gemma 4 E2B is the lightest Gemma 4 model and targets phones with 4–6 GB RAM.

## Architecture

Clean Architecture with three layers; dependencies point inwards only.

```
lib/
├── core/        Cross-cutting: Result/Failure, UseCase contract, Clock, IdGenerator,
│                logging, responsive system, theme, shared widgets
├── domain/      Pure Dart — no Flutter, no packages with I/O
│   ├── entities/      Memory, TaskItem, Conversation, CaptureDraft, …
│   ├── repositories/  Interfaces (MemoryRepository, ModelRepository, …)
│   ├── services/      AI ports (MemoryAnalyzer, AnswerGenerator, TextEmbedder, …)
│   │                  and ranking strategies (RelevanceScorer)
│   └── usecases/      One class per operation (AskBrain, SaveCapture, SearchMemories, …)
├── data/        Implementations of the domain interfaces
│   ├── datasources/   SQLite database; OnDeviceAiRuntime port + LiteRT adapter
│   ├── mappers/       Row ↔ entity and export JSON mapping
│   ├── repositories/  Sqlite*, SharedPrefs*, OnDeviceModelRepository, …
│   └── services/      Gemma / rule-based analyzers, prompts, parsers, link reader
├── features/    Presentation, one folder per screen: bloc/ view/ widgets/
└── app/         Composition root (get_it), router, adaptive shell
```

### Principles applied

- **Single Responsibility** — each use case does one thing; prompts, parsing,
  date parsing and HTML extraction are separate classes.
- **Open/Closed** — search modes are `RelevanceScorer` strategies;
  `WipeAllData` clears any list of `Clearable` stores.
- **Liskov** — Gemma, rule-based and fallback analyzers are interchangeable
  `MemoryAnalyzer`s.
- **Interface Segregation** — small ports (`MemoryRepository` vs
  `MemoryMetadataStore`, `AnswerGenerator` vs `TextEmbedder`).
- **Dependency Inversion** — blocs depend on use cases, use cases on
  interfaces; only `app/di/injection.dart` knows concrete classes.

### Design patterns

Repository · Use Case (Command) · Strategy (relevance scoring) · Decorator /
Chain of Responsibility (`FallbackMemoryAnalyzer`, `FallbackRecapWriter`) ·
Adapter (`LiteRtAiRuntime`) · Mapper · Observer (repository change streams,
`AskProgress` events) · Template Method (`AutoRefreshCubit`, memory commands) ·
State (sealed bloc states) · Result type for errors · Service Locator /
Composition Root (get_it) · Parameter Object.

### State management

BLoC (`flutter_bloc`). Sealed events and states, `bloc_concurrency`
transformers (droppable submits, restartable/debounced search), and an
`AutoRefreshCubit` base that reloads when data changes.

### Responsive design

Material 3 window size classes (`core/responsive/window_size.dart`):

| Width | Class | Navigation | Layout |
|---|---|---|---|
| < 600 | compact | bottom bar | single column, full-screen forms |
| 600–839 | medium | rail with labels | single column, wider padding |
| 840–1199 | expanded | rail with labels | two panes (content + side panel) |
| ≥ 1200 | large | extended rail | two panes, persistent chat history |

`test/responsive/` renders every screen at 320 px, 390 px, 800 px, 1024 px
and 1440 px wide and fails on any overflow.

## Privacy

Local SQLite storage, no accounts, no sync. Export everything as JSON or wipe
all data from Settings. Link capture fetches only the URL you save.
