<template>
  <div class="aperturex">
    <a href="#content" class="skip-link">Skip to content</a>

    <Layout>
      <template #default>
        <main id="content">
          <ApertureHero />
          <Marquee />
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
  </div>
</template>

<script setup>
import Layout from './components/Layout.vue'
import ApertureHero from './components/ApertureHero.vue'
import Marquee from './components/Marquee.vue'
import HeroSpecs from './components/HeroSpecs.vue'
import CompareSection from './components/CompareSection.vue'
import FeaturesGrid from './components/FeaturesGrid.vue'
import ScreensDemo from './components/ScreensDemo.vue'
import PipelineSection from './components/PipelineSection.vue'
import DownloadSection from './components/DownloadSection.vue'
import ReleaseList from './components/ReleaseList.vue'
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
