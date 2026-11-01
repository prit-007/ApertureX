<template>
  <section id="screens">
    <div class="wrap">
      <div class="section-head center">
        <span class="hud-tag">INTERACTIVE STUDIO TOUR</span>
        <h2>Experience the real app workflows</h2>
        <p>
          ApertureX is designed with thumb ergonomics and zero canvas obstruction.
          Test the live interactive simulator below across all five core studios.
        </p>
      </div>

      <div class="interactive-demo">
        <div class="demo-nav" role="tablist" aria-label="Studio tour">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            type="button"
            class="demo-tab-btn"
            :class="{ active: activeTab === tab.id }"
            role="tab"
            :aria-selected="activeTab === tab.id"
            aria-controls="demoPanel"
            @click="setDemoTab(tab.id)"
          >
            {{ tab.label }}
          </button>
        </div>

        <div class="demo-stage" id="demoPanel" role="tabpanel" :aria-labelledby="`tab-${activeTab}`">
          <!-- Mockup Column -->
          <div class="demo-mockup-col">
            <div class="phone-frame">
              <div class="phone-island"></div>
              <div class="phone-screen" id="mockScreen">
                <!-- 1. Lightroom View -->
                <div id="mockLightroomView" v-if="activeTab === 'lightroom'" style="display:flex; flex-direction:column; height:100%;">
                  <div class="mock-canvas" id="mockCanvas">
                    <img
                      id="mockCanvasImg"
                      :src="editorImg"
                      alt="Editor canvas preview"
                      style="width:100%;height:100%;object-fit:cover;opacity:0;transition:opacity .5s ease;"
                    />
                    <div id="mockCanvasFallback" class="mock-canvas-art" style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;color:rgba(255,255,255,0.7);">
                      <svg width="72" height="72" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <circle cx="12" cy="12" r="10" />
                        <path d="m4.93 4.93 4.24 4.24M14.83 9.17l4.24-4.24M14.83 14.83l4.24 4.24M9.17 14.83l-4.24 4.24" />
                      </svg>
                    </div>
                  </div>

                  <div class="mock-hud-tray">
                    <div class="mock-chip-row" id="mockChipRow" role="group" aria-label="Adjustment category">
                      <button type="button" class="mock-chip active" aria-pressed="true" data-cat="Light" @click="setMockCategory('Light')">Light</button>
                      <button type="button" class="mock-chip" aria-pressed="false" data-cat="Color" @click="setMockCategory('Color')">Color</button>
                      <button type="button" class="mock-chip" aria-pressed="false" data-cat="Blur" @click="setMockCategory('Blur')">Blur</button>
                      <button type="button" class="mock-chip" aria-pressed="false" data-cat="Effects" @click="setMockCategory('Effects')">Effects</button>
                      <button type="button" class="mock-chip" aria-pressed="false" data-cat="Detail" @click="setMockCategory('Detail')">Detail</button>
                      <button type="button" class="mock-chip" aria-pressed="false" data-cat="Geometry" @click="setMockCategory('Geometry')">Geometry</button>
                    </div>

                    <div class="mock-subchip-row" id="mockSubchipRow" role="group" aria-label="Adjustment submenu">
                      <button v-for="(sub, idx) in currentCategory.submenus" :key="idx" type="button" class="mock-subchip" :class="{ active: idx === 0 }">
                        {{ sub }}
                      </button>
                    </div>

                    <div class="mock-slider-box">
                      <div class="mock-slider-head">
                        <span class="name">{{ currentCategory.s1.name }}</span>
                        <span class="val">{{ formatSlider1 }}</span>
                      </div>
                      <div class="mock-slider-track" id="mockSlider1Track" role="slider" tabindex="0" @mousedown="startS1Drag" @touchstart="startS1Drag">
                        <div class="mock-slider-fill" id="mockSlider1Fill" :style="slider1Style"></div>
                        <div class="mock-slider-thumb" id="mockSlider1Thumb" :style="{ left: slider1ThumbLeft }"></div>
                      </div>
                    </div>

                    <div class="mock-slider-box">
                      <div class="mock-slider-head">
                        <span class="name">{{ currentCategory.s2.name }}</span>
                        <span class="val">{{ formatSlider2 }}</span>
                      </div>
                      <div class="mock-slider-track" id="mockSlider2Track" role="slider" tabindex="0" @mousedown="startS2Drag" @touchstart="startS2Drag">
                        <div class="mock-slider-fill" id="mockSlider2Fill" :style="slider2Style"></div>
                        <div class="mock-slider-thumb" id="mockSlider2Thumb" :style="{ left: slider2ThumbLeft }"></div>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- 2. Snapseed Mode View -->
                <div id="mockSnapseedView" v-if="activeTab === 'snapseed'" class="mock-snapseed">
                  <div class="mock-canvas" id="mockSnapseedCanvas" style="background:#0B0E15; cursor: crosshair;" @mousemove="moveSnBrush" @touchmove="moveSnBrush">
                    <img
                      id="snapseedMaskImg"
                      :src="maskImg"
                      alt="Ruby mask overlay"
                      style="width:100%;height:100%;object-fit:cover;opacity:0;transition:opacity .5s ease;"
                    />
                    <div id="snapseedMaskFallback" style="position:absolute;inset:0;">
                      <div class="mock-ruby-mask" id="mockRubyMask" :style="{ left: rubyLeft, top: rubyTop }"></div>
                      <div class="mock-brush-cursor" id="mockBrushCursor" :style="{ left: brushLeft, top: brushTop }"></div>
                    </div>
                  </div>
                  <div class="mock-gesture-hud" id="mockGestureHud" role="group" aria-label="Gesture mask tool">
                    <button type="button" class="active" aria-pressed="true" @click="setSnapseedTool($event)">BRUSH</button>
                    <button type="button" aria-pressed="false" @click="setSnapseedTool($event)">LINEAR</button>
                    <button type="button" aria-pressed="false" @click="setSnapseedTool($event)">RADIAL</button>
                    <button type="button" aria-pressed="false" @click="setSnapseedTool($event)">DEPTH</button>
                    <button type="button" aria-pressed="false" @click="setSnapseedTool($event)">ERASER</button>
                  </div>
                </div>

                <!-- 3. Look QR Studio View -->
                <div id="mockQrView" v-if="activeTab === 'lookqr'" class="mock-qr-box">
                  <div class="mock-qr-card">
                    <div class="mock-qr-preview-thumb">
                      <span>Kodak Portra 400</span>
                      <span style="font-size:0.5rem; background:rgba(0,229,255,0.25); color:var(--cyan);">APERTUREX</span>
                    </div>
                    <div class="mock-qr-code-graphic">
                      <img
                        id="lookqrImg"
                        :src="lookqrImgSrc"
                        alt="Look QR code"
                        style="width:100px;height:100px;border-radius:8px;padding:6px;object-fit:cover;opacity:0;transition:opacity .5s ease;box-shadow:0 4px 16px rgba(0,0,0,0.5);background:#FFF;"
                      />
                      <div id="lookqrFallback" style="width:100px;height:100px;background:#FFF;border-radius:8px;padding:6px;display:flex;align-items:center;justify-content:center;box-shadow:0 4px 16px rgba(0,0,0,0.5);">
                        <svg viewBox="0 0 100 100" width="88" height="88">
                          <rect x="5" y="5" width="28" height="28" fill="#000" />
                          <rect x="9" y="9" width="20" height="20" fill="#FFF" />
                          <rect x="13" y="13" width="12" height="12" fill="#000" />
                          <rect x="67" y="5" width="28" height="28" fill="#000" />
                          <rect x="71" y="9" width="20" height="20" fill="#FFF" />
                          <rect x="75" y="13" width="12" height="12" fill="#000" />
                          <rect x="5" y="67" width="28" height="28" fill="#000" />
                          <rect x="9" y="71" width="20" height="20" fill="#FFF" />
                          <rect x="13" y="75" width="12" height="12" fill="#000" />
                          <rect x="38" y="10" width="8" height="8" fill="#000" />
                          <rect x="50" y="15" width="8" height="8" fill="#000" />
                          <rect x="38" y="25" width="6" height="6" fill="#000" />
                          <rect x="48" y="38" width="14" height="14" fill="#000" />
                          <rect x="68" y="40" width="8" height="8" fill="#000" />
                          <rect x="15" y="42" width="10" height="10" fill="#000" />
                          <rect x="38" y="55" width="8" height="8" fill="#000" />
                          <rect x="52" y="65" width="10" height="10" fill="#000" />
                          <rect x="68" y="65" width="8" height="8" fill="#000" />
                          <rect x="40" y="80" width="12" height="12" fill="#000" />
                          <rect x="70" y="80" width="8" height="8" fill="#000" />
                        </svg>
                      </div>
                    </div>
                    <div class="mock-qr-meta">
                      <strong>Look QR Creator Card</strong>
                      <span>Exp +0.50 &bull; Warm 5600K &bull; Film Grain 24</span>
                    </div>
                  </div>
                  <div class="mock-qr-badge">100% Offline &bull; Scanned via Rust rxing</div>
                </div>

                <!-- 4. Export & C2PA Mode View -->
                <div id="mockExportView" v-if="activeTab === 'export'" class="mock-export-box" style="--export-img: url('/assets/stock/export.webp');">
                  <img
                    id="mockExportRingImg"
                    :src="exportImg"
                    alt="Export processing"
                    style="width:100%;height:100%;object-fit:cover;opacity:0;transition:opacity .5s ease;"
                  />
                  <div id="mockExportRingFallback" style="position:absolute;inset:0;background:#090C12;display:flex;align-items:center;justify-content:center;padding:20px;">
                    <div class="mock-ring" id="mockExportRing" :style="{ background: exportRingBg }">
                      <b id="mockExportVal">{{ exportPercent }}%</b>
                    </div>
                  </div>
                  <span id="mockExportLabel">{{ exportLabel }}</span>
                  <button type="button" class="btn btn-ghost" style="padding:6px 16px; font-size:0.75rem; border-radius:100px; cursor:pointer;" @click="triggerSimulatedExport">
                    Simulate Stream
                  </button>
                  <div style="width:100%; padding:8px 12px; border-radius:8px; background:rgba(255,255,255,0.05); font-size:0.7rem; display:flex; justify-content:space-between;">
                    <span>C2PA Manifest</span><b style="color:var(--emerald);">Signed On-Device</b>
                  </div>
                  <div style="width:100%; padding:8px 12px; border-radius:8px; background:rgba(255,255,255,0.05); font-size:0.7rem; display:flex; justify-content:space-between;">
                    <span>Watermark</span><b style="color:var(--cyan);">Photographer Stamp</b>
                  </div>
                  <div style="width:100%; padding:8px 12px; border-radius:8px; background:rgba(255,255,255,0.05); font-size:0.7rem; display:flex; justify-content:space-between;">
                    <span>Sidecar</span><b style="color:var(--text);">photo.xmp + .cube</b>
                  </div>
                </div>

                <!-- 5. Gallery Mode View -->
                <div id="mockGalleryView" v-if="activeTab === 'gallery'" class="mock-gallery-box">
                  <div class="mock-gallery-header">
                    <h4>Photos <span style="font-size:0.65rem; color:var(--text-muted);">(October 2026)</span></h4>
                    <span class="mock-gallery-badge">BATCH SELECT</span>
                  </div>
                  <div class="mock-gallery-grid">
                    <div v-for="(g, i) in galleryItems" :key="i" class="mock-photo-tile" :class="{ sel: gallerySel > i }" :style="{ background: g.bg }">
                      <img
                        class="gallery-img"
                        :src="g.img"
                        :alt="`Gallery photo ${i + 1}`"
                        style="width:100%;height:100%;object-fit:cover;opacity:0;transition:opacity .5s ease;"
                      />
                      <div class="gallery-fallback" :style="{ background: g.bg }"></div>
                      <span class="mock-photo-tag">{{ g.tag }}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Details Column -->
          <div class="demo-details-col">
            <div v-if="activeTab === 'lightroom'" id="demoTextLightroom">
              <span class="hud-tag">ZEN 6-MASTER NAVIGATION</span>
              <h3 style="margin-top:14px;">The photo is the hero: never suffocate the canvas</h3>
              <p>
                Unlike bloated apps where bottom sheets cover 80% of the screen, ApertureX guarantees that the photo
                occupies 75&ndash;80% of portrait height. Clean progressive disclosure groups controls into 6 Master Tabs:
                <strong>Light</strong>, <strong>Color</strong>, <strong>Blur</strong>, <strong>Effects</strong>,
                <strong>Detail</strong>, and <strong>Geometry</strong> with dedicated sub-menus.
              </p>
              <div class="feature-checklist">
                <div class="check-item">
                  <div class="check-dot"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6 9 17l-5-5" /></svg></div>
                  <div class="check-text">
                    <strong>Interactive 120 FPS Response</strong>
                    <span>Drag the exposure and contrast sliders in the mockup above to see live preview updates in real-time.</span>
                  </div>
                </div>
                <div class="check-item">
                  <div class="check-dot"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6 9 17l-5-5" /></svg></div>
                  <div class="check-text">
                    <strong>Rotary Jog Dial &amp; Micro-Haptics</strong>
                    <span>Haptic clicks whenever crossing neutral zero detents; values never jitter during high-speed drag.</span>
                  </div>
                </div>
                <div class="check-item">
                  <div class="check-dot"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6 9 17l-5-5" /></svg></div>
                  <div class="check-text">
                    <strong>Deep Pro Sub-Menus</strong>
                    <span>Curve RGB channels, Color Grading Wheels, HSL 8-Channel Mixer, LAB space, and Retouch Healing.</span>
                  </div>
                </div>
              </div>
            </div>

            <div v-if="activeTab === 'snapseed'" id="demoTextSnapseed" style="display:none;">
              <span class="hud-tag hud-tag-coral">FULL-BLEED GESTURE SHELL</span>
              <h3 style="margin-top:14px;">Pro Pen precision &amp; hardware palm rejection</h3>
              <p>Switch to the Snapseed shell for gesture-first editing. Paint local adjustments with pressure sensitivity
                (Apple Pencil / S-Pen), while touch gestures remain locked to zoom and pan.</p>
              <div class="feature-checklist">
                <div class="check-item">
                  <div class="check-dot"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6 9 17l-5-5" /></svg></div>
                  <div class="check-text">
                    <strong>Device Filtering &amp; Inverted Eraser</strong>
                    <span>Touch inputs are strictly rejected during brush strokes to eliminate accidental thumb marks.</span>
                  </div>
                </div>
                <div class="check-item">
                  <div class="check-dot"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6 9 17l-5-5" /></svg></div>
                  <div class="check-text">
                    <strong>Ruby Mask Heatmap</strong>
                    <span>Active mask layers glow in ruby red so you see precisely which highlights, shadows, or figures are affected.</span>
                  </div>
                </div>
              </div>
            </div>

            <div v-if="activeTab === 'lookqr'" id="demoTextLookQr" style="display:none;">
              <span class="hud-tag hud-tag-amber">LOOK QR OPEN STANDARD</span>
              <h3 style="margin-top:14px;">Share color grades offline via QR cards</h3>
              <p>Presets shouldn't be trapped behind paywalls or proprietary server accounts. ApertureX encodes 100% of
                your color grading recipe mathematics into an offline scannable QR code.</p>
              <div class="feature-checklist">
                <div class="check-item">
                  <div class="check-dot"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6 9 17l-5-5" /></svg></div>
                  <div class="check-text">
                    <strong>Pure-FOSS Rust rxing Scanner</strong>
                    <span>Point your camera at a computer screen, printed card, or phone. Decodes instantly with zero Google blobs.</span>
                  </div>
                </div>
                <div class="check-item">
                  <div class="check-dot"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6 9 17l-5-5" /></svg></div>
                  <div class="check-text">
                    <strong>Community Preset Hub</strong>
                    <span>Browse and download community-curated styles from public GitHub repositories with in-app previews.</span>
                  </div>
                </div>
              </div>
            </div>

            <div v-if="activeTab === 'export'" id="demoTextExport" style="display:none;">
              <span class="hud-tag hud-tag-emerald">BANDED EXPORT &amp; C2PA SIGNING</span>
              <h3 style="margin-top:14px;">Banded 200MP streaming with authenticity manifests</h3>
              <p>Exporting massive multi-megapixel files requires gigabytes if processed in one buffer. ApertureX streams
                bands through compiled Rust, keeping memory capped under 512MB while signing C2PA Content Credentials.</p>
              <div class="feature-checklist">
                <div class="check-item">
                  <div class="check-dot"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6 9 17l-5-5" /></svg></div>
                  <div class="check-text">
                    <strong>On-Device C2PA Manifest Signing</strong>
                    <span>Embeds cryptographic proof of digital authorship and transparent edit history without cloud telemetry.</span>
                  </div>
                </div>
                <div class="check-item">
                  <div class="check-dot"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6 9 17l-5-5" /></svg></div>
                  <div class="check-text">
                    <strong>Custom Export Branding &amp; Watermark</strong>
                    <span>Render photographer signatures, camera EXIF stamps, and open-source badges in native Rust.</span>
                  </div>
                </div>
              </div>
            </div>

            <div v-if="activeTab === 'gallery'" id="demoTextGallery" style="display:none;">
              <span class="hud-tag">STUDIO ASSET MANAGEMENT</span>
              <h3 style="margin-top:14px;">Fast photo catalog with RAW badges &amp; batch ops</h3>
              <p>Organize, rate, and filter entire photo libraries smoothly. View RAW, HDR, and edited versions,
                copy-paste settings recipes across multiple photos, and batch export in seconds.</p>
              <div class="feature-checklist">
                <div class="check-item">
                  <div class="check-dot"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6 9 17l-5-5" /></svg></div>
                  <div class="check-text">
                    <strong>Batch Copy &amp; Paste Recipes</strong>
                    <span>Grade one photo to perfection and instantly apply the exact adjustments across an entire photoshoot.</span>
                  </div>
                </div>
                <div class="check-item">
                  <div class="check-dot"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M20 6 9 17l-5-5" /></svg></div>
                  <div class="check-text">
                    <strong>Non-Destructive Versions</strong>
                    <span>Keep multiple artistic edits of the same capture without duplicating multi-megabyte storage files.</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import editorImg from '../assets/stock/editor.webp'
