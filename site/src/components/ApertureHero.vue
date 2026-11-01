<template>
  <header class="hero pin" id="top" ref="heroRef">
    <div class="stick" ref="stickRef">
      <div class="hero-ambient"></div>
      <div class="hero-grid-bg"></div>

      <!-- Bokeh particle canvas -->
      <canvas id="fx" class="hero-fx" aria-hidden="true" ref="fxRef"></canvas>

      <!-- Scroll flash -->
      <div class="flash" ref="flashRef"></div>

      <!-- Orbiting capability pills -->
      <div class="orb" aria-hidden="true">
        <span v-for="pill in primaryOrb" :key="pill.label" :style="{ '--a': pill.angle + 'deg' }">
          <b>{{ pill.label }}</b>
        </span>
      </div>
      <div class="orb o2" aria-hidden="true">
        <span v-for="pill in secondaryOrb" :key="pill.label" :style="{ '--a': pill.angle + 'deg' }">
          <b>{{ pill.label }}</b>
        </span>
      </div>

      <!-- Iris + aperture blades -->
      <div class="iris" ref="irisRef">
        <img
          id="photo"
          ref="photoRef"
          :src="irisImageSrc"
          alt="Hero photo preview"
          class="photo"
          draggable="false"
        />

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
            <blade v-for="n in 8" :key="n" :angle="(n - 1) * 45" />
          </g>
          <circle r="196" fill="none" stroke="#00E5FF" stroke-width="2" opacity="0.45" />
        </svg>
      </div>

      <!-- Hero content -->
      <div class="hcopy hero-content" ref="contentRef" id="hcopy">
        <div class="hero-badge-wrap">
          <span class="hud-tag">TRUE FOSS CREATIVE SUITE</span>
          <span class="hud-tag hud-tag-amber">GPL-3.0</span>
          <span class="hud-tag hud-tag-emerald">100% ON-DEVICE</span>
          <span class="hud-tag hud-tag-cyan">F-DROID READY</span>
        </div>

        <h1 class="hero-title">
          Pro Photo Editing.<br />
          <span class="gradient-text">Zero Cloud. Zero Subscriptions.</span>
        </h1>

        <p class="lead">
          The open-source alternative to Lightroom &amp; Snapseed. Two pro UI shells over one
          non-destructive recipe, a compiled <strong>Rust engine</strong>,
          <strong>55+ cinematic presets</strong>, <strong>Depth Anything V2 bokeh</strong>,
          and <strong>C2PA provenance</strong> — <strong>100% on-device</strong>,
          GPL-3.0, with zero cloud and zero subscriptions.
        </p>

        <div class="hero-cta">
          <a
            href="https://github.com/prit-007/ApertureX/releases/latest"
            class="btn btn-primary"
            target="_blank"
            rel="noopener"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
              <path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" />
            </svg>
            <span>Download Universal APK ({{ version }})</span>
          </a>
          <a href="#screens" class="btn btn-ghost">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
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
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z" />
            </svg>
            GitHub (FOSS)
          </a>
          <p class="hero-note">Android 8.0+ &bull; Signed Universal APK &bull; F-Droid Ready &bull; 100% Offline</p>
        </div>
      </div>

      <!-- Every pixel stays yours -->
      <div class="rev2" ref="rev2Ref" aria-hidden="true">
        <p class="big">Every pixel stays yours.</p>
        <div class="ch">
          <span>200 MP tiles</span>
          <span>16-bit TIFF</span>
          <span>Zero trackers</span>
        </div>
      </div>

      <!-- Aperture f-stop readout -->
      <div class="fstop" aria-hidden="true">
        <span>Aperture <b ref="fvalRef" id="fval">f/16</b></span>
        <span>Scroll to open</span>
      </div>
    </div>
  </header>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import Blade from './Blade.vue'
import irisImg from '../assets/stock/iris.webp'

const heroRef = ref(null)
const stickRef = ref(null)
const irisRef = ref(null)
const photoRef = ref(null)
const contentRef = ref(null)
const rev2Ref = ref(null)
const fvalRef = ref(null)
const bladesRef = ref(null)
const fxRef = ref(null)
const flashRef = ref(null)

const version = 'v0.3.9'
const irisImageSrc = irisImg

const primaryOrb = [
  { label: 'Rust engine', angle: 0 },
  { label: 'RAW', angle: 90 },
  { label: 'C2PA', angle: 180 },
  { label: 'Look QR', angle: 270 },
]

