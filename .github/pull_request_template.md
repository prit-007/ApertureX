## What & why

Closes #<issue>.

Briefly describe the change and why it is needed.

## Branch convention

- [ ] Branch name follows `feat/<issue-number>-short-description` or `fix/<issue-number>-short-description`
- [ ] Branch created from `main` (not from another feature branch)
- [ ] No direct pushes to `main` — all changes come through this PR

## Checklist

- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] `cargo test` + `cargo fmt --check` + `cargo clippy --all-targets -- -D warnings` clean
- [ ] `flutter build apk --debug` succeeds (shaders + plugins compile)
- [ ] New dependencies added to `THIRD_PARTY.md`
- [ ] Docs/ADR updated if behaviour or architecture changed
- [ ] Tests added or updated for the change (TDD house standard)

## Notes
