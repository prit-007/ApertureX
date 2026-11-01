<template>
  <header class="hero pin" id="top" ref="heroRef">
    <div class="stick" ref="stickRef">
      <div class="hero-ambient"></div>
      <div class="hero-grid-bg"></div>
      <canvas id="fx" class="hero-fx" aria-hidden="true"></canvas>

      <!-- Orbiting pills -->
      <div class="orb" aria-hidden="true" ref="orbRef">
        <span style="--a:0deg"><b>Rust engine</b></span>
        <span style="--a:90deg"><b>RAW</b></span>
        <span style="--a:180deg"><b>C2PA</b></span>
        <span style="--a:270deg"><b>Look QR</b></span>
      </div>

      <!-- Iris + aperture blades -->
      <div class="iris" ref="irisRef" @mousemove="onMouseMove" @mouseleave="onMouseLeave">
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
          <circle r="196" fill="none" stroke="#00E5FF" stroke-width="2" opacity="0.45" />
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
import { ref, onMounted, onUnmounted, computed, nextTick } from 'vue'
import irisImg from '../assets/stock/iris.webp'

const heroRef = ref(null)
const stickRef = ref(null)
const irisRef = ref(null)
const contentRef = ref(null)
const rev2Ref = ref(null)
const fstopRef = ref(null)
const bladesRef = ref(null)
const orbRef = ref(null)

const version = 'v0.3.7'
const irisImageSrc = irisImg

const apertureStops = [16, 11, 8, 5.6, 4, 2.8, 2, 1.4, 1.2]

let bladeEls = []
let heroEl = null
let contentEl = null
let rev2El = null
let fstopEl = null
let photoEl = null
let ticking = false
let scrollP = 0

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

  // Aperture blades: rotate to position + translate outward + rotate open
  bladeEls.forEach((b, k) => {
    b.setAttribute(
      'transform',
      `rotate(${k * 45}) translate(${e * 210}px, 0) rotate(${e * -24}deg)`
    )
  })

  // Photo scale
  if (photoEl) {
    photoEl.style.transform = `scale(${0.6 + e * 1.3})`
  }

  // Hero content (hcopy): lift + fade
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

onMounted(async () => {
  await nextTick()
  heroEl = heroRef.value
  contentEl = contentRef.value
  rev2El = rev2Ref.value
  fstopEl = fstopRef.value
  photoEl = document.getElementById('photo')
  // Collect individual blade <g> elements
  const bladesContainer = bladesRef.value
  if (bladesContainer) {
    bladeEls = Array.from(bladesContainer.querySelectorAll('g'))
  }

  updateScroll()

  window.addEventListener('scroll', onScroll, { passive: true })
  window.addEventListener('resize', onScroll)

  // Mouse parallax
  const iris = irisRef.value
  const orb = orbRef.value
  if (iris && orb) {
    window.addEventListener('mousemove', (e) => {
      if (!heroEl) return
      const rect = heroEl.getBoundingClientRect()
      const cx = rect.left + rect.width / 2
      const cy = rect.top + rect.height / 2
      const dx = (e.clientX - cx) / (rect.width / 2)
      const dy = (e.clientY - cy) / (rect.height / 2)
      const mx = Math.max(-1, Math.min(1, dx))
      const my = Math.max(-1, Math.min(1, dy))
      iris.style.setProperty('--px', mx.toFixed(4))
      iris.style.setProperty('--py', my.toFixed(4))
      orb.style.setProperty('--px', mx.toFixed(4))
      orb.style.setProperty('--py', my.toFixed(4))
    })
  }
})

onUnmounted(() => {
  window.removeEventListener('scroll', onScroll)
  window.removeEventListener('resize', onScroll)
})
</script>

<style scoped></style>