import maskImg from '../assets/stock/mask.webp'
import lookqrImgSrc from '../assets/stock/lookqr.webp'
import exportImg from '../assets/stock/export.webp'

const tabs = [
  { id: 'lightroom', label: '1. Zen Lightroom Inspector' },
  { id: 'snapseed', label: '2. Snapseed Gesture Shell' },
  { id: 'lookqr', label: '3. Look QR & Film Studio' },
  { id: 'export', label: '4. Lossless Export & C2PA' },
  { id: 'gallery', label: '5. Studio Library & Batch' },
]

const activeTab = ref('lightroom')
const editorImageSrc = editorImg
const maskImageSrc = maskImg
const lookqrImage = lookqrImgSrc
const exportImageSrc = exportImg

const MOCK_CATEGORIES = {
  Light: {
    submenus: ['Tone', 'Curve', 'Dynamic Range'],
    s1: { name: 'Exposure (EV)', min: -5, max: 5, val: 0.5, format: (v) => (v >= 0 ? '+' : '') + v.toFixed(2) + ' EV' },
    s2: { name: 'Contrast', min: -100, max: 100, val: 18, format: (v) => (v >= 0 ? '+' : '') + Math.round(v) },
    filter: (v1, v2) => 'brightness(' + (1 + v1 * 0.15) + ') contrast(' + (1 + v2 * 0.005) + ')',
  },
  Color: {
    submenus: ['White Balance', 'HSL Mixer', 'Color Wheels', 'LAB Space'],
    s1: { name: 'Temp (Kelvin)', min: 2000, max: 10000, val: 5600, format: (v) => Math.round(v) + ' K' },
    s2: { name: 'Vibrance', min: -100, max: 100, val: 24, format: (v) => (v >= 0 ? '+' : '') + Math.round(v) },
    filter: (v1, v2) => 'sepia(' + Math.max(0, (v1 - 5000) / 10000) + ') saturate(' + (1 + v2 * 0.006) + ')',
  },
  Blur: {
    submenus: ['Lens Optics', 'Optical Bokeh', 'Depth Map'],
    s1: { name: 'Iris Aperture', min: 1.2, max: 16, val: 1.8, format: (v) => 'f/' + v.toFixed(1) },
    s2: { name: 'Aperture Blades', min: 5, max: 9, val: 7, format: (v) => Math.round(v) + ' blades' },
    filter: (v1, v2) => 'blur(' + Math.max(0, (4 - v1) * 0.9) + 'px)',
  },
  Effects: {
    submenus: ['Clarity', 'Film Grain', 'Halation', 'Vignette'],
    s1: { name: 'Clarity', min: -100, max: 100, val: 15, format: (v) => (v >= 0 ? '+' : '') + Math.round(v) },
    s2: { name: 'Film Grain', min: 0, max: 100, val: 24, format: (v) => Math.round(v) + '%' },
    filter: (v1, v2) => 'contrast(' + (1 + v1 * 0.004) + ')',
  },
  Detail: {
    submenus: ['Sharpening', 'Denoise', 'Retouch Healing'],
    s1: { name: 'Sharpening', min: 0, max: 150, val: 40, format: (v) => Math.round(v) },
    s2: { name: 'Luminance Denoise', min: 0, max: 100, val: 20, format: (v) => Math.round(v) },
    filter: (v1, v2) => 'contrast(' + (1 + v1 * 0.002) + ')',
  },
  Geometry: {
    submenus: ['Crop & Aspect', 'Auto-Straighten', 'Keystone'],
    s1: { name: 'Auto-Straighten', min: -10, max: 10, val: 0.4, format: (v) => (v >= 0 ? '+' : '') + v.toFixed(1) + '° (Hough)' },
    s2: { name: 'Perspective Skew', min: -40, max: 40, val: 0, format: (v) => (v >= 0 ? '+' : '') + Math.round(v) + '°' },
    filter: () => 'none',
  },
}

