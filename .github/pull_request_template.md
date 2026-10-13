## What & why

Closes #<issue>.

## Checklist

- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] `cargo test` + `cargo fmt --check` + `cargo clippy --all-targets -- -D warnings` clean
- [ ] `flutter build apk --debug` succeeds (shaders + plugins compile)
- [ ] New dependencies added to `THIRD_PARTY.md`
- [ ] Docs/ADR updated if behaviour or architecture changed

## Notes
