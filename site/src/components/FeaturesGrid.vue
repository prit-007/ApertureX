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
          <div class="film-strip">
            <figure v-for="stock in filmStocks" :key="stock.name">
              <div
                class="ft"
                :style="{
                  backgroundImage: `url(${stock.img})`,
                  backgroundSize: 'cover',
                  backgroundPosition: 'center',
                  filter: stock.filter,
                }"
              ></div>
              <figcaption>{{ stock.name }}</figcaption>
            </figure>
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

        <!-- Card 11: Output Sharpening & Auto Upright -->
        <div class="bento-card glass-card bento-span-6">
          <div>
            <div class="bento-icon" style="background: rgba(0, 229, 255, 0.12); color: var(--cyan);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 3v18M3 12h18M5.6 5.6l12.8 12.8M18.4 5.6 5.6 18.4" />
              </svg>
            </div>
            <div class="bento-title">Targeted Output Sharpening &amp; Auto Upright</div>
            <div class="bento-desc">
              Separate output-stage sharpening from input capture sharpening with targeted radius and halo
              suppression tuned for <strong>Screen</strong>, <strong>Print Matte</strong>,
              <strong>Print Glossy</strong>, and <strong>Web</strong>. Paired with Sobel gradient line
              detection that automatically calculates and corrects keystone divergence in architectural photos.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag">Output Sharpen</span>
            <span class="hud-tag hud-tag-amber">Sobel Upright Geometry</span>
            <span class="hud-tag hud-tag-emerald">Print vs. Screen</span>
          </div>
        </div>

        <!-- Card 12: Smart Collections & 64-Bit Perceptual Dedup -->
        <div class="bento-card glass-card bento-span-6">
          <div>
            <div class="bento-icon" style="background: rgba(16, 185, 129, 0.12); color: var(--emerald);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
                <polygon points="12 11 14 15 10 15" />
              </svg>
            </div>
            <div class="bento-title">Smart Collections, 64-Bit Dedup &amp; Quality Culling</div>
            <div class="bento-desc">
              Build dynamic query collections matching ratings, flags, focal lengths, apertures, ISO, and
              camera models. Cull thousands of shots effortlessly with 64-bit dHash perceptual
              fingerprinting, Hamming duplicate clustering, Laplacian variance blur detection, and YuNet
              eye openness analysis.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-emerald">Smart Rules Query</span>
            <span class="hud-tag">64-bit dHash Hamming</span>
            <span class="hud-tag hud-tag-coral">Laplacian Sharpness</span>
          </div>
        </div>

        <!-- Card 13: Edge-Aware Auto Mask & Depth Range Slicing -->
        <div class="bento-card glass-card bento-span-6">
          <div>
            <div class="bento-icon" style="background: rgba(255, 42, 85, 0.12); color: var(--coral-soft);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10" />
                <path d="M8 12h8M12 8v8" />
              </svg>
            </div>
            <div class="bento-title">Edge-Aware Auto Mask &amp; Depth Range Slicing</div>
            <div class="bento-desc">
              Local adjustments snap directly to real subject contours using color contrast Euclidean
              distance gating. Isolate subjects, backgrounds, or foreground layers cleanly with depth map
              range masking and feathered falloff transitions.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-coral">Auto-Mask Edge Brush</span>
            <span class="hud-tag">Depth Range Slicing</span>
            <span class="hud-tag hud-tag-amber">Feathered Falloff</span>
          </div>
        </div>

        <!-- Card 14: Print Studio & Video Color Studio -->
        <div class="bento-card glass-card bento-span-6">
          <div>
            <div class="bento-icon" style="background: rgba(255, 179, 0, 0.12); color: var(--amber);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M6 9V2h12v7M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
            </div>
            <div class="bento-title">Pro Print Studio &amp; Video Color Studio</div>
            <div class="bento-desc">
              Prepare exhibitions and client deliveries with multi-up contact sheets, printer ICC profile
              soft-proofing, and high-DPI vector PDF export. Grade video clips with the exact same
              non-destructive 3D LUT pipeline and trim controls.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-amber">Contact Sheets</span>
            <span class="hud-tag">ICC Soft-Proof</span>
            <span class="hud-tag">Video 3D LUT Grading</span>
          </div>
        </div>

        <!-- Card 15: Universal Format Vault & Lossless DNG -->
        <div class="bento-card glass-card bento-span-6">
          <div>
            <div class="bento-icon" style="background: rgba(0, 229, 255, 0.12); color: var(--cyan);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 2 2 7l10 5 10-5-10-5z" />
                <path d="M2 12l10 5 10-5" />
                <path d="M2 17l10 5 10-5" />
              </svg>
            </div>
            <div class="bento-title">Universal Format Vault &amp; Lossless DNG</div>
            <div class="bento-desc">
              Import <strong>RAW</strong> (DNG, CR2, NEF, ARW, RAF), <strong>HEIC / AVIF</strong>, PNG,
              and JPEG. Export full-resolution JPEG, PNG, <strong>lossless DNG</strong> with the XMP
              recipe embedded, and <strong>16-bit TIFF</strong> with the entire edit baked in. Background
              batch export runs in its own isolate with wake-lock persistence.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag">RAW Demosaic + DCP</span>
            <span class="hud-tag hud-tag-amber">Lossless DNG Export</span>
            <span class="hud-tag hud-tag-emerald">16-bit TIFF</span>
            <span class="hud-tag">HEIC / AVIF</span>
          </div>
        </div>

        <!-- Card 16: Lensfun Optics, Defringe & EXIF Inspector -->
        <div class="bento-card glass-card bento-span-6">
          <div>
            <div class="bento-icon" style="background: rgba(255, 42, 85, 0.12); color: var(--coral-soft);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="9" />
                <circle cx="12" cy="12" r="3.5" />
                <path d="M12 3v3.5M21 12h-3.5M12 21v-3.5M3 12h3.5" />
              </svg>
            </div>
            <div class="bento-title">Lensfun Optics, Defringe &amp; EXIF Inspector</div>
            <div class="bento-desc">
              A hardware lens database corrects distortion and vignetting per camera and lens profile,
              paired with purple/green <strong>chromatic-aberration defringe</strong>. The full EXIF
              sheet exposes body, lens, shutter, aperture, ISO, and focus distance for every shot.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-coral">Lensfun Profiles</span>
            <span class="hud-tag">CA Defringe</span>
            <span class="hud-tag hud-tag-amber">Full EXIF Sheet</span>
          </div>
        </div>

        <!-- Card 17: Tethered Capture, OTA Updates & Desktop MenuBar -->
        <div class="bento-card glass-card bento-span-6">
          <div>
            <div class="bento-icon" style="background: rgba(255, 179, 0, 0.12); color: var(--amber);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M9 2v6M15 2v6M7 8h10v4a5 5 0 0 1-10 0V8z" />
                <path d="M12 17v5" />
              </svg>
            </div>
            <div class="bento-title">Tethered Capture, OTA &amp; Desktop MenuBar</div>
            <div class="bento-desc">
              Live USB/PTP telemetry with remote shutter release, auto-import, and auto-recipe on
              capture. The in-app OTA updater pulls signed GitHub releases with download progress,
              while native macOS, Windows, and Linux menu bars expose shortcuts and batch actions.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-amber">USB / PTP Tether</span>
            <span class="hud-tag">Signed OTA Updater</span>
            <span class="hud-tag">Native MenuBar</span>
          </div>
        </div>

        <!-- Card 18: Community Hub, BYOM Plugins & Global UI -->
        <div class="bento-card glass-card bento-span-6">
          <div>
            <div class="bento-icon" style="background: rgba(16, 185, 129, 0.12); color: var(--emerald);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10" />
                <path d="M2 12h20M12 2a15 15 0 0 1 0 20 15 15 0 0 1 0-20" />
              </svg>
            </div>
            <div class="bento-title">Community Hub, BYOM Plugins &amp; Global UI</div>
            <div class="bento-desc">
              Browse a GitHub-backed <strong>community preset hub</strong> with one-tap previews and
              saves, or bring your own ONNX model through declarative manifests. The whole interface
              ships in English, Spanish, German, French, Japanese, and Chinese, with a searchable
              in-app academy and tool guide.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-emerald">Community Presets</span>
            <span class="hud-tag">BYOM ONNX</span>
            <span class="hud-tag">6 Languages</span>
            <span class="hud-tag hud-tag-coral">In-App Academy</span>
          </div>
        </div>

        <!-- Card 19: Master Preset Catalog & Depth Anything V2 Bokeh -->
        <div class="bento-card glass-card bento-span-12">
          <div>
            <div class="bento-icon" style="background: rgba(0, 229, 255, 0.12); color: var(--cyan);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="3" />
                <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" />
              </svg>
            </div>
            <div class="bento-title">55+ Curated Master Presets &amp; Subject-Aware Bokeh</div>
            <div class="bento-desc">
              Explore an expansive library categorized across <strong>Cinema</strong>
              (<em>Oppenheimer, Interstellar, Pulp Fiction, Fight Club, La La Land, Blade Runner, John Wick 1–4, The Batman trilogy</em>),
              <strong>Anime Styles</strong> (<em>Shinkai Sky, Spirited Away, Ghibli, Akira Neo-Tokyo, Cyberpunk Edgerunners</em>),
              <strong>Nature &amp; Travel</strong> (<em>Greenery Forest, Alpine Mountains, Royal Rajasthan, Kerala Monsoon, Bollywood Golden Hour</em>),
              and <strong>Analog Film</strong> (<em>Leica M Monochrom, Vintage Kodachrome 64, Fuji Velvia 50, Cinestill 800T</em>).
              Every preset features full 3-way color wheels, 8-band HSL mixes, and routes through Depth Anything V2
              with 7 optical bokeh blade shapes.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag">55+ Cinematic Looks</span>
            <span class="hud-tag hud-tag-amber">Depth Anything V2 Bokeh</span>
            <span class="hud-tag hud-tag-emerald">3-Way Color Wheels &amp; 8-Band HSL</span>
            <span class="hud-tag hud-tag-coral">7 Optical Bokeh Shapes</span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { onMounted } from 'vue'
import filmPortra from '../assets/stock/gallery-1.webp'
import filmPro400h from '../assets/stock/gallery-4.webp'
import filmHp5 from '../assets/stock/compare.webp'
import filmTeal from '../assets/stock/gallery-6.webp'

const filmStocks = [
  { name: 'Portra 400', img: filmPortra, filter: 'saturate(1.3) contrast(1.1) sepia(0.18) hue-rotate(-8deg)' },
  { name: 'Pro 400H', img: filmPro400h, filter: 'saturate(0.9) contrast(1.05) brightness(1.08) hue-rotate(12deg)' },
  { name: 'HP5', img: filmHp5, filter: 'grayscale(1) contrast(1.4)' },
  { name: 'Teal & Orange', img: filmTeal, filter: 'saturate(1.7) contrast(1.2) hue-rotate(-20deg)' },
]

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
