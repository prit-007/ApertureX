<template>
  <section id="features">
    <div class="wrap">
      <div class="section-head">
        <span class="hud-tag">STUDIO-GRADE CAPABILITIES</span>
        <h2>Engineered for creators. Built for freedom.</h2>
        <p>
          Whether you are a professional colorist demanding calibrated tone curves, or a
          mobile creator sharing film looks on Instagram, ApertureX delivers desktop-class
          power with zero compromise.
        </p>
      </div>

      <div class="bento-grid">
        <!-- Card 1: Dual UI Shells -->
        <div class="bento-card glass-card bento-span-8">
          <div>
            <div class="bento-icon" style="background: rgba(0, 229, 255, 0.12); color: var(--cyan);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="3" y="3" width="7" height="18" rx="1" />
                <rect x="14" y="3" width="7" height="18" rx="1" />
              </svg>
            </div>
            <div class="bento-title">Dual UI Shells, One Shared Non-Destructive Recipe</div>
            <div class="bento-desc">
              Seamlessly switch back and forth between a <strong>Lightroom-style Precision Instrument Inspector</strong>
              (with 6 Master Tabs: Light, Color, Blur, Effects, Detail, Geometry) and a <strong>Snapseed-style Gesture Shell</strong>
              for edge-to-edge painting. Edits manipulate a unified JSON recipe with 0ms sync latency and zero canvas
              obstruction.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag">6 Master Tabs</span>
            <span class="hud-tag hud-tag-amber">Rotary Jog Dial</span>
            <span class="hud-tag hud-tag-coral">Zero Canvas Suffocation</span>
          </div>
        </div>

        <!-- Card 2: Look QR -->
        <div class="bento-card glass-card bento-span-4">
          <div>
            <div class="bento-icon" style="background: rgba(255, 42, 85, 0.12); color: var(--coral-soft);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="3" y="3" width="7" height="7" />
                <rect x="14" y="3" width="7" height="7" />
                <rect x="3" y="14" width="7" height="7" />
                <rect x="14" y="14" width="7" height="7" />
              </svg>
            </div>
            <div class="bento-title">Look QR Code Open Standard</div>
            <div class="bento-desc">
              Bypass closed proprietary app silos forever. Turn any color grade into a stunning, printable Creator Card
              with a scannable QR code. Anyone points their phone camera and imports the full grade instantly. Zero
              cloud accounts required.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-coral">Look QR Spec</span>
            <span class="hud-tag">100% Offline</span>
          </div>
        </div>

        <!-- Card 3: QR Scanner -->
        <div class="bento-card glass-card bento-span-4">
          <div>
            <div class="bento-icon" style="background: rgba(255, 179, 0, 0.12); color: var(--amber);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M4 8V4h4M20 8V4h-4M4 16v4h4M20 16v4h-4" />
                <circle cx="12" cy="12" r="3" />
              </svg>
            </div>
            <div class="bento-title">Pure-FOSS QR Scanner (Rust rxing)</div>
            <div class="bento-desc">
              Unlike commercial apps that bundle Google Play Services or closed MLKit blobs, ApertureX processes live
              camera frames directly in compiled Rust using <code>rxing</code>. Ultra-fast, glare-resistant, and 100%
              F-Droid compliant.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-amber">Rust rxing Engine</span>
            <span class="hud-tag">Zero Google Blobs</span>
          </div>
        </div>

        <!-- Card 4: Film Simulation -->
        <div class="bento-card glass-card bento-span-4">
          <div>
            <div class="bento-icon" style="background: rgba(16, 185, 129, 0.12); color: var(--emerald);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10" />
                <path d="M12 2a14.5 14.5 0 0 0 0 20M2 12a14.5 14.5 0 0 0 20 0" />
              </svg>
            </div>
            <div class="bento-title">Pat David Analog Film Simulation Core</div>
            <div class="bento-desc">
              Bundles legendary open-source film stock profiling: Kodak Portra 400, Fuji Pro 400H, Ilford HP5 B&amp;W,
              and Cine Teal &amp; Orange. Mathematical color transforms compressed into lightweight JSON recipes
              (&lt;0.05MB APK size footprint).
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-emerald">Pat David Film Stocks</span>
            <span class="hud-tag">0.05 MB Footprint</span>
          </div>
        </div>

        <!-- Card 5: C2PA -->
        <div class="bento-card glass-card bento-span-4">
          <div>
            <div class="bento-icon" style="background: rgba(0, 229, 255, 0.12); color: var(--cyan);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                <path d="m9 12 2 2 4-4" />
              </svg>
            </div>
            <div class="bento-title">C2PA Content Credentials Provenance</div>
            <div class="bento-desc">
              Defend human photography against AI scraping and unauthorized alteration. ApertureX generates
              cryptographic C2PA manifests on-device (<code>c2pa.rs</code>) embedding verifiable digital authorship and
              edit transparency directly in exported JPEGs.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag">C2PA Verified</span>
            <span class="hud-tag hud-tag-amber">SHA-256 Manifest</span>
          </div>
        </div>

        <!-- Card 6: Preset Translation -->
        <div class="bento-card glass-card bento-span-7">
          <div>
            <div class="bento-icon" style="background: rgba(255, 42, 85, 0.12); color: var(--coral-soft);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
              </svg>
            </div>
            <div class="bento-title">Universal Preset Translation Engine</div>
            <div class="bento-desc">
              Import purchased Adobe Lightroom <code>.xmp</code> &amp; <code>.lrtemplate</code> presets, Hollywood
              <code>.cube</code> 3D LUTs, or reverse-engineer filters from VSCO/Instagram HALD CLUT images. Export your
              grades straight to DaVinci Resolve or Premiere Pro. Total cross-platform interoperability.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-coral">Adobe XMP / LRTEMPLATE</span>
            <span class="hud-tag">3D LUT .CUBE</span>
            <span class="hud-tag hud-tag-emerald">HALD CLUT PNG</span>
          </div>
        </div>

        <!-- Card 7: Wiper & History -->
        <div class="bento-card glass-card bento-span-5">
          <div>
            <div class="bento-icon" style="background: rgba(0, 229, 255, 0.12); color: var(--cyan);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="12" y1="2" x2="12" y2="22" />
                <path d="m19 15-7 7-7-7" />
              </svg>
            </div>
            <div class="bento-title">Wiper Curtain &amp; History Tree</div>
            <div class="bento-desc">
              Interactive Wiper Split Curtain comparison slider for live A/B evaluation, paired with a non-destructive
              Git-like branching history tree. Never lose an edit idea—branch, snapshot, and undo freely.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag">Live Wiper Compare</span>
            <span class="hud-tag hud-tag-amber">Branching Snapshots</span>
          </div>
        </div>

        <!-- Card 8: Rust Core -->
        <div class="bento-card glass-card bento-span-4">
          <div>
            <div class="bento-icon" style="background: rgba(255, 179, 0, 0.12); color: var(--amber);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
              </svg>
            </div>
            <div class="bento-title">Compiled Rust Engine Core</div>
            <div class="bento-desc">
              Raw sensor demosaicing, spatial denoise, matrix operations, and lens geometry run in memory-safe Rust with
              zero garbage collection pauses.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-amber">rust_lib_aperturex</span>
          </div>
        </div>

        <!-- Card 9: Tile Viewport -->
        <div class="bento-card glass-card bento-span-4">
          <div>
            <div class="bento-icon" style="background: rgba(0, 229, 255, 0.12); color: var(--cyan);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="3" y="3" width="18" height="18" rx="2" />
                <path d="M3 9h18M9 3v18" />
              </svg>
            </div>
            <div class="bento-title">200 MP Tile Viewport</div>
            <div class="bento-desc">
              Smoothly zoom and pan medium format RAWs and 200MP phone photos. Strict 512MB device LRU tile cache
              prevents out-of-memory crashes on mobile.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag">512MB LRU Tile Cache</span>
          </div>
        </div>

        <!-- Card 10: Stylus -->
        <div class="bento-card glass-card bento-span-4">
          <div>
            <div class="bento-icon" style="background: rgba(255, 42, 85, 0.12); color: var(--coral-soft);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 20h9M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4z" />
              </svg>
            </div>
            <div class="bento-title">Pro Pen &amp; Palm Rejection</div>
            <div class="bento-desc">
              Full pressure sensitivity (0.0 to 1.0) with Apple Pencil and S-Pen. Hardware device filtering rejects
              accidental palm touches while painting local masks.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-coral">Hardware Filtering</span>
            <span class="hud-tag">Ruby Heatmap</span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { onMounted } from 'vue'

