<template>
  <div class="marquee" aria-hidden="true">
    <div class="mq-track">
      <span v-for="(t, i) in items" :key="i">{{ t }}</span>
      <span v-for="(t, i) in items" :key="`dup-${i}`">{{ t }}</span>
    </div>
  </div>
</template>

<script setup>
const items = [
  'Non-destructive',
  '100% offline',
  'RAW ready',
  'Open source',
  'Look QR',
  '200 MP tiles',
  'C2PA signed',
  'No trackers',
]
</script>

<style scoped>
.marquee {
  overflow: hidden;
  padding: 12px 0;
  background: var(--bg-darkest);
  border-top: 1px solid var(--border-soft);
  border-bottom: 1px solid var(--border-soft);
}

.mq-track {
  display: flex;
  gap: 40px;
  will-change: transform;
  animation: scroll 20s linear infinite;
}

.mq-track span {
  font-family: var(--mono);
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--text-muted);
  letter-spacing: 0.08em;
  text-transform: uppercase;
  white-space: nowrap;
}

@keyframes scroll {
  from { transform: translatex(0); }
  to { transform: translatex(-50%); }
}

@media (prefers-reduced-motion: reduce) {
  .mq-track {
    animation: none;
    display: flex;
    gap: 20px;
    justify-content: center;
  }
}
</style>
