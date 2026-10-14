# ApertureX

The Flutter app for **ApertureX** — a mobile-native, non-destructive FOSS photo
editor. See the [project README](../README.md) and [`docs/`](../docs) for
architecture, roadmap and decisions.

## Layout

- `lib/` — Dart app (shells, canvas, gallery, edit model, settings, logs).
- `rust/` — the Rust engine (color/geometry/spatial/mask/decode/export) behind
  `flutter_rust_bridge`.
- `shaders/` — the fragment shader that samples the baked 3D LUT.
- `test/` — unit + widget tests.

## Develop

```sh
flutter pub get
flutter analyze
flutter test
(cd rust && cargo test)
flutter run --profile   # use --profile/--release for real 60fps
```

After editing `rust/src/api/**`, regenerate the bridge:

```sh
flutter_rust_bridge_codegen generate
```

## Privacy

ApertureX is fully offline: it makes no network calls and sends nothing
anywhere. All edits are stored locally; the activity log lives on-device.
