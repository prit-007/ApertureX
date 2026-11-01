<template>
  <div class="hero-specs">
    <div class="wrap">
      <div class="specs-grid">
        <div class="spec-chip">
          <span class="spec-label">Non-destructive</span>
          <span class="spec-value">0 ms recipe sync</span>
        </div>
        <div class="spec-chip">
          <span class="spec-label">100% offline</span>
          <span class="spec-value">zero cloud, zero subscriptions</span>
        </div>
        <div class="spec-chip">
          <span class="spec-label">RAW ready</span>
          <span class="spec-value">TurboJPEG & LibRaw demosaic</span>
        </div>
        <div class="spec-chip">
          <span class="spec-label">Open source</span>
          <span class="spec-value">GPL-3.0 FOSS</span>
        </div>
        <div class="spec-chip">
          <span class="spec-label">Look QR</span>
          <span class="spec-value">open preset standard</span>
        </div>
        <div class="spec-chip">
          <span class="spec-label">200 MP tiles</span>
          <span class="spec-value">512 MB LRU cache</span>
        </div>
        <div class="spec-chip">
          <span class="spec-label">C2PA signed</span>
          <span class="spec-value">on-device provenance</span>
        </div>
        <div class="spec-chip">
          <span class="spec-label">No trackers</span>
          <span class="spec-value">0 analytics SDKs</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
</script>

<style scoped>
.hero-specs {
  padding: 32px 0;
  background: var(--bg-1);
  border-top: 1px solid var(--border-soft);
  border-bottom: 1px solid var(--border-soft);
}

.specs-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  justify-content: center;
}

.spec-chip {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 10px 16px;
  border-radius: var(--radius-m);
  background: var(--glass);
  border: 1px solid var(--border);
  min-width: 150px;
}

.spec-label {
  font-family: var(--mono);
  font-size: 0.68rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--cyan);
}

.spec-value {
  font-size: 0.85rem;
  color: var(--text-muted);
  line-height: 1.4;
}

@media (max-width: 640px) {
  .spec-chip {
    min-width: 140px;
    padding: 8px 12px;
  }
}
</style>
