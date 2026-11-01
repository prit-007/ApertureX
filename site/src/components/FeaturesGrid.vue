<template>
  <section id="features" class="features-section reveal">
    <div class="wrap">
      <div class="section-head">
        <span class="hud-tag">STUDIO-GRADE CAPABILITIES</span>
        <h2>Engineered for creators. Built for freedom.</h2>
        <p>
          Whether you are a professional colorist demanding calibrated tone
          curves, or a mobile creator sharing film looks on Instagram,
          ApertureX delivers desktop-class power with zero compromise.
        </p>
      </div>

      <div class="bento-grid">
        <article
          v-for="card in cards"
          :key="card.id"
          class="bento-card glass-card"
          :class="`bento-span-${card.span}`"
          :style="card.style"
        >
          <div>
            <div
              class="bento-icon"
              :style="card.iconStyle"
            >
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                :inner-html="card.svg"
              />
            </div>
            <div class="bento-title">{{ card.title }}</div>
            <div class="bento-desc" v-html="card.desc"></div>
          </div>
          <div class="bento-tag-row">
            <span
              v-for="(tag, ti) in card.tags"
              :key="ti"
              class="hud-tag"
              :class="tagClass(tag)"
            >
              {{ tag }}
            </span>
          </div>
        </article>
      </div>
    </div>
  </section>
</template>