const currentCategory = computed(() => MOCK_CATEGORIES[activeCategory.value])
const activeCategory = ref('Light')

const formatSlider1 = computed(() => currentCategory.value.s1.format(currentCategory.value.s1.val))
const formatSlider2 = computed(() => currentCategory.value.s2.format(currentCategory.value.s2.val))

const slider1Pct = computed(() => ((currentCategory.value.s1.val - currentCategory.value.s1.min) / (currentCategory.value.s1.max - currentCategory.value.s1.min)) * 100)
const slider2Pct = computed(() => ((currentCategory.value.s2.val - currentCategory.value.s2.min) / (currentCategory.value.s2.max - currentCategory.value.s2.min)) * 100)

const slider1Style = computed(() => {
  const cat = currentCategory.value
  const p1 = slider1Pct.value
  if (cat.s1.min < 0 && cat.s1.max > 0) {
    const mid = ((-cat.s1.min) / (cat.s1.max - cat.s1.min)) * 100
    if (p1 >= mid) {
      return { left: mid + '%', width: (p1 - mid) + '%' }
    } else {
      return { left: p1 + '%', width: (mid - p1) + '%' }
    }
  } else {
    return { left: '0%', width: p1 + '%' }
  }
})

const slider2Style = computed(() => {
  const cat = currentCategory.value
  const p2 = slider2Pct.value
  if (cat.s2.min < 0 && cat.s2.max > 0) {
    const mid2 = ((-cat.s2.min) / (cat.s2.max - cat.s2.min)) * 100
    if (p2 >= mid2) {
      return { left: mid2 + '%', width: (p2 - mid2) + '%' }
    } else {
      return { left: p2 + '%', width: (mid2 - p2) + '%' }
    }
  } else {
    return { left: '0%', width: p2 + '%' }
  }
})

