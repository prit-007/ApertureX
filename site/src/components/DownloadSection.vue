<template>
  <section id="download" class="download-section reveal">
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
            class="btn btn-primary"
            href="https://github.com/prit-007/ApertureX/releases/latest"
            target="_blank"
            rel="noopener"
          >
            <svg
              width="20"
              height="20"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2.5"
            >
              <path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" />
            </svg>
            <span>Download APK (v{{ version }})</span>
          </a>
          <a
            class="btn btn-ghost"
            href="https://github.com/prit-007/ApertureX/releases"
            target="_blank"
            rel="noopener"
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2M7 11l5 5 5-5M12 4v12" />
            </svg>
            All Release Assets
          </a>
        </div>

        <div class="version-badge-lg">
          Latest Release: <b>v{{ version }}</b> &bull; Signed Universal APK
        </div>

        <div class="arch-strip">
          <span>
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
            </svg>
            Android 8.0+ (ARM64, ARMv7, x86_64)
          </span>
          <span>
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <rect x="5" y="2" width="14" height="20" rx="2" />
              <path d="M12 18h.01" />
            </svg>
            iOS Support (Xcode Build)
          </span>
          <span>
            <svg
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <circle cx="12" cy="12" r="10" />
              <path d="m9 12 2 2 4-4" />
            </svg>
            GPL-3.0 Licensed FOSS
          </span>
        </div>

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
                  <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                  >
                    <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
                  </svg>
                  Android Universal
                </div>
                <span class="build-card-badge rec">Recommended</span>
              </div>
              <div class="build-card-name">app-release.apk</div>
              <div class="build-card-desc">
                All-in-one signed APK with bundled native binaries for ARM64,
                ARMv7, and x86_64 devices.
              </div>
            </div>
            <span class="build-card-action">
              Download Universal APK
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" />
              </svg>
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
                  <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                  >
                    <rect x="5" y="2" width="14" height="20" rx="2" />
                    <path d="M12 18h.01" />
                  </svg>
                  Android ARM64
                </div>
                <span class="build-card-badge">Leanest Size</span>
              </div>
              <div class="build-card-name">app-arm64-v8a-release.apk</div>
              <div class="build-card-desc">
                Optimized 64-bit ARM binary with the smallest download size
                for modern smartphones and tablets.
              </div>
            </div>
            <span class="build-card-action">
              Download ARM64 APK
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" />
              </svg>
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
                  <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                  >
                    <rect x="5" y="2" width="14" height="20" rx="2" />
                    <path d="M12 18h.01" />
                  </svg>
                  Android ARMv7
                </div>
                <span class="build-card-badge">Legacy 32-bit</span>
              </div>
              <div class="build-card-name">app-armeabi-v7a-release.apk</div>
              <div class="build-card-desc">
                32-bit ARM binary for older phones and budget devices.
              </div>
            </div>
            <span class="build-card-action">
              Download ARMv7 APK
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" />
              </svg>
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
                  <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                  >
                    <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
                  </svg>
                  Android x86_64
                </div>
                <span class="build-card-badge">Emulator</span>
              </div>
              <div class="build-card-name">app-x86_64-release.apk</div>
              <div class="build-card-desc">
                x86_64 binary for Android emulators and x86 tablets.
              </div>
            </div>
            <span class="build-card-action">
              Download x86_64 APK
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2.5"
              >
                <path d="M12 3v13m0 0-4-4m4 4 4-4M5 21h14" />
              </svg>
            </span>
          </a>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
const version = '0.3.7'
</script>

<style scoped>
.download-section {
  padding: 64px 0;
  background: var(--bg-darkest);
}

.download-box {
  padding: 40px;
  border-radius: var(--radius-xl);
  max-width: 720px;
  margin: 0 auto;
}

.section-head {
  text-align: center;
  margin-bottom: 32px;
}

.section-head .hud-tag {
  display: block;
  text-align: center;
  margin-bottom: 10px;
}

.section-head h2 {
  font-size: 1.75rem;
  margin: 0 0 10px 0;
}

.download-box > p {
  color: var(--text-muted);
  font-size: 1rem;
  margin-bottom: 24px;
  text-align: center;
}

.download-actions {
  display: flex;
  gap: 12px;
  justify-content: center;
  margin-bottom: 20px;
  flex-wrap: wrap;
}

.version-badge-lg {
  font-family: var(--mono);
  font-size: 0.85rem;
  color: var(--text-muted);
  text-align: center;
  margin-bottom: 28px;
}

.version-badge-lg b {
  color: var(--cyan);
}

.arch-strip {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  justify-content: center;
  margin-bottom: 32px;
  border-top: 1px solid var(--border-soft);
  border-bottom: 1px solid var(--border-soft);
  padding: 16px 0;
}

.arch-strip span {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 0.85rem;
  color: var(--text-muted);
}

.arch-strip svg {
  width: 16px;
  height: 16px;
  color: var(--cyan);
  flex-shrink: 0;
}

.builds-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
}

.build-card {
  display: block;
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius-l);
  padding: 20px;
  text-decoration: none;
  color: inherit;
  transition: all 0.2s;
}

.build-card:hover {
  border-color: var(--border-highlight);
  transform: translateY(-2px);
  background: var(--bg-card-hover);
}

.build-card-head {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
}

.build-card-platform {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--text);
}

.build-card-platform svg {
  width: 18px;
  height: 18px;
  color: var(--cyan);
  flex-shrink: 0;
}

.build-card-badge {
  margin-left: auto;
  font-family: var(--mono);
  font-size: 0.65rem;
  font-weight: 700;
  padding: 2px 8px;
  border-radius: 100px;
  background: rgba(0, 229, 255, 0.1);
  border: 1px solid rgba(0, 229, 255, 0.2);
  color: var(--cyan);
  text-transform: uppercase;
  letter-spacing: 0.06em;
}

.build-card-badge.rec {
  background: rgba(255, 42, 85, 0.1);
  border-color: rgba(255, 42, 85, 0.2);
  color: var(--coral-soft);
}

.build-card-name {
  font-family: var(--mono);
  font-size: 0.85rem;
  color: var(--text);
  margin-bottom: 6px;
}

.build-card-desc {
  font-size: 0.8rem;
  color: var(--text-muted);
  line-height: 1.5;
  margin-bottom: 16px;
}

.build-card-action {
  margin-top: auto;
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--cyan);
}

.build-card-action svg {
  width: 14px;
  height: 14px;
}

@media (max-width: 640px) {
  .download-box {
    padding: 24px;
  }
  .builds-grid {
    grid-template-columns: 1fr;
  }
  .download-actions {
    flex-direction: column;
    align-items: stretch;
  }
  .download-actions .btn {
    justify-content: center;
  }
}
</style>
