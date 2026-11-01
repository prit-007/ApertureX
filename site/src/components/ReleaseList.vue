<template>
  <section id="changelog">
    <div class="wrap">
      <div class="section-head center">
        <span class="hud-tag">CONTINUOUS EVOLUTION</span>
        <h2>Verified Release History</h2>
        <p>
          All release artifacts are generated transparently via GitHub Actions
          with cryptographically verified checksums.
        </p>
      </div>

      <div id="releasesContainer">
        <div v-if="loading" class="releases-loading">
          <div class="spinner"></div>
          <p style="text-align:center; font-size:0.85rem; color:var(--text-muted);">
            Fetching verified release notes from GitHub&hellip;
          </p>
        </div>
        <div v-else-if="error" class="release-error">
          <p style="text-align:center; color:var(--text-muted);">Unable to load releases. Showing cached fallback.</p>
          <button class="btn btn-primary" @click="fetchReleases">Retry</button>
        </div>
        <div v-else>
          <div v-for="(rel, i) in releases" :key="rel.tag_name" class="cl-entry">
            <details :open="i === 0">
              <summary class="cl-toggle">
                <span>{{ rel.tag_name }} &mdash; {{ formatDate(rel.published_at) }}</span>
                <span class="arrow">&#9662;</span>
              </summary>
              <div class="cl-body">
                <ul v-if="groupsAdded(i).length" class="cl-items cl-added">
                  <li v-for="(item, idx) in groupsAdded(i)" :key="idx" v-html="item"></li>
                </ul>
                <ul v-if="groupsChanged(i).length" class="cl-items cl-changed" style="margin-top:12px;">
                  <li v-for="(item, idx) in groupsChanged(i)" :key="idx" v-html="item"></li>
                </ul>
                <ul v-if="groupsFixed(i).length" class="cl-items cl-fixed" style="margin-top:12px;">
                  <li v-for="(item, idx) in groupsFixed(i)" :key="idx" v-html="item"></li>
                </ul>
              </div>
            </details>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref, onMounted } from 'vue'

const REPO = 'prit-007/ApertureX'
const API_URL = 'https://api.github.com/repos/' + REPO + '/releases?per_page=6'
const CACHE_KEY = 'aperturex_releases_v1'
const CACHE_TTL_MS = 10 * 60 * 1000

const releases = ref([])
const loading = ref(true)
const error = ref(null)

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }[char]))
}