const secondaryOrb = [
  { label: '65³ LUT', angle: 0 },
  { label: '16-bit TIFF', angle: 60 },
  { label: 'AI masks', angle: 120 },
  { label: '0 trackers', angle: 180 },
  { label: 'GPL-3.0', angle: 240 },
  { label: '200 MP', angle: 300 },
]

const apertureStops = [16, 11, 8, 5.6, 4, 2.8, 2, 1.4, 1.2]

let heroEl, stickEl, contentEl, rev2El, fvalEl, photoEl, flashEl, irisEl
let bladeEls = []
let ticking = false
let flashWas = false
let reducedMotion = false

// Canvas bokeh state
let fxEl, fxCtx, fxW, fxH, fxD = 1
let fxPx = 0, fxPy = 0, fxTx = 0, fxTy = 0
let fxRaf = null, fxVis = true
let lastY = 0, fxVel = 0, fxSkew = 0
const FX_COL = ['0,229,255', '255,179,0', '255,42,85', '255,255,255']
const FX_P = []
let fxObserver = null

const currentFStop = (p) => {
  const idx = Math.min(8, Math.round(p * 8))
  return `f/${apertureStops[idx]}`
}

const smoothstep = (p) => p * p * (3 - 2 * p)

const updateScroll = () => {
  ticking = false
  if (!heroEl) return

  const r = heroEl.getBoundingClientRect()
  const viewH = window.innerHeight
  const travel = Math.max(1, r.height - viewH)
  const p = reducedMotion ? 0 : Math.max(0, Math.min(1, -r.top / travel))
  const e = smoothstep(p)

  // ---- Aperture blades (SVG transforms) ----
  // Outer groups keep their k*45deg base rotation; the blade itself
  // slides outward and swings open around its pivot at (95, 0).
  bladeEls.forEach((b) => {
    b.setAttribute(
      'transform',
      `translate(${e * 210},0) rotate(${e * -24} 95 0)`
    )
  })

  // Photo scale (capped inside the iris circle)
  if (photoEl) {
    photoEl.style.transform = `scale(${Math.min(1.45, 0.62 + e * 0.83)})`
  }

  // Hero content lift + fade
  const hp = Math.min(1, p * 2.2)
  const ho = 1 - Math.max(0, (p - 0.25) * 3)
  if (contentEl) {
    contentEl.style.opacity = ho
    contentEl.style.pointerEvents = ho < 0.15 ? 'none' : ''
    contentEl.style.transform = `translateY(${-hp * 60}px) scale(${1 - hp * 0.08})`
  }

  // Rev2 reveal
  const q = Math.max(0, Math.min(1, (p - 0.5) * 3))
  if (rev2El) {
    rev2El.style.opacity = q
    rev2El.style.transform = `translateY(${(1 - q) * 40}px)`
  }

  // F-stop readout
  if (fvalEl) {
    fvalEl.textContent = currentFStop(p)
  }

  // Flash on scroll past midpoint
  if (flashEl) {
    const on = p > 0.5
    if (on !== flashWas) {
      flashWas = on
      flashEl.classList.remove('go')
      void flashEl.offsetWidth
      flashEl.classList.add('go')
    }
  }
}

const onScroll = () => {
  if (ticking) return
  ticking = true
  requestAnimationFrame(updateScroll)
}

// Canvas bokeh
function fxSize() {
  if (!fxEl) return
  const r = fxEl.getBoundingClientRect()
  fxD = Math.min(2, window.devicePixelRatio || 1)
  fxW = fxEl.width = Math.max(1, Math.round(r.width * fxD))
  fxH = fxEl.height = Math.max(1, Math.round(r.height * fxD))
  fxEl.style.width = r.width + 'px'
  fxEl.style.height = r.height + 'px'
}

function fxMk() {
  return {
    x: Math.random() * fxW,
    y: Math.random() * fxH,
    r: (2 + Math.random() * 9) * fxD,
    vy: -(0.08 + Math.random() * 0.35) * fxD,
    vx: (Math.random() - 0.5) * 0.2 * fxD,
    a: 0.08 + Math.random() * 0.35,
    c: FX_COL[Math.floor(Math.random() * FX_COL.length)],
    z: 0.3 + Math.random() * 1.2,
    ph: Math.random() * 6.28,
    ring: Math.random() < 0.4,
  }
}

