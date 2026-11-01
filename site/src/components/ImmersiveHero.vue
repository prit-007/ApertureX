<template>
  <section
    class="immersive-hero"
    ref="heroRef"
    @mousemove="onMouseMove"
    @mouseleave="onMouseLeave"
  >
    <!-- Full-bleed hero canvas for depth bokeh overlay -->
    <canvas class="depth-canvas" ref="depthCanvas" aria-hidden="true"></canvas>

    <!-- Background image layers: RAW (left) vs Graded (right) -->
    <div class="hero-bg-wrap">
      <div
        class="hero-bg-layer bg-raw"
        :style="{ clipPath: `inset(0 50% 0 0)` }"
      >
        <div class="bg-tint tint-raw"></div>
        <img
          class="hero-bg-img"
          src="/assets/stock/iris.webp"
          alt="RAW capture"
          aria-hidden="true"
          draggable="false"
        />
        <div class="bg-label label-raw">RAW Capture</div>
      </div>
      <div
        class="hero-bg-layer bg-graded"
        :style="{ clipPath: `inset(0 0 0 calc(100% - var(--split)))` }"
      >
        <div class="bg-tint tint-graded"></div>
        <img
          class="hero-bg-img"
          src="/assets/stock/compare.webp"
          alt="ApertureX Grade"
          aria-hidden="true"
          draggable="false"
        />
        <div class="bg-label label-graded">ApertureX Grade</div>
      </div>

      <!-- Split divider line -->
      <div class="split-divider" :style="{ left: split + '%' }">
        <div class="divider-dot"></div>
        <svg
          class="divider-arrow"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <polyline points="9 18 15 12 9 6" />
        </svg>
      </div>
    </div>

    <!-- Overlay content -->
    <div class="wrap immersive-wrap">
      <div class="immersive-copy reveal-block">
        <div class="hero-kicker reveal-line">Immersive Preview</div>
        <h1 class="immersive-title reveal-line">
          See <span class="grade-word">Every</span> Shade
        </h1>
        <p class="immersive-lead reveal-block">
          Drag the curtain. Feel the grade. Every pixel stays yours —
          non-destructive, 32-bit float, compiled Rust core.
        </p>
        <div class="immersive-actions reveal-block">
          <a href="#download" class="btn btn-primary btn-lg btn-glow">
            Download v0.3.7
          </a>
          <a href="#compare" class="btn btn-outline btn-lg">Try Compare</a>
        </div>
        <div class="immersive-stats reveal-block">
          <div class="stat">
            <span class="stat-value">32-bit</span>
            <span class="stat-label">float pipeline</span>
          </div>
          <div class="stat">
            <span class="stat-value">65³</span>
            <span class="stat-label">LUT atlas</span>
          </div>
          <div class="stat">
            <span class="stat-value">0 ms</span>
            <span class="stat-label">recipe sync</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Bottom scroll anchor -->
    <div class="immersive-anchor">
      <div class="anchor-line"></div>
      <span class="anchor-text">Scroll into the studio →</span>
    </div>
  </section>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const heroRef = ref(null)
const depthCanvas = ref(null)

const split = ref(50)
let raf = null
let width = 0
let height = 0
let px = 0
let py = 0
let tx = 0
let ty = 0
let ctx = null

const COL = ['0,229,255', '255,179,0', '255,42,85', '255,255,255']
const particles = []

function resize() {
  const el = depthCanvas.value
  if (!el || !heroRef.value) return
  const rect = heroRef.value.getBoundingClientRect()
  const dpr = Math.min(2, window.devicePixelRatio || 1)
  width = el.width = Math.max(1, rect.width * dpr)
  height = el.height = Math.max(1, rect.height * dpr)
  el.style.width = rect.width + 'px'
  el.style.height = rect.height + 'px'
  ctx = el.getContext('2d')
  ctx.scale(dpr, dpr)
}

function mkParticle() {
  return {
    x: Math.random() * width,
    y: Math.random() * height,
    r: (1 + Math.random() * 6),
    vy: -(0.04 + Math.random() * 0.2),
    vx: (Math.random() - 0.5) * 0.15,
    a: 0.03 + Math.random() * 0.25,
    c: COL[Math.floor(Math.random() * COL.length)],
    z: 0.4 + Math.random() * 1.4,
    ph: Math.random() * 6.28,
    ring: Math.random() < 0.35,
  }
}

