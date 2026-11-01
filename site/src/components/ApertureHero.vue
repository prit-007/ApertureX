<template>
  <header class="hero pin" id="top" ref="heroRef">
    <div class="stick" ref="stickRef">
      <!-- Ambient gradient glow -->
      <div class="hero-ambient"></div>
      <div class="hero-grid-bg"></div>
      <!-- Bokeh particle canvas -->
      <canvas id="fx" class="hero-fx" aria-hidden="true"></canvas>

      <!-- Orbiting pills (counter-rotating) -->
      <div class="orb" aria-hidden="true" ref="orbRef">
        <span style="--a:0deg"><b>Rust engine</b></span>
        <span style="--a:90deg"><b>RAW</b></span>
        <span style="--a:180deg"><b>C2PA</b></span>
        <span style="--a:270deg"><b>Look QR</b></span>
      </div>
      <div class="orb o2" aria-hidden="true">
        <span style="--a:0deg"><b>65³ LUT</b></span>
        <span style="--a:60deg"><b>16-bit TIFF</b></span>
        <span style="--a:120deg"><b>AI masks</b></span>
        <span style="--a:180deg"><b>0 trackers</b></span>
        <span style="--a:240deg"><b>GPL-3.0</b></span>
        <span style="--a:300deg"><b>200 MP</b></span>
      </div>

      <!-- Iris + aperture blades -->
      <div class="iris" ref="irisRef" @mousemove="onMouseMove" @mouseleave="onMouseLeave">
        <img
          id="photo"
          :src="irisImg"
          alt="Hero photo preview"
          class="photo"
          draggable="false"
        />
        <div id="photoFallback" class="photo-fallback"></div>

        <!-- Aperture blades SVG -->
        <svg
          class="aperture-svg"
          viewBox="-200 -200 400 400"
          preserveAspectRatio="xMidYMid slice"
        >
          <defs>
            <linearGradient id="apertureGrad" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stop-color="#1b2438" />
              <stop offset="1" stop-color="#0b0f1a" />
            </linearGradient>
          </defs>
          <g id="blades" ref="bladesRef">
            <g
              v-for="n in 8"
              :key="n"
              :transform="`rotate(${n * 45})`"
            >
              <polygon
                class="blade"
                points="0,-190 190,-90 190,120 0,40"
                fill="url(#apertureGrad)"
                stroke="#00E5FF"
                stroke-opacity="0.3"
                stroke-width="1.5"
              />
            </g>
          </g>
          <circle
            r="196"
            fill="none"
            stroke="#00E5FF"
            stroke-width="2"
            opacity="0.45"
          />
        </svg>
      </div>

      <!-- Hero content -->
      <div class="hcopy hero-content" ref="contentRef" id="hcopy">
        <div class="hero-badge-wrap">
          <span class="hud-tag">TRUE FOSS CREATIVE SUITE</span>
          <span class="hud-tag hud-tag-amber">GPL-3.0</span>
          <span class="hud-tag hud-tag-emerald">100% ON-DEVICE</span>
        </div>

        <h1 class="hero-title">
          Pro Photo Editing.<br />
          <span class="gradient-text">Zero Cloud. Zero Subscriptions.</span>
        </h1>

        <p class="hero-lead">
          The open-source alternative to Adobe Lightroom &amp; Snapseed. Dual UI
          shells over one non-destructive recipe, a high-performance
          <strong>compiled Rust engine</strong>, <strong>on-device AI masks</strong>,
          <strong>16-bit TIFF export</strong>, and cryptographic
          <strong>C2PA provenance</strong>.
        </p>

        <div class="hero-cta">
          <a
            href="https://github.com/prit-007/ApertureX/releases/latest"
            class="btn btn-primary"
            target="_blank"
            rel="noopener"
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
            >
              <path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" />
            </svg>
            <span>Download Universal APK (v0.3.7)</span>
          </a>
          <a href="#screens" class="btn btn-ghost">
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <circle cx="12" cy="12" r="10" />
              <polygon points="10 8 16 12 10 16 10 8" />
            </svg>
            Explore Studio Tour
          </a>
          <a
            href="https://github.com/prit-007/ApertureX"
            class="btn btn-ghost"
            target="_blank"
            rel="noopener"
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="currentColor"
            >
              <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z" />
            </svg>
            GitHub (FOSS)
          </a>
          <p class="hero-note">
            Android 8.0+ &bull; Signed APK &bull; No account required
          </p>
        </div>
      </div>

      <!-- "Every pixel stays yours" reveal -->
      <div class="rev2" ref="rev2Ref" aria-hidden="true">
        <p class="big">Every pixel stays yours.</p>
        <div class="ch">
          <span>200 MP tiles</span>
          <span>16-bit TIFF</span>
          <span>Zero trackers</span>
        </div>
      </div>

      <!-- Aperture f-stop readout -->
      <div class="fstop" ref="fstopRef" aria-hidden="true">
        <span>Aperture</span>
        <b id="fval">{{ fStop }}</b>
        <span>Scroll to open</span>
      </div>
    </div>
  </header>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import irisImg from '../assets/stock/iris.webp'

