<template>
  <div class="mq" aria-hidden="true">
    <div id="mq"></div>
  </div>
</template>

<script setup>
import { onMounted } from 'vue'

const items = [
  'Non-destructive',
  '100% offline',
  'RAW ready',
  'Open source',
  'Look QR',
  '200 MP tiles',
  'C2PA signed',
  'No accounts',
  'DNG export',
  'USB tethering',
  '6 languages',
]

onMounted(() => {
  const el = document.getElementById('mq')
  if (el) {
    const html = items.map((t) => `<span>${t}</span>`).join('')
    el.innerHTML = html + html
  }
})
</script>

<style scoped>
.mq {
  background: linear-gradient(90deg, #00E5FF, #0099FF);
  color: #040810;
  overflow: hidden;
  white-space: nowrap;
  padding: 15px 0;
  transform: rotate(-1.2deg);
  margin: -14px -20px 0;
  position: relative;
  z-index: 7;
  will-change: transform;
}
.mq div {
  display: inline-flex;
  gap: 44px;
  animation: mq 30s linear infinite;
  font: 800 1.4rem var(--mono);
}
.mq span::after {
  content: '\2736';
  margin-left: 44px;
}
@keyframes mq {
  to {
    transform: translateX(-50%);
  }
}
@media (prefers-reduced-motion: reduce) {
  .mq div {
    animation: none;
    display: flex;
    gap: 20px;
    justify-content: center;
  }
}
</style>
