<template>
  <section id="screens" class="screens-section reveal">
    <div class="wrap">
      <div class="section-head center">
        <span class="hud-tag">INTERACTIVE STUDIO TOUR</span>
        <h2>Experience the real app workflows</h2>
        <p>
          ApertureX is designed with thumb ergonomics and zero canvas
          obstruction. Test the live interactive simulator below across all
          five core studios.
        </p>
      </div>

      <div class="demo-tabs">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          class="demo-tab-btn"
          :class="{ active: activeTab === tab.id }"
          role="tab"
          :aria-selected="activeTab === tab.id"
          aria-controls="demoPanel"
          @click="activeTab = tab.id"
        >
          {{ tab.label }}
        </button>
      </div>

      <div class="demo-stage" id="demoPanel" role="tabpanel" :aria-labelledby="`tab-${activeTab}`">
        <div class="phone-frame">
          <div class="phone-screen" id="mockScreen">
            <div v-if="activeTab === 'lightroom'" id="mockLightroomView" style="display:flex; flex-direction:column; height:100%; background:#080B11; border-radius:16px; overflow:hidden;">
              <div class="mock-header" style="padding:12px; color:#F3F5F9; font-family:var(--mono); font-size:0.8rem; display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid #141A25;">
                <span>LIGHTROOM INSPECTOR</span>
                <span id="mockModeBadge">LIGHT</span>
              </div>
              <div class="mock-canvas" id="mockCanvas" style="flex:1; background:radial-gradient(circle at 50% 50%, #141A25 0%, #080B11 100%); position:relative;">
                <div style="position:absolute; inset:0; display:flex; align-items:center; justify-content:center; color:#94A3B8; font-family:var(--mono); font-size:0.75rem;">
                  Live grade canvas &mdash; slider auto-scrubs
                </div>
              </div>
              <div class="mock-chip-row" id="mockChipRow" style="padding:10px 12px; border-top:1px solid #141A25; background:#0E121A; display:flex; gap:8px; overflow-x:auto;">
                <span class="mock-chip active">Light</span>
                <span class="mock-chip">Color</span>
                <span class="mock-chip">Blur</span>
                <span class="mock-chip">Effects</span>
                <span class="mock-chip">Detail</span>
                <span class="mock-chip">Geometry</span>
              </div>
              <div class="mock-slider-group" style="padding:12px; background:#080B11;">
                <div class="mock-slider-row" style="display:flex; justify-content:space-between; margin-bottom:10px; font-family:var(--mono); font-size:0.75rem;">
                  <span id="mockSlider1Name">Exposure (EV)</span>
                  <span id="mockSlider1Val">+0.50 EV</span>
                </div>
                <div class="mock-slider-track" id="mockSlider1Track" role="slider" tabindex="0" aria-label="Exposure" aria-valuemin="-5" aria-valuemax="5" aria-valuenow="0.5">
                  <div class="mock-slider-fill" id="mockSlider1Fill"></div>
                  <div class="mock-slider-thumb" id="mockSlider1Thumb"></div>
                </div>
                <div class="mock-slider-row" style="display:flex; justify-content:space-between; margin-bottom:10px; font-family:var(--mono); font-size:0.75rem; margin-top:8px;">
                  <span id="mockSlider2Name">Contrast</span>
                  <span id="mockSlider2Val">+18</span>
                </div>
                <div class="mock-slider-track" id="mockSlider2Track" role="slider" tabindex="0" aria-label="Contrast" aria-valuemin="-100" aria-valuemax="100" aria-valuenow="18">
                  <div class="mock-slider-fill" id="mockSlider2Fill"></div>
                  <div class="mock-slider-thumb" id="mockSlider2Thumb"></div>
                </div>
              </div>
            </div>

            <div v-if="activeTab === 'snapseed'" id="mockSnapseedView" class="mock-snapseed" style="display:flex; flex-direction:column; height:100%; background:#080B11; border-radius:16px; overflow:hidden;">
              <div class="mock-header" style="padding:12px; color:#F3F5F9; font-family:var(--mono); font-size:0.8rem; display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid #141A25;">
                <span>SNAPSEED GESTURE SHELL</span>
                <span id="mockModeBadge">GESTURE</span>
              </div>
              <div class="mock-canvas" id="mockSnapseedCanvas" style="flex:1; cursor:crosshair; position:relative; background:linear-gradient(135deg, #0E121A 0%, #141A25 100%);">
                <div id="mockRubyMask" class="mock-ruby-mask" style="position:absolute; width:200px; height:200px; border-radius:50%; background:rgba(255,42,85,0.35); pointer-events:none; transform:translate(-50%,-50%); left:50%; top:50%; transition:transform 0.1s;"></div>
                <div id="mockBrushCursor" class="mock-brush-cursor" style="position:absolute; width:38px; height:38px; border:2px solid #00E5FF; border-radius:50%; pointer-events:none; transform:translate(-50%,-50%); left:50%; top:50%; transition:transform 0.1s;"></div>
                <div style="position:absolute; inset:0; display:flex; align-items:center; justify-content:center; color:#94A3B8; font-family:var(--mono); font-size:0.75rem;">
                  Pinch to zoom &mdash; drag to paint mask
                </div>
              </div>
              <div class="mock-gesture-hud" id="mockGestureHud" style="padding:12px; border-top:1px solid #141A25; background:#0E121A; display:flex; gap:10px; justify-content:center;">
                <span class="mock-chip">Brush</span>
                <span class="mock-chip">Erase</span>
                <span class="mock-chip">Feather</span>
                <span class="mock-chip active">Depth Range</span>
              </div>
            </div>

            <div v-if="activeTab === 'lookqr'" id="mockQrView" class="mock-qr-box" style="display:flex; flex-direction:column; align-items:center; justify-content:center; height:100%; background:#080B11; border-radius:16px; overflow:hidden;">
              <div class="mock-header" style="padding:12px; color:#F3F5F9; font-family:var(--mono); font-size:0.8rem; width:100%; border-bottom:1px solid #141A25;">
                <span>LOOK QR &amp; FILM STUDIO</span>
              </div>
              <div style="flex:1; display:flex; align-items:center; justify-content:center;">
                <div style="width:220px; height:220px; background:#080B11; border:2px solid var(--border); border-radius:12px; display:flex; align-items:center; justify-content:center; color:#94A3B8; font-family:var(--mono); font-size:0.7rem;">
                  Scannable Creator Card
                </div>
              </div>
              <div style="padding:16px; font-family:var(--mono); font-size:0.7rem; color:#94A3B8; text-align:center;">
                Import any grade via QR &mdash; 100% offline
              </div>
            </div>

            <div v-if="activeTab === 'export'" id="mockExportView" class="mock-export-box" style="display:flex; flex-direction:column; align-items:center; justify-content:center; height:100%; background:#080B11; border-radius:16px; overflow:hidden;">
              <div class="mock-header" style="padding:12px; color:#F3F5F9; font-family:var(--mono); font-size:0.8rem; width:100%; border-bottom:1px solid #141A25;">
                <span>LOSSLESS EXPORT &amp; C2PA</span>
              </div>
              <div class="mock-ring" id="mockExportRing" style="width:120px; height:120px; border:6px solid #141A25; border-top-color:var(--cyan); border-radius:50%; margin-top:24px; position:relative; animation:spin 1.2s linear infinite;">
                <b id="mockExportVal" style="position:absolute; inset:0; display:flex; align-items:center; justify-content:center; font-family:var(--mono); font-size:1.2rem; color:#F3F5F9;">74%</b>
              </div>
              <span id="mockExportLabel" style="margin-top:12px; font-family:var(--display); font-size:0.75rem; color:var(--text-muted); letter-spacing:0.06em; text-transform:uppercase;">Banded Streaming</span>
            </div>

            <div v-if="activeTab === 'gallery'" id="mockGalleryView" class="mock-gallery-box" style="display:flex; flex-direction:column; height:100%; background:#080B11; border-radius:16px; overflow:hidden;">
              <div class="mock-header" style="padding:12px; color:#F3F5F9; font-family:var(--mono); font-size:0.8rem; width:100%; border-bottom:1px solid #141A25;">
                <span>STUDIO LIBRARY &amp; BATCH</span>
              </div>
              <div class="mock-gallery-grid" style="flex:1; padding:10px; display:grid; grid-template-columns:repeat(3,1fr); gap:8px; overflow-y:auto;">
                <div v-for="i in 12" :key="i" class="mock-photo-tile" :class="{ sel: activeTab === 'gallery' && i <= gallerySel }" style="aspect-ratio:1; background:#141A25; border-radius:8px; position:relative; opacity:0.85; transition:opacity 0.2s;">
                  <div class="gallery-fallback" style="inset:0; background:linear-gradient(135deg,#1b2438 0%,#0b0f1a 100%); border-radius:8px;"></div>
                </div>
              </div>
            </div>

            <div v-if="activeTabTextRef" class="demo-text-overlay" style="margin-top:20px; padding:16px; background:#0E121A; border-radius:var(--radius-l); border:1px solid var(--border);">
              <h3 style="font-family:var(--display); font-size:1rem; color:var(--cyan); margin:0 0 8px 0;">{{ activeTabTextRef.title }}</h3>
              <p style="color:var(--text-muted); font-size:0.85rem; line-height:1.5; margin:0;">{{ activeTabTextRef.desc }}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const tabs = [
  { id: 'lightroom', label: '1. Zen Lightroom Inspector' },
  { id: 'snapseed', label: '2. Snapseed Gesture Shell' },
  { id: 'lookqr', label: '3. Look QR & Film Studio' },
  { id: 'export', label: '4. Lossless Export & C2PA' },
  { id: 'gallery', label: '5. Studio Library & Batch' },
]