<script setup>
const cards = [
  {
    id: 'dual-shells',
    span: 8,
    title: 'Dual UI Shells, One Shared Non-Destructive Recipe',
    desc:
      'Seamlessly switch back and forth between a <strong>Lightroom-style Precision Instrument Inspector</strong> (with 6 Master Tabs: Light, Color, Blur, Effects, Detail, Geometry) and a <strong>Snapseed-style Gesture Shell</strong> for edge-to-edge painting. Edits manipulate a unified JSON recipe with 0ms sync latency and zero canvas obstruction.',
    tags: ['6 Master Tabs', 'Rotary Jog Dial', 'Zero Canvas Suffocation'],
    tagTypes: [null, 'amber', 'coral'],
    svg: '<rect x="3" y="3" width="7" height="18" rx="1"/><rect x="14" y="3" width="7" height="18" rx="1"/>',
    iconStyle: 'background: rgba(0, 229, 255, 0.12); color: var(--cyan);',
  },
  {
    id: 'look-qr',
    span: 4,
    title: 'Look QR Code Open Standard',
    desc:
      'Bypass closed proprietary app silos forever. Turn any color grade into a stunning, printable Creator Card with a scannable QR code. Anyone points their phone camera and imports the full grade instantly. Zero cloud accounts required.',
    tags: ['Look QR Spec', '100% Offline'],
    tagTypes: ['coral', null],
    svg: '<rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/>',
    iconStyle: 'background: rgba(255, 42, 85, 0.12); color: var(--coral-soft);',
  },
  {
    id: 'qr-scanner',
    span: 4,
    title: 'Pure-FOSS QR Scanner (Rust rxing)',
    desc:
      'Unlike commercial apps that bundle Google Play Services or closed MLKit blobs, ApertureX processes live camera frames directly in compiled Rust using <code>rxing</code>. Ultra-fast, glare-resistant, and 100% F-Droid compliant.',
    tags: ['Rust rxing Engine', 'Zero Google Blobs'],
    tagTypes: ['amber', null],
    svg: '<path d="M4 8V4h4M20 8V4h-4M4 16v4h4M20 16v4h-4"/><circle cx="12" cy="12" r="3"/>',
    iconStyle: 'background: rgba(255, 179, 0, 0.12); color: var(--amber);',
  },
  {
    id: 'film-core',
    span: 4,
    title: 'Pat David Analog Film Simulation Core',
    desc:
      'Bundles legendary open-source film stock profiling: Kodak Portra 400, Fuji Pro 400H, Ilford HP5 B&W, and Cine Teal & Orange. Mathematical color transforms compressed into lightweight JSON recipes (&lt;0.05MB APK size footprint).',
    tags: ['Pat David Film Stocks', '0.05 MB Footprint'],
    tagTypes: ['emerald', null],
    svg: '<circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20M2 12a14.5 14.5 0 0 0 20 0"/>',
    iconStyle: 'background: rgba(16, 185, 129, 0.12); color: var(--emerald);',
  },
  {
    id: 'c2pa',
    span: 4,
    title: 'C2PA Content Credentials Provenance',
    desc:
      'Defend human photography against AI scraping and unauthorized alteration. ApertureX generates cryptographic C2PA manifests on-device (<code>c2pa.rs</code>) embedding verifiable digital authorship and edit transparency directly in exported JPEGs.',
    tags: ['C2PA Verified', 'SHA-256 Manifest'],
    tagTypes: [null, 'amber'],
    svg: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>',
    iconStyle: 'background: rgba(0, 229, 255, 0.12); color: var(--cyan);',
  },
  {
    id: 'preset-translation',
    span: 7,
    title: 'Universal Preset Translation Engine',
    desc:
      'Import purchased Adobe Lightroom <code>.xmp</code> &amp; <code>.lrtemplate</code> presets, Hollywood <code>.cube</code> 3D LUTs, or reverse-engineer filters from VSCO/Instagram HALD CLUT images. Export your grades straight to DaVinci Resolve or Premiere Pro. Total cross-platform interoperability.',
    tags: ['Adobe XMP / LRTEMPLATE', '3D LUT .CUBE', 'HALD CLUT PNG'],
    tagTypes: ['coral', null, 'emerald'],
    svg: '<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/>',
    iconStyle: 'background: rgba(255, 42, 85, 0.12); color: var(--coral-soft);',
  },
  {
    id: 'wiper-history',
    span: 5,
    title: 'Wiper Curtain & History Tree',
    desc:
      'Interactive Wiper Split Curtain comparison slider for live A/B evaluation, paired with a non-destructive Git-like branching history tree. Never lose an edit idea—branch, snapshot, and undo freely.',
    tags: ['Live Wiper Compare', 'Branching Snapshots'],
    tagTypes: [null, 'amber'],
    svg: '<line x1="12" y1="2" x2="12" y2="22"/><path d="m19 15-7 7-7-7"/>',
    iconStyle: 'background: rgba(0, 229, 255, 0.12); color: var(--cyan);',
  },
  {
    id: 'rust-core',
    span: 4,
    title: 'Compiled Rust Engine Core',
    desc:
      'Raw sensor demosaicing, spatial denoise, matrix operations, and lens geometry run in memory-safe Rust with zero garbage collection pauses.',
    tags: ['rust_lib_aperturex'],
    tagTypes: ['amber'],
    svg: '<path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>',
    iconStyle: 'background: rgba(255, 179, 0, 0.12); color: var(--amber);',
  },
  {
    id: 'tile-viewport',
    span: 4,
    title: '200 MP Tile Viewport',
    desc:
      'Smoothly zoom and pan medium format RAWs and 200MP phone photos. Strict 512MB device LRU tile cache prevents out-of-memory crashes on mobile.',
    tags: ['512MB LRU Tile Cache'],
    tagTypes: [null],
    svg: '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M9 3v18"/>',
    iconStyle: 'background: rgba(0, 229, 255, 0.12); color: var(--cyan);',
  },
  {
    id: 'stylus',
    span: 4,
    title: 'Pro Pen & Palm Rejection',
    desc:
      'Full pressure sensitivity (0.0 to 1.0) with Apple Pencil and S-Pen. Hardware device filtering rejects accidental palm touches while painting local masks.',
    tags: ['Hardware Filtering', 'Ruby Heatmap'],
    tagTypes: ['coral', null],
    svg: '<path d="M12 20h9M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4z"/>',
    iconStyle: 'background: rgba(255, 42, 85, 0.12); color: var(--coral-soft);',
  },
  {
    id: 'sharpen-upright',
    span: 6,
    title: 'Targeted Output Sharpening & Auto Upright',
    desc:
      'Separate output-stage sharpening from input capture sharpening with targeted radius and halo suppression tuned for <strong>Screen</strong>, <strong>Print Matte</strong>, <strong>Print Glossy</strong>, and <strong>Web</strong>. Paired with Sobel gradient line detection that automatically calculates and corrects keystone divergence in architectural photos.',
    tags: ['Output Sharpen', 'Sobel Upright Geometry', 'Print vs. Screen'],
    tagTypes: [null, 'amber', 'emerald'],
    svg: '<path d="M12 3v18M3 12h18M5.6 5.6l12.8 12.8M18.4 5.6 5.6 18.4"/>',
    iconStyle: 'background: rgba(0, 229, 255, 0.12); color: var(--cyan);',
  },
  {
    id: 'collections',
    span: 6,
    title: 'Smart Collections, 64-Bit Dedup & Quality Culling',
    desc:
      'Build dynamic query collections matching ratings, flags, focal lengths, apertures, ISO, and camera models. Cull thousands of shots effortlessly with 64-bit dHash perceptual fingerprinting, Hamming duplicate clustering, Laplacian variance blur detection, and YuNet eye openness analysis.',
    tags: ['Smart Rules Query', '64-bit dHash Hamming', 'Laplacian Sharpness'],
    tagTypes: ['emerald', null, 'coral'],
    svg: '<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/><polygon points="12 11 14 15 10 15"/>',
    iconStyle: 'background: rgba(16, 185, 129, 0.12); color: var(--emerald);',
  },
  {
    id: 'auto-mask',
    span: 6,
    title: 'Edge-Aware Auto Mask & Depth Range Slicing',
    desc:
      'Local adjustments snap directly to real subject contours using color contrast Euclidean distance gating. Isolate subjects, backgrounds, or foreground layers cleanly with depth map range masking and feathered falloff transitions.',
    tags: ['Auto-Mask Edge Brush', 'Depth Range Slicing', 'Feathered Falloff'],
    tagTypes: ['coral', null, 'amber'],
    svg: '<circle cx="12" cy="12" r="10"/><path d="M8 12h8M12 8v8"/>',
    iconStyle: 'background: rgba(255, 42, 85, 0.12); color: var(--coral-soft);',
  },
  {
    id: 'print-video',
    span: 6,
    title: 'Pro Print Studio & Video Color Studio',
    desc:
      'Prepare exhibitions and client deliveries with multi-up contact sheets, printer ICC profile soft-proofing, and high-DPI vector PDF export. Grade video clips with the exact same non-destructive 3D LUT pipeline and trim controls.',
    tags: ['Contact Sheets', 'ICC Soft-Proof', 'Video 3D LUT Grading'],
    tagTypes: ['amber', null, 'cyan'],
    svg: '<path d="M6 9V2h12v7M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/>',
    iconStyle: 'background: rgba(255, 179, 0, 0.12); color: var(--amber);',
  },
  {
    id: 'master-presets',
    span: 12,
    title: '55+ Curated Master Presets & Subject-Aware Bokeh',
    desc:
      'Explore an expansive library categorized across <strong>Cinema</strong> (<em>Oppenheimer, Interstellar, Pulp Fiction, Fight Club, La La Land, Blade Runner, John Wick 1–4, The Batman trilogy</em>), <strong>Anime Styles</strong> (<em>Shinkai Sky, Spirited Away, Ghibli, Akira Neo-Tokyo, Cyberpunk Edgerunners</em>), <strong>Nature & Travel</strong> (<em>Greenery Forest, Alpine Mountains, Royal Rajasthan, Kerala Monsoon, Bollywood Golden Hour</em>), and <strong>Analog Film</strong> (<em>Leica M Monochrom, Vintage Kodachrome 64, Fuji Velvia 50, Cinestill 800T</em>). Every preset features full 3-way color wheels, 8-band HSL mixes, and routes through Depth Anything V2 with 7 optical bokeh blade shapes.',
    tags: ['55+ Cinematic Looks', 'Depth Anything V2 Bokeh', '3-Way Color Wheels & 8-Band HSL', '7 Optical Bokeh Shapes'],
    tagTypes: ['cyan', 'amber', 'emerald', 'coral'],
    svg: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
    iconStyle: 'background: rgba(0, 229, 255, 0.12); color: var(--cyan);',
  },
]

