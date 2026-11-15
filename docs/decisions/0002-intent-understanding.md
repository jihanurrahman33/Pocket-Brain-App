# ADR 0002: Understand every message as a structured intent

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

Ask Brain used three mechanisms that each failed on real messages:

1. **Regular expressions per phrasing.** "drink water done" worked only
   after a rule was added; "i want to sing a song tomorrow" needed another.
   People phrase things endlessly, so this never converges.
2. **Free-form tool calling** by a ~2B on-device model, which often did not
   call a tool, or called the wrong one.
3. **A single fallback.** Anything that was not a matching memory got
   "I couldn't find that in your saved memories", which leaves the user stuck.

## Decision

Adopt the pipeline production assistants use — **understand → resolve →
act → respond** — with the model confined to the understanding step.

| Step | Component | Notes |
|---|---|---|
| Understand | `UnderstandMessage` → `UserIntent` | One of 11 intents plus slots (title, date, time, task reference, query, note, filter) and a confidence |
| | `IntentRouter` (rules) | Fast path only for phrasings measured to be reliable; **gated in CI at 100% precision** on the labelled set |
| | `GemmaIntentUnderstander` | Everything else: one call, output **constrained by a JSON schema** (enum of intents), ~1 s of output; calendar and the open tasks in the prompt |
| | Corrections | "Not what I meant" redoes the answer as the chosen intent and stores the pair on device; recent pairs become prompt examples |
| Resolve | `DueDateParser` | Dates for known phrases are computed, overriding the model; past model dates are dropped |
| | `TaskResolver` | "the second one"/"it" from the last answer → title words → embedding similarity (EmbeddingGemma) |
| Act | `IntentHandlers` (Strategy + Registry) | Deterministic, tested. Complete/reopen happen at once and are undoable from the card; create, reschedule, delete and save-note are proposals that need Confirm |
| Respond | Handlers / `AnswerGenerator` | Fixed sentences for actions; generated, cited text only for questions about memories |

Low-confidence decisions that would change data become `unclear`, which
offers "add as a task" or "save as a note" instead of guessing.

## Measuring instead of guessing

`test/fixtures/intent_eval_set.json` holds labelled messages (English,
Bangla, Banglish, typos and tricky cases, including every message that was
misunderstood in real use).

- `test/domain/intent_eval_rules_test.dart` (CI): the rules fast path must
  never claim a message wrongly.
- `integration_test/intent_eval_test.dart` (desktop, real model): reports
  intent and slot accuracy and latency to `build/intent_eval/report.md`.

### Results (Linux desktop CPU, Gemma 4 E2B, 265 messages)

| Run | Change | Intent | + details | Median |
|---|---|---|---|---|
| 1 | first version (189 messages) | 91.5% | 87.3% | 10.9 s |
| 2 | shorter prompt, wider set | 91.0% | 89.6% | 11.3 s |
| 3 | optional output fields | 90.9% | 74.7% | 6.1 s (model skipped titles) |
| 4 | six required fields + title fallback | 92.5% | 92.1% | 9.4 s |

Safety nets matter more than the headline number: a personal question
misfiled as chit-chat is searched in memories first, changes that need
certainty become `unclear`, and everything that changes data is undoable or
confirmed. Latency is the open item (prefill ≈ 3 s, decoding ≈ 5 s on this
CPU); the fine-tuned router below is the planned fix.

Every misunderstood message is fixed by adding it to the set (and, if
needed, improving the prompt), never by a new one-off rule.

## Alternatives considered

- **More rules:** rejected — the reason for this ADR.
- **Bigger model only:** Gemma 4 E4B is offered on 8 GB+ devices, but most
  target phones have 4–6 GB; reliability must come from the design.
- **Free-form tool calling:** kept only inside memory answers (read-only
  `list_tasks`); decisions moved to schema-constrained output, which small
  models follow far more reliably.
- **Fine-tuned router (FunctionGemma 270M):** promising for speed (<0.3 s)
  but needs a training pipeline. `tool/export_intent_finetune.dart` exports
  the labelled set as training data so this can be done later without code
  changes: it would be another `IntentUnderstander`.

## Consequences

- One extra short model call for messages the rules do not claim (memory
  questions save a call: the understanding step also writes the English
  search keywords that the separate rewrite call used to produce).
- Adding a capability means adding an intent, a handler and labelled
  examples — not touching unrelated code.