const activeTab = ref('lightroom')
const gallerySel = ref(3)

const tabTexts = {
  lightroom: {
    title: 'Zen Lightroom Inspector',
    desc: 'Six master tabs (Light, Color, Blur, Effects, Detail, Geometry) manipulate a unified JSON recipe with 0ms sync latency and zero canvas obstruction.',
  },
  snapseed: {
    title: 'Snapseed Gesture Shell',
    desc: 'Edge-to-edge painting with pressure-sensitive brushes, ruby mask overlay, and gesture-driven local adjustments.',
  },
  lookqr: {
    title: 'Look QR & Film Studio',
    desc: 'Turn any color grade into a scannable Creator Card QR code. Import full grades instantly with zero cloud accounts.',
  },
  export: {
    title: 'Lossless Export & C2PA',
    desc: 'Full-resolution streaming export with C2PA Content Credentials manifests and cryptographic authorship.',
  },
  gallery: {
    title: 'Studio Library & Batch',
    desc: 'Smart collections, 64-bit dHash dedup, and batch operations across your entire photo library.',
  },
}

const activeTabTextRef = ref(tabTexts.lightroom)

// Auto-play studio tour
let autoPlay = null
let userInteracted = false

function startAutoPlay() {
  if (autoPlay) return
  let ti = 0
  let ci = 0
  let lr = 0
  autoPlay = setInterval(() => {
    if (userInteracted) return
    ti = (ti + 1) % tabs.length
    activeTab.value = tabs[ti].id
    activeTabTextRef.value = tabTexts[tabs[ti].id]
  }, 6500)
}

