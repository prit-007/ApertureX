# ADR 0015 — Plugins Panel (AI Models UI)

- **Status:** Accepted
- **Date:** 2026-10-19
- **Deciders:** Developer's Paradise

## Context

ApertureX ships an on-device ML stack (ADR 0010) supporting subject segmentation,
sky detection, background blur, and optional community plugins via a declarative
manifest + ONNX weights (docs/PLUGINS.md). Users need a single place to:

- See which AI models are installed and which task each one serves (subject
  masking, sky segmentation, depth estimation, etc.).
- Install new community plugins from a curated hub.
- Add custom models via a URL + manifest.
- Choose which model is **active** for each task when multiple models are
  installed for the same task (e.g., two subject segmenters).
- Consent to AI inference on first use (F-Droid compliance).

## Decision

### 1. Single "Plugins" Master Tab

A dedicated **Plugins** tab lives in the Lightroom shell alongside Light &
Color, Effects & Detail, Crop & Geometry, Pro Tools, and Masks. It hosts two
sub-tabs:

- **Installed** — lists every installed plugin with its task label, version,
  built-in vs custom status, an enable/disable toggle, and (for non-built-in)
  a delete button.
- **Community Hub** — lists verified open-source models ready for one-tap
  install, with source URL, file size, and an Install button.

### 2. Task Router (active model per task)

When multiple installed+enabled plugins exist for the same `AiTask`, the user
chooses which one is active via a dropdown in an **"Active Model per Task"**
section at the top of the Installed tab. The router:

- Maps each `AiTask` → active plugin id (persisted via shared_preferences).
- Falls back to the first enabled+installed plugin for the task when none is
  explicitly selected.
- Defaults built-in `SaliencySegmenter` as active for `subjectSegmentation`.

The Dart side exposes `AiPluginNotifier.getActivePluginForTask(task)` and
`setActivePluginForTask(task, pluginId)`.

### 3. Add Custom Model

A bottom sheet collects: model name, GitHub/HuggingFace URL, AI task dropdown,
input tensor resolution (256/512/1024), author, and optional description. On
submit it installs via `AiPluginNotifier.addCustomPlugin(...)` and marks it
enabled + installed.

### 4. AI Consent

First use of any AI inference (subject/sky/depth) shows an `aiConsentProvider`
dialog explaining local-first, no-telemetry processing. The user must grant
consent before inference runs.

### 5. UI constraints

- All plugin management stays inside the bottom sheet / tab panel — no modal
  dialogs that block the canvas unless the user explicitly triggers them.
- Installed plugin cards show the task label as a chip (e.g. "Subject Masking",
  "Depth Map Estimation") so users can tell at a glance what each model does.
- Community Hub cards show an Install button when not installed, a progress
  bar while downloading, and a disabled "Installed" chip when done.

## Consequences

**Positive**
- Users see exactly which model runs for which task — no mystery AI.
- Community plugins are discoverable and installable in-app.
- F-Droid-compliant consent dialog precedes any model inference.

**Negative / risks**
- Model licensing is manual and ongoing (see ADR 0010); the UI surfaces model
  metadata but does not verify licenses — that remains a maintainer duty.
- The Community Hub list is static/curated; a fully decentralized plugin
  registry is out of scope for P2.

**Follow-ups**
- Wire `AiPluginNotifier.getActivePluginForTask()` into the blur/spatial
  pipeline so the selected depth model drives lens blur depth maps.
- Add a "Model status" indicator (loaded / failed / incompatible) per plugin.
- Document the `manifest.json` schema in-repo when it ships.
