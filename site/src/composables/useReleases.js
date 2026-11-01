import { ref, reactive } from 'vue'

const GITHUB_REPO = 'prit-007/ApertureX'
const API_URL = `https://api.github.com/repos/${GITHUB_REPO}/releases`
const CACHE_KEY = 'aperturex_releases_cache'
const CACHE_TTL = 60 * 60 * 1000 // 1 hour

export function useReleases() {
  const releases = ref([])
  const loading = ref(false)
  const error = ref(null)
  const latest = ref(null)

  function cacheValid(cached) {
    if (!cached || !cached.timestamp || !cached.data) return false
    return Date.now() - cached.timestamp < CACHE_TTL
  }

  function writeCache(data) {
    try {
      localStorage.setItem(
        CACHE_KEY,
        JSON.stringify({ timestamp: Date.now(), data })
      )
    } catch (_) {
      // ignore quota errors
    }
  }

  function readCache() {
    try {
      const raw = localStorage.getItem(CACHE_KEY)
      return raw ? JSON.parse(raw) : null
    } catch (_) {
      return null
    }
  }

  function applyLatest(list) {
    latest.value = list.find((r) => !r.draft && !r.prerelease) || list[0] || null
  }

  async function fetchReleases() {
    if (loading.value) return
    loading.value = true
    error.value = null

    const cached = readCache()
    if (cacheValid(cached)) {
      releases.value = cached.data
      applyLatest(releases.value)
      loading.value = false
      return
    }

    try {
      const res = await fetch(API_URL, {
        headers: { Accept: 'application/vnd.github+json' },
      })
      if (!res.ok) throw new Error(`GitHub API: ${res.status}`)
      const data = await res.json()
      releases.value = data
      applyLatest(data)
      writeCache(data)
    } catch (err) {
      error.value = err
      const fallback = readCache()
      if (fallback && fallback.data) {
        releases.value = fallback.data
        applyLatest(releases.value)
      }
    } finally {
      loading.value = false
    }
  }

  return {
    releases,
    loading,
    error,
    latest,
    fetchReleases,
  }
}
