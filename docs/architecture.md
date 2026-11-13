# Architecture

Pocket Brain follows **Clean Architecture**: business rules live in a pure
Dart core that knows nothing about Flutter, SQLite or the AI engine. Outer
layers depend inward; the inner layers define interfaces that outer layers
implement.

```
┌─────────────────────────────────────────────────────────────┐
│ app/          composition root · router · adaptive shell    │
├─────────────────────────────────────────────────────────────┤
│ features/     BLoCs/cubits · pages · widgets (presentation) │
│        │ calls                                              │
│        ▼                                                    │
│ domain/usecases      one class per operation                │
│        │ depends on                                         │
│        ▼                                                    │
│ domain/repositories · domain/services   (interfaces/ports)  │
│ domain/entities                         (immutable models)  │
│        ▲ implemented by                                     │
│ data/         SQLite repos · LiteRT-LM adapter · HTTP       │
├─────────────────────────────────────────────────────────────┤
│ core/         Result · Failure · UseCase · Clock · logging  │
│               responsive system · theme · shared widgets    │
└─────────────────────────────────────────────────────────────┘
```

## Layers

### `core/`
Cross-cutting building blocks with **no knowledge of the app's domain**:
`Result`/`Failure`/`guard` for error handling, the `UseCase` contract,
`Clock` and `IdGenerator` abstractions (for deterministic tests), `AppLogger`,
`TextUtils`, the responsive system, theme, spacing tokens and generic widgets.

### `domain/`
Pure Dart.

- **entities/** — `Memory`, `MemoryCollection`, `TaskItem`, `Conversation`,
  `ChatMessage`, `CaptureDraft`, `MemoryAnalysis`, search and recall value
  objects. Immutable and `Equatable`.
- **repositories/** — persistence interfaces: `MemoryRepository`,
  `MemoryMetadataStore`, `CollectionRepository`, `TaskRepository`,
  `ConversationRepository`, `SearchHistoryRepository`,
  `PreferencesRepository`, `ModelRepository`, `DataExportRepository`.
- **services/** — AI ports (`MemoryAnalyzer`, `AnswerGenerator`,
  `RecapWriter`, `TextEmbedder`, `LinkReader`) and pure domain services
  (`RelevanceScorer` strategies, `SimilarityScorer`, `TopicRanker`).
- **usecases/** — application operations grouped by area: capture,
  memories, collections, tasks, search, ask, recall, indexing, models,
  settings.

### `data/`
Implements domain interfaces.

- **datasources/local** — `AppDatabase` and `DatabaseSchema` (with
  migrations).
- **datasources/ai** — `OnDeviceAiRuntime` port and `LiteRtAiRuntime`, the
  **only** code that touches `flutter_edge_ai`.
- **mappers/** — row ↔ entity and export JSON.
- **repositories/** — `Sqlite*Repository`, `SharedPrefsPreferencesRepository`,
  `OnDeviceModelRepository`, `JsonFileExportRepository`.
- **services/** — Gemma and rule-based analyzers, prompts, response parser,
  date parser, recap writers, embedder, HTTP link reader.

### `features/`
One folder per screen: `bloc/`, `view/` (routed pages), `widgets/`.
`features/shared/` holds UI reused across features (memory tiles and cards).

### `app/`
`di/injection.dart` is the **composition root** — the single place where
concrete classes are chosen and wired. `router/` defines routes and the
adaptive navigation shell.

## Dependency rules

Enforced by `test/architecture/layer_rules_test.dart`:

| Layer | May import | Must not import |
|---|---|---|
| core | Flutter, packages | domain, data, features, app |
| domain | core, pure Dart packages | Flutter, I/O packages, data, features, app |
| data | core, domain (not use cases) | features, app, domain/usecases |
| features | core, domain entities & use cases, other features | data, domain/repositories, domain/services |
| app | everything | — |

## SOLID in practice

| Principle | Where |
|---|---|
| Single Responsibility | One use case per operation; prompts, response parsing, date parsing and HTML extraction are separate classes. |
| Open/Closed | Search modes are `RelevanceScorer` strategies selected from a map; `WipeAllData` clears any list of `Clearable` stores; `ObserveDataChanges` merges any `ChangeSource`s. |
| Liskov Substitution | `GemmaMemoryAnalyzer`, `RuleBasedMemoryAnalyzer` and `FallbackMemoryAnalyzer` are interchangeable `MemoryAnalyzer`s. |
| Interface Segregation | `MemoryRepository` (visible data) vs `MemoryMetadataStore` (view times, embeddings); separate AI ports per capability. |
| Dependency Inversion | Blocs → use cases → interfaces. Only the composition root knows implementations. |

## Design patterns

| Pattern | Implementation |
|---|---|
| Repository | `domain/repositories/*` with SQLite implementations |
| Use Case / Command | `domain/usecases/**` (`UseCase<Output, Params>`) |
| Strategy | `KeywordRelevanceScorer`, `HybridRelevanceScorer` |
| Decorator / Chain of Responsibility | `FallbackMemoryAnalyzer`, `FallbackRecapWriter` |
| Adapter | `LiteRtAiRuntime` adapts `flutter_edge_ai` to `OnDeviceAiRuntime` |
| Mapper | `data/mappers/*` |
| Observer | Repository `changes` streams; `AskProgress` event stream |
| Template Method | `AutoRefreshCubit.fetch()`; `_MemoryCommand.apply()` |
| State | Sealed bloc states (`CaptureEditing → Analyzing → Reviewing → Saved`) |
| Result type | `Result<T>` = `Success` / `Err(Failure)` |
| Parameter Object | `MemoryDetailActions`, `TaskActions`, request records |
| Composition Root / Service Locator | `get_it` in `app/di/injection.dart` |

## Data flow examples

### Capture

```
CaptureInputForm ─CaptureSubmitted─▶ CaptureBloc
  └▶ AnalyzeCapture: LinkReader (links) → MemoryAnalyzer (Gemma or rules)
                     → FindSimilarMemories
  ◀─ CaptureReviewing(review)          user edits suggestions
CaptureConfirmed ─▶ SaveCapture: MemoryRepository.save → TaskRepository.save
                     → IndexMemory (background embedding)
  ◀─ CaptureSaved(id)
```

### Ask Brain

```
AskQuestionSubmitted ─▶ AskBloc (events processed sequentially)
  └▶ AskBrain (stream):
       AskConversationStarted → AskQuestionRecorded
       → RetrieveAnswerSources (SearchMemories, relevance threshold)
       → AskSourcesFound
       → AnswerGenerator.generate   (skipped if no sources / no model)
       → AskAnswerUpdated × n → AskAnswerCompleted (persisted)
```

Grounding rules live in the use case, not the UI: no relevant memory means
the fixed reply `AskReplies.notFound` without calling the model.

## Error handling

Infrastructure throws; use cases catch via `guard()` and return
`Err(Failure)`. Expected failures may be thrown as `FailureException` to
carry a specific `Failure` (e.g. `NotFoundFailure`). Blocs and widgets only
ever see `Result` / `Failure` values. Unexpected errors are logged through
`AppLogger` and surfaced as `UnexpectedFailure`.

## Persistence

SQLite (`sqflite_common_ffi` on desktop, `sqflite` on mobile). Schema is in
`DatabaseSchema`; bump `version` and add a step to `migrate()` for any change.
Embeddings are stored as `Float32List` blobs alongside memories.
