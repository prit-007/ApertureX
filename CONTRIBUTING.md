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

**`main` is protected — no direct pushes.** Every change must go through a pull request.

- **Create a feature branch** from `main`: `git checkout -b feat/<issue-number>-short-description` or `fix/<issue-number>-short-description`
- **Small, focused commits** referencing the issue number (`Closes #<issue>` or `Fixes #<issue>`)
- **Run baseline checks locally** before opening the PR:
  - `flutter analyze`
  - `flutter test`
  - `cd rust && cargo test && cargo fmt --check && cargo clippy --all-targets -- -D warnings`
- **Open a PR against `main`**; CI must pass. Fill in the PR checklist completely.
- **CI must pass** on the PR before merging. Maintainers review and merge — the PR author does not self-merge unless they are a maintainer.


## Labels & milestones

- `area:*` (engine/color/ui/platform/perf/docs), `type:*`
  (feature/task/chore/spike), `phase:P*`.
- Milestones track phases (`P1`, `P2`, `P2.5`, `P3`, `P3.5`, `P4`).

## Releases (maintainers)

1. Add a `## [X.Y.Z] - date` section to `app/CHANGELOG.md`.
2. Bump `version: X.Y.Z+N` in `app/pubspec.yaml` (the `+N` is the Android
   build number; the per-ABI `×10+{1,2,3}` codes are derived from it).
3. Tag and push:
   ```sh
   git tag vX.Y.Z && git push origin vX.Y.Z
   ```
CI verifies the tag matches `pubspec.yaml`, builds signed per-ABI + universal
APKs in the F-Droid buildserver container, and publishes a GitHub Release with
the APKs and the changelog section. First-time signing setup:
`tool/ci/make_release_keystore.sh` (keystore + passwords stay on your machine;
secrets go to the `ci` environment — **back the keystore up**).

## Architecture

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), the ADRs in
[`docs/adr/`](docs/adr/), and the forward plan in
[`docs/IMPLEMENTATION_PLAN.md`](docs/IMPLEMENTATION_PLAN.md) /
[`docs/ROADMAP.md`](docs/ROADMAP.md).

## Collaboration & Code Review

- **Be kind and patient** — we welcome contributors of all experience levels.
- **Review constructively** — focus on the code, not the person. Suggest
  concrete changes with code examples when possible.
- **Respond to review comments** in a timely manner. If you need more time,
  just say so on the PR.
- **One PR, one concern** — keep PRs small and focused. Do not bundle
  unrelated changes together.
- **Reference issues** — every commit and PR should reference an issue number
  (`Closes #<issue>` or `Fixes #<issue>`).
- **Maintainers merge** — the PR author does not self-merge unless they are a
  maintainer.

## First-time contributors

1. Fork the repo (if you don't have write access) or create a branch from `main`.
2. Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and
   [`docs/ROADMAP.md`](docs/ROADMAP.md) to understand the project direction.
3. Pick an issue labeled `good first issue` or ask in the issue comments if you
   need help getting started.
4. Follow the TDD workflow: write a failing test first, make it pass, refactor.
5. Open a draft PR early to get feedback before you finish.
6. Make sure all baseline checks pass before requesting review.

