# ApertureX Collaboration Guide

Welcome to ApertureX! We're glad you're here. This guide explains how to
collaborate on the project — from saying hello to shipping your first PR.

---

## 1. Values

- **FOSS first.** ApertureX is Free and Open Source Software. No proprietary
  SDKs, no telemetry, no cloud inference. Everything runs on-device.
- **TDD is the house standard.** Write a failing test, make it pass, refactor.
- **Keep the tree green.** `flutter analyze`, `flutter test`, `cargo
  test/fmt/clippy`, and `flutter build apk --debug` must all pass before a PR
  is merged.
- **One PR, one concern.** Keep PRs small and focused. Do not bundle unrelated
  changes.
- **Be kind.** Review the code, not the person. Suggest concrete changes with
  code examples.

---

## 2. Getting Started

### Prerequisites

- **Flutter 3.44.x** (Dart 3.12.x)
- **Rust 1.99.x** (`. "$HOME/.cargo/env"`)
- **Android SDK/NDK** (for Android builds)
- **Xcode** (only for iOS changes)

### First build

```sh
cd app
flutter pub get
flutter analyze
flutter test
(cd rust && cargo test && cargo fmt --check && cargo clippy --all-targets -- -D warnings)
```

After changing `rust/src/api/*`, regenerate the Flutter bindings:

```sh
flutter_rust_bridge_codegen generate
```

---

## 3. How We Work

### Branches and commits

**`main` is protected — no direct pushes.** Every change goes through a pull
request.

1. Create a feature branch from `main`:
   ```sh
   git checkout -b feat/<issue-number>-short-description
   # or
   git checkout -b fix/<issue-number>-short-description
   ```
2. Make small, focused commits referencing the issue number:
   ```sh
   git commit -m "feat: short description (Closes #<issue>)"
   ```
3. Run the baseline checks (see §4).
4. Open a PR against `main` — fill in the PR checklist completely.
5. CI must pass before merging. Maintainers review and merge; the PR author
   does not self-merge unless they are a maintainer.

### Issue templates

Use the appropriate template when opening an issue:

- **Bug report** — `.github/ISSUE_TEMPLATE/bug_report.md`
- **Feature request** — `.github/ISSUE_TEMPLATE/feature_request.md`
- **General / question** — `.github/ISSUE_TEMPLATE/general.md`

Always search existing issues first to avoid duplicates.

### PR checklist

Every PR must include:

- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] `cargo test` + `cargo fmt --check` + `cargo clippy --all-targets -- -D warnings` clean
- [ ] `flutter build apk --debug` succeeds
- [ ] New dependencies added to `THIRD_PARTY.md`
- [ ] Docs/ADR updated if behavior or architecture changed
- [ ] Tests added or updated (TDD)

---

## 4. Baseline Checks

Before opening a PR (and before asking for review), run:

| Command | Purpose |
|---------|---------|
| `flutter analyze` | Dart type correctness |
| `flutter test` | Dart unit tests |
| `cargo test` | Rust unit tests |
| `cargo fmt --check` | Rust formatting |
| `cargo clippy --all-targets -- -D warnings` | Rust linting |
| `flutter build apk --debug` | Build verification (shaders + plugins) |

All must pass. CI runs the same checks plus Android and iOS builds.

---

## 5. Code Review Norms

### For authors

- Keep PRs small — under ~400 lines is ideal.
- Write a clear "What & why" summary.
- Reference the issue: `Closes #<issue>` or `Fixes #<issue>`.
- Respond to review comments. If you need more time, just say so.
- Do not self-merge unless you are a maintainer.

### For reviewers

- Review within 2 business days when possible.
- Be constructive: "Consider X because Y" beats "This is wrong."
- Suggest code changes using the "suggest a change" feature when possible.
- Approve only when all checks pass and you're confident in the change.

---

## 6. Releases (maintainers)

1. Add a `## [X.Y.Z] - date` section to `app/CHANGELOG.md`.
2. Bump `version: X.Y.Z+N` in `app/pubspec.yaml`.
3. Tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`.
4. CI builds signed per-ABI + universal APKs and publishes a GitHub Release.

---

## 7. Getting Help

- **Stuck on setup?** Open a "General / Question" issue.
- **Unsure which issue to pick?** Look for `good first issue` labels, or ask
  in any issue's comments.
- **Need a design review?** Open a draft PR early — we'd rather review
  in-progress work than surprise you at the end.

Thank you for contributing to ApertureX!
