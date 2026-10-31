# ADR 0023 — Studio Tethered Shooting & Camera Link Workflow

- **Status:** Accepted
- **Date:** 2026-10-30
- **Deciders:** Developer's Paradise
- **Consults:** ADR 0001 (Flutter UI & Rust Engine), ADR 0003 (Non-destructive Recipe Model), ADR 0014 (Library Catalog)

---

## 1. Context

Commercial studio workflows (fashion, product photography, portrait sessions) require tethered shooting:
- Connecting the camera directly to a tablet, laptop, or desktop monitor via USB 3.2 or Wi-Fi (PTP/IP).
- Live camera telemetry streaming: Shutter speed, aperture, ISO, battery percentage, remaining shots on CFexpress/SD media, and lens metadata.
- Remote shutter release trigger from the software interface without touching the camera tripod setup.
- Immediate auto-import of captured RAW files into the active project session.
- Automatic application of the active look/recipe so clients and art directors see the final graded photo within seconds of shutter release.

## 2. Decision

Implement the Studio Tethered Shooting pipeline (`app/lib/features/tether/`):

1. **Telemetry & Session Data Structures (`tether_model.dart`)**:
   - `CameraTelemetry`: Real-time camera telemetry (shutter speed, aperture, ISO, battery %, lens, card capacity).
   - `TetherSession`: Session name, destination folder, auto-naming pattern (`[Session]_[Seq4].ARW`), auto-select latest, and auto-apply recipe settings.
   - `TetherCaptureItem`: Queued RAW asset with metadata and timestamp.

2. **Tether Controller & Capture State (`tether_controller.dart`)**:
   - Manages connection states (`disconnected`, `connecting`, `connected`, `capturing`, `error`).
   - `triggerShutter()`: Remote shutter release method triggering camera exposure and high-speed asset transfer.
   - Automatically increments session sequence numbers and decrements remaining card capacity.

3. **Studio Telemetry HUD (`tether_hud.dart`)**:
   - Top studio bar displaying connection status indicator, camera model chip, exposure parameter pills (`SS`, `F`, `ISO`), battery gauge, and remote shutter release button with tactile haptic response.
   - Responsive horizontal scrolling for seamless adaptation across phones, tablets, and wide studio monitors.

4. **Studio Tether Screen (`tether_screen.dart`)**:
   - Full loupe inspection viewport for instant image review.
   - Bottom filmstrip showing all captures in the active session with sequence numbering.
   - Session settings sheet for folder routing and auto-grading configuration.

## 3. Consequences

### Positive
- **Studio Ready**: Matches Capture One Pro and Lightroom Classic tethered workflows.
- **Instant Client Review**: Auto-selected incoming captures allow real-time evaluation with active recipes applied.
- **Hardware Agnostic**: Supports standard PTP/IP and USB tethering protocols.

### Negative
- Wireless tethering over congested studio 2.4/5GHz Wi-Fi requires reliable fallback buffering when transferring high-resolution 60-100MP uncompressed RAW files.
