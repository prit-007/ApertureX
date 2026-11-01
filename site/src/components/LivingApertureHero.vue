<template>
  <section
    class="living-hero"
    ref="heroRef"
    @mousemove="onMouseMove"
    @mouseleave="onMouseLeave"
    @scroll="onScroll"
  >
    <!-- Ambient gradient mesh behind everything -->
    <div class="hero-ambient" ref="ambientRef"></div>

    <!-- Floating bokeh particles -->
    <div class="hero-bokeh" ref="bokehRef"></div>

    <!-- Aperture stage: blades that open/close with mouse + scroll -->
    <div class="aperture-stage" ref="apertureRef">
      <svg
        class="aperture-svg"
        viewBox="0 0 600 600"
        preserveAspectRatio="xMidYMid slice"
      >
        <defs>
          <radialGradient id="apertureCoreGlow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stop-color="#00E5FF" stop-opacity="0.35" />
            <stop offset="45%" stop-color="#00E5FF" stop-opacity="0.08" />
            <stop offset="100%" stop-color="#00E5FF" stop-opacity="0" />
          </radialGradient>
          <filter id="bladeGlow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="6" result="blur" />
            <feComposite in="SourceGraphic" in2="blur" operator="over" />
          </filter>
        </defs>

        <!-- Outer rim ring -->
        <circle
          cx="300"
          cy="300"
          r="250"
          fill="none"
          stroke="rgba(0, 229, 255, 0.10)"
          stroke-width="2"
        />

        <!-- Blade group: rotates + scales with aperture -->
        <g
          class="blade-group"
          :style="{
            transform: `translate(300px, 300px) rotate(${apertureRotation}deg) scale(${apertureScale})`,
            transformOrigin: 'center',
          }"
        >
          <g v-for="n in bladeCount" :key="n" :transform="`rotate(${n * (360 / bladeCount)})`">
            <polygon
              class="aperture-blade"
              :points="bladePoints"
              fill="var(--bg-1)"
              stroke="var(--cyan)"
              :stroke-opacity="bladeStrokeOpacity"
              stroke-width="2"
              :filter="apertureOpen > 0.4 ? 'url(#bladeGlow)' : 'none'"
            />
          </g>
        </g>

        <!-- Core glow: brightens as aperture opens -->
        <circle
          cx="300"
          cy="300"
          :r="coreRadius"
          fill="url(#apertureCoreGlow)"
          :style="{ opacity: coreGlowOpacity }"
        />

        <!-- App icon shining through the aperture center -->
        <image
          class="aperture-icon"
          href="/assets/app_icon.png"
          x="240"
          y="240"
          width="120"
          height="120"
          :opacity="iconOpacity"
        />
      </svg>
    </div>

    <div class="wrap hero-grid">
      <div class="hero-copy" ref="copyRef">
        <div class="hero-kicker reveal-line">ApertureX</div>

        <h1 class="hero-title reveal-line">
          <span
            v-for="(word, i) in titleWords"
            :key="i"
            class="title-word reveal-word"
            :style="{ transitionDelay: wordDelay(i) + 's' }"
          >
            {{ word }}
          </span>
        </h1>

        <p class="hero-lead reveal-block" v-html="leadHtml"></p>

        <div class="hero-actions reveal-block">
          <a href="#download" class="btn btn-primary btn-pulse">
            Download v0.3.7
          </a>
          <a href="#features" class="btn btn-outline">Features</a>
        </div>

        <div class="hero-stats reveal-block">
          <div class="stat" v-for="(s, i) in stats" :key="i">
            <span class="stat-value">{{ s.value }}</span>
            <span class="stat-label">{{ s.label }}</span>
          </div>
        </div>
      </div>

      <div class="hero-visual">
        <div class="visual-card glass-card">
          <div class="visual-mask">
            <img
              src="/assets/app_icon.png"
              alt="ApertureX"
              class="app-icon"
            />
            <div class="icon-ring"></div>
          </div>
        </div>
        <div class="hero-chip-row reveal-block">
          <div class="chip chip-cyan">Lightroom Shell</div>
          <div class="chip chip-coral">Snapseed Gestures</div>
          <div class="chip chip-amber">Look QR</div>
          <div class="chip chip-emerald">C2PA Signed</div>
        </div>
      </div>
    </div>

    <div class="hero-scroll-hint reveal-block">
      <span>Scroll to open</span>
      <svg
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M19 14l-7 7m0 0l-7-7m7 7V3" />
      </svg>
    </div>
  </section>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'