function inlineMarkdown(text) {
  return escapeHtml(text)
    .replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/`([^`]+)`/g, '<code>$1</code>')
}

function parseBody(body) {
  const groups = { added: [], changed: [], fixed: [], notes: [], technical: [] }
  let section = 'added'
  let currentItem = ''

  const flushItem = () => {
    if (!currentItem) return
    groups[section].push('<li>' + inlineMarkdown(currentItem) + '</li>')
    currentItem = ''
  }

  body.split('\n').forEach((line) => {
    const t = line.trim()
    if (!t) {
      flushItem()
      return
    }
    if (t.startsWith('### ')) {
      flushItem()
      const heading = t.slice(4).toLowerCase()
      if (heading.includes('fixed')) section = 'fixed'
      else if (heading.includes('changed')) section = 'changed'
      else if (heading.includes('added')) section = 'added'
      else if (heading.includes('technical')) section = 'technical'
      else section = 'notes'
      return
    }
    if (t.startsWith('## ') || t.startsWith('#')) {
      flushItem()
      return
    }
    if (t.startsWith('- ') || t.startsWith('* ')) {
      flushItem()
      currentItem = t.slice(2)
      return
    }
    if (currentItem) currentItem += ' ' + t
  })
  flushItem()

  let html = ''
  if (groups.added.length) html += '<ul class="cl-items cl-added">' + groups.added.join('') + '</ul>'
  if (groups.changed.length) html += '<ul class="cl-items cl-changed" style="margin-top:12px;">' + groups.changed.join('') + '</ul>'
  if (groups.fixed.length) html += '<ul class="cl-items cl-fixed" style="margin-top:12px;">' + groups.fixed.join('') + '</ul>'
  if (groups.technical.length) html += '<ul class="cl-items cl-notes" style="margin-top:12px;">' + groups.technical.join('') + '</ul>'
  if (groups.notes.length) html += '<ul class="cl-items cl-notes" style="margin-top:12px;">' + groups.notes.join('') + '</ul>'
  return html
}

const groupsAdded = (i) => parseItems(i, 'added')
const groupsChanged = (i) => parseItems(i, 'changed')
const groupsFixed = (i) => parseItems(i, 'fixed')

function parseItems(i, section) {
  const rel = releases.value[i]
  if (!rel) return []
  const body = rel.body || ''
  const groups = { added: [], changed: [], fixed: [], notes: [], technical: [] }
  let sec = 'added'
  let cur = ''
  const flush = () => {
    if (!cur) return
    groups[sec].push('<li>' + inlineMarkdown(cur) + '</li>')
    cur = ''
  }
  body.split('\n').forEach((line) => {
    const t = line.trim()
    if (!t) { flush(); return }
    if (t.startsWith('### ')) {
      flush()
      const h = t.slice(4).toLowerCase()
      if (h.includes('fixed')) sec = 'fixed'
      else if (h.includes('changed')) sec = 'changed'
      else if (h.includes('added')) sec = 'added'
      else if (h.includes('technical')) sec = 'technical'
      else sec = 'notes'
      return
    }
    if (t.startsWith('## ') || t.startsWith('#')) { flush(); return }
    if (t.startsWith('- ') || t.startsWith('* ')) { flush(); cur = t.slice(2); return }
    if (cur) cur += ' ' + t
  })
  flush()
  return groups[section]
}

function formatDate(iso) {
  if (!iso) return ''
  return new Date(iso).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
}

function readCache() {
  try {
    const cached = JSON.parse(sessionStorage.getItem(CACHE_KEY))
    if (cached && Array.isArray(cached.releases) && Date.now() - cached.savedAt < CACHE_TTL_MS) {
      return cached.releases
    }
  } catch (_) {}
  return null
}

function writeCache(rels) {
  try {
    sessionStorage.setItem(CACHE_KEY, JSON.stringify({ savedAt: Date.now(), releases: rels }))
  } catch (_) {}
}

async function fetchReleases() {
  loading.value = true
  error.value = null
  const cached = readCache()
  if (cached && cached.length) {
    releases.value = cached
    loading.value = false
    return
  }
  try {
    const resp = await fetch(API_URL, { headers: { 'Accept': 'application/vnd.github.v3+json' } })
    if (!resp.ok) throw new Error('API error ' + resp.status)
    const data = await resp.json()
    if (!data.length) throw new Error('No releases')
    releases.value = data
    writeCache(data)
  } catch (_) {
    error.value = true
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchReleases()
})
</script>

<style scoped>
#releasesContainer {
  max-width: 860px;
  margin: 0 auto;
}
.cl-entry {
  background: var(--bg-1);
  border: 1px solid var(--border);
  border-radius: var(--radius-m);
  margin-bottom: 16px;
  overflow: hidden;
}
.cl-toggle {
  padding: 18px 24px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-family: var(--display);
  font-weight: 700;
  font-size: 1.05rem;
  cursor: pointer;
  background: rgba(255, 255, 255, 0.02);
}
.cl-toggle:hover {
  background: rgba(255, 255, 255, 0.05);
}
.cl-body {
  padding: 20px 24px 24px 24px;
  border-top: 1px solid var(--border-soft);
}
.cl-items li {
  position: relative;
  padding-left: 20px;
  margin-bottom: 8px;
  font-size: 0.9rem;
  color: var(--text-muted);
  line-height: 1.55;
}
.cl-items li::before {
  content: '•';
  position: absolute;
  left: 4px;
  color: var(--cyan);
  font-weight: 800;
}
.cl-items strong {
  color: var(--text);
}
.cl-items code {
  font-family: var(--mono);
  font-size: 0.88em;
  color: var(--cyan);
  background: rgba(0, 229, 255, 0.08);
  padding: 1px 4px;
  border-radius: 4px;
}
.cl-items a {
  color: var(--cyan);
  text-decoration: underline;
}
.spinner {
  width: 24px;
  height: 24px;
  border: 3px solid rgba(0, 229, 255, 0.2);
  border-top-color: var(--cyan);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  margin: 20px auto;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}
.releases-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 40px 0;
}
.release-error {
  padding: 40px 0;
  text-align: center;
}
</style>