function tagClass(type) {
  const map = {
    amber: 'hud-tag-amber',
    coral: 'hud-tag-coral',
    emerald: 'hud-tag-emerald',
    cyan: 'hud-tag-cyan',
  }
  return map[type] || ''
}
</script>

<style scoped>
.features-section {
  padding: 64px 0;
  background: var(--bg-darkest);
}

.section-head {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 40px;
}

.section-head .hud-tag {
  align-self: flex-start;
}

.section-head h2 {
  font-size: 1.75rem;
  margin: 0;
}

.section-head p {
  color: var(--text-muted);
  font-size: 1rem;
  max-width: 640px;
}

.bento-grid {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  gap: 20px;
}

.bento-card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius-xl);
  padding: 26px;
  display: flex;
  flex-direction: column;
  transition: transform 0.2s, border-color 0.2s;
}

.bento-card:hover {
  border-color: var(--border-highlight);
  transform: translateY(-2px);
}

.bento-card > div:first-child {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.bento-icon {
  width: 40px;
  height: 40px;
  border-radius: var(--radius-m);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.25rem;
  flex-shrink: 0;
}

.bento-icon svg {
  width: 100%;
  height: 100%;
}

.bento-title {
  font-family: var(--display);
  font-weight: 700;
  font-size: 1.05rem;
  color: var(--text);
  margin: 0;
}

.bento-desc {
  color: var(--text-muted);
  font-size: 0.9rem;
  line-height: 1.6;
}

.bento-tag-row {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
  margin-top: auto;
  padding-top: 18px;
  border-top: 1px solid var(--border-soft);
}

/* Span utilities */
.bento-span-12 { grid-column: span 12; }
.bento-span-8 { grid-column: span 8; }
.bento-span-7 { grid-column: span 7; }
.bento-span-6 { grid-column: span 6; }
.bento-span-5 { grid-column: span 5; }
.bento-span-4 { grid-column: span 4; }

@media (max-width: 640px) {
  .bento-grid {
    grid-template-columns: 1fr;
  }
  .bento-card {
    grid-column: span 1 !important;
  }
}
</style>