const heroRef = ref(null)
const stickRef = ref(null)
const irisRef = ref(null)
const contentRef = ref(null)
const rev2Ref = ref(null)
const fstopRef = ref(null)
const bladesRef = ref(null)
const orbRef = ref(null)

const mouse = ref({ x: 0, y: 0 })
const scrollProgress = ref(0)
const fStop = ref('f/16')

const apertureStops = [16, 11, 8, 5.6, 4, 2.8, 2, 1.4, 1.2]

// Aperture blade transform based on scroll (0 = closed, 1 = open)
const apertureTransform = computed(() => {
  const p = scrollProgress.value
  const e = p * p * (3 - 2 * p) // smoothstep
  return `translate(${e * 210}px, 0) rotate(${e * -24}deg)`
})

const photoScale = computed(() => {
  const p = scrollProgress.value
  const e = p * p * (3 - 2 * p)
  return 0.6 + e * 1.3
})

const contentOpacity = computed(() => {
  const p = scrollProgress.value
  const hp = Math.min(1, p * 2.2)
  const ho = 1 - Math.max(0, (p - 0.25) * 3)
  return ho
})

const contentTransform = computed(() => {
  const p = scrollProgress.value
  const hp = Math.min(1, p * 2.2)
  return `translateY(${-hp * 60}px) scale(${1 - hp * 0.08})`
})

const rev2Opacity = computed(() => {
  const p = scrollProgress.value
  return Math.max(0, Math.min(1, (p - 0.5) * 3))
})

const rev2Transform = computed(() => {
  const p = scrollProgress.value
  const q = Math.max(0, Math.min(1, (p - 0.5) * 3))
  return `translateY(${(1 - q) * 40}px)`
})

// Aperture f-stop text based on scroll
const currentFStop = computed(() => {
  const p = scrollProgress.value
  const idx = Math.min(8, Math.round(p * 8))
  return `f/${apertureStops[idx]}`
})

onMounted(() => {
  fStop.value = currentFStop.value

  // Initial blade polygon points per blade (rotate each blade around center)
  // The transform is applied via CSS :style on each <g>

  // Scroll handler: aperture engine
  let ticking = false
  const onScroll = () => {
    if (ticking) return
    ticking = true
    requestAnimationFrame(() => {
      const hero = heroRef.value
      const stick = stickRef.value
      if (!hero || !stick) {
        ticking = false
        return
      }
      const r = hero.getBoundingClientRect()
      const viewHeight = window.innerHeight
      // p = how far the hero has scrolled up (0 = fully visible, 1 = scrolled past)
      const p = Math.max(0, Math.min(1, (viewHeight - r.top) / viewHeight))
      scrollProgress.value = p
      fStop.value = currentFStop.value
      ticking = false
    })
  }

  window.addEventListener('scroll', onScroll, { passive: true })
  window.addEventListener('resize', onScroll)
  onScroll() // initial call

  // Mouse parallax for iris + orb
  const iris = irisRef.value
  const orb = orbRef.value
  if (iris && orb) {
    window.addEventListener('mousemove', (e) => {
      const rect = heroRef.value.getBoundingClientRect()
      const cx = rect.left + rect.width / 2
      const cy = rect.top + rect.height / 2
      const dx = (e.clientX - cx) / (rect.width / 2)
      const dy = (e.clientY - cy) / (rect.height / 2)
      mouse.value = { x: Math.max(-1, Math.min(1, dx)), y: Math.max(-1, Math.min(1, dy)) }

      // Apply parallax transforms via CSS custom properties
      iris.style.setProperty('--px', mouse.value.x.toFixed(4))
      iris.style.setProperty('--py', mouse.value.y.toFixed(4))
      orb.style.setProperty('--px', mouse.value.x.toFixed(4))
      orb.style.setProperty('--py', mouse.value.y.toFixed(4))
    })
  }
})

onUnmounted(() => {
  window.removeEventListener('scroll', () => {})
  window.removeEventListener('resize', () => {})
})
</script>

<style scoped>
.hero.pin {
  height: 260vh;
  padding: 0;
  overflow: visible;
  text-align: center;
  background: var(--bg-darkest);
}

