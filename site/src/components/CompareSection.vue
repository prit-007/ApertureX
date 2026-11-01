<template>
  <section class="compare-section" id="compare">
    <div class="wrap">
      <div class="section-head center">
        <span class="hud-tag">INTERACTIVE HARDWARE DEMO</span>
        <h2>Drag to compare the grading math</h2>
        <p>
          True 32-bit floating point color pipeline running completely on device.
          Slide to compare flat camera sensor capture against the ApertureX film-calibrated
          3D LUT grade.
        </p>
      </div>

      <div class="compare-container">
        <div
          class="compare-viewport"
          id="compareViewport"
          ref="viewportRef"
          role="slider"
          tabindex="0"
          :aria-valuenow="comparePercent"
          aria-valuemin="0"
          aria-valuemax="100"
          :aria-valuetext="`${comparePercent}% graded image`"
          @pointerdown="onPointerDown"
          @keydown="onKeyDown"
        >
          <!-- Underneath: Raw capture layer -->
          <div class="compare-layer compare-raw">
            <img
              id="compareRawImg"
              class="compare-img"
              :src="compareImg"
              alt="Original flat RAW capture"
              style="width:100%;height:100%;object-fit:cover;opacity:0;transition:opacity .5s ease;"
              @load="onImageLoad"
              @error="onImageError"
            />
            <div
              id="compareRawFallback"
              style="position:absolute;inset:0;background:radial-gradient(circle at 35% 45%, #4B5565 0%, #242B36 55%, #12151D 100%);filter:saturate(0.65) contrast(0.9) brightness(0.92);display:flex;align-items:center;justify-content:center;"
            />
          </div>

          <!-- On top: Graded layer -->
          <div class="compare-layer compare-graded">
            <img
              id="compareGradedImg"
              class="compare-img"
              :src="compareImg"
              alt="ApertureX film grade"
              style="width:100%;height:100%;object-fit:cover;opacity:0;transition:opacity .5s ease;"
              @load="onImageLoad"
              @error="onImageError"
            />
            <div
              id="compareGradedFallback"
              style="position:absolute;inset:0;background:radial-gradient(circle at 65% 35%, #FFB300 0%, #FF2A55 35%, #00E5FF 70%, #081120 100%);filter:contrast(1.18) saturate(1.3) brightness(1.05);display:flex;align-items:center;justify-content:center;"
            />
          </div>

          <!-- Badges -->
          <span class="compare-badge badge-after">ApertureX Film Grade (Portra 400)</span>
          <span class="compare-badge badge-before">Original Flat RAW Capture</span>

          <!-- Divider line & handle -->
          <div class="compare-line"></div>
          <div class="compare-handle" id="compareHandle">
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
            >
              <path d="m9 18-6-6 6-6M15 6l6 6-6 6" />
            </svg>
          </div>
        </div>

        <div class="compare-bar">
          <div>
            <span>Grade profile: </span>
            <strong>Pat David Kodak Portra 400 + Soft Highlight Roll-Off + Vignette</strong>
          </div>
          <div class="compare-bar-metrics">
            <span class="hud-tag">65³ 3D LUT Atlas</span>
            <span class="hud-tag hud-tag-emerald">Zero Compression Loss</span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import compareImg from '../assets/stock/compare.webp'

const compareImageSrc = compareImg

const viewportRef = ref(null)
const comparePercent = ref(50)

function onImageLoad(e) {
  const img = e.currentTarget
  img.style.opacity = '1'
  const fallback = img.nextElementSibling
  if (fallback) fallback.style.display = 'none'
}

function onImageError(e) {
  e.currentTarget.style.opacity = '0'
  const fallback = e.currentTarget.nextElementSibling
  if (fallback) fallback.style.display = 'flex'
}

function setComparePercent(pct) {
  comparePercent.value = Math.max(0, Math.min(100, pct))
  const rounded = Math.round(comparePercent.value)
  const vp = viewportRef.value
  if (vp) {
    vp.style.setProperty('--split', rounded + '%')
    vp.setAttribute('aria-valuenow', String(rounded))
    vp.setAttribute('aria-valuetext', rounded + '% graded image')
  }
}

function updateCompare(clientX) {
  const vp = viewportRef.value
  if (!vp) return
  const rect = vp.getBoundingClientRect()
  const pos = Math.max(0, Math.min(clientX - rect.left, rect.width))
  setComparePercent((pos / rect.width) * 100)
}

function onPointerDown(e) {
  const vp = viewportRef.value
  if (!vp) return
  vp.setPointerCapture?.(e.pointerId)
  updateCompare(e.clientX)
}