const heroRef = ref(null)
const ambientRef = ref(null)
const bokehRef = ref(null)
const apertureRef = ref(null)
const copyRef = ref(null)

// --- Mouse state (0-1 normalized from center) ---
const mouse = reactive({ x: 0, y: 0 })
const scroll = ref(0)

// Aperture aperture (0 = closed, 1 = wide open)
const apertureOpen = ref(0.35)

// Derived transforms
const apertureRotation = computed(() => mouse.x * 12) // subtle tilt
const apertureScale = computed(() => 0.85 + apertureOpen.value * 0.25)
const coreRadius = computed(() => 60 + apertureOpen.value * 110)
const coreGlowOpacity = computed(() => 0.4 + apertureOpen.value * 0.6)
const bladeStrokeOpacity = computed(() => 0.2 + apertureOpen.value * 0.5)
const iconOpacity = computed(() => 0.2 + apertureOpen.value * 0.8)

const bladeCount = 8

// Blade polygon points (a curved aperture blade shape)
const bladePoints = '0,-210 250,-105 250,105 0,70'

// --- Title word animation ---
const titleWords = ['Pro-grade', 'FOSS', 'photo', 'editor']
const leadHtml =
  'Mobile-native, non-destructive editing with dual <strong>Lightroom-style</strong> and <strong>Snapseed-style</strong> shells over one shared recipe. Look QR open standard, on-device C2PA provenance, compiled <strong>Rust</strong> engine. 100% offline, GPL-3.0.'

const stats = [
  { value: '65³', label: '3D LUT Atlas' },
  { value: '200 MP', label: 'Tile Viewport' },
  { value: '120 FPS', label: 'Impeller' },
]

function wordDelay(i) {
  return i * 0.12
}

// --- Interaction handlers ---
function onMouseMove(e) {
  if (!heroRef.value) return
  const rect = heroRef.value.getBoundingClientRect()
  const cx = rect.left + rect.width / 2
  const cy = rect.top + rect.height / 2
  const dx = (e.clientX - cx) / (rect.width / 2)
  const dy = (e.clientY - cy) / (rect.height / 2)
  mouse.x = Math.max(-1, Math.min(1, dx))
  mouse.y = Math.max(-1, Math.min(1, dy))

  // Aperture opens as mouse approaches center, closes at edges
  const dist = Math.sqrt(dx * dx + dy * dy)
  const target = Math.max(0, 1 - dist * 0.8)
  apertureOpen.value = target
}

function onMouseLeave() {
  apertureOpen.value = 0.35
  mouse.x = 0
  mouse.y = 0
}

function onScroll(e) {
  if (!heroRef.value) return
  const rect = heroRef.value.getBoundingClientRect()
  const viewBottom = window.innerHeight
  const heroBottom = rect.bottom
  // As hero scrolls up, aperture gradually closes
  const progress = Math.max(0, Math.min(1, (viewBottom - rect.top) / viewBottom))
  scroll.value = progress
  apertureOpen.value = Math.max(0.2, 0.9 - progress * 0.6)
}

onMounted(() => {
  // Initial aperture pulse
  apertureOpen.value = 0.5
  setTimeout(() => {
    apertureOpen.value = 0.35
  }, 1200)
})

onUnmounted(() => {
  // cleanup handled by component unmount
})
</script>