.stick {
  position: sticky;
  top: 0;
  height: 100dvh;
  overflow: hidden;
  display: grid;
  place-items: center;
  padding-top: 68px;
  box-sizing: border-box;
}

/* Ambient gradient */
.hero-ambient {
  position: absolute;
  inset: 0;
  z-index: 0;
  background: radial-gradient(
    60% 60% at 50% 40%,
    rgba(0, 229, 255, 0.06) 0%,
    var(--bg-darkest) 55%
  );
}
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
  100% { transform: translate(50px, -70px); }
}
@keyframes ambientDrift2 {
  0% { transform: translate(0, 0); }
  100% { transform: translate(-60px, 90px); }
}

/* Grid bg */
.hero-grid-bg {
  position: absolute;
  inset: 0;
  z-index: 0;
  background-image:
    linear-gradient(rgba(255, 255, 255, 0.02) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.02) 1px, transparent 1px);
  background-size: 40px 40px;
  opacity: 0.4;
}

/* FX canvas */
.hero-fx {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  z-index: 1;
  pointer-events: none;
}

/* Orbiting pills */
.orb {
  position: absolute;
  width: min(112vmin, 900px);
  aspect-ratio: 1;
  animation: spin 46s linear infinite;
  pointer-events: none;
  z-index: 2;
}
.orb.o2 {
  width: min(76vmin, 620px);
  animation: spin 38s linear infinite reverse;
}
.orb::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: 50%;
  border: 1px dashed rgba(0, 229, 255, 0.22);
  z-index: -1;
}
.orb.o2::before {
  border-color: rgba(255, 179, 0, 0.2);
}
.orb span {
  position: absolute;
  left: 50%;
  top: 50%;
  width: 0;
  height: 0;
  transform: rotate(var(--a)) translateY(calc(min(56vmin, 450px) * -1)) rotate(calc(var(--a) * -1));
  translate: calc(var(--px, 0) * 18px) calc(var(--py, 0) * 18px);
}
.orb.o2 span {
  transform: rotate(var(--a)) translateY(calc(min(38vmin, 310px) * -1)) rotate(calc(var(--a) * -1));
  translate: calc(var(--px, 0) * -12px) calc(var(--py, 0) * -12px);
}
.orb b {
  display: block;
  transform: translate(-50%, -50%);
  white-space: nowrap;
  padding: 7px 14px;
  border-radius: 99px;
  background: rgba(14, 18, 26, 0.88);
  border: 1px solid rgba(0, 229, 255, 0.4);
  color: var(--cyan);
  font: 700 0.72rem var(--mono);
  animation: spinr 46s linear infinite;
}
.orb.o2 b {
  animation: spinr 38s linear infinite reverse;
  border-color: rgba(255, 179, 0, 0.45);
  color: var(--amber);
}
@keyframes spin {
  to { transform: rotate(360deg); }
}
@keyframes spinr {
  to { transform: translate(-50%, -50%) rotate(-360deg); }
}