function stopAutoPlay() {
  if (autoPlay) clearInterval(autoPlay)
  autoPlay = null
}

onMounted(() => {
  const panel = document.getElementById('demoPanel')
  const screen = document.getElementById('mockScreen')
  const brush = document.getElementById('mockBrushCursor')
  const ruby = document.getElementById('mockRubyMask')
  let snT = 0
  let snCanvas = null

  if (screen) {
    ['pointerdown', 'keydown'].forEach((v) =>
      screen.addEventListener(v, () => {
        userInteracted = true
        stopAutoPlay()
      }, true)
    )
  }

  // Start auto play after mount
  setTimeout(startAutoPlay, 1000)

  // Lightroom slider scrub animation
  ;(function loop(ms) {
    requestAnimationFrame(loop)
    if (userInteracted || activeTab.value !== 'lightroom') return
    const t = ms / 1000
    const s1 = document.getElementById('mockSlider1Fill')
    const t1 = document.getElementById('mockSlider1Thumb')
    const v1 = document.getElementById('mockSlider1Val')
    const s2 = document.getElementById('mockSlider2Fill')
    const t2 = document.getElementById('mockSlider2Thumb')
    const v2 = document.getElementById('mockSlider2Val')
    const badge = document.getElementById('mockModeBadge')
    if (s1 && t1 && v1 && s2 && t2 && v2 && ms - lr > 70) {
      lr = ms
      const p1 = 0.5 + 0.3 * Math.sin(t * 0.9)
      const p2 = 0.5 + 0.3 * Math.cos(t * 0.7)
      s1.style.left = (p1 * 100) + '%'
      t1.style.left = (p1 * 100) + '%'
      v1.textContent = (p1 * 10 - 5).toFixed(2) + ' EV'
      s2.style.left = (p2 * 100) + '%'
      t2.style.left = (p2 * 100) + '%'
      v2.textContent = Math.round((p2 * 200 - 100)) + ''
    }
    // Badge cycle
    if (ms - snT > 3200 && activeTab.value === 'lightroom') {
      snT = ms
      ci = (ci + 1) % 4
      const modes = ['LIGHT', 'COLOR', 'BLUR', 'EFFECTS']
      if (badge) badge.textContent = modes[ci]
    }
    // Snapseed brush drift
    if (activeTab.value === 'snapseed') {
      snCanvas = document.getElementById('mockSnapseedCanvas')
      if (snCanvas) {
        const r = snCanvas.getBoundingClientRect()
        const x = r.width * (0.5 + 0.26 * Math.sin(t * 1.1))
        const y = r.height * (0.5 + 0.18 * Math.sin(t * 1.7))
        if (brush) {
          brush.style.left = (x - 19) + 'px'
          brush.style.top = (y - 19) + 'px'
        }
        if (ruby) {
          ruby.style.left = (x - 100) + 'px'
          ruby.style.top = (y - 100) + 'px'
        }
      }
    }
    // Gallery selection sweep
    if (activeTab.value === 'gallery') {
      const gt = document.getElementById('mockGalleryView')
      if (gt && ms - (window._galT || 0) > 650) {
        window._galT = ms
        const tiles = gt.querySelectorAll('.mock-photo-tile')
        const k = Math.floor(ms / 650) % (tiles.length + 2)
        tiles.forEach((el, j) => el.classList.toggle('sel', j < k))
        gallerySel.value = k
      }
    }
    // Export ring pulse
    if (activeTab.value === 'export') {
      const exT = window._exT || 0
      if (ms - exT > 5500) {
        window._exT = ms
        const val = document.getElementById('mockExportVal')
        const label = document.getElementById('mockExportLabel')
        const pct = 60 + Math.floor(Math.random() * 35)
        if (val) val.textContent = pct + '%'
        if (label) label.textContent = pct > 90 ? 'Finalizing C2PA manifest…' : 'Banded Streaming'
      }
    }
  })(0)
})