onMounted(() => {
  // Linear spotlight follows pointer across bento cards (hover devices only)
  if (window.matchMedia('(hover: hover)').matches) {
    document.querySelectorAll('.bento-card').forEach((card) => {
      card.addEventListener('pointermove', (e) => {
        const rect = card.getBoundingClientRect()
        card.style.setProperty('--mouse-x', (e.clientX - rect.left) + 'px')
        card.style.setProperty('--mouse-y', (e.clientY - rect.top) + 'px')
      })
    })
  }
})
</script>

<style scoped>
.bento-grid {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  gap: 20px;
}
.bento-card {
  padding: 32px;
  position: relative;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  --mouse-x: 50%;
  --mouse-y: 50%;
}
.bento-card > * {
  position: relative;
  z-index: 1;
}
.bento-card::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  padding: 1px;
  background: radial-gradient(
    800px circle at var(--mouse-x) var(--mouse-y),
    rgba(0, 229, 255, 0.4),
    transparent 40%
  );
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
  opacity: 0;
  transition: opacity 0.3s ease;
  z-index: 2;
}
.bento-card::after {
  content: '';
  position: absolute;
  inset: 0;
  background: radial-gradient(
    600px circle at var(--mouse-x) var(--mouse-y),
    rgba(0, 229, 255, 0.04),
    transparent 40%
  );
  border-radius: inherit;
  pointer-events: none;
  opacity: 0;
  transition: opacity 0.3s ease;
  z-index: 0;
}
.bento-card:hover::before,
.bento-card:hover::after {
  opacity: 1;
}
.bento-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 20px;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.15);
  transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}
.bento-icon svg {
  width: 24px;
  height: 24px;
}
.bento-card:hover .bento-icon {
  transform: scale(1.1) rotate(-3deg);
}
.bento-title {
  font-size: 1.35rem;
  font-weight: 700;
  color: var(--text);
  margin-bottom: 10px;
}
.bento-desc {
  font-size: 0.94rem;
  color: var(--text-muted);
  line-height: 1.6;
  margin-bottom: 18px;
}
.bento-tag-row {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
  margin-top: 12px;
}
.bento-span-8 {
  grid-column: span 8;
}
.bento-span-7 {
  grid-column: span 7;
}
.bento-span-5 {
  grid-column: span 5;
}
.bento-span-4 {
  grid-column: span 4;
}
@media (max-width: 980px) {
  .bento-span-8,
  .bento-span-7,
  .bento-span-5,
  .bento-span-4 {
    grid-column: span 12;
  }
}
</style>