/* Iris + aperture blades */
.iris {
  position: absolute;
  width: min(94vmin, 780px);
  aspect-ratio: 1;
  z-index: 1;
  pointer-events: none;
  translate: calc(var(--px, 0) * -26px) calc(var(--py, 0) * -26px);
}
.iris svg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  overflow: visible;
}
.photo {
  position: absolute;
  width: 56%;
  aspect-ratio: 1;
  left: 22%;
  top: 22%;
  border-radius: 50%;
  transform: scale(0.6);
  will-change: transform;
  background: #111;
  box-shadow: 0 0 90px rgba(0, 229, 255, 0.28);
  opacity: 0;
  transition: opacity 0.6s ease;
}
.photo-fallback {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  overflow: hidden;
  background: radial-gradient(circle at 35% 45%, #4B5565 0%, #242B36 55%, #12151D 100%);
}

/* Aperture blades transform via scroll */
.blade {
  transform-origin: 0 0;
  transition: transform 0.1s ease;
}
.blade-group-transform {
  /* applied dynamically */
}

/* Hero content */
.hcopy {
  position: relative;
  z-index: 5;
  width: 100%;
  will-change: transform, opacity;
  translate: calc(var(--px, 0) * 10px) calc(var(--py, 0) * 8px);
}
.hcopy h1,
.hcopy p.lead {
  text-shadow: 0 4px 40px rgba(6, 8, 13, 0.9);
}

.hero-badge-wrap {
  display: flex;
  gap: 10px;
  justify-content: center;
  margin-bottom: 16px;
  animation: up 0.9s var(--ease) both;
  animation-delay: 0.1s;
}

.hero-title {
  font: 800 clamp(2.1rem, 6.4vw, 4.6rem) var(--display);
  letter-spacing: -0.03em;
  line-height: 1.04;
  text-shadow: 0 4px 40px rgba(6, 8, 13, 0.95);
  margin: 0 0 0 0;
  animation: trk 1.3s var(--ease) both;
}

.gradient-text {
  background: linear-gradient(110deg, #fff 5%, #70F3FF 28%, #FFB300 50%, #FF2A55 72%, #fff 95%);
  background-size: 250% 100%;
  -webkit-background-clip: text;
  background-clip: text;
  animation: gshift 7s linear infinite;
}
@keyframes gshift {
  to { background-position: -250% 0; }
}

.hero-lead {
  color: var(--text-muted);
  font-size: 1rem;
  line-height: 1.7;
  max-width: 640px;
  margin: 0 auto 28px;
  animation: up 0.9s var(--ease) both;
  animation-delay: 0.55s;
}

.hero-cta {
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
  margin-bottom: 0;
  animation: up 0.9s var(--ease) both;
  animation-delay: 0.75s;
}

.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px 24px;
  border-radius: var(--radius-m);
  font-size: 0.95rem;
  font-weight: 600;
  font-family: var(--display);
  cursor: pointer;
  transition: all 0.2s;
  text-decoration: none;
  border: none;
}
.btn-primary {
  background: var(--cyan);
  color: #040810;
  overflow: hidden;
}
.btn-primary::after {
  content: '';
  position: absolute;
  top: 0;
  bottom: 0;
  left: -60%;
  width: 40%;
  background: linear-gradient(100deg, transparent, rgba(255, 255, 255, 0.6), transparent);
  transform: skewX(-20deg);
  animation: shine 3.8s ease-in-out infinite;
  pointer-events: none;
}
@keyframes shine {
  0%, 55% { left: -60%; }
  100% { left: 140%; }
}
.btn-primary:hover {
  background: var(--cyan-soft);
  transform: translateY(-1px);
}
.btn-ghost {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text);
}
.btn-ghost:hover {
  border-color: var(--cyan);
  color: var(--cyan);
}

.hero-note {
  font-size: 0.8rem;
  color: var(--text-faint);
  margin-top: 10px;
  letter-spacing: 0.04em;
}

/* Reveal animations */
@keyframes up {
  from { opacity: 0; transform: translateY(40px); }
}
@keyframes trk {
  from { opacity: 0; letter-spacing: 0.1em; filter: blur(14px); transform: translateY(20px); }
}

/* rev2 - Every pixel stays yours */
.rev2 {
  position: absolute;
  z-index: 5;
  text-align: center;
  padding: 0 24px;
  max-width: 780px;
  opacity: 0;
  pointer-events: none;
  will-change: transform, opacity;
  top: 60%;
  left: 50%;
  transform: translate(-50%, -50%);
}
.rev2 .big {
  font: 800 clamp(2.1rem, 6.4vw, 4.6rem) var(--display);
  letter-spacing: -0.03em;
  line-height: 1.04;
  text-shadow: 0 4px 40px rgba(6, 8, 13, 0.95);
  margin: 0;
}
.rev2 .ch {
  display: flex;
  gap: 10px;
  justify-content: center;
  flex-wrap: wrap;
  margin-top: 22px;
}
.rev2 .ch span {
  padding: 10px 18px;
  border-radius: 99px;
  background: rgba(8, 11, 17, 0.74);
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  font: 700 0.9rem var(--display);
}

/* fstop - Aperture readout */
.fstop {
  position: absolute;
  bottom: 22px;
  left: 0;
  right: 0;
  display: flex;
  justify-content: center;
  gap: 18px;
  font: 600 0.8rem var(--mono);
  color: var(--text-faint);
  z-index: 6;
}
.fstop b {
  color: var(--cyan);
  min-width: 4.5ch;
  display: inline-block;
}

/* Dynamic transforms applied via inline style */
.hero-blade-transform {
  transform: var(--blade-transform);
}

@media (max-width: 760px) {
  .hero.pin { height: 220vh; }
  .hero h1 { font-size: clamp(2.2rem, 11vw, 3.2rem); margin-bottom: 16px; }
  .hero p.lead { font-size: 1rem; margin-bottom: 22px; }
  .hero-badge-wrap { margin-bottom: 16px; }
  .hcopy { padding: 0 18px; }
  .fstop span:last-child { display: none; }
  .orb span { transform: rotate(var(--a)) translateY(-40vmin) rotate(calc(var(--a) * -1)); }
  .orb b { font-size: 0.6rem; padding: 4px 9px; }
  .rev2 .ch span { font-size: 0.8rem; padding: 8px 14px; }
}
</style>
