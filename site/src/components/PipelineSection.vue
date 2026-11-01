<template>
  <section id="pipeline" class="pipeline-section reveal">
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
          <p>{{ step.desc }}</p>
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
    desc: 'TurboJPEG & LibRaw demosaic to native resident heap; EXIF & GDepth extraction.',
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
    title: 'Banded & C2PA',
    desc: 'Full-res streaming export with C2PA Content Credentials manifests & watermark branding.',
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
  padding: 64px 0;
  background: var(--bg-darkest);
}

.section-head.center {
  text-align: center;
  margin-bottom: 48px;
}

.flow-track {
  display: flex;
  flex-direction: column;
  gap: 20px;
  align-items: center;
  margin-bottom: 48px;
}

.flow-step {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 24px 20px;
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius-xl);
  max-width: 420px;
  width: 100%;
  text-align: center;
}

.flow-step .num {
  font-family: var(--mono);
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--cyan);
  letter-spacing: 0.1em;
  text-transform: uppercase;
}

.flow-step h4 {
  font-size: 1rem;
  color: var(--text);
  margin: 0;
}

.flow-step p {
  color: var(--text-muted);
  font-size: 0.85rem;
  line-height: 1.5;
  margin: 6px 0 0 0;
}

.flow-connector {
  font-size: 1.2rem;
  color: var(--text-faint);
  padding: 8px 0;
}

.trust-row {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
  justify-content: center;
}

.trust-card {
  flex: 1;
  min-width: 200px;
  max-width: 260px;
  padding: 20px;
  border-radius: var(--radius-l);
  text-align: center;
}

.trust-card b {
  display: block;
  font-size: 1.1rem;
  margin-bottom: 6px;
  font-family: var(--display);
}

.trust-card span {
  font-size: 0.85rem;
  color: var(--text-muted);
  line-height: 1.5;
}

@media (max-width: 640px) {
  .flow-step {
    max-width: 100%;
  }
}
</style>
