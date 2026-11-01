<template>
  <div class="layout">
    <announcement-bar />
    <header class="site-nav" ref="navRef" :class="{ scrolled }">
      <div class="wrap nav-inner">
        <a href="#top" class="nav-brand" @click="scrollToTop">
          <img :src="appIcon" alt="ApertureX logo" width="34" height="34" />
          <span>APERTUREX</span>
        </a>

        <nav class="nav-links" aria-label="Primary">
          <a href="#compare" data-nav="compare" :class="{ active: activeNav === 'compare' }">Compare</a>
          <a href="#features" data-nav="features" :class="{ active: activeNav === 'features' }">Capabilities</a>
          <a href="#screens" data-nav="screens" :class="{ active: activeNav === 'screens' }">Studio Tour</a>
          <a href="#pipeline" data-nav="pipeline" :class="{ active: activeNav === 'pipeline' }">Architecture</a>
          <a href="#changelog" data-nav="changelog" :class="{ active: activeNav === 'changelog' }">Changelog</a>
          <a href="#developers" data-nav="developers" :class="{ active: activeNav === 'developers' }">Developers</a>
        </nav>

        <div class="nav-actions">
          <span class="nav-version-badge">{{ version }}</span>
          <a
            href="https://github.com/prit-007/ApertureX/releases/latest"
            class="btn btn-primary"
            target="_blank"
            rel="noopener"
          >
            Download APK
          </a>
          <button type="button" class="menu-toggle-btn" @click="toggleDrawer" :aria-expanded="drawerOpen">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
        </div>
      </div>
    </header>

    <!-- Mobile Drawer -->
    <div class="drawer-backdrop" :class="{ open: drawerOpen }" @click.self="closeDrawer" />
    <nav class="mobile-drawer" :class="{ open: drawerOpen }" aria-label="Mobile navigation">
      <a href="#why">Why ApertureX</a>
      <a href="#compare">Before &amp; After</a>
      <a href="#features">Studio Capabilities</a>
      <a href="#screens">Interactive Studio Tour</a>
      <a href="#pipeline">Zero-Copy Architecture</a>
      <a href="#changelog">Release Changelog</a>
      <a href="#developers">About Developers</a>
      <a
        href="https://github.com/prit-007/ApertureX/releases/latest"
        class="btn btn-primary"
        target="_blank"
        rel="noopener"
        @click="closeDrawer"
      >
        Download APK ({{ version }})
      </a>
    </nav>

    <main class="layout-main">
      <slot />
    </main>

    <footer>
      <div class="wrap">
        <div class="foot-row">
          <span class="foot-mark">
            <img :src="appIcon" alt="ApertureX icon" width="28" height="28" />
            APERTUREX
          </span>
          <div class="foot-links">
            <a href="https://github.com/prit-007/ApertureX" target="_blank" rel="noopener">GitHub</a>
            <a href="https://github.com/prit-007/ApertureX/releases" target="_blank" rel="noopener">Releases</a>
            <a href="https://github.com/prit-007/ApertureX/blob/main/docs/ROADMAP.md" target="_blank" rel="noopener">Roadmap</a>
            <a href="https://github.com/prit-007/ApertureX/blob/main/docs/PARITY.md" target="_blank" rel="noopener">Parity Ledger</a>
            <a href="https://github.com/prit-007/ApertureX/blob/main/CONTRIBUTING.md" target="_blank" rel="noopener">Contributing</a>
            <a href="https://github.com/prit-007/ApertureX/blob/main/THIRD_PARTY.md" target="_blank" rel="noopener">Third-Party</a>
            <a href="https://github.com/prit-007/ApertureX/blob/main/LICENSE" target="_blank" rel="noopener">GPL-3.0 License</a>
          </div>
        </div>
        <div class="foot-bottom">
          <div>&copy; 2026 Developer's Paradise &bull; Architected by Prit Vasani &bull; Released under the GNU General Public License v3.0</div>
          <div>Designed for creators &bull; 100% on-device &bull; Zero telemetry &bull; Free &amp; Open Source</div>
        </div>
      </div>
    </footer>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import AnnouncementBar from './AnnouncementBar.vue'
import appIcon from '../assets/app_icon.png'

const navRef = ref(null)
const scrolled = ref(false)
const drawerOpen = ref(false)
const activeNav = ref('compare')
const version = 'v0.3.9'

const appIconSrc = appIcon

function scrollToTop(e) {
  e.preventDefault()
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

function toggleDrawer() {
  drawerOpen.value = !drawerOpen.value
  document.body.classList.toggle('drawer-open', drawerOpen.value)
}

function closeDrawer() {
  drawerOpen.value = false
  document.body.classList.remove('drawer-open')
}

onMounted(() => {
  document.documentElement.classList.add('js')
  const handler = () => {
    scrolled.value = window.scrollY > 8
    updateActiveNav()
  }
  window.addEventListener('scroll', handler, { passive: true })
  window.addEventListener('resize', handler)
  handler()

  // Close drawer on escape
  const onEsc = (e) => {
    if (e.key === 'Escape' && drawerOpen.value) closeDrawer()
  }
  window.addEventListener('keydown', onEsc)
  onUnmounted(() => {
    window.removeEventListener('scroll', handler)
    window.removeEventListener('resize', handler)
    window.removeEventListener('keydown', onEsc)
  })
})

function updateActiveNav() {
  const sections = ['compare', 'features', 'screens', 'pipeline', 'changelog', 'developers']
  let found = 'compare'
  sections.forEach((id) => {
    const el = document.getElementById(id)
    if (el && el.getBoundingClientRect().top <= 140) {
      found = id
    }
  })
  activeNav.value = found
}
</script>

<style scoped>
.layout {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}
.layout-main {
  flex: 1;
}
</style>
