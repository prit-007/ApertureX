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

        <!-- Release Builds Grid -->
        <div class="builds-grid">
          <a
            class="build-card"
            href="https://github.com/prit-007/ApertureX/releases/latest/download/app-release.apk"
            target="_blank"
            rel="noopener"
          >
            <div>
              <div class="build-card-head">
                <div class="build-card-platform">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" /></svg>
                  Android Universal
                </div>
                <span class="build-card-badge rec">Recommended</span>
              </div>
              <div class="build-card-name">app-release.apk</div>
              <div class="build-card-desc">All-in-one signed APK with bundled native binaries for ARM64, ARMv7, and x86_64 devices.</div>
            </div>
            <span class="build-card-action">
              Download Universal APK
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" /></svg>
            </span>
          </a>

          <a
            class="build-card"
            href="https://github.com/prit-007/ApertureX/releases/latest/download/app-arm64-v8a-release.apk"
            target="_blank"
            rel="noopener"
          >
            <div>
              <div class="build-card-head">
                <div class="build-card-platform">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2" /><path d="M12 18h.01" /></svg>
                  Android ARM64
                </div>
                <span class="build-card-badge">Leanest Size</span>
              </div>
              <div class="build-card-name">app-arm64-v8a-release.apk</div>
              <div class="build-card-desc">Optimized 64-bit ARM binary with the smallest download size for modern smartphones and tablets.</div>
            </div>
            <span class="build-card-action">
              Download ARM64 APK
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" /></svg>
            </span>
          </a>

          <a
            class="build-card"
            href="https://github.com/prit-007/ApertureX/releases/latest/download/app-armeabi-v7a-release.apk"
            target="_blank"
            rel="noopener"
          >
            <div>
              <div class="build-card-head">
                <div class="build-card-platform">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2" /><path d="M12 18h.01" /></svg>
                  Android ARMv7
                </div>
                <span class="build-card-badge">Legacy 32-bit</span>
              </div>
              <div class="build-card-name">app-armeabi-v7a-release.apk</div>
              <div class="build-card-desc">Compatible package targeting older 32-bit ARM hardware and lightweight budget devices.</div>
            </div>
            <span class="build-card-action">
              Download ARMv7 APK
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" /></svg>
            </span>
          </a>

          <a
            class="build-card"
            href="https://github.com/prit-007/ApertureX/releases/latest/download/app-x86_64-release.apk"
            target="_blank"
            rel="noopener"
          >
            <div>
              <div class="build-card-head">
                <div class="build-card-platform">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="3" width="20" height="14" rx="2" /><line x1="8" y1="21" x2="16" y2="21" /><line x1="12" y1="17" x2="12" y2="21" /></svg>
                  Android x86_64
                </div>
                <span class="build-card-badge">Emulators &amp; OS</span>
              </div>
              <div class="build-card-name">app-x86_64-release.apk</div>
              <div class="build-card-desc">Compiled for Intel/AMD Chromebooks and desktop Android virtual device emulators.</div>
            </div>
            <span class="build-card-action">
              Download x86_64 APK
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" /></svg>
            </span>
          </a>

          <a
            class="build-card"
            href="https://github.com/prit-007/ApertureX/releases/latest"
            target="_blank"
            rel="noopener"
          >
            <div>
              <div class="build-card-head">
                <div class="build-card-platform">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="8" height="8" /><rect x="13" y="3" width="8" height="8" /><rect x="3" y="13" width="8" height="8" /><rect x="13" y="13" width="8" height="8" /></svg>
                  Windows Desktop
                </div>
                <span class="build-card-badge">Win 10/11 x64</span>
              </div>
              <div class="build-card-name">aperturex-windows-x64.zip</div>
              <div class="build-card-desc">Portable Windows archive with native keyboard bindings, multi-core SIMD engine, and MenuBar.</div>
            </div>
            <span class="build-card-action">
              Download Windows Package
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" /></svg>
            </span>
          </a>

          <a
            class="build-card"
            href="https://github.com/prit-007/ApertureX/releases/latest"
            target="_blank"
            rel="noopener"
          >
            <div>
              <div class="build-card-head">
                <div class="build-card-platform">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10" /><path d="M12 6v6l4 2" /></svg>
                  macOS Universal
                </div>
                <span class="build-card-badge">M1–M4 &amp; Intel</span>
              </div>
              <div class="build-card-name">aperturex-macos-universal.zip</div>
              <div class="build-card-desc">Standalone universal application bundle optimized for Apple Silicon neural accelerators.</div>
            </div>
            <span class="build-card-action">
              Download macOS Bundle
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" /></svg>
            </span>
          </a>

          <a
            class="build-card"
            href="https://github.com/prit-007/ApertureX/releases/latest"
            target="_blank"
            rel="noopener"
          >
            <div>
              <div class="build-card-head">
                <div class="build-card-platform">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2M7 11l5 5 5-5M12 4v12" /></svg>
                  Linux x86_64
                </div>
                <span class="build-card-badge">GTK3 Tarball</span>
              </div>
              <div class="build-card-name">aperturex-linux-x64.tar.gz</div>
              <div class="build-card-desc">Self-contained GTK3 Linux release bundle with embedded librust_lib_aperturex.so engine.</div>
            </div>
            <span class="build-card-action">
              Download Linux Tarball
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" /></svg>
            </span>
          </a>

          <a
            class="build-card"
            href="https://github.com/prit-007/ApertureX/releases/latest"
            target="_blank"
            rel="noopener"
          >
            <div>
              <div class="build-card-head">
                <div class="build-card-platform">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2" /><path d="M12 18h.01" /></svg>
                  iOS Sideload
                </div>
                <span class="build-card-badge">AltStore / TrollStore</span>
              </div>
              <div class="build-card-name">aperturex-ios-release.zip</div>
              <div class="build-card-desc">Pre-packaged iOS payload archive for sideloading on iPhone and iPad without an App Store account.</div>
            </div>
            <span class="build-card-action">
              Download iOS Archive
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" /></svg>
            </span>
          </a>

          <a
            class="build-card"
            :href="`https://github.com/prit-007/ApertureX/archive/refs/tags/${version}.tar.gz`"
            target="_blank"
            rel="noopener"
          >
            <div>
              <div class="build-card-head">
                <div class="build-card-platform">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10" /><path d="m9 12 2 2 4-4" /></svg>
                  Source &amp; C2PA
                </div>
                <span class="build-card-badge">GPL-3.0 / Git</span>
              </div>
              <div class="build-card-name">Source code ({{ version }}.tar.gz)</div>
              <div class="build-card-desc">Full 100% auditable source code with zero analytics, verifiable SHA-256 sums, and build scripts.</div>
            </div>
            <span class="build-card-action">
              Download Source Archive
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" /></svg>
            </span>
          </a>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
const version = 'v0.3.9'
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