function initParticles() {
  particles.length = 0
  const n = window.innerWidth < 768 ? 16 : 34
  for (let i = 0; i < n; i++) particles.push(mkParticle())
}

function loop() {
  raf = requestAnimationFrame(loop)
  if (!ctx) return

  ctx.clearRect(0, 0, width, height)

  // Smooth follow
  px += (tx - px) * 0.06
  py += (ty - py) * 0.06

  for (const p of particles) {
    p.y += p.vy * p.z
    p.x += p.vx + Math.sin(Date.now() / 1200 + p.ph) * 0.15

    if (p.y < -20) {
      p.y = height + 20
      p.x = Math.random() * width
    }
    if (p.x < -20) p.x = width + 20
    if (p.x > width + 20) p.x = -20

    // Depth-of-field: particles near cursor are sharper/brighter
    const dx = p.x - tx
    const dy = p.y - ty
    const dist = Math.sqrt(dx * dx + dy * dy)
    const near = Math.max(0, 1 - dist / 400)
    const al = p.a * (0.4 + near * 0.9) * (0.7 + 0.3 * Math.sin(Date.now() / 700 + p.ph))

    ctx.beginPath()
    ctx.arc(p.x, p.y, p.r * (0.6 + near * 0.6), 0, 6.283)
    if (p.ring) {
      ctx.strokeStyle = `rgba(${p.c},${al})`
      ctx.lineWidth = 1.2
      ctx.stroke()
    } else {
      ctx.fillStyle = `rgba(${p.c},${al * 0.85})`
      ctx.fill()
    }
  }
}

function onMouseMove(e) {
  if (!heroRef.value) return
  const rect = heroRef.value.getBoundingClientRect()
  tx = e.clientX - rect.left
  ty = e.clientY - rect.top

  // Move split divider with mouse X (clamped 20-80%)
  const pct = Math.max(20, Math.min(80, (tx / rect.width) * 100))
  split.value = pct
  heroRef.value.style.setProperty('--split', pct + '%')
}

function onMouseLeave() {
  split.value = 50
  if (heroRef.value) heroRef.value.style.setProperty('--split', '50%')
}

onMounted(() => {
  resize()
  initParticles()
  raf = requestAnimationFrame(loop)
  window.addEventListener('resize', resize)
})

onUnmounted(() => {
  if (raf) cancelAnimationFrame(raf)
  window.removeEventListener('resize', resize)
})
</script>

<style scoped>
.immersive-hero {
  position: relative;
  min-height: 88vh;
  height: 100vh;
  background: var(--bg-darkest);
  overflow: hidden;
  display: flex;
  align-items: center;
  z-index: 1;
}

.depth-canvas {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  z-index: 3;
  pointer-events: none;
}

/* Background layers */
.hero-bg-wrap {
  position: absolute;
  inset: 0;
  z-index: 2;
  overflow: hidden;
}

.hero-bg-layer {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  background-size: cover;
  background-position: center;
  transition: clip-path 0.15s linear;
}

.bg-raw {
  background-color: #0b1220;
}
.bg-graded {
  background-color: #120a16;
}

.bg-tint {
  position: absolute;
  inset: 0;
  pointer-events: none;
}
.tint-raw {
  background: linear-gradient(
    135deg,
    rgba(0, 229, 255, 0.05) 0%,
    rgba(0, 0, 0, 0.35) 100%
  );
}
.tint-graded {
  background: linear-gradient(
    135deg,
    rgba(255, 42, 85, 0.08) 0%,
    rgba(0, 0, 0, 0.45) 100%
  );
}

.hero-bg-img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  opacity: 0.55;
  filter: grayscale(0.35) contrast(0.95);
  mix-blend-mode: soft-light;
}

.bg-graded .hero-bg-img {
  filter: grayscale(0) contrast(1.05) saturate(1.15);
  opacity: 0.75;
  mix-blend-mode: overlay;
}

.bg-label {
  position: absolute;
  top: 48px;
  font-family: var(--mono);
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  padding: 6px 14px;
  border-radius: 100px;
  backdrop-filter: blur(8px);
  background: rgba(0, 0, 0, 0.35);
  border: 1px solid rgba(255, 255, 255, 0.08);
  z-index: 6;
}

.label-raw {
  left: 48px;
  color: var(--text-muted);
  border-color: rgba(255, 255, 255, 0.12);
}
.label-graded {
  right: 48px;
  color: var(--cyan);
  border-color: rgba(0, 229, 255, 0.35);
  text-shadow: 0 0 12px rgba(0, 229, 255, 0.35);
}