function onKeyDown(e) {
  const step = e.shiftKey ? 10 : 2
  if (e.key === 'ArrowLeft') {
    setComparePercent(comparePercent.value - step)
    e.preventDefault()
  } else if (e.key === 'ArrowRight') {
    setComparePercent(comparePercent.value + step)
    e.preventDefault()
  } else if (e.key === 'Home') {
    setComparePercent(0)
    e.preventDefault()
  } else if (e.key === 'End') {
    setComparePercent(100)
    e.preventDefault()
  }
}

let isDragging = false

onMounted(() => {
  const vp = viewportRef.value
  if (!vp) return
  vp.addEventListener('pointermove', (e) => {
    if (isDragging) updateCompare(e.clientX)
  })
  vp.addEventListener('pointerup', () => {
    isDragging = false
  })
  vp.addEventListener('pointercancel', () => {
    isDragging = false
  })

  // Intro sweep animation
  const observer = new IntersectionObserver(
    (entries) => {
      if (!entries[0].isIntersecting) return
      observer.disconnect()
      const s = performance.now()
      ;(function f(n) {
        const q = Math.min(1, (n - s) / 2200)
        setComparePercent(50 + Math.sin(q * Math.PI * 2) * 38 * (1 - q * 0.6))
        if (q < 1) requestAnimationFrame(f)
        else setComparePercent(50)
      })(s)
    },
    { threshold: 0.6 }
  )
  observer.observe(vp)
})
</script>

<style scoped>
.compare-section {
  padding: 100px 0;
}
.compare-container {
  background: var(--bg-1);
  border: 1px solid var(--border);
  border-radius: var(--radius-xl);
  overflow: hidden;
  box-shadow: 0 40px 90px -30px rgba(0, 0, 0, 0.85);
}
.compare-viewport {
  position: relative;
  width: 100%;
  height: 520px;
  overflow: hidden;
  cursor: ew-resize;
  user-select: none;
  -webkit-user-select: none;
  touch-action: pan-y;
}
.compare-viewport:focus-visible {
  outline: 3px solid var(--cyan);
  outline-offset: -3px;
}
@media (max-width: 640px) {
  .compare-viewport {
    height: 360px;
  }
}
.compare-layer {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}
.compare-raw {
  background: radial-gradient(circle at 35% 45%, #4B5565 0%, #242B36 55%, #12151D 100%);
  filter: saturate(0.65) contrast(0.9) brightness(0.92);
  display: flex;
  align-items: center;
  justify-content: center;
}
.compare-graded {
  background: radial-gradient(circle at 65% 35%, #FFB300 0%, #FF2A55 35%, #00E5FF 70%, #081120 100%);
  filter: contrast(1.18) saturate(1.3) brightness(1.05);
  display: flex;
  align-items: center;
  justify-content: center;
  clip-path: inset(0 calc(100% - var(--split, 50%)) 0 0);
  will-change: clip-path;
}
.compare-line {
  position: absolute;
  top: 0;
  bottom: 0;
  left: var(--split, 50%);
  width: 2px;
  background: #FFFFFF;
  box-shadow: 0 0 16px rgba(0, 229, 255, 0.85), 0 0 4px #FFFFFF;
  transform: translateX(-50%);
  z-index: 15;
  pointer-events: none;
  will-change: left;
}
.compare-handle {
  position: absolute;
  top: 50%;
  left: var(--split, 50%);
  transform: translate(-50%, -50%);
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: #FFFFFF;
  color: #06090E;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 6px 24px rgba(0, 0, 0, 0.6), 0 0 0 3px rgba(0, 229, 255, 0.5);
  z-index: 20;
  pointer-events: none;
  will-change: left;
  transition: transform 0.15s ease;
}
.compare-viewport:hover .compare-handle {
  transform: translate(-50%, -50%) scale(1.1);
}
.compare-handle svg {
  width: 22px;
  height: 22px;
}

.compare-badge {
  position: absolute;
  top: 20px;
  padding: 6px 14px;
  border-radius: 100px;
  font-family: var(--display);
  font-size: 0.76rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  backdrop-filter: blur(16px);
  z-index: 15;
  pointer-events: none;
}
.badge-after {
  left: 20px;
  background: rgba(0, 229, 255, 0.18);
  color: var(--cyan);
  border: 1px solid rgba(0, 229, 255, 0.4);
  box-shadow: 0 0 16px rgba(0, 229, 255, 0.2);
}
.badge-before {
  right: 20px;
  background: rgba(0, 0, 0, 0.65);
  color: var(--text-muted);
  border: 1px solid var(--border);
}

.compare-bar {
  padding: 16px 28px;
  background: rgba(14, 18, 28, 0.95);
  border-top: 1px solid var(--border-soft);
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 14px;
  font-size: 0.88rem;
  color: var(--text-muted);
}
.compare-bar strong {
  color: var(--text);
}
.compare-bar-metrics {
  display: flex;
  align-items: center;
  gap: 12px;
}
</style>
