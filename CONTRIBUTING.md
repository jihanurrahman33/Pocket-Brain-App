# Contributing to Pocket Brain

Thanks for your interest! Bug reports, ideas, docs and code are all welcome.
By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Ways to contribute

- **Report a bug** — open an issue with the *Bug report* template.
- **Suggest a feature** — open an issue with the *Feature request* template.
  Check [docs/product.md](docs/product.md) for the roadmap first.
- **Improve docs** — typos and clarifications are great first PRs.
- **Write code** — look for issues labelled `good first issue` or
  `help wanted`, and comment before starting larger work so we can agree on
  the approach.

## Development setup

See [docs/development.md](docs/development.md). In short:

```bash
flutter pub get
flutter run -d linux
```

## Making a change

1. Fork the repository and create a branch from `main`:
   `git checkout -b fix/short-description`.
2. Follow the architecture and conventions in
   [AGENTS.md](AGENTS.md) and [docs/architecture.md](docs/architecture.md).
   In particular: blocs depend only on use cases, the domain layer stays
   pure Dart, and every new class is registered in `app/di/injection.dart`.
3. Add tests:
   - use cases and blocs for logic changes,
   - a regression test for every bug fix,
   - an entry in `test/responsive/responsive_layout_test.dart` for new screens.
4. Run the quality gates — CI runs the same commands:
   ```bash
   flutter analyze
   dart format --set-exit-if-changed lib test
   flutter test
   ```
5. Update docs and add a line under **Unreleased** in
   [CHANGELOG.md](CHANGELOG.md) for user-visible changes.
6. Open a pull request and fill in the template.

## Commit messages

Use short, imperative subjects (≤ 72 characters), optionally with a
[Conventional Commits](https://www.conventionalcommits.org/) prefix:

```
fix(ask): replace stale answer when regenerating
feat(capture): import text from PDF files
docs: explain the model fallback chain
```

## Pull request checklist

- [ ] Analyzer, formatter and tests pass locally
- [ ] Tests cover the change (regression test for bug fixes)
- [ ] No layer rule violations (`test/architecture/` passes)
- [ ] Screens render at 320 px wide without overflow
- [ ] Docs and changelog updated where relevant
- [ ] No user data, model files, secrets or machine-specific paths committed

## Privacy commitments

Pocket Brain promises users that their memories stay on their device.
Changes that send user content to any network service will not be accepted.
The only allowed network calls are model downloads and fetching a link the
user explicitly saves.

## Licence

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