<style scoped>
.living-hero {
  position: relative;
  padding: 10vh 0 140px 0;
  background: var(--bg-darkest);
  overflow: hidden;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.hero-ambient {
  position: absolute;
  inset: 0;
  z-index: 0;
  background: radial-gradient(
    60% 60% at 50% 40%,
    rgba(14, 18, 26, 0.9) 0%,
    var(--bg-darkest) 60%
  );
  background: radial-gradient(
    60% 60% at 50% 40%,
    rgba(0, 229, 255, 0.04) 0%,
    var(--bg-darkest) 55%
  );
}

/* Ambient gradient orbs for depth */
.hero-ambient::before,
.hero-ambient::after {
  content: '';
  position: absolute;
  border-radius: 50%;
  filter: blur(60px);
  z-index: 0;
  opacity: 0.6;
}
.hero-ambient::before {
  top: -10%;
  left: 20%;
  width: 500px;
  height: 500px;
  background: var(--cyan);
  opacity: 0.10;
  animation: ambientDrift1 14s ease-in-out infinite alternate;
}
.hero-ambient::after {
  bottom: -10%;
  right: 15%;
  width: 600px;
  height: 600px;
  background: var(--coral);
  opacity: 0.08;
  animation: ambientDrift2 16s ease-in-out infinite alternate-reverse;
}

@keyframes ambientDrift1 {
  0% { transform: translate(0, 0); }
  100% { transform: translate(40px, -60px); }
}
@keyframes ambientDrift2 {
  0% { transform: translate(0, 0); }
  100% { transform: translate(-50px, 80px); }
}

.hero-bokeh {
  position: absolute;
  inset: 0;
  z-index: 1;
  pointer-events: none;
  overflow: hidden;
}

/* Bokeh circles generated via CSS */
.hero-bokeh::before,
.hero-bokeh::after,
.hero-bokeh::after {
  content: '';
  position: absolute;
  border-radius: 50%;
  filter: blur(44px);
  opacity: 0;
  animation: bokehFloat linear infinite;
}
.hero-bokeh::before {
  top: 20%;
  left: -10%;
  width: 340px;
  height: 340px;
  background: var(--cyan);
  opacity: 0.12;
  animation-duration: 10s;
  animation-delay: -2s;
}
.hero-bokeh::after {
  bottom: 15%;
  right: -8%;
  width: 420px;
  height: 420px;
  background: var(--amber);
  opacity: 0.09;
  animation-duration: 13s;
  animation-delay: -4s;
}
.hero-bokeh::after {
  /* third orb */
  top: 55%;
  left: 60%;
  width: 260px;
  height: 260px;
  background: var(--coral);
  opacity: 0.10;
  animation-duration: 11s;
  animation-delay: -1s;
}

@keyframes bokehFloat {
  0% { transform: translate(0, 0) scale(1); opacity: 0; }
  10% { opacity: 0.12; }
  90% { opacity: 0.12; }
  100% { transform: translate(60px, -120px) scale(1.15); opacity: 0; }
}

/* Aperture stage */
.aperture-stage {
  position: absolute;
  top: 10%;
  right: 8%;
  z-index: 3;
  width: 420px;
  height: 420px;
  pointer-events: none;
  display: flex;
  align-items: center;
  justify-content: center;
}

.aperture-svg {
  width: 100%;
  height: 100%;
  overflow: visible;
}

.aperture-blade {
  transition: fill 0.3s ease, stroke-opacity 0.3s ease;
  transform-origin: 300px 300px;
}

.aperture-icon {
  pointer-events: none;
  filter: drop-shadow(0 0 14px rgba(0, 229, 255, 0.35));
  transition: opacity 0.4s ease, transform 0.4s cubic-bezier(0.2, 0.8, 0.2, 1);
}

.aperture-stage:hover .aperture-icon {
  transform: scale(1.05);
}

/* Content grid */
.hero-grid {
  position: relative;
  z-index: 4;
  display: grid;
  grid-template-columns: 1fr 420px;
  gap: 56px;
  align-items: center;
  max-width: 1240px;
  margin: 0 auto;
  padding: 0 32px;
}

@media (max-width: 900px) {
  .hero-grid {
    grid-template-columns: 1fr;
    gap: 40px;
  }
  .aperture-stage {
    position: relative;
    top: auto;
    right: auto;
    width: 320px;
    height: 320px;
    margin: 0 auto 32px auto;
  }
  .hero-ambient::before { width: 300px; height: 300px; left: 10%; }
  .hero-ambient::after { width: 360px; height: 360px; right: 10%; left: auto; }
}

.hero-copy {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.hero-kicker {
  font-family: var(--mono);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--cyan);
  opacity: 0;
  transform: translateY(12px);
  animation: kickerReveal 0.8s cubic-bezier(0.2, 0.8, 0.2, 1) forwards;
}

.hero-title {
  font-family: var(--display);
  font-size: clamp(2.6rem, 5vw, 4.2rem);
  font-weight: 800;
  line-height: 1.02;
  letter-spacing: -0.04em;
  color: var(--text);
  margin: 0;
  opacity: 0;
}

.title-word {
  display: inline-block;
  opacity: 0;
  transform: translateY(20px);
  white-space: pre-wrap;
}

.hero-lead {
  color: var(--text-muted);
  font-size: 1.05rem;
  line-height: 1.7;
  max-width: 540px;
  opacity: 0;
  transform: translateY(14px);
}

.hero-actions {
  display: flex;
  gap: 14px;
  opacity: 0;
  transform: translateY(14px);
}

.hero-stats {
  display: flex;
  gap: 30px;
  margin-top: 10px;
  opacity: 0;
  transform: translateY(14px);
}

.stat {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.stat-value {
  font-family: var(--mono);
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--cyan);
  letter-spacing: -0.02em;
}

.stat-label {
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.14em;
  color: var(--text-faint);
}

.hero-visual {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 20px;
  position: relative;
}

.visual-card {
  position: relative;
  width: 300px;
  height: 300px;
  border-radius: 48px;
  background: var(--bg-card);
  border: 1px solid var(--border);
  box-shadow: 0 24px 60px rgba(0, 0, 0, 0.5);
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform 0.4s ease, border-color 0.3s ease;
}

.visual-card:hover {
  transform: scale(1.02);
  border-color: var(--cyan);
}

.visual-mask {
  position: relative;
  width: 176px;
  height: 176px;
  border-radius: 50%;
  overflow: hidden;
  background: var(--bg-2);
  border: 2px solid var(--border-highlight);
  box-shadow: inset 0 0 40px rgba(0, 229, 255, 0.1);
}

.app-icon {
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: drop-shadow(0 0 20px rgba(0, 229, 255, 0.25));
  transition: filter 0.3s ease;
}

.visual-card:hover .app-icon {
  filter: drop-shadow(0 0 32px rgba(0, 229, 255, 0.45));
}

.icon-ring {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  border: 1px dashed rgba(0, 229, 255, 0.25);
  animation: ringSpin 10s linear infinite;
}

@keyframes ringSpin {
  to { transform: rotate(360deg); }
}

.hero-chip-row {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
  justify-content: center;
}

.chip {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 7px 14px;
  border-radius: 100px;
  font-size: 0.78rem;
  font-weight: 600;
  font-family: var(--display);
  letter-spacing: 0.06em;
  border: 1px solid var(--border);
  color: var(--text-muted);
  background: var(--glass);
  transition: all 0.2s;
}

.chip-cyan {
  color: var(--cyan);
  border-color: rgba(0, 229, 255, 0.25);
  background: rgba(0, 229, 255, 0.06);
}
.chip-cyan:hover {
  background: rgba(0, 229, 255, 0.15);
  border-color: var(--cyan);
}
.chip-coral {
  color: var(--coral-soft);
  border-color: rgba(255, 42, 85, 0.25);
  background: rgba(255, 42, 85, 0.06);
}
.chip-coral:hover {
  background: rgba(255, 42, 85, 0.15);
  border-color: var(--coral);
}
.chip-amber {
  color: var(--amber-soft);
  border-color: rgba(255, 179, 0, 0.25);
  background: rgba(255, 179, 0, 0.06);
}
.chip-amber:hover {
  background: rgba(255, 179, 0, 0.15);
  border-color: var(--amber);
}
.chip-emerald {
  color: var(--emerald-glow);
  border-color: rgba(16, 185, 129, 0.25);
  background: rgba(16, 185, 129, 0.06);
}
.chip-emerald:hover {
  background: rgba(16, 185, 129, 0.15);
  border-color: var(--emerald);
}

/* Scroll hint */
.hero-scroll-hint {
  position: absolute;
  bottom: 36px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 4;
  display: flex;
  align-items: center;
  gap: 10px;
  font-family: var(--mono);
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--text-faint);
  opacity: 0;
  animation: hintFade 1.2s 1.4s ease forwards;
}

