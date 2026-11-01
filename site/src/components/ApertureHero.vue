<template>
  <header class="hero pin" id="top" ref="heroRef">
    <div class="stick" ref="stickRef">
      <div class="hero-ambient"></div>
      <div class="hero-grid-bg"></div>

      <!-- Bokeh particle canvas -->
      <canvas id="fx" class="hero-fx" aria-hidden="true" ref="fxRef"></canvas>

      <!-- Scroll flash -->
      <div class="flash" ref="flashRef"></div>

      <!-- Iris + aperture blades -->
      <div class="iris-wrap" ref="irisRef" @mousemove="onMouseMove" @mouseleave="onMouseLeave">
        <img
          id="photo"
          :src="irisImageSrc"
          alt="Hero photo preview"
          class="photo"
          draggable="false"
        />
        <div id="photoFallback" class="photo-fallback"></div>

        <svg
          class="aperture-svg"
          viewBox="-220 -220 440 440"
          preserveAspectRatio="xMidYMid slice"
        >
          <defs>
            <linearGradient id="apertureGrad" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stop-color="#1b2438" />
              <stop offset="1" stop-color="#0b0f1a" />
            </linearGradient>
          </defs>
          <g id="blades" ref="bladesRef">
            <blade
              v-for="n in 8"
              :key="n"
              :angle="n * 45"
            />
          </g>
          <circle r="210" fill="none" stroke="#00E5FF" stroke-width="2" opacity="0.35" />
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
          The open-source alternative to Adobe Lightroom &amp; Snapseed. Dual UI shells over one
          non-destructive recipe, a high-performance <strong>compiled Rust engine</strong>,
          <strong>on-device AI masks</strong>, <strong>16-bit TIFF export</strong>, and
          cryptographic <strong>C2PA provenance</strong>.
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
          <p class="hero-note">Android 8.0+ &bull; Signed APK &bull; No account required</p>
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
      <div class="fstop" ref="fstopRef" aria-hidden="true">
        <span>Aperture</span>
        <b id="fval">f/16</b>
        <span>Scroll to open</span>
      </div>
    </div>
  </header>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import irisImg from '../assets/stock/iris.webp'

const heroRef = ref(null)
const stickRef = ref(null)
const irisRef = ref(null)
const contentRef = ref(null)
const rev2Ref = ref(null)
const fstopRef = ref(null)
const bladesRef = ref(null)
const fxRef = ref(null)
const flashRef = ref(null)

const version = 'v0.3.7'
const irisImageSrc = irisImg

const apertureStops = [16, 11, 8, 5.6, 4, 2.8, 2, 1.4, 1.2]

let heroEl, contentEl, rev2El, fstopEl, photoEl, stickEl, flashEl, irisEl
let bladeEls = []
let ticking = false
let scrollP = 0

// Canvas bokeh state
let fxEl, fxCtx, fxW, fxH, fxD = 1
let fxPx = 0, fxPy = 0, fxTx = 0, fxTy = 0
let fxRaf, fxVis = true
let lastY = window.scrollY, fxVel = 0, fxSkew = 0
const FX_COL = ['0,229,255', '255,179,0', '255,42,85', '255,255,255']
const FX_P = []

const currentFStop = (p) => {
  const idx = Math.min(8, Math.round(p * 8))
  return `f/${apertureStops[idx]}`
}

const smoothstep = (p) => p * p * (3 - 2 * p)

const updateScroll = () => {
  if (!heroEl) return
  const r = heroEl.getBoundingClientRect()
  const viewH = window.innerHeight
  const p = Math.max(0, Math.min(1, -r.top / (r.height - viewH)))
  const e = smoothstep(p)
  scrollP = p

  // ---- Aperture blades (GPU transforms) ----
  // Each blade rotates to its position, translates outward, rotates open
  bladeEls.forEach((b, k) => {
    const baseRot = k * 45
    const openRot = e * -20
    const tx = e * 190
    b.style.transform = `rotate(${baseRot}deg) translate(${tx}px, 0) rotate(${openRot}deg)`
  })

  // Photo scale
  if (photoEl) {
    photoEl.style.transform = `scale(${0.6 + e * 1.4})`
  }

  // Hero content lift + fade
  const hp = Math.min(1, p * 2.2)
  const ho = 1 - Math.max(0, (p - 0.25) * 3)
  if (contentEl) {
    contentEl.style.opacity = ho
    contentEl.style.pointerEvents = ho < 0.15 ? 'none' : ''
    contentEl.style.transform = `translateY(${-hp * 56}px) scale(${1 - hp * 0.06})`
  }

  // Rev2 reveal
  const q = Math.max(0, Math.min(1, (p - 0.5) * 3))
  if (rev2El) {
    rev2El.style.opacity = q
    rev2El.style.transform = `translateY(${(1 - q) * 36}px)`
  }

  // F-stop readout
  if (fstopEl) {
    fstopEl.textContent = currentFStop(p)
  }

  ticking = false
}

const onScroll = () => {
  if (ticking) return
  ticking = true
  requestAnimationFrame(() => {
    updateScroll()
    ticking = false
  })
}

const onMouseMove = (e) => {
  if (!heroEl || !irisEl) return
  const r = heroEl.getBoundingClientRect()
  const cx = r.left + r.width / 2
  const cy = r.top + r.height / 2
  const dx = Math.max(-1, Math.min(1, (e.clientX - cx) / (r.width / 2)))
  const dy = Math.max(-1, Math.min(1, (e.clientY - cy) / (r.height / 2)))
  irisEl.style.setProperty('--px', dx.toFixed(4))
  irisEl.style.setProperty('--py', dy.toFixed(4))
}