/* Split divider */
.split-divider {
  position: absolute;
  top: 0;
  bottom: 0;
  left: 50%;
  width: 1px;
  z-index: 5;
  transform: translateX(-50%);
  pointer-events: none;
  background: linear-gradient(to bottom, transparent, var(--cyan), transparent);
  opacity: 0.45;
}

.divider-dot {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 14px;
  height: 14px;
  transform: translate(-50%, -50%);
  border-radius: 50%;
  background: var(--cyan);
  box-shadow: 0 0 14px var(--cyan);
  border: 2px solid var(--bg-darkest);
}

.divider-arrow {
  position: absolute;
  top: calc(50% + 24px);
  left: 50%;
  transform: translate(-50%, -50%);
  color: var(--cyan);
  filter: drop-shadow(0 0 8px rgba(0, 229, 255, 0.5));
  opacity: 0.8;
}

/* Content overlay */
.immersive-wrap {
  position: relative;
  z-index: 6;
  max-width: 1240px;
  margin: 0 auto;
  padding: 0 32px;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 22px;
  text-shadow: 0 2px 12px rgba(0, 0, 0, 0.5);
}

.immersive-copy {
  max-width: 620px;
  animation: copyRise 1s cubic-bezier(0.2, 0.8, 0.2, 1) forwards;
}

.hero-kicker {
  font-family: var(--mono);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--cyan);
  margin: 0;
}

.immersive-title {
  font-family: var(--display);
  font-size: clamp(3rem, 6vw, 5rem);
  font-weight: 800;
  line-height: 1.0;
  letter-spacing: -0.05em;
  color: var(--text);
  margin: 8px 0 0 0;
}

.grade-word {
  color: var(--cyan);
  position: relative;
}

.grade-word::after {
  content: '';
  position: absolute;
  bottom: -6px;
  left: 0;
  width: 100%;
  height: 4px;
  background: var(--coral);
  opacity: 0.6;
  border-radius: 2px;
  animation: gradeUnderline 2.2s ease-in-out infinite;
}

@keyframes gradeUnderline {
  0%, 100% { width: 0%; left: 50%; }
  50% { width: 100%; left: 0; }
}

.immersive-lead {
  color: var(--text-muted);
  font-size: 1.05rem;
  line-height: 1.7;
  margin: 0;
  max-width: 520px;
}

.immersive-actions {
  display: flex;
  gap: 14px;
  flex-wrap: wrap;
}

.btn-lg {
  padding: 14px 28px;
  font-size: 1rem;
}

.btn-glow {
  box-shadow: 0 0 0 0 rgba(0, 229, 255, 0.55);
  animation: btnGlow 2.6s infinite;
}

@keyframes btnGlow {
  0% { box-shadow: 0 0 0 0 rgba(0, 229, 255, 0.55); }
  70% { box-shadow: 0 0 0 20px rgba(0, 229, 255, 0); }
  100% { box-shadow: 0 0 0 0 rgba(0, 229, 255, 0); }
}

.immersive-stats {
  display: flex;
  gap: 30px;
  margin-top: 10px;
}

.immersive-stats .stat {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.immersive-stats .stat-value {
  font-family: var(--mono);
  font-size: 1.3rem;
  font-weight: 700;
  color: var(--cyan);
  letter-spacing: -0.02em;
}

.immersive-stats .stat-label {
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.14em;
  color: var(--text-faint);
}

/* Anchor */
.immersive-anchor {
  position: absolute;
  bottom: 40px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 6;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  animation: anchorFade 1.4s 1s ease forwards;
  opacity: 0;
}

.anchor-line {
  width: 1px;
  height: 90px;
  background: linear-gradient(to bottom, var(--cyan), transparent);
  opacity: 0.5;
}

.anchor-text {
  font-family: var(--mono);
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.18em;
  text-transform: uppercase;
  color: var(--text-muted);
}

@keyframes copyRise {
  0% { opacity: 0; transform: translateY(22px); }
  100% { opacity: 1; transform: translateY(0); }
}
@keyframes anchorFade {
  to { opacity: 0.85; }
}

@media (max-width: 768px) {
  .immersive-hero { min-height: 70vh; height: auto; padding: 60px 0; }
  .immersive-title { font-size: 2.6rem; }
  .immersive-wrap { gap: 16px; }
  .bg-label { display: none; }
  .split-divider { display: none; }
}
</style>
