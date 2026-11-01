<template>
  <div class="aperturex">
    <a href="#content" class="skip-link">Skip to content</a>

    <BokehCanvas />

    <div class="scroll-progress" ref="scrollProgress"></div>

    <Layout>
      <template #default>
        <main id="content">
          <!-- Hero 1: Living Aperture (mouse-responsive blades + app icon) -->
          <LivingApertureHero />

          <!-- Hero specs chips -->
          <HeroSpecs />

          <!-- Hero 2: Immersive Before/After (depth bokeh + split curtain) -->
          <ImmersiveHero />

          <!-- Interactive compare widget -->
          <CompareSection />

          <FeaturesGrid />

          <ScreensDemo />

          <PipelineSection />

          <DownloadSection />

          <ReleaseList />
        </main>
      </template>
    </Layout>

    <footer class="site-footer">
      <div class="wrap footer-inner">
        <div class="footer-brand">
                <img
                  :src="appIcon"
                  alt="ApertureX icon"
                  class="hero-icon"
                  width="120"
                  height="120"
                />
          <span class="brand-text">ApertureX</span>
        </div>
        <p class="footer-copy">
          Mobile-native FOSS photo editor &middot; 100% offline &middot;
          GPL-3.0 &middot; Built with Flutter + Rust
        </p>
      </div>
    </footer>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import Layout from './components/Layout.vue'
import BokehCanvas from './components/BokehCanvas.vue'
import appIcon from './assets/app_icon.png'
import LivingApertureHero from './components/LivingApertureHero.vue'
import ImmersiveHero from './components/ImmersiveHero.vue'
import HeroSpecs from './components/HeroSpecs.vue'
import CompareSection from './components/CompareSection.vue'
import FeaturesGrid from './components/FeaturesGrid.vue'
import ScreensDemo from './components/ScreensDemo.vue'
import PipelineSection from './components/PipelineSection.vue'
import DownloadSection from './components/DownloadSection.vue'
import ReleaseList from './components/ReleaseList.vue'

const scrollProgress = ref(null)

onMounted(() => {
  document.documentElement.classList.add('js')
  const handler = () => {
    if (!scrollProgress.value) return
    const winScroll =
      document.documentElement.scrollTop || document.body.scrollTop
    const height =
      document.documentElement.scrollHeight - document.documentElement.clientHeight
    const scrolled = height ? (winScroll / height) * 100 : 0
    scrollProgress.value.style.width = scrolled + '%'
  }
  window.addEventListener('scroll', handler, { passive: true })
  handler()
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

.scroll-progress {
  position: fixed;
  top: 0;
  left: 0;
  width: 0;
  height: 2px;
  z-index: 150;
  background: linear-gradient(90deg, var(--cyan), var(--amber), var(--coral));
  box-shadow: 0 0 10px rgba(0, 229, 255, 0.6);
  pointer-events: none;
  transition: width 0.08s linear;
}

.site-footer {
  border-top: 1px solid var(--border);
  padding: 40px 0;
  margin-top: auto;
}

.footer-inner {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.footer-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  font-family: var(--display);
  font-weight: 800;
  font-size: 1rem;
  color: var(--text);
}

.footer-copy {
  font-size: 0.85rem;
  color: var(--text-muted);
}

.site-footer .brand-img {
  border-radius: var(--radius-s);
}

.site-footer .brand-text {
  letter-spacing: -0.02em;
}
</style>