const onMouseLeave = () => {
  if (irisEl) {
    irisEl.style.setProperty('--px', '0')
    irisEl.style.setProperty('--py', '0')
  }
}

// Canvas bokeh
function fxSize() {
  if (!fxEl) return
  const r = fxEl.getBoundingClientRect()
  fxD = Math.min(2, window.devicePixelRatio || 1)
  fxW = fxEl.width = Math.max(1, r.width * fxD)
  fxH = fxEl.height = Math.max(1, r.height * fxD)
  fxEl.style.width = r.width + 'px'
  fxEl.style.height = r.height + 'px'
  if (fxCtx) fxCtx.scale(fxD, fxD)
}

function fxMk() {
  return {
    x: Math.random() * fxW,
    y: Math.random() * fxH,
    r: (1 + Math.random() * 6) * fxD,
    vy: -(0.05 + Math.random() * 0.25) * fxD,
    vx: (Math.random() - 0.5) * 0.12 * fxD,
    a: 0.03 + Math.random() * 0.2,
    c: FX_COL[Math.floor(Math.random() * FX_COL.length)],
    z: 0.5 + Math.random() * 1.2,
    ph: Math.random() * 6.28,
    ring: Math.random() < 0.35,
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
  fxPx += (fxTx - fxPx) * 0.06
  fxPy += (fxTy - fxPy) * 0.06

  fxCtx.clearRect(0, 0, fxW, fxH)
  const boost = 1 + Math.min(12, Math.abs(fxVel) * 0.5)

  for (const p of FX_P) {
    p.y += p.vy * boost * p.z
    p.x += p.vx + Math.sin(t / 1500 + p.ph) * 0.2 * fxD
    if (p.y < -20 * fxD) { p.y = fxH + 20 * fxD; p.x = Math.random() * fxW }
    if (p.x < -20 * fxD) p.x = fxW + 10 * fxD
    if (p.x > fxW + 20 * fxD) p.x = -10 * fxD
    const ox = fxPx * -50 * p.z * fxD
    const oy = fxPy * -50 * p.z * fxD
    const al = p.a * (0.6 + 0.4 * Math.sin(t / 800 + p.ph))
    fxCtx.beginPath()
    fxCtx.arc(p.x + ox, p.y + oy, p.r * p.z, 0, 6.283)
    if (p.ring) {
      fxCtx.strokeStyle = `rgba(${p.c},${al})`
      fxCtx.lineWidth = 1 * fxD
      fxCtx.stroke()
    } else {
      fxCtx.fillStyle = `rgba(${p.c},${al * 0.75})`
      fxCtx.fill()
    }
  }
}

onMounted(async () => {
  await nextTick()
  heroEl = heroRef.value
  stickEl = stickRef.value
  contentEl = contentRef.value
  rev2El = rev2Ref.value
  fstopEl = fstopRef.value
  photoEl = document.getElementById('photo')
  irisEl = irisRef.value
  flashEl = flashRef.value

  const bladesContainer = bladesRef.value
  if (bladesContainer) {
    bladeEls = Array.from(bladesContainer.querySelectorAll('g > g'))
  }

  updateScroll()

  window.addEventListener('scroll', onScroll, { passive: true })
  window.addEventListener('resize', onScroll)

  // Canvas bokeh
  fxEl = fxRef.value
  fxSize()
  fxCtx = fxEl.getContext('2d')
  for (let i = 0; i < (window.innerWidth < 760 ? 16 : 32); i++) FX_P.push(fxMk())
  fxRaf = requestAnimationFrame(fxLoop)
  window.addEventListener('resize', fxSize)

  // Flash on scroll past midpoint
  let flashWas = false
  window.addEventListener('scroll', () => {
    if (flashEl && heroEl) {
      const r = heroEl.getBoundingClientRect()
      const pr = -r.top / (r.height - window.innerHeight)
      const on = pr > 0.5
      if (on !== flashWas) {
        flashWas = on
        flashEl.classList.remove('go')
        void flashEl.offsetWidth
        flashEl.classList.add('go')
      }
    }
  }, { passive: true })

  // Stick visibility for canvas
  if (stickEl) {
    new IntersectionObserver((e) => {
      fxVis = e[0].isIntersecting
    }).observe(stickEl)
  }
})

onUnmounted(() => {
  window.removeEventListener('scroll', onScroll)
  window.removeEventListener('resize', onScroll)
  if (fxRaf) cancelAnimationFrame(fxRaf)
})
</script>

<style scoped>
.iris-wrap {
  position: absolute;
  width: min(100vmin, 820px);
  aspect-ratio: 1;
  z-index: 1;
  pointer-events: none;
  translate: calc(var(--px, 0) * -24px) calc(var(--py, 0) * -24px);
}
.iris-wrap svg {
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
  will-change: transform;
  background: #111;
  box-shadow: 0 0 90px rgba(0, 229, 255, 0.28);
  opacity: 0;
  transition: opacity 0.6s ease;
}
.photo-fallback {
  position: absolute;
  inset: 0;
  border-radius: 50%;
  overflow: hidden;
  background: radial-gradient(circle at 35% 45%, #4B5565 0%, #242B36 55%, #12151D 100%);
}
.blade {
  transform-origin: 0 0;
  will-change: transform;
  transform-box: fill-box;
}
</style>
