# ApertureX — Professional Editor UX Enhancements (Lightroom & Snapseed Synthesis)

## 1. Overview
ApertureX synthesizes the best UX patterns from Adobe Lightroom Mobile and Google Snapseed into a unified, non-destructive mobile photo editor. This document outlines the key UX enhancements implemented and planned to deliver a pro-grade editing experience on Android and iOS.

---

## 2. Core UX Pillars

### 2.1 Viewport Sanctity & Glassmorphic UI Mode
* **Problem**: Editing panels and HUD chrome obscure significant portions of the image, making it hard to evaluate composition, global tone, and peripheral balance.
* **Solution**:
  - **Glassmorphic Frosted Glass**: Uses hardware-accelerated `BackdropFilter` (Impeller/Skia) with `sigma=16–20` and translucent surface colors (`alpha=0.65–0.72`) with subtle outline borders.
  - **Photo Extension Behind Chrome**: The photo extends beneath the top HUD and bottom sheet so edges and composition remain visible at all times.
  - **Active Touch Fade**: While actively dragging a slider or canvas parameter, surrounding chrome automatically fades out (`_Fade`), leaving a distraction-free view of the photo.

### 2.2 Gesture Precision & Direct Manipulation (Snapseed Magic)
* **Vertical Axis**: Fluid axis-locked swipe to cycle between related parameters (e.g. Exposure → Highlights → Shadows → Saturation).
* **Horizontal Axis**: Pixel-scrubbing parameter adjustment with non-linear fine control.
* **Instant Reset**: Double-tap any slider thumb, numeric label, or sheet handle to reset to neutral.
* **Instant Before/After**: Dedicated `Hold to compare` affordance that immediately reveals the unedited base image without losing current slider focus.

### 2.3 On-Device AI Intelligence & Calibration (Lightroom Parity)
* **AI Depth Calibration**:
  - Automatically estimates scene depth and subject plane using on-device saliency subject centroid and vertical extent (`cy` / `ry`).
  - Calibrates `blurFocalPoint` and `blurFocalRange` with one tap, enabling DSLR-like optical lens blur on photos taken without dual-camera depth metadata.
  - 100% offline and F-Droid compliant (zero telemetry, zero cloud calls).
* **AI Subject & Sky Masks**:
  - Instant one-tap subject/background isolation with 256×256 alpha bitmaps.
  - Intent-based "Smart Paste" that automatically re-infers AI masks when copying edits across different photos.
  - Floating status pill (`_AiProgressFloatingPill`) giving clear progress feedback during background inference.

### 2.4 Ergonomics & Responsive Form Factors
* **Thumb Zone Architecture**:
  - All critical adjustment tools live within the bottom 25–40% thumb reach zone in portrait mode.
  - Multi-snap bottom sheet: Collapsed (0%), Peek (20%), Half (36%), and Full (62%) with swipe-velocity snap physics.
* **Universal Tablet/Desktop Layout**:
  - Automatically transitions to a split layout on wide screens (>=600dp or landscape): 70% viewport on the left, 30% responsive instrument sidebar on the right (clamped to 320–480dp) with notch/punch-hole safety insets.
* **Stylus Precision & Palm Rejection**:
  - Filters touch events during brush masking to reject accidental palm contacts.
  - Detects `invertedStylus` to switch automatically between brush paint and eraser modes.

### 2.5 Film Simulation & Shader Lab (Lightroom Effects parity)
* **Photochemical film physics** baked into the CPU preview base: halation (red highlight fringe with radius/threshold), bloom (glow with radius/threshold), dust flecks, and scratches — each 0–1 with neutral-at-zero defaults.
* **Shader Lab**: selectable film presets (`shaderLabPreset`) plus three freeform parameters (`shaderParam1..3`, `customGlslCode`) for creative, non-destructive looks.
* Film parameters live in their own `RecipeSection.film` / `RecipeSection.lab` groups in the versioned recipe schema, so they round-trip through QR shares, presets, and DNG XMP sidecars unchanged.

### 2.6 Interactive Split Curtain A/B Compare
* **Draggable Split Divider**: Live touch/mouse draggable divider splitting original unedited photo and current edited render with zero latency.
* **Dual Orientations**: 1-tap toggle between vertical (left-to-right) and horizontal (top-to-bottom) split axes to fit portrait or landscape compositions.
* **Haptic Snapping**: Snaps smoothly back to 50% center upon double-tap.

