<template>
  <section id="compare" class="compare-section reveal">
    <div class="wrap">
      <div class="section-head center">
        <span class="hud-tag">INTERACTIVE HARDWARE DEMO</span>
        <h2>Drag to compare the grading math</h2>
        <p>
          True 32-bit floating point color pipeline running completely on device.
          Slide to compare flat camera sensor capture against the ApertureX
          film-calibrated 3D LUT grade.
        </p>
      </div>

      <div class="compare-container">
        <div
          class="compare-viewport"
          role="slider"
          tabindex="0"
          :aria-valuenow="split"
          aria-valuemin="0"
          aria-valuemax="100"
          :aria-valuetext="`${split}% graded image`"
          :style="{ '--split': split + '%' }"
          @mousedown="startDrag"
          @touchstart="startDrag"
          @keydown="handleKey"
        >
          <!-- Underneath: Raw capture layer -->
          <div class="compare-layer compare-raw">
            <img
              src="/assets/stock/compare.webp"
              alt="Original RAW capture"
              draggable="false"
            />
          </div>

          <!-- On top: Graded layer with dynamic clip-path -->
          <div class="compare-layer compare-graded">
            <img
              src="/assets/stock/compare.webp"
              alt="Graded image"
              draggable="false"
            />
          </div>

          <!-- Badges -->
          <span class="compare-badge badge-after">
            ApertureX Film Grade (Portra 400)
          </span>
          <span class="compare-badge badge-before">
            Original Flat RAW Capture
          </span>

          <!-- Divider line & handle -->
          <div class="compare-line"></div>
          <div class="compare-handle" ref="handle">
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
            <strong>
              Pat David Kodak Portra 400 + Soft Highlight Roll-Off +
              Vignette
            </strong>
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

const split = ref(50)
const dragging = ref(false)
const handle = ref(null)
const viewport = ref(null)

function clamp(v) {
  return Math.max(0, Math.min(100, v))
}

function setSplitFromClientX(clientX) {
  if (!viewport.value) return
  const rect = viewport.value.getBoundingClientRect()
  const width = rect.width
  const x = Math.max(0, Math.min(width, clientX - rect.left))
  split.value = Math.round((x / width) * 100)
  viewport.value.setAttribute('aria-valuenow', split.value)
}

function startDrag(e) {
  dragging.value = true
  document.body.style.userSelect = 'none'
  const clientX =
    e.touches && e.touches.length ? e.touches[0].clientX : e.clientX
  setSplitFromClientX(clientX)
}

function onMove(e) {
  if (!dragging.value) return
  const clientX =
    e.touches && e.touches.length ? e.touches[0].clientX : e.clientX
  setSplitFromClientX(clientX)
}

function endDrag() {
  dragging.value = false
  document.body.style.userSelect = ''
}

function handleKey(e) {
  if (e.key === 'ArrowLeft') split.value = clamp(split.value - 1)
  else if (e.key === 'ArrowRight') split.value = clamp(split.value + 1)
  else if (e.key === 'Home') split.value = 0
  else if (e.key === 'End') split.value = 100
  else return
  e.preventDefault()
  viewport.value.setAttribute('aria-valuenow', split.value)
}

onMounted(() => {
  window.addEventListener('mousemove', onMove)
  window.addEventListener('touchmove', onMove, { passive: false })
  window.addEventListener('mouseup', endDrag)
  window.addEventListener('touchend', endDrag)
  window.addEventListener('keydown', handleKey)
})
</script>

<style scoped>
.compare-section {
  padding: 64px 0;
  background: var(--bg-1);
}

.section-head.center {
  text-align: center;
  margin-bottom: 40px;
}

.compare-container {
  position: relative;
  border-radius: var(--radius-xl);
  overflow: hidden;
  border: 1px solid var(--border);
  box-shadow: 0 24px 48px rgba(0, 0, 0, 0.4);
}

.compare-viewport {
  position: relative;
  width: 100%;
  height: 420px;
  overflow: hidden;
  cursor: ew-resize;
}

.compare-layer {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
}

.compare-layer img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.compare-raw {
  clip-path: inset(0 50% 0 0);
  opacity: 0.65;
}

.compare-graded {
  clip-path: inset(0 0 0 calc(100% - var(--split)));
  opacity: 0.95;
}

.compare-badge {
  position: absolute;
  top: 16px;
  font-size: 0.75rem;
  font-family: var(--mono);
  font-weight: 600;
  padding: 6px 12px;
  border-radius: 100px;
  background: rgba(0, 0, 0, 0.45);
  border: 1px solid var(--border);
  color: var(--text);
  pointer-events: none;
  z-index: 10;
}

.badge-after {
  left: 16px;
  color: var(--cyan);
  border-color: rgba(0, 229, 255, 0.3);
}

.badge-before {
  right: 16px;
  color: var(--text-muted);
  border-color: rgba(255, 255, 255, 0.15);
}

.compare-line {
  position: absolute;
  top: 0;
  bottom: 0;
  left: 50%;
  width: 1px;
  background: linear-gradient(
    to bottom,
    transparent,
    var(--cyan),
    transparent
  );
  opacity: 0.5;
  pointer-events: none;
  z-index: 5;
  transform: translatex(-50%);
}

.compare-handle {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 40px;
  height: 40px;
  background: #080B11;
  border: 2px solid var(--cyan);
  border-radius: 50%;
  transform: translate(-50%, -50%);
  pointer-events: none;
  z-index: 15;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 0 24px rgba(0, 229, 255, 0.25);
}

.compare-handle svg {
  width: 20px;
  height: 20px;
  color: var(--cyan);
}

.compare-bar {
  margin-top: 24px;
  padding: 18px 22px;
  background: var(--bg-2);
  border: 1px solid var(--border);
  border-radius: var(--radius-l);
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.compare-bar > div {
  display: flex;
  align-items: baseline;
  gap: 8px;
  font-size: 0.9rem;
  color: var(--text-muted);
}

.compare-bar strong {
  color: var(--text);
}

.compare-bar-metrics {
  display: flex;
  gap: 12px;
}

@media (max-width: 640px) {
  .compare-viewport {
    height: 300px;
  }
  .compare-bar {
    padding: 14px 16px;
  }
}
</style>