const slider1ThumbLeft = computed(() => slider1Pct.value + '%')
const slider2ThumbLeft = computed(() => slider2Pct.value + '%')

const galleryItems = [
  { bg: 'radial-gradient(circle, #FFB300, #FF2A55)', img: '/assets/stock/gallery-1.webp', tag: 'RAW' },
  { bg: 'radial-gradient(circle, #00E5FF, #006699)', img: '/assets/stock/gallery-2.webp', tag: 'HDR' },
  { bg: 'radial-gradient(circle, #70F3FF, #152238)', img: '/assets/stock/gallery-3.webp', tag: 'RAW' },
  { bg: 'radial-gradient(circle, #FF5C7E, #3A0C16)', img: '/assets/stock/gallery-4.webp', tag: 'EDIT' },
  { bg: 'radial-gradient(circle, #FFD54F, #5D3A00)', img: '/assets/stock/gallery-5.webp', tag: 'RAW' },
  { bg: 'radial-gradient(circle, #10B981, #083320)', img: '/assets/stock/gallery-6.webp', tag: 'C2PA' },
]
const gallerySel = ref(3)

// Snapseed brush state
const brushLeft = ref('151px')
const brushTop = ref('221px')
const rubyLeft = ref('90px')
const rubyTop = ref('150px')

