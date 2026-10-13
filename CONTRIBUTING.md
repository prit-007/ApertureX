# Contributing to ApertureX

ApertureX is a FOSS, mobile-native, non-destructive photo editor (Android + iOS)
with a Rust engine behind `flutter_rust_bridge`. **TDD is the house standard.**

## Setup

- **Flutter** 3.44.x (Dart 3.12.x)
- **Rust** 1.99.x (`. "$HOME/.cargo/env"`)
- `flutter_rust_bridge_codegen` 2.13.0 (matches the `flutter_rust_bridge` dep)
- Android SDK + NDK (for `app/`); Xcode only if you touch iOS.

```sh
cd app
flutter pub get
flutter analyze
flutter test
(cd rust && cargo test && cargo fmt --check && cargo clippy --all-targets -- -D warnings)
flutter build apk --debug
```

After changing `rust/src/api/*`, regenerate the bridge:

```sh
flutter_rust_bridge_codegen generate
```

## Ground rules

- **TDD**: write a failing test, make it pass, refactor. Pure logic (recipe,
  controller, math, Rust core) is unit-tested; platform/GPU paths are wrapped
  behind interfaces so they can be faked in tests.
- **Keep the tree green**: `analyze`, `flutter test`, `cargo test/fmt/clippy`,
  and `flutter build apk --debug` must all pass before a PR.
- **No new dependency without a `THIRD_PARTY.md` row** (name, license, URL).
- **The recipe is the single source of truth.** UIs (shells) must not own edit
  state; they read/write one `RecipeController` (ADR 0008).
- **Preview == export**: grading math lives once in Rust; the preview LUT and
  the export path share it.

## Branches, commits, PRs

- Trunk is `main`; branch `feat/<issue>` or `fix/<issue>`.
- Small, focused commits (featurewise). Reference the issue number.
- Open a PR against `main`; CI must pass. Fill in the PR checklist.

## Labels & milestones

- `area:*` (engine/color/ui/platform/perf/docs), `type:*`
  (feature/task/chore/spike), `phase:P*`.
- Milestones track phases (`P1`, `P2`, `P2.5`, `P3`, `P3.5`, `P4`).

## Architecture

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), the ADRs in
[`docs/adr/`](docs/adr/), and the plan in [`docs/ROADMAP.md`](docs/ROADMAP.md).
