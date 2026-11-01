<template>
  <div class="layout">
    <header class="site-header" ref="header">
      <div class="wrap header-inner">
        <a href="/" class="brand" aria-label="ApertureX home">
          <img
            :src="logoSrc"
            alt="ApertureX"
            class="brand-img"
            width="32"
            height="32"
          />
          <span class="brand-text">ApertureX</span>
        </a>

        <nav class="nav" aria-label="Main navigation">
          <a href="#features">Features</a>
          <a href="#presets">Presets</a>
          <a href="#plugins">AI Plugins</a>
          <a href="#download">Download</a>
          <a href="#about">About</a>
        </nav>

        <div class="header-actions">
          <button class="btn btn-outline" @click="toggleDrawer">
            <span class="sr-only">Menu</span>
            <svg
              class="menu-icon"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <line x1="3" y1="12" x2="21" y2="12"></line>
              <line x1="3" y1="6" x2="21" y2="6"></line>
              <line x1="3" y1="18" x2="21" y2="18"></line>
            </svg>
          </button>
        </div>
      </div>
    </header>

    <aside
      v-if="drawerOpen"
      class="drawer-overlay"
      @click.self="drawerOpen = false"
    >
      <div class="drawer-panel">
        <button class="drawer-close" @click="drawerOpen = false">
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
          <span class="sr-only">Close menu</span>
        </button>
        <nav class="drawer-nav" aria-label="Mobile navigation">
          <a href="#features" @click="drawerOpen = false">Features</a>
          <a href="#presets" @click="drawerOpen = false">Presets</a>
          <a href="#plugins" @click="drawerOpen = false">AI Plugins</a>
          <a href="#download" @click="drawerOpen = false">Download</a>
          <a href="#about" @click="drawerOpen = false">About</a>
        </nav>
        <div class="drawer-version">
          <span class="hud-tag">v{{ version }}</span>
        </div>
      </div>
    </aside>

    <main class="layout-main">
      <slot />
    </main>

    <footer class="site-footer">
      <div class="wrap footer-inner">
        <div class="footer-brand">
          <img
            :src="logoSrc"
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
import { ref } from 'vue'

const drawerOpen = ref(false)
const version = '0.3.7'

function toggleDrawer() {
  drawerOpen.value = !drawerOpen.value
}

const logoSrc = '/assets/app_icon.png'
</script>

<style scoped>
.layout {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

.site-header {
  position: sticky;
  top: 0;
  z-index: 50;
  background: rgba(8, 11, 17, 0.6);
  backdrop-filter: blur(12px);
  border-bottom: 1px solid var(--border);
}

.header-inner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 64px;
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  font-family: var(--display);
  font-weight: 800;
  font-size: 1.25rem;
  color: var(--text);
}

.brand-img {
  border-radius: var(--radius-s);
}

.brand-text {
  letter-spacing: -0.02em;
}

.nav {
  display: flex;
  gap: 26px;
  align-items: center;
}

.nav a {
  color: var(--text-muted);
  font-size: 0.9rem;
  font-weight: 500;
  transition: color 0.2s;
}

.nav a:hover {
  color: var(--cyan);
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.btn-outline {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 8px 14px;
  border: 1px solid var(--border);
  border-radius: var(--radius-m);
  background: var(--glass);
  color: var(--text);
  font-size: 0.85rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-outline:hover {
  border-color: var(--cyan);
  background: var(--glass-hover);
}

.menu-icon {
  display: block;
}

.drawer-overlay {
  position: fixed;
  inset: 0;
  background: rgba(6, 8, 13, 0.6);
  backdrop-filter: blur(8px);
  z-index: 60;
}

.drawer-panel {
  position: absolute;
  top: 0;
  right: 0;
  width: min(320px, 85vw);
  height: 100vh;
  background: var(--bg-2);
  border-left: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  transform: translateX(100%);
  transition: transform 0.3s ease;
}

.drawer-overlay[class*="overlay"] .drawer-panel,
.drawer-panel {
  transform: translateX(0);
}

.drawer-close {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  background: transparent;
  border: none;
  color: var(--text-muted);
  cursor: pointer;
  margin: 16px;
}

.drawer-close svg {
  width: 22px;
  height: 22px;
}

.drawer-nav {
  display: flex;
  flex-direction: column;
  gap: 0;
  margin-top: 8px;
  padding: 0 20px;
}

.drawer-nav a {
  display: block;
  padding: 14px 16px;
  color: var(--text-muted);
  border-bottom: 1px solid var(--border-soft);
  font-size: 0.95rem;
}

.drawer-nav a:hover {
  color: var(--cyan);
  background: var(--glass);
}

.drawer-version {
  margin: auto 20px 24px 20px;
  font-family: var(--mono);
  font-size: 0.75rem;
  color: var(--text-faint);
}

.layout-main {
  flex: 1;
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

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  border: 0;
  white-space: nowrap;
}

@media (max-width: 640px) {
  .nav {
    display: none;
  }
}
</style>