// Export simulator state
const exportPercent = ref(74)
const exportLabel = ref('Banded Streaming')
const exportRingBg = ref('conic-gradient(var(--cyan) 0% 74%, rgba(255, 255, 255, 0.08) 74% 100%)')
let exportInterval = null

function setDemoTab(tab) {
  activeTab.value = tab
  activeCategory.value = 'Light'
}

function setMockCategory(name) {
  activeCategory.value = name
}

function moveSnBrush(e) {
  const canvas = document.getElementById('mockSnapseedCanvas')
  if (!canvas) return
  const rect = canvas.getBoundingClientRect()
  const clientX = e.touches ? e.touches[0].clientX : e.clientX
  const clientY = e.touches ? e.touches[0].clientY : e.clientY
  const x = clientX - rect.left
  const y = clientY - rect.top
  brushLeft.value = (x - 19) + 'px'
  brushTop.value = (y - 19) + 'px'
  rubyLeft.value = (x - 80) + 'px'
  rubyTop.value = (y - 90) + 'px'
}

function setSnapseedTool(e) {
  e.currentTarget.parentElement.querySelectorAll('button').forEach((s) => {
    s.classList.remove('active')
    s.setAttribute('aria-pressed', 'false')
  })
  e.currentTarget.classList.add('active')
  e.currentTarget.setAttribute('aria-pressed', 'true')
}

