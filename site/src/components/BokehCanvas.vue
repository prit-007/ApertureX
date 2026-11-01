<template>
  <canvas ref="canvas" class="bokeh-canvas" aria-hidden="true"></canvas>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'

const canvas = ref(null)

let W = 0
let H = 0
let D = 1
let P = []
let vis = true
let tx = 0
let ty = 0
let px = 0
let py = 0
let lastY = 0
let vel = 0
let skew = 0
let raf = null

const COL = ['0,229,255', '255,179,0', '255,42,85', '255,255,255']

function mk() {
  return {
    x: Math.random() * W,
    y: Math.random() * H,
    r: (2 + Math.random() * 9) * D,
    vy: -(0.08 + Math.random() * 0.35) * D,
    vx: (Math.random() - 0.5) * 0.2 * D,
    a: 0.08 + Math.random() * 0.3,
    c: COL[Math.floor(Math.random() * COL.length)],
    z: 0.3 + Math.random() * 1.2,
    ph: Math.random() * 6.28,
    ring: Math.random() < 0.4,
  }
}

function size() {
  const el = canvas.value
  if (!el) return
  const r = el.getBoundingClientRect()
  D = Math.min(2, window.devicePixelRatio || 1)
  W = el.width = Math.max(1, r.width * D)
  H = el.height = Math.max(1, r.height * D)
  el.style.width = r.width + 'px'
  el.style.height = r.height + 'px'
}

function loop(t) {
  raf = requestAnimationFrame(loop)
  const cx = canvas.value.getContext('2d')
  const dy = window.scrollY - lastY
  lastY = window.scrollY
  vel += (dy - vel) * 0.12

  const mq = document.querySelector('.mq')
  if (mq) {
    skew += (Math.max(-8, Math.min(8, vel * 0.25)) - skew) * 0.15
    mq.style.transform = 'rotate(-1.2deg) skewX(' + skew.toFixed(2) + 'deg)'
  }

  if (!vis) return
  px += (tx - px) * 0.07
  py += (ty - py) * 0.07
  canvas.value.style.setProperty('--px', px.toFixed(4))
  canvas.value.style.setProperty('--py', py.toFixed(4))

  cx.clearRect(0, 0, W, H)
  const boost = 1 + Math.min(14, Math.abs(vel) * 0.6)

  for (const p of P) {
    p.y += p.vy * boost * p.z
    p.x += p.vx + Math.sin(t / 1600 + p.ph) * 0.25 * D
    if (p.y < -20 * D) {
      p.y = H + 20 * D
      p.x = Math.random() * W
    }
    if (p.x < -20 * D) p.x = W + 10 * D
    if (p.x > W + 20 * D) p.x = -10 * D
    const ox = px * -60 * p.z * D
    const oy = py * -60 * p.z * D
    const al = p.a * (0.7 + 0.3 * Math.sin(t / 900 + p.ph))
    cx.beginPath()
    cx.arc(p.x + ox, p.y + oy, p.r * p.z, 0, 6.283)
    if (p.ring) {
      cx.strokeStyle = 'rgba(' + p.c + ',' + al + ')'
      cx.lineWidth = 1.2 * D
      cx.stroke()
    } else {
      cx.fillStyle = 'rgba(' + p.c + ',' + al * 0.7 + ')'
      cx.fill()
    }
  }
}

onMounted(() => {
  size()
  const N = window.innerWidth < 760 ? 18 : 38
  for (let i = 0; i < N; i++) P.push(mk())

  const st = document.querySelector('.stick')
  if (st) {
    const observer = new IntersectionObserver((e) => {
      vis = e[0].isIntersecting
    })
    observer.observe(st)

    st.addEventListener('pointermove', (e) => {
      const r = st.getBoundingClientRect()
      tx = (e.clientX - r.left) / r.width - 0.5
      ty = (e.clientY - r.top) / r.height - 0.5
    })
    st.addEventListener('pointerleave', () => {
      tx = 0
      ty = 0
    })
  }

  window.addEventListener('resize', size)
  raf = requestAnimationFrame(loop)
})

onUnmounted(() => {
  if (raf) cancelAnimationFrame(raf)
  window.removeEventListener('resize', size)
})
</script>

<style scoped>
.bokeh-canvas {
  position: fixed;
  inset: 0;
  width: 100vw;
  height: 100vh;
  z-index: -1;
  pointer-events: none;
}
</style>