function fxLoop(t) {
  fxRaf = requestAnimationFrame(fxLoop)
  if (!fxCtx) return

  const dy = window.scrollY - lastY
  lastY = window.scrollY
  fxVel += (dy - fxVel) * 0.12

  const mq = document.querySelector('.mq')
  if (mq) {
    fxSkew += (Math.max(-8, Math.min(8, fxVel * 0.25)) - fxSkew) * 0.15
    mq.style.transform = `rotate(-1.2deg) skewX(${fxSkew.toFixed(2)}deg)`
  }

  if (!fxVis) return

  fxPx += (fxTx - fxPx) * 0.07
  fxPy += (fxTy - fxPy) * 0.07
  if (stickEl) {
    stickEl.style.setProperty('--px', fxPx.toFixed(4))
    stickEl.style.setProperty('--py', fxPy.toFixed(4))
  }

  fxCtx.clearRect(0, 0, fxW, fxH)
  const boost = 1 + Math.min(14, Math.abs(fxVel) * 0.6)

  for (const p of FX_P) {
    p.y += p.vy * boost * p.z
    p.x += p.vx + Math.sin(t / 1600 + p.ph) * 0.25 * fxD
    if (p.y < -20 * fxD) {
      p.y = fxH + 20 * fxD
      p.x = Math.random() * fxW
    }
    if (p.x < -20 * fxD) p.x = fxW + 10 * fxD
    if (p.x > fxW + 20 * fxD) p.x = -10 * fxD

    const ox = fxPx * -60 * p.z * fxD
    const oy = fxPy * -60 * p.z * fxD
    const al = p.a * (0.7 + 0.3 * Math.sin(t / 900 + p.ph))

    fxCtx.beginPath()
    fxCtx.arc(p.x + ox, p.y + oy, p.r * p.z, 0, 6.283)
    if (p.ring) {
      fxCtx.strokeStyle = `rgba(${p.c},${al})`
      fxCtx.lineWidth = 1.2 * fxD
      fxCtx.stroke()
    } else {
      fxCtx.fillStyle = `rgba(${p.c},${al * 0.7})`
      fxCtx.fill()
    }
  }
}

function onPointerMove(e) {
  if (!stickEl) return
  const r = stickEl.getBoundingClientRect()
  fxTx = (e.clientX - r.left) / r.width - 0.5
  fxTy = (e.clientY - r.top) / r.height - 0.5
}

function onPointerLeave() {
  fxTx = 0
  fxTy = 0
}

onMounted(async () => {
  await nextTick()

  heroEl = heroRef.value
  stickEl = stickRef.value
  irisEl = irisRef.value
  photoEl = photoRef.value
  contentEl = contentRef.value
  rev2El = rev2Ref.value
  fvalEl = fvalRef.value
  flashEl = flashRef.value
  fxEl = fxRef.value

  const bladesContainer = bladesRef.value
  if (bladesContainer) {
    bladeEls = Array.from(bladesContainer.querySelectorAll('polygon.blade'))
  }

  reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches

  updateScroll()

  window.addEventListener('scroll', onScroll, { passive: true })
  window.addEventListener('resize', onScroll)

  if (reducedMotion) {
    if (fxEl) fxEl.style.display = 'none'
    return
  }

  // Pointer parallax drives .iris, .orb, .hcopy and .hero-ambient via CSS vars.
  if (stickEl) {
    stickEl.addEventListener('pointermove', onPointerMove)
    stickEl.addEventListener('pointerleave', onPointerLeave)
  }

  // Canvas bokeh
  fxSize()
  if (fxEl) {
    fxCtx = fxEl.getContext('2d')
    const count = window.innerWidth < 760 ? 18 : 38
    for (let i = 0; i < count; i++) FX_P.push(fxMk())
    lastY = window.scrollY
    fxRaf = requestAnimationFrame(fxLoop)
    window.addEventListener('resize', fxSize)
  }

  // Pause the particle loop while the hero is off-screen.
  if (stickEl) {
    fxObserver = new IntersectionObserver((entries) => {
      fxVis = entries[0].isIntersecting
    })
    fxObserver.observe(stickEl)
  }
})

onUnmounted(() => {
  window.removeEventListener('scroll', onScroll)
  window.removeEventListener('resize', onScroll)
  window.removeEventListener('resize', fxSize)
  if (stickEl) {
    stickEl.removeEventListener('pointermove', onPointerMove)
    stickEl.removeEventListener('pointerleave', onPointerLeave)
  }
  if (fxRaf) cancelAnimationFrame(fxRaf)
  if (fxObserver) fxObserver.disconnect()
})
</script>

<style scoped>
.aperture-svg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  overflow: visible;
}
</style>