let s1Dragging = false
let s2Dragging = false

function startS1Drag(e) {
  s1Dragging = true
  updateS1(e)
}
function startS2Drag(e) {
  s2Dragging = true
  updateS2(e)
}

function updateS1(e) {
  if (!s1Dragging) return
  const track = document.getElementById('mockSlider1Track')
  if (!track) return
  const rect = track.getBoundingClientRect()
  const clientX = e.touches ? e.touches[0].clientX : e.clientX
  const pct = Math.max(0, Math.min(100, ((clientX - rect.left) / rect.width) * 100))
  const cat = currentCategory.value
  cat.s1.val = cat.s1.min + (pct / 100) * (cat.s1.max - cat.s1.min)
}

function updateS2(e) {
  if (!s2Dragging) return
  const track = document.getElementById('mockSlider2Track')
  if (!track) return
  const rect = track.getBoundingClientRect()
  const clientX = e.touches ? e.touches[0].clientX : e.clientX
  const pct = Math.max(0, Math.min(100, ((clientX - rect.left) / rect.width) * 100))
  const cat = currentCategory.value
  cat.s2.val = cat.s2.min + (pct / 100) * (cat.s2.max - cat.s2.min)
}

function triggerSimulatedExport() {
  const ring = document.getElementById('mockExportRing')
  const val = document.getElementById('mockExportVal')
  const label = document.getElementById('mockExportLabel')
  if (!ring || !val) return
  if (exportInterval) clearInterval(exportInterval)
  let p = exportPercent.value
  label.value = 'Streaming Bands...'
  exportLabel.value = 'Streaming Bands...'
  exportInterval = setInterval(() => {
    p += 3
    if (p >= 100) {
      p = 100
      clearInterval(exportInterval)
      exportLabel.value = 'C2PA Signed (photo.xmp)'
    }
    exportPercent.value = p
    exportRingBg.value = 'conic-gradient(var(--cyan) 0% ' + p + '%, rgba(255, 255, 255, 0.08) ' + p + '% 100%)'
  }, 25)
}

onMounted(() => {
  // Wire window drag listeners
  window.addEventListener('mousemove', (e) => {
    if (s1Dragging) updateS1(e)
    if (s2Dragging) updateS2(e)
  })
  window.addEventListener('mouseup', () => {
    s1Dragging = false
    s2Dragging = false
  })
  window.addEventListener('touchmove', (e) => {
    if (s1Dragging) updateS1(e)
    if (s2Dragging) updateS2(e)
  }, { passive: true })
  window.addEventListener('touchend', () => {
    s1Dragging = false
    s2Dragging = false
  })
})

onUnmounted(() => {
  if (exportInterval) clearInterval(exportInterval)
})
</script>

<style scoped>
.interactive-demo {
  background: var(--bg-1);
  border: 1px solid var(--border);
  border-radius: var(--radius-xl);
  padding: 44px;
  box-shadow: 0 40px 80px -30px rgba(0, 0, 0, 0.8);
}
@media (max-width: 640px) {
  .interactive-demo {
    padding: 24px 18px;
  }
}

.demo-nav {
  display: flex;
  justify-content: center;
  gap: 8px;
  margin-bottom: 40px;
  flex-wrap: wrap;
}
.demo-tab-btn {
  padding: 10px 18px;
  border-radius: 100px;
  font-family: var(--display);
  font-size: 0.88rem;
  font-weight: 700;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--border);
  color: var(--text-muted);
  cursor: pointer;
  transition: all 0.2s ease;
}
.demo-tab-btn:hover {
  background: rgba(255, 255, 255, 0.08);
  color: var(--text);
}
.demo-tab-btn.active {
  background: var(--cyan);
  color: #040810;
  border-color: var(--cyan);
  box-shadow: 0 4px 20px rgba(0, 229, 255, 0.35);
}

.demo-stage {
  display: grid;
  grid-template-columns: 310px 1fr;
  gap: 50px;
  align-items: center;
}
@media (max-width: 900px) {
  .demo-stage {
    grid-template-columns: 1fr;
    gap: 36px;
  }
}

.demo-mockup-col {
  display: flex;
  justify-content: center;
}