onUnmounted(() => {
  stopAutoPlay()
  window.removeEventListener('mousemove', () => {})
  window.removeEventListener('touchmove', () => {})
  window.removeEventListener('mouseup', () => {})
  window.removeEventListener('touchend', () => {})
})
</script>

<style scoped>
.screens-section {
  padding: 64px 0;
  background: var(--bg-1);
}

.section-head.center {
  text-align: center;
  margin-bottom: 40px;
}

.demo-tabs {
  display: flex;
  gap: 10px;
  overflow-x: auto;
  padding-bottom: 24px;
  scrollbar-width: none;
}

.demo-tabs::-webkit-scrollbar {
  display: none;
}

.demo-tab-btn {
  flex-shrink: 0;
  padding: 10px 18px;
  border: 1px solid var(--border-soft);
  border-radius: 100px;
  background: var(--glass);
  color: var(--text-muted);
  font-size: 0.85rem;
  font-family: var(--mono);
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.demo-tab-btn:hover {
  border-color: var(--cyan);
  color: var(--cyan);
}

.demo-tab-btn.active {
  background: var(--cyan);
  color: #040810;
  border-color: var(--cyan);
}

.demo-stage {
  display: flex;
  justify-content: center;
}

.phone-frame {
  width: min(320px, 92vw);
  height: 560px;
  border-radius: 34px;
  background: #06080D;
  box-shadow: 0 30px 60px rgba(0, 0, 0, 0.6);
  border: 1px solid var(--border);
  overflow: hidden;
  position: relative;
}

.phone-screen {
  width: 100%;
  height: 100%;
  position: relative;
}

.mock-header {
  font-weight: 700;
}

.mock-chip {
  display: inline-block;
  padding: 4px 10px;
  border-radius: 100px;
  font-family: var(--mono);
  font-size: 0.65rem;
  border: 1px solid var(--border-soft);
  color: var(--text-muted);
}

.mock-chip.active {
  border-color: var(--cyan);
  color: var(--cyan);
  background: rgba(0, 229, 255, 0.1);
}

.mock-slider-track {
  height: 6px;
  background: #141A25;
  border-radius: 3px;
  position: relative;
  overflow: hidden;
  cursor: pointer;
}

.mock-slider-fill {
  position: absolute;
  top: 0;
  left: 0;
  height: 100%;
  background: var(--cyan);
  border-radius: 3px;
  width: 50%;
}

.mock-slider-thumb {
  position: absolute;
  top: 50%;
  width: 16px;
  height: 16px;
  background: #080B11;
  border: 2px solid var(--cyan);
  border-radius: 50%;
  transform: translate(-50%, -50%);
}

.mock-gallery-grid {
  background: transparent;
}

.mock-photo-tile {
  background: #141A25;
  border-radius: 8px;
  opacity: 0.6;
}

.mock-photo-tile.sel {
  opacity: 1;
  border: 2px solid var(--cyan);
  border-radius: 6px;
}

.demo-text-overlay {
  max-width: 300px;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

@media (max-width: 640px) {
  .phone-frame {
    height: 480px;
  }
}
</style>
