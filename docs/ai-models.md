# On-device AI

All inference runs locally through
[`flutter_edge_ai_litertlm`](https://pub.dev/packages/flutter_edge_ai_litertlm)
(LiteRT-LM). Models are downloaded once from Hugging Face, pinned to exact
revisions by the package's model catalog, and verified by size and SHA-256.

## One "Pocket Brain AI" pack

Users never see model names. Settings shows a single **Pocket Brain AI**
card with one *Set up* button and one progress bar; the Home and Ask
banners say "Turn on Pocket Brain AI".

- `domain/` only knows `AiPackStatus` (total size, bytes remaining, loaded)
  and `ModelRepository.install()` for the whole pack.
- `OnDeviceModelRepository` (data) downloads every **missing** component in
  order and reports one size-weighted progress value. An interrupted setup
  resumes with only what is left ("Resume setup (165 MB left)").
- Component kinds (`AiModelKind`) and sizes live in the data layer
  (`OnDeviceAiRuntime.components`).

To change models, edit `LiteRtAiRuntime` (variants and `components`). No
domain or UI code changes. `test/data/ai_pack_test.dart` fails if
user-facing code ever names a model.

## Models

| Model | File | Size | Role |
|---|---|---|---|
| **Gemma 4 E2B** (`LiteRtLmModels.gemma4E2bIt.generic`) | `gemma-4-E2B-it.litertlm` | 2.59 GB | Capture analysis, Ask Brain answers, weekly recap |
| **EmbeddingGemma 2 Text 270M** (`LiteRtEmbedders.embeddinggemma2Text270m.generic`) | `embeddinggemma-2-text-270m.litertlm` | 165 MB | Semantic search, related memories, duplicate detection |

Gemma 4 E2B is the lightest Gemma 4 model ("E2B" ≈ 2 billion effective
parameters) and targets phones with 4–6 GB of RAM. The generic bundle runs on
CPU everywhere and on GPU (Vulkan on Linux, OpenCL on Android) where
available. The context window is set to 4096 tokens.

### Hardware guidance

| Device | Expectation |
|---|---|
| Desktop, 8 GB+ RAM | Comfortable on CPU |
| Desktop / laptop, 6 GB RAM | Works; close other apps; first answer loads the model (several seconds) |
| Phone, 6 GB+ RAM | Recommended |
| Phone, 4 GB RAM | Possible but tight; prefer GPU backend |

Use **Settings → Free memory** to unload models when not needed.

## Where the AI code lives

```
domain/services/ai_services.dart        ports: MemoryAnalyzer, AnswerGenerator,
                                        RecapWriter, TextEmbedder, LinkReader
data/datasources/ai/on_device_ai_runtime.dart   OnDeviceAiRuntime port
data/datasources/ai/litert_ai_runtime.dart      LiteRT-LM adapter (only file
                                                importing flutter_edge_ai)
data/services/ai/prompts/prompts.dart           all prompts
data/services/ai/parsers/                       model output parsing
data/services/ai/memory_analyzers.dart          Gemma, rule-based, fallback
data/services/ai/generation_services.dart       answers, recaps, embeddings
```

Generations are serialised (LiteRT-LM runs one session at a time) and
streamed token by token. Models load lazily on first use.

## Grounding and safety rules

1. **Answers come only from saved memories.** `RetrieveAnswerSources` keeps
   memories above a relevance threshold; if none qualify, `AskBrain` returns
   `AskReplies.notFound` *without calling the model*.
2. The prompt instructs the model to cite sources as `[n]` and to reply with
   the exact "couldn't find" sentence when the sources don't answer.
3. Every answer shows the source memories it was given as clickable cards.
4. **AI never edits the user's content.** Suggestions (title, summary,
   category, tags, tasks) are reviewed before saving; the original text is
   stored untouched. AI-written text is marked with an `AiBadge`.
5. Tasks extracted by AI are created only when the user ticks them.

## Fallbacks

| Situation | Behaviour |
|---|---|
| AI pack not set up | `RuleBasedMemoryAnalyzer` (deterministic rules) labelled "Offline rules" |
| Gemma fails mid-analysis | `FallbackMemoryAnalyzer` logs and uses rules |
| Gemma not installed for Ask Brain | Shows the relevant memories and explains the model is missing |
| Embedder not installed | Keyword search with token-overlap boost |
| AI suggestions switched off | Plain title from the first line; nothing else suggested |

## Licences

Pocket Brain's code is MIT-licensed. The models are **not** part of this
repository and are downloaded at runtime under their own terms:
Gemma 4 E2B and EmbeddingGemma 2 Text are distributed under Apache 2.0
according to the package's model catalog; check each model card on Hugging
Face before redistribution.