.phone-frame {
  width: 290px;
  height: 590px;
  border-radius: 44px;
  padding: 10px;
  background: #080B12;
  border: 1px solid rgba(255, 255, 255, 0.12);
  box-shadow: 0 35px 70px -15px rgba(0, 229, 255, 0.28), 0 0 0 1px rgba(255, 255, 255, 0.05);
  position: relative;
  user-select: none;
  animation: phoneFloat 6s ease-in-out infinite;
  will-change: transform;
}
@keyframes phoneFloat {
  0%, 100% {
    transform: translateY(0) rotateX(0deg) rotateY(0deg);
    box-shadow: 0 35px 70px -15px rgba(0, 229, 255, 0.28), 0 0 0 1px rgba(255, 255, 255, 0.05);
  }
  50% {
    transform: translateY(-12px) rotateX(2deg) rotateY(-2deg);
    box-shadow: 0 50px 80px -10px rgba(0, 229, 255, 0.15), 0 0 0 1px rgba(255, 255, 255, 0.05);
  }
}
@media (prefers-reduced-motion: reduce) {
  .phone-frame { animation: none; }
}
.phone-screen {
  position: relative;
  width: 100%;
  height: 100%;
  border-radius: 34px;
  overflow: hidden;
  background: #0A0D14;
  display: flex;
  flex-direction: column;
}
.phone-island {
  position: absolute;
  top: 10px;
  left: 50%;
  transform: translateX(-50%);
  width: 80px;
  height: 18px;
  border-radius: 20px;
  background: #000;
  z-index: 50;
}

