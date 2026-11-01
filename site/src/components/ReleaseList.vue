<template>
  <section id="releases" class="releases-section reveal">
    <div class="wrap">
      <div class="section-head">
        <h2>Releases</h2>
        <p class="section-desc">
          Latest builds for Android, iOS, Windows, macOS, and Linux.
          <span class="hud-tag">GPL-3.0</span>
        </p>
      </div>

      <div v-if="loading" class="release-loading">
        <p>Loading releases&hellip;</p>
      </div>

      <div v-else-if="error" class="release-error">
        <p>Unable to load releases.</p>
        <button class="btn" @click="fetchReleases">Retry</button>
      </div>

      <div v-else class="release-grid">
        <!-- Latest release card -->
        <article v-if="latest" class="release-card release-card--latest">
          <div class="release-badge">Latest</div>
          <div class="release-meta">
            <span class="release-tag">v{{ latest.tag_name }}</span>
            <time class="release-date">{{ formattedDate(latest.published_at) }}</time>
          </div>
          <h3 class="release-title">{{ latest.name || latest.tag_name }}</h3>
          <div class="release-desc" v-html="latest.body"></div>
          <div class="release-assets">
            <a
              v-for="asset in latest.assets"
              :key="asset.id"
              :href="asset.browser_download_url"
              class="asset-link"
              target="_blank"
              rel="noopener"
            >
              <span class="asset-icon">⬇</span>
              {{ asset.name }}
              <span class="asset-size">{{ formatSize(asset.size) }}</span>
            </a>
          </div>
          <a
            :href="latest.html_url"
            class="btn"
            target="_blank"
            rel="noopener"
          >
            View on GitHub
          </a>
        </article>

        <!-- Older releases -->
        <div v-if="older.length > 0" class="release-list">
          <h4 class="release-subhead">Previous releases</h4>
          <ul class="release-list-items">
            <li
              v-for="r in older"
              :key="r.id"
              class="release-item"
            >
              <span class="release-item-tag">v{{ r.tag_name }}</span>
              <span class="release-item-date">{{ formattedDate(r.published_at) }}</span>
              <a
                :href="r.html_url"
                class="release-item-link"
                target="_blank"
                rel="noopener"
              >
                View assets
              </a>
            </li>
          </ul>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { computed } from 'vue'
import { useReleases } from '../composables/useReleases.js'

const { releases, loading, error, latest, fetchReleases } = useReleases()

const older = computed(() => releases.value.filter((r) => r !== latest.value))

function formattedDate(iso) {
  if (!iso) return ''
  return new Date(iso).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
}

function formatSize(bytes) {
  if (!bytes) return ''
  const units = ['B', 'KB', 'MB', 'GB']
  let size = bytes
  let i = 0
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024
    i++
  }
  return size.toFixed(1) + ' ' + units[i]
}
</script>

<style scoped>
.releases-section {
  padding: 64px 0;
  background: var(--bg-1);
}

.section-head {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 40px;
}

.section-head h2 {
  font-size: 1.75rem;
  margin: 0;
}

.section-desc {
  color: var(--text-muted);
  font-size: 0.95rem;
}

.release-loading,
.release-error {
  display: flex;
  justify-content: center;
  padding: 48px 0;
  color: var(--text-muted);
}

.release-error button {
  margin-left: 12px;
}

.release-grid {
  display: grid;
  gap: 24px;
}

.release-card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius-xl);
  padding: 32px;
  position: relative;
  overflow: hidden;
}

.release-card--latest {
  background: var(--bg-2);
  border-color: var(--border-highlight);
}

.release-badge {
  position: absolute;
  top: 24px;
  left: 24px;
  font-family: var(--mono);
  font-size: 0.7rem;
  font-weight: 700;
  color: var(--cyan);
  background: rgba(0, 229, 255, 0.1);
  border: 1px solid rgba(0, 229, 255, 0.2);
  padding: 4px 10px;
  border-radius: 100px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.release-meta {
  display: flex;
  align-items: baseline;
  gap: 10px;
  margin-bottom: 12px;
}

.release-tag {
  font-family: var(--display);
  font-weight: 800;
  font-size: 1.1rem;
  color: var(--cyan);
  letter-spacing: -0.01em;
}

.release-date {
  font-family: var(--mono);
  font-size: 0.8rem;
  color: var(--text-faint);
}

.release-title {
  font-size: 1.25rem;
  margin: 0 0 16px 0;
  color: var(--text);
}

.release-desc {
  color: var(--text-muted);
  font-size: 0.9rem;
  line-height: 1.6;
  margin-bottom: 20px;
}

.release-assets {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.asset-link {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  background: var(--glass);
  border: 1px solid var(--border);
  border-radius: var(--radius-m);
  color: var(--text);
  font-size: 0.9rem;
  transition: all 0.2s;
}

.asset-link:hover {
  border-color: var(--cyan);
  background: var(--glass-hover);
  color: var(--cyan);
}

.asset-icon {
  font-size: 1.1rem;
  opacity: 0.7;
}

.asset-size {
  margin-left: auto;
  font-family: var(--mono);
  font-size: 0.8rem;
  color: var(--text-faint);
}

.release-subhead {
  font-family: var(--display);
  font-size: 1rem;
  color: var(--text-muted);
  margin-bottom: 12px;
}

.release-list-items {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.release-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 14px;
  background: var(--glass);
  border: 1px solid var(--border-soft);
  border-radius: var(--radius-m);
}

.release-item-tag {
  font-family: var(--mono);
  font-weight: 700;
  color: var(--cyan);
}

.release-item-date {
  font-family: var(--mono);
  font-size: 0.8rem;
  color: var(--text-faint);
}

.release-item-link {
  font-size: 0.85rem;
  color: var(--text-muted);
}

.release-item-link:hover {
  color: var(--cyan);
  text-decoration: underline;
}

@media (max-width: 640px) {
  .release-card {
    padding: 24px;
  }
  .release-grid {
    gap: 16px;
  }
}
</style>
