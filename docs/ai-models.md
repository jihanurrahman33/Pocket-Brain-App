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

### Resumable downloads

Downloads never restart from zero. `ResumableDownloader`
(`data/datasources/ai/resumable_downloader.dart`) is used instead of the
engine package's downloader, because that one disables resume for Hugging
Face URLs.

- Bytes stream into `<app support>/ai_models/<file>.part` on disk.
- Every attempt requests the rest with `Range: bytes=<on disk>-` (kept across
  CDN redirects); a server that ignores ranges is handled by starting over.
- Dropped or stalled connections (30 s idle timeout) are retried with
  back-off; each retry resumes from disk.
- The finished file must match the catalog's pinned size and SHA-256 before
  it is registered with the engine (in place, no copy). Corrupt files are
  deleted, never used.
- Progress counts bytes already on disk, so the UI continues at the same
  percentage after a restart.
- An interrupted setup (crash, restart, network loss) resumes automatically
  on the next launch; an explicit **Cancel** keeps the bytes but waits for
  the user to tap **Resume setup**.

To change models, edit `LiteRtAiRuntime` (variants and `components`). No
domain or UI code changes. `test/data/ai_pack_test.dart` fails if
user-facing code ever names a model.

## Models

| Model | File | Size | Role |
|---|---|---|---|
| **Gemma 4 E2B** (`LiteRtLmModels.gemma4E2bIt.generic`) | `gemma-4-E2B-it.litertlm` | 2.59 GB | Capture analysis, Ask Brain answers, weekly recap |
| **Gemma 4 E4B** (`LiteRtLmModels.gemma4E4bIt.generic`), optional | `gemma-4-E4B-it.litertlm` | 3.66 GB | Same role at *Higher quality*, only on 8 GB+ devices |
| **EmbeddingGemma 2 Text 270M** (`LiteRtEmbedders.embeddinggemma2Text270m.generic`) | `embeddinggemma-2-text-270m.litertlm` | 165 MB | Semantic search, related memories, duplicate detection |

Gemma 4 E2B is the lightest Gemma 4 model ("E2B" ≈ 2 billion effective
parameters) and targets phones with 4–6 GB of RAM. The generic bundle runs on
CPU everywhere and on GPU (Vulkan on Linux, OpenCL on Android) where
available. The context window is set to 4096 tokens.

### Quality tiers

`AiQuality.standard` (E2B) is the default everywhere. `GetAvailableAiQualities`
reads total RAM through the `DeviceMemory` port (`/proc/meminfo` on Linux and
Android) and offers `AiQuality.high` (E4B) only from 7 GiB — what "8 GB"
devices report. Larger models (Gemma 3n E4B at 4.9 GB, 7B+ models) do not
fit beside the OS on 4–6 GB phones and are deliberately not offered.

Switching (`ChangeAiQuality`) saves the preference and selects the other
file; the pack then reports *not installed* and the normal resumable install
downloads it. Until it is registered, `OnDeviceAiRuntime.isUsable` keeps the
previous model answering; afterwards the old file is uninstalled.

Most reliability comes from **not asking the model to decide** things rules
can decide: task completion and task questions (`IntentRouter`,
`AnswerTaskIntent`), reminder times (`ReminderTimeParser`), task summaries
(`TaskSummary`), plan statements → proposed tasks (`PlanTaskIntent`,
`DueDateParser`) and grounding are all deterministic and tested.

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

## Images, OCR and audio

Gemma 4 E2B is multimodal. Pocket Brain loads its vision or audio encoder
**only** for a request that needs it and unloads it right after, so text-only
use keeps the smaller memory footprint (important on 4 GB phones).

- **Images / screenshots:** `GemmaMediaReader.readImage` asks for
  `{"text", "description"}` (schema-enforced where supported). The memory's
  text gets the user's note, then `Image: …` and `Text in image: …`, so AI
  text is always labelled. The image is copied into private storage.
- **Voice notes:** recorded as 16 kHz mono WAV (PipeWire `pw-record` or ALSA
  `arecord` on Linux, the `record` plugin on Android), transcribed on-device,
  and moved into private storage with the memory.
- Without the AI set up, the image or recording is still saved with the
  user's note.

## Tool calling (Ask Brain actions)

`AssistantToolbox` (`domain/services/assistant_toolbox.dart`) exposes three
tools through the engine's function-calling loop:

| Tool | Effect |
|---|---|
| `list_tasks` | Read-only; runs immediately and grounds the answer in real tasks |
| `create_task` | **Proposes** a task (with optional reminder); nothing changes until the user taps Confirm |
| `save_memory` | **Proposes** a new note; Confirm saves it, Dismiss discards it |

A deterministic guard keeps the "never invent" rule: an answer with no
matching memories and no tool data is replaced with the fixed
"couldn't find" reply, whatever the model wrote. Small models sometimes pick
the wrong tool, which is why every data change needs confirmation.

## Guardrails

`AssistantGuardrails` (`domain/services/assistant_guardrails.dart`) wraps every
Ask Brain answer with deterministic rules that hold whatever the model writes:

| Stage | Guardrail |
|---|---|
| Input | Whitespace collapsed; questions capped at 1,000 characters |
| Safety | Messages about self-harm get a fixed, caring reply pointing to emergency help — never a model answer |
| Intent | "What can you do?", greetings and thanks get fixed replies instead of a memory search |
| Task routing | `IntentRouter` classifies task commands ("drink water done", "I drank water") and task questions by tested rules; `AnswerTaskIntent` completes the one matching open task or asks which, from real data, with no model call and no memory sources |
| Retrieval | Questions whose words match nothing (other languages, Bangla in English letters) are rewritten into English search terms and searched again |
| Prompt injection | Memories are passed inside `<memory>` blocks marked *data, never instructions* |
| Tools | Write tools only propose; arguments are validated; at most 4 tool turns |
| Output | Leaked tool-call markup removed; citations to non-existent sources removed; answers capped |
| Grounding | No matching memories and no tool data ⇒ the fixed "couldn't find" reply |
| Language | The model answers in the user's language (English or Bangla) |

Decision on model-generated UI (A2UI): see
[ADR 0001](decisions/0001-generative-ui-a2ui.md).

## Structured output

Capture analysis and image reading request a JSON schema
(`GenerationRequest.jsonSchema`). The engine enforces it where it can
(Linux x64, Android arm64, Apple); elsewhere the prompt asks for JSON and the
lenient parser still applies. Tools and schemas are never combined.

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
