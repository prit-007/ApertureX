<template>
  <section id="pipeline" class="pipeline-section">
    <div class="wrap">
      <div class="section-head center">
        <span class="hud-tag">ZERO-COPY COMPILATION</span>
        <h2>Under the hood: Pure Rust Core &amp; Flutter Viewport</h2>
        <p>
          Decoded image data lives resident in Rust native heap memory. Edits
          manipulate a lightweight Dart recipe object with 0ms sync latency.
        </p>
      </div>

      <div class="flow-track">
        <div v-for="(step, i) in steps" :key="step.id" class="flow-step">
          <span class="num">{{ step.num }}</span>
          <h4>{{ step.title }}</h4>
          <p v-html="step.desc"></p>
          <div v-if="i < steps.length - 1" class="flow-connector">&rarr;</div>
        </div>
      </div>

      <div class="trust-row">
        <div v-for="(t, i) in trust" :key="i" class="trust-card glass-card">
          <b :style="{ color: t.color }">{{ t.label }}</b>
          <span>{{ t.desc }}</span>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
const steps = [
  {
    id: 'ingest',
    num: '01 // INGEST',
    title: 'Native Decode',
    desc: 'TurboJPEG &amp; LibRaw demosaic to native resident heap; EXIF &amp; GDepth extraction.',
  },
  {
    id: 'translate',
    num: '02 // TRANSLATE',
    title: 'Universal Translation',
    desc: 'Ingest/export Adobe XMP, 3D .cube LUTs, HALD CLUTs, and Look QR open standard.',
  },
  {
    id: 'viewport',
    num: '03 // VIEWPORT',
    title: '120 FPS Impeller',
    desc: '65³ 3D LUT atlas baked in &lt;1ms; live Wiper split curtain A/B compare.',
  },
  {
    id: 'scanner',
    num: '04 // SCANNER',
    title: 'Rust rxing Scanner',
    desc: 'Pure-Rust ZXing barcode detection over camera YUV/RGBA frames with 0 Google blobs.',
  },
  {
    id: 'provenance',
    num: '05 // PROVENANCE',
    title: 'Banded &amp; C2PA',
    desc: 'Full-res streaming export with C2PA Content Credentials manifests &amp; watermark branding.',
  },
]

const trust = [
  { label: '100% Offline', desc: 'Guarded by CI test against any networking code.', color: 'var(--cyan)' },
  { label: '0 Analytics', desc: 'Zero trackers, no analytics SDKs, no device identifiers.', color: 'var(--coral-soft)' },
  { label: 'GPL-3.0 FOSS', desc: 'Free and open source forever. Auditable code.', color: 'var(--amber)' },
  { label: 'F-Droid Clean', desc: 'Zero Google Play Services or closed vendor blobs.', color: 'var(--emerald)' },
]
</script>

<style scoped>
.pipeline-section {
  padding: 100px 0;
  background: var(--bg-darkest);
}
.section-head.center {
  text-align: center;
  margin-bottom: 52px;
}
.flow-track {
  display: flex;
  align-items: stretch;
  justify-content: space-between;
  gap: 12px;
  margin-top: 48px;
  overflow-x: auto;
  padding-bottom: 12px;
}
.flow-step {
  flex: 1;
  min-width: 190px;
  padding: 24px;
  background: var(--bg-1);
  border: 1px solid var(--border);
  border-radius: var(--radius-m);
  position: relative;
}
.flow-step .num {
  font-family: var(--mono);
  font-size: 0.72rem;
  color: var(--cyan);
  font-weight: 700;
  display: block;
  margin-bottom: 8px;
}
.flow-step h4 {
  font-size: 1.08rem;
  color: var(--text);
  margin-bottom: 8px;
}
.flow-step p {
  font-size: 0.85rem;
  color: var(--text-muted);
  line-height: 1.5;
}
.flow-connector {
  width: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--border-highlight);
  flex-shrink: 0;
}
.trust-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
  gap: 16px;
  margin-top: 40px;
}
.trust-card {
  padding: 20px;
  border-radius: var(--radius-m);
  text-align: center;
}
.trust-card b {
  display: block;
  font-family: var(--display);
  font-size: 1.15rem;
  color: var(--text);
  margin-bottom: 4px;
}
.trust-card span {
  font-size: 0.82rem;
  color: var(--text-muted);
}
</style>