.hero-scroll-hint svg {
  width: 18px;
  height: 18px;
  color: var(--cyan);
  animation: scrollBounce 2.2s ease-in-out infinite;
}

@keyframes scrollBounce {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(6px); }
}

/* Reveal animations */
@keyframes kickerReveal {
  to { opacity: 1; transform: translateY(0); }
}

@keyframes ambientDrift1 {
  0% { transform: translate(0, 0); }
  100% { transform: translate(50px, -70px); }
}
@keyframes ambientDrift2 {
  0% { transform: translate(0, 0); }
  100% { transform: translate(-60px, 90px); }
}

@keyframes hintFade {
  to { opacity: 0.7; }
}

.reveal-line,
.reveal-block {
  opacity: 0;
}

.btn-pulse {
  box-shadow: 0 0 0 0 rgba(0, 229, 255, 0.5);
  animation: btnPulse 2.5s infinite;
}

@keyframes btnPulse {
  0% { box-shadow: 0 0 0 0 rgba(0, 229, 255, 0.5); }
  70% { box-shadow: 0 0 0 16px rgba(0, 229, 255, 0); }
  100% { box-shadow: 0 0 0 0 rgba(0, 229, 255, 0); }
}

.glass-card {
  backdrop-filter: blur(16px);
  background: rgba(15, 20, 30, 0.55);
}
</style>
