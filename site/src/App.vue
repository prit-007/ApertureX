<template>
  <div class="aperturex">
    <a href="#content" class="skip-link">Skip to content</a>

    <Layout>
      <template #default>
        <main id="content">
          <ApertureHero />
          <Marquee />
          <HeroSpecs />
          <PitchSection />
          <CompareSection />
          <FeaturesGrid />
          <ScreensDemo />
          <PipelineSection />
          <DownloadSection />
          <ReleaseList />
          <DevelopersSection />
        </main>
      </template>
    </Layout>
  </div>
</template>

<script setup>
import { nextTick, onMounted, onUnmounted } from 'vue'
import Layout from './components/Layout.vue'
import ApertureHero from './components/ApertureHero.vue'
import Marquee from './components/Marquee.vue'
import HeroSpecs from './components/HeroSpecs.vue'
import PitchSection from './components/PitchSection.vue'
import CompareSection from './components/CompareSection.vue'
import FeaturesGrid from './components/FeaturesGrid.vue'
import ScreensDemo from './components/ScreensDemo.vue'
import PipelineSection from './components/PipelineSection.vue'
import DownloadSection from './components/DownloadSection.vue'
import ReleaseList from './components/ReleaseList.vue'
import DevelopersSection from './components/DevelopersSection.vue'

let revealTargets = []

function splitHeadingWords() {
  document.querySelectorAll('.section-head h2, .download-box h2').forEach((heading) => {
    if (heading.dataset.split === 'true') return
    const text = heading.textContent.trim()
    if (!text) return

    heading.dataset.split = 'true'
    heading.setAttribute('aria-label', text)
    heading.textContent = ''

    text.split(/\s+/).forEach((word, index) => {
      const wrap = document.createElement('span')
      wrap.className = 'w'
      wrap.setAttribute('aria-hidden', 'true')

      const inner = document.createElement('span')
      inner.style.setProperty('--k', index)
      inner.textContent = word
      wrap.appendChild(inner)

      heading.appendChild(wrap)
      if (index < text.split(/\s+/).length - 1) {
        heading.appendChild(document.createTextNode(' '))
      }
    })
  })
}

function revealVisible() {
  const limit = window.innerHeight - 30
  revealTargets.forEach((el) => {
    if (el.classList.contains('is-visible')) return
    const rect = el.getBoundingClientRect()
    if (rect.top < limit && rect.bottom > 0) {
      el.classList.add('is-visible')
    }
  })
}

function onRevealScroll() {
  revealVisible()
}

onMounted(async () => {
  await nextTick()

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  if (reduceMotion) return

  splitHeadingWords()

  revealTargets = [
    ...document.querySelectorAll(
      '.section-head, .bento-card, .flow-step, .trust-card, .download-box, .hero-spec-card, .pitch-card, .interactive-demo, .caption-box'
    ),
  ]

  revealTargets.forEach((el, index) => {
    el.classList.add('reveal')
    el.style.transitionDelay = Math.min((index % 6) * 35, 175) + 'ms'
  })

  revealVisible()
  window.addEventListener('scroll', onRevealScroll, { passive: true })
  window.addEventListener('resize', onRevealScroll)
})

onUnmounted(() => {
  window.removeEventListener('scroll', onRevealScroll)
  window.removeEventListener('resize', onRevealScroll)
  revealTargets = []
})
</script>

<style scoped>
.aperturex {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
.skip-link {
  position: fixed;
  top: 10px;
  left: 50%;
  transform: translate(-50%, -160%);
  z-index: 200;
  background: var(--cyan);
  color: #040810;
  font-family: var(--display);
  font-weight: 800;
  padding: 10px 18px;
  border-radius: 100px;
  transition: transform 0.2s ease;
}
.skip-link:focus {
  transform: translate(-50%, 0);
}
</style>
