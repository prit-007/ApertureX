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
  - Multi-snap bottom sheet: Collapsed (0%), Peek (20%), Half (24%), and Full (38%) with swipe-velocity snap physics.
* **Universal Tablet/Desktop Layout**:
  - Automatically transitions to a split layout on wide screens (>=600dp or landscape): 70% viewport on the left, 30% responsive instrument sidebar on the right (clamped to 320–480dp) with notch/punch-hole safety insets.
* **Stylus Precision & Palm Rejection**:
  - Filters touch events during brush masking to reject accidental palm contacts.
  - Detects `invertedStylus` to switch automatically between brush paint and eraser modes.