.mock-canvas {
  flex: 1;
  position: relative;
  background: radial-gradient(circle at 50% 40%, #FFB300 0%, #FF3366 50%, #007799 100%);
  transition: filter 0.1s ease;
  overflow: hidden;
}
.mock-canvas-art {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  color: rgba(255, 255, 255, 0.7);
}
.mock-hud-tray {
  height: 236px;
  background: rgba(11, 14, 21, 0.95);
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(16px);
  display: flex;
  flex-direction: column;
  padding: 8px 12px;
  gap: 8px;
  z-index: 10;
}
.mock-chip-row {
  display: flex;
  gap: 5px;
  overflow-x: auto;
  scrollbar-width: none;
  padding-bottom: 2px;
}
.mock-chip {
  appearance: none;
  padding: 3px 8px;
  border-radius: 100px;
  font-size: 0.62rem;
  font-family: var(--display);
  font-weight: 700;
  line-height: 1.2;
  color: var(--text-muted);
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.08);
  white-space: nowrap;
  cursor: pointer;
}
.mock-chip.active {
  background: rgba(0, 229, 255, 0.15);
  color: var(--cyan);
  border-color: rgba(0, 229, 255, 0.4);
}
.mock-subchip-row {
  display: flex;
  gap: 4px;
  overflow-x: auto;
  scrollbar-width: none;
  padding-bottom: 2px;
}
.mock-subchip {
  appearance: none;
  padding: 2px 7px;
  border-radius: 4px;
  font-size: 0.56rem;
  font-family: var(--mono);
  line-height: 1.2;
  color: var(--text-faint);
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.06);
  white-space: nowrap;
  cursor: pointer;
}
.mock-subchip.active {
  color: var(--amber);
  background: rgba(255, 179, 0, 0.12);
  border-color: rgba(255, 179, 0, 0.35);
}
.mock-slider-box {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.mock-slider-head {
  display: flex;
  justify-content: space-between;
  font-size: 0.62rem;
  font-family: var(--display);
  font-weight: 700;
}
.mock-slider-head .name {
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
.mock-slider-head .val {
  color: var(--cyan);
  font-family: var(--mono);
}
.mock-slider-track {
  position: relative;
  height: 6px;
  border-radius: 3px;
  background: rgba(255, 255, 255, 0.12);
  cursor: pointer;
  touch-action: pan-y;
}
.mock-slider-fill {
  position: absolute;
  top: 0;
  bottom: 0;
  background: var(--cyan);
  border-radius: 3px;
}
.mock-slider-thumb {
  position: absolute;
  top: 50%;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  background: #FFF;
  box-shadow: 0 0 8px rgba(0, 229, 255, 0.8);
  cursor: grab;
}

.mock-snapseed {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  background: #0B0E15;
}
.mock-ruby-mask {
  position: absolute;
  top: 140px;
  left: 50px;
  width: 160px;
  height: 180px;
  border-radius: 50% 45% 60% 40%;
  background: radial-gradient(circle, rgba(255, 42, 85, 0.6), rgba(255, 42, 85, 0.2) 65%, transparent 80%);
  filter: blur(4px);
  pointer-events: none;
  animation: pulseMask 4s ease-in-out infinite alternate;
}
@keyframes pulseMask {
  0% { transform: scale(0.98); opacity: 0.75; }
  100% { transform: scale(1.04); opacity: 0.95; }
}
.mock-brush-cursor {
  position: absolute;
  top: 240px;
  left: 170px;
  width: 38px;
  height: 38px;
  border-radius: 50%;
  border: 2px dashed rgba(255, 255, 255, 0.9);
  box-shadow: 0 0 10px rgba(0, 0, 0, 0.6);
}
.mock-gesture-hud {
  position: absolute;
  bottom: 24px;
  left: 16px;
  right: 16px;
  background: rgba(14, 18, 28, 0.85);
  border: 1px solid var(--border);
  border-radius: 100px;
  padding: 10px 16px;
  display: flex;
  justify-content: space-around;
  backdrop-filter: blur(16px);
}
.mock-gesture-hud button {
  appearance: none;
  background: none;
  border: 0;
  padding: 4px 2px;
  font-size: 0.68rem;
  font-family: var(--display);
  font-weight: 700;
  color: var(--text-muted);
  cursor: pointer;
}
.mock-gesture-hud button.active {
  color: var(--cyan);
}

.mock-export-box {
  position: absolute;
  inset: 0;
  background: #090C12;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 20px;
}
.mock-ring {
  width: 96px;
  height: 96px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  box-shadow: 0 0 30px rgba(0, 229, 255, 0.25);
}
.mock-ring::after {
  content: '';
  position: absolute;
  inset: 9px;
  border-radius: 50%;
  background: #0B0E15;
}
.mock-ring b {
  position: relative;
  z-index: 2;
  font-family: var(--display);
  font-size: 1.3rem;
  font-weight: 800;
  color: var(--cyan);
}

.mock-qr-box {
  position: absolute;
  inset: 0;
  background: #090C12;
  display: flex;
  flex-direction: column;
  padding: 24px 14px 14px 14px;
  gap: 10px;
  align-items: center;
  overflow-y: auto;
}
.mock-qr-card {
  width: 100%;
  background: linear-gradient(145deg, #141924, #0D111A);
  border: 1px solid rgba(0, 229, 255, 0.25);
  border-radius: 16px;
  padding: 14px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6);
}
.mock-qr-preview-thumb {
  width: 100%;
  height: 90px;
  border-radius: 10px;
  background: radial-gradient(circle at 60% 40%, #FFB300 0%, #FF3366 50%, #007799 100%);
  position: relative;
  overflow: hidden;
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  padding: 8px 10px;
}
.mock-qr-preview-thumb span {
  font-size: 0.62rem;
  font-weight: 700;
  background: rgba(0, 0, 0, 0.7);
  backdrop-filter: blur(8px);
  padding: 2px 7px;
  border-radius: 4px;
  color: #FFF;
}
.mock-qr-code-graphic {
  width: 100px;
  height: 100px;
  background: #FFF;
  border-radius: 8px;
  padding: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);
}
.mock-qr-meta {
  text-align: center;
  font-size: 0.68rem;
  color: var(--text-muted);
}
.mock-qr-meta strong {
  display: block;
  color: var(--text);
  font-size: 0.8rem;
  letter-spacing: 0.02em;
}
.mock-qr-badge {
  font-size: 0.6rem;
  font-family: var(--mono);
  color: var(--cyan);
  background: rgba(0, 229, 255, 0.1);
  padding: 3px 8px;
  border-radius: 100px;
  border: 1px solid rgba(0, 229, 255, 0.25);
}

.mock-gallery-box {
  position: absolute;
  inset: 0;
  background: #090C12;
  display: flex;
  flex-direction: column;
  padding: 30px 12px 12px 12px;
  gap: 10px;
}
.mock-gallery-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 4px;
}
.mock-gallery-header h4 {
  font-size: 0.78rem;
  font-family: var(--display);
  color: var(--text);
  display: flex;
  align-items: center;
  gap: 6px;
}
.mock-gallery-badge {
  font-size: 0.6rem;
  font-family: var(--mono);
  color: var(--cyan);
  background: rgba(0, 229, 255, 0.1);
  padding: 2px 6px;
  border-radius: 4px;
  border: 1px solid rgba(0, 229, 255, 0.2);
}
.mock-gallery-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 6px;
  flex: 1;
}
.mock-photo-tile {
  position: relative;
  border-radius: 8px;
  aspect-ratio: 1;
  overflow: hidden;
  background-size: cover;
  background-position: center;
  border: 1px solid rgba(255, 255, 255, 0.06);
}
.mock-photo-tile.sel {
  transform: scale(0.92);
  box-shadow: 0 0 0 2px var(--cyan);
}
.mock-photo-tag {
  position: absolute;
  top: 4px;
  left: 4px;
  font-size: 0.52rem;
  font-weight: 800;
  font-family: var(--mono);
  padding: 1px 4px;
  border-radius: 3px;
  background: rgba(0, 0, 0, 0.75);
  color: var(--cyan);
}

.demo-details-col h3 {
  font-size: clamp(1.8rem, 3.2vw, 2.5rem);
  color: var(--text);
}
.demo-details-col p {
  font-size: 1.05rem;
  color: var(--text-muted);
  margin-top: 14px;
  line-height: 1.65;
}
.feature-checklist {
  margin-top: 24px;
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.check-item {
  display: flex;
  align-items: flex-start;
  gap: 14px;
}
.check-dot {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: rgba(0, 229, 255, 0.12);
  color: var(--cyan);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  margin-top: 2px;
  border: 1px solid rgba(0, 229, 255, 0.3);
}
.check-dot svg {
  width: 13px;
  height: 13px;
  stroke-width: 2.8;
}
.check-text strong {
  display: block;
  font-size: 0.95rem;
  color: var(--text);
}
.check-text span {
  font-size: 0.86rem;
  color: var(--text-muted);
  line-height: 1.45;
}
</style>

