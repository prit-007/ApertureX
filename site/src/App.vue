<template>
  <div class="aperturex">
    <a href="#content" class="skip-link">Skip to content</a>

    <BokehCanvas />

    <div class="scroll-progress" ref="scrollProgress"></div>

    <Layout>
      <template #default>
        <main id="content">
          <section id="home" class="hero-section reveal">
            <div class="wrap hero-inner">
              <ApertureBlades class="hero-decoration" />
              <Marquee />

              <div class="hero-copy">
                <div class="hero-kicker">ApertureX</div>
                <h1 class="hero-title">
                  Pro-grade FOSS photo editor
                </h1>
                <p class="hero-lead">
                  Mobile-native, non-destructive editing with dual Lightroom-style
                  and Snapseed-style shells over one shared recipe. Look QR open
                  preset standard, on-device C2PA provenance, and a compiled Rust
                  engine. 100% offline, zero subscriptions, GPL-3.0.
                </p>
                <div class="hero-actions">
                  <a href="#download" class="btn btn-primary">Download v0.3.7</a>
                  <a href="#features" class="btn btn-outline">Features</a>
                </div>
              </div>

              <div class="hero-visual">
                <img
                  src="/assets/app_icon.png"
                  alt="ApertureX icon"
                  class="hero-icon"
                  width="120"
                  height="120"
                />
              </div>
            </div>
          </section>

          <HeroSpecs />

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
            src="/assets/app_icon.png"
            alt="ApertureX"
            class="brand-img"
            width="32"
            height="32"
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
import ApertureBlades from './components/ApertureBlades.vue'
import Marquee from './components/Marquee.vue'
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

.hero-section {
  padding: 80px 0 64px 0;
  background: var(--bg-darkest);
  position: relative;
  overflow: hidden;
}

.hero-inner {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 48px;
  align-items: center;
  position: relative;
  z-index: 2;
}

@media (max-width: 768px) {
  .hero-inner {
    grid-template-columns: 1fr;
    gap: 32px;
    text-align: center;
  }
}

.hero-copy {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.hero-kicker {
  display: inline-block;
  font-family: var(--mono);
  font-size: 0.8rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--cyan);
  margin-bottom: 8px;
}

.hero-title {
  font-size: 2.5rem;
  line-height: 1.1;
  margin: 0;
  letter-spacing: -0.03em;
}

.hero-lead {
  color: var(--text-muted);
  font-size: 1.05rem;
  line-height: 1.7;
  max-width: 560px;
}

.hero-actions {
  display: flex;
  gap: 12px;
  margin-top: 8px;
}

.hero-visual {
  display: flex;
  justify-content: center;
}

.hero-icon {
  border-radius: var(--radius-l);
  box-shadow: 0 20px 40px rgba(0, 229, 255, 0.15);
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
}

.btn-primary:hover {
  background: var(--cyan-soft);
  transform: translateY(-1px);
}

.btn-outline {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text);
}

.btn-outline:hover {
  border-color: var(--cyan);
  color: var(--cyan);
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