### 2.7 Zen Top Bar Ergonomics & Accessibility (a11y)
* **Active Canvas Immersion**: Touching or scrubbing any image parameter dims out and ignores top bar chrome, giving 100% visual focus to the photo.
* **Tactile Undo/Redo & History Tree**: Tapping undo reverts the last committed node; long-pressing summons the visual `HistoryTreeSheet` showing the branching edit graph with direct branch switching.
* **WCAG Minimum Touch Targets**: All export cancel, navigation, and modal buttons adhere to 44×44dp minimum interactive bounding constraints with clear semantic hints for TalkBack / VoiceOver.

### 2.8 Google Photos-Style Gallery & DAM
* **Fluid Date-Grouped Grid**: Responsive multi-column layout adapting across mobile phones (2–3 columns) up to 14" tablets (5–7 columns) with pinch-to-zoom grid density.
* **Album Truncation & Text Ellipses**: Custom album sheet safely clamps lengthy folder paths with intelligent mid/tail truncation, avoiding RenderFlex overflows.
* **Pro DAM Tagging**: Full keywords chip management and Lightroom-compatible color labels (Red, Yellow, Green, Blue, Purple) integrated into Drift SQLite catalog with 1-tap filtering.
* **Multi-Photo Batch Sync**: Select multiple assets and batch sync entire recipes or selective parameter groups with background job status feedback.

### 2.9 Soft Proofing & Out-of-Gamut Warnings
* **Target Output Profile Simulation**: Live on-canvas simulation for sRGB (web), Display P3 (wide gamut), Adobe RGB (photography), and US Web Coated SWOP (CMYK print).
* **Rendering Intents**: Selectable Perceptual and Relative Colorimetric gamut compression mappings.
* **High-Visibility Gamut Warning**: Customizable false-color overlay (bright cyan default) pinpointing pixels that clip or exceed target printer gamut boundaries.

### 2.10 Output Sharpening & Media Profiling (ADR 0024)
* **Dedicated Output Medium Profiling**: Distinct high-boost convolution profiles separating capture/input sharpening from output publishing destinations.
* **Media Targets**:
  - `Screen`: 3×3 unsharp mask tuned for modern high-DPI smartphone, tablet, and desktop panels.
  - `PrintMatte`: 5×5 broader convolution ($R=2$, $\times 1.4$ boost) specifically formulated to counter physical ink absorption and fiber dot gain on fine-art rag paper.
  - `PrintGlossy`: 3×3 micro-contrast edge kernel matching smooth ink holdout on resin-coated glossy media.
  - `Web`: Compact thresholded edge sharpening preventing downsampling blur.

### 2.11 Upright Geometry & Auto-Convergence (ADR 0024)
* **Single-Tap Vertical Correction**: Architectural upright button in `GeometryControls` calculating Sobel edge divergence and automatically applying horizon auto-straighten and keystone vertical perspective without manual grid guessing.

### 2.12 Edge-Aware Auto Masking & Depth Range Slicing (ADR 0024)
* **Smart Edge-Aware Brush (`MASK_AUTO_BRUSH`)**: Evaluates color contrast against the initial stroke touch point, letting users brush quickly near boundaries while the mask halts cleanly at contrasting edges.
* **Depth Plane Slicing (`MASK_DEPTH_RANGE`)**: Isolate foreground objects, subject planes, or backgrounds across depth thresholds with feathering controls.

### 2.13 Smart Collections, Perceptual Duplicate Culling & Folder Watching (ADR 0025)
* **Multi-Rule Dynamic Collections**: Instant query filtering based on ratings, flags, color labels, keywords, camera models, dates, and edit state with built-in presets (*5 Star Picks*, *Flagged Favorites*, *Needs Review*).
* **64-bit Perceptual Hash Duplicate Culling**: Rapid dHash scanning with popcount Hamming distance clustering ($d \le 6$) to identify, inspect, and bulk-select burst shots and redundant files.
* **Optical Sharpness & Closed-Eye Detection**: Laplacian variance blur scoring and YuNet eye openness detection flagging blinks on group shots directly on gallery tiles.
* **Debounced Auto-Import Folder Watching**: Background file monitoring automatically ingesting photos dropped into target directories.
