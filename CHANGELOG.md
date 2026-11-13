# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-11-14

### Added
- **Image & screenshot capture with on-device OCR**: the AI reads the text in
  an image and describes it; the image is kept with the memory.
- **Voice capture**: record a note (PipeWire/ALSA on Linux, microphone on
  Android), transcribed on-device and kept with the memory.
- **Ask Brain actions** via tool calling: create tasks/reminders, save notes
  and list tasks. Changes are proposed as cards and happen only on Confirm.
- **Local notifications** for task reminders (OS-scheduled on Android and
  restored after reboot; in-app on Linux, with missed reminders on launch).
- Schema-constrained JSON output for capture analysis and image reading.
- Database v2 migration (attachments, assistant actions).
- **Guardrails** for Ask Brain: crisis-safe replies, prompt-injection
  hardening, output clean-up, bounded input and answers.
- "What can you do?", greetings and thanks get helpful replies instead of
  "couldn't find".
- Questions in Bangla (including English letters) find English memories via
  AI query rewriting, and answers come back in the user's language.
- The model is given today's date and the next two weeks, so "next Friday"
  becomes the right date.
- Ask Brain shows tasks as **interactive cards** (tick off, due day,
  reminder, overdue) instead of a typed list; task questions are answered
  by the app from real data — instant and always correct.
- **Task commands in plain words**: "drink water done", "I drank water",
  "mark the report as done", "call mum korechi" complete exactly the task
  named — decided by tested rules, not by the model. The task appears as a
  card that can be unticked to undo; unclear messages ask which task, and
  intentions ("I need to…") never complete anything.
- **Plans become tasks**: "I want to sing a song tomorrow", "I need to buy
  eggs", "I'll pay the bill tonight" offer a task card (with the right day)
  to confirm, instead of "couldn't find that". A plan already on the list
  is pointed out rather than added twice.
- **Higher-quality AI option** on devices with 8 GB of RAM or more
  (Settings → AI quality). The standard AI stays the default for 4–6 GB
  phones. Switching downloads in the background (resumable) while the
  current AI keeps answering, then frees the old files.

### Changed
- On-device AI is now one **Pocket Brain AI** setup with a single download
  and progress bar instead of two separately downloaded models. Model names
  no longer appear in the app, so models can change without UI changes.
- An interrupted AI setup can be resumed and only downloads what is missing.

### Fixed
- "Remind me after 5 minutes" created a deadline for today and a 9:00 AM
  reminder. Reminder times are now computed by the app from the user's own
  words ("in 5 minutes", "after 2 hours", "5 minute pore", "at 6 pm"), and a
  relative reminder no longer invents a deadline.
- Date-only deadlines no longer display as "12:00 AM".
- "Check the drink water todo, I'm done" listed a completed task instead
  of completing the open one; "drink water done" answered "couldn't find
  that in your saved memories".
- Task replies no longer show unrelated memories as sources.
- Searches with AI-rewritten keywords match words exactly, so they no
  longer pull in loosely related notes.
- The Linux window title is "Pocket Brain".
- AI downloads restarted from 0% after any interruption (restart, crash,
  lost connection). Downloads now resume from the bytes on disk via HTTP
  range requests, are verified by SHA-256, show progress from where they
  stopped, and continue automatically on the next launch.
- Stalled connections no longer hang the download forever.
- Partial downloads are kept on disk instead of `/tmp`, which is RAM-backed
  on many Linux systems.

## [0.2.0] - 2026-11-13

### Fixed
- Asking from Search while another chat was open wrote the question into
  that chat; Ask Brain events now run strictly in order.
- Regenerating an answer left a duplicate question and the old answer in
  stored history.
- The Ask scope could not be switched back to "All memories".
- Text typed on the Capture screen was lost if analysis failed.
- Overlapping reloads could show stale data; search results could stay stale
  after edits.

### Changed
- Clean Architecture refactor: pure-Dart domain layer, use cases, repository
  interfaces and a single composition root (`get_it`).
- Fully responsive layouts for phone, tablet and desktop (Material 3 window
  size classes).
- Architecture fitness tests enforce layer dependency rules.

### Added
- Open-source project files: documentation, contributing guide, code of
  conduct, security policy, issue/PR templates and CI.

## [0.1.0] - 2026-11-13

### Added
- First version: capture with AI review, collections, tasks, Ask Brain with
  citations, semantic search, digest and recall, model manager, export and
  wipe. On-device Gemma 4 E2B and EmbeddingGemma 2 via LiteRT-LM.

[Unreleased]: https://github.com/jihanurrahman33/Pocket-Brain-App/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/jihanurrahman33/Pocket-Brain-App/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/jihanurrahman33/Pocket-Brain-App/releases/tag/v0.1.0
