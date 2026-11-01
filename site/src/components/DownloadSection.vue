<template>
  <section id="download">
    <div class="wrap">
      <div class="download-box glass-card">
        <span class="hud-tag">READY FOR STUDIO-GRADE EDITING</span>
        <h2>Download ApertureX Today</h2>
        <p>
          Sideload the universal signed APK directly for Android devices or
          compile from source for iOS and desktop.
        </p>

        <div class="download-actions">
          <a
            :href="dlUrl"
            class="btn btn-primary"
            target="_blank"
            rel="noopener"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
              <path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" />
            </svg>
            <span>Download APK ({{ version }})</span>
          </a>
          <a
            href="https://github.com/prit-007/ApertureX/releases"
            class="btn btn-ghost"
            target="_blank"
            rel="noopener"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2M7 11l5 5 5-5M12 4v12" />
            </svg>
            All Release Assets
          </a>
        </div>

        <div class="version-badge-lg">
          Latest Release: <b>{{ version }}</b> &bull; Signed Universal APK
        </div>

        <div class="arch-strip">
          <span>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
            </svg>
            Android 8.0+ (ARM64, ARMv7, x86_64)
          </span>
          <span>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="5" y="2" width="14" height="20" rx="2" />
              <path d="M12 18h.01" />
            </svg>
            iOS Support (Xcode Build)
          </span>
          <span>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10" />
              <path d="m9 12 2 2 4-4" />
            </svg>
            GPL-3.0 Licensed FOSS
          </span>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
const version = 'v0.3.7'
const dlUrl = 'https://github.com/prit-007/ApertureX/releases/latest/download/app-release.apk'
</script>

<style scoped>
.download-section {
  padding: 100px 0;
  background: var(--bg-darkest);
}
.download-box {
  padding: 60px 40px;
  text-align: center;
  max-width: 900px;
  margin: 0 auto;
  border-radius: var(--radius-xl);
  position: relative;
  overflow: hidden;
}
.download-box::before {
  content: '';
  position: absolute;
  top: -50%;
  left: 50%;
  transform: translateX(-50%);
  width: 600px;
  height: 300px;
  background: radial-gradient(ellipse at center, rgba(0, 229, 255, 0.2), transparent 70%);
  filter: blur(50px);
  pointer-events: none;
}
.download-box h2 {
  font-size: clamp(2.2rem, 4vw, 3.2rem);
  margin-top: 14px;
  margin-bottom: 12px;
}
.download-box p {
  color: var(--text-muted);
  font-size: 1.1rem;
  max-width: 620px;
  margin: 0 auto 34px auto;
}
.download-actions {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  flex-wrap: wrap;
  margin-bottom: 24px;
}
.version-badge-lg {
  display: inline-block;
  font-family: var(--mono);
  font-size: 0.84rem;
  color: var(--cyan);
  background: rgba(0, 229, 255, 0.1);
  border: 1px solid rgba(0, 229, 255, 0.25);
  padding: 6px 16px;
  border-radius: 100px;
}
.arch-strip {
  display: flex;
  justify-content: center;
  gap: 24px;
  flex-wrap: wrap;
  margin-top: 28px;
  font-size: 0.82rem;
  color: var(--text-muted);
}
.arch-strip span {
  display: flex;
  align-items: center;
  gap: 8px;
}
.arch-strip svg {
  width: 16px;
  height: 16px;
  color: var(--cyan);
}
</style>
