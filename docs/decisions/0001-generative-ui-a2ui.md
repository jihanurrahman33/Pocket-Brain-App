# ADR 0001: Generative UI (A2UI) for Ask Brain answers

- **Status:** Deferred (revisit when a capable on-device model or a cloud
  option exists)
- **Date:** 2026-11-13

## Context

[A2UI](https://a2ui.org) is an open protocol in which an agent streams JSON
describing UI (cards, lists, buttons, forms) that a renderer such as
[`a2ui_flutter`](https://pub.dev/packages/a2ui_flutter) (labs.flutter.dev,
v0.3.0, replaces `genui`) turns into native widgets. The question was whether
Ask Brain should answer with model-generated UI instead of text.

## Decision

Not now. Ask Brain keeps **deterministic rich UI built from structured data**
(source cards, action confirmation cards) rather than letting the model write
UI.

## Reasons

1. **Model capability.** A2UI asks the model to emit schema-valid component
   trees against a catalog, with a validate-and-retry loop. Its examples and
   tooling target large hosted models (the example app uses Gemini). Our model
   is Gemma 4 E2B (~2B effective parameters) on CPU; it already makes mistakes
   with three small tools. Multi-component UI JSON would be far less reliable.
2. **Speed and battery.** UI JSON costs many more output tokens than a sentence.
   On a phone CPU that means seconds of extra generation for every answer.
3. **Trust and safety.** The app's core promise is that answers come only
   from the user's memories and nothing changes without confirmation. UI an
   agent invents (buttons, forms, links) widens what the model can do; A2UI's
   own guidance is to treat agent output as untrusted. Deterministic cards keep
   every action under the app's control.
4. **Maturity.** `a2ui_flutter` is pre-1.0 and days old, with the protocol at
   v1.0 and a large open-issue count.

## What we do instead

The model returns text and *structured tool calls*; the app renders those
with its own widgets (`SourceCard`, `AssistantActionCard`). This gives rich,
interactive answers with predictable behaviour and no UI-generation cost.

## When to revisit

- A larger on-device model (e.g. Gemma 4 E4B on 8 GB+ devices) proves reliable
  at structured output, or an optional cloud mode is added; and
- `a2ui_flutter` reaches 1.0. A small custom catalog (memory card, task list,
  date picker) would then be the first experiment, behind a feature flag.
