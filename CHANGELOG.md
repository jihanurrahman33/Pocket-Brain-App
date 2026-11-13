# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- On-device AI is now one **Pocket Brain AI** setup with a single download
  and progress bar instead of two separately downloaded models. Model names
  no longer appear in the app, so models can change without UI changes.
- An interrupted AI setup can be resumed and only downloads what is missing.

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
