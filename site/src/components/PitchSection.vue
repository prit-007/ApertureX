<template>
  <section id="why" class="pitch-section">
    <div class="wrap">
      <div class="section-head center">
        <span class="hud-tag hud-tag-emerald">THE PITCH</span>
        <h2>Pro editing without the subscription trap.</h2>
        <p>
          One non-destructive recipe. Two professional shells. Every pixel processed on
          the device in your hand.
        </p>
      </div>

      <div class="pitch-grid">
        <article class="pitch-card glass-card">
          <span class="pitch-kicker">THE OLD WAY</span>
          <h3>Subscription clouds</h3>
          <p>
            Recurring fees, mandatory accounts, and a library that lives behind someone
            else's cloud.
          </p>
          <ul>
            <li>Monthly subscription</li>
            <li>Account required</li>
            <li>Cloud dependency</li>
          </ul>
        </article>

        <article class="pitch-card glass-card">
          <span class="pitch-kicker">THE CLOSED WAY</span>
          <h3>Closed black boxes</h3>
          <p>
            Free or one-off, but the engine is opaque and your looks cannot travel
            between apps or devices.
          </p>
          <ul>
            <li>Closed source</li>
            <li>Vendor lock-in</li>
            <li>No portable recipes</li>
          </ul>
        </article>

        <article class="pitch-card glass-card featured">
          <span class="pitch-kicker">THE APERTUREX WAY</span>
          <h3>Yours, forever</h3>
          <p>
            GPL-3.0, 100% on-device, zero accounts. One recipe flows between phone,
            tablet, and desktop — and your pixels never leave your hands.
          </p>
          <ul>
            <li>Zero subscriptions</li>
            <li>Zero cloud, zero trackers</li>
            <li>Look QR portable looks</li>
          </ul>
          <a class="pitch-cta" href="#download">
            Get the APK
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" aria-hidden="true">
              <path d="M5 12h14M13 6l6 6-6 6" />
            </svg>
          </a>
        </article>
      </div>

      <div class="pitch-stats">
        <div><b>0</b><span>Subscriptions</span></div>
        <div><b>0</b><span>Trackers</span></div>
        <div><b>100%</b><span>On-device</span></div>
        <div><b>55+</b><span>Master presets</span></div>
        <div><b>200 MP</b><span>Tile viewport</span></div>
        <div><b>6</b><span>Languages</span></div>
      </div>
    </div>
  </section>
</template>

<style scoped>
.pitch-section {
  padding-top: 20px;
}
.pitch-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 20px;
  align-items: stretch;
}
.pitch-card {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 32px;
  border-radius: var(--radius-m);
  border: 1px solid var(--border);
  position: relative;
  overflow: hidden;
}
.pitch-card h3 {
  font-size: 1.4rem;
  color: var(--text);
  margin: 0;
}
.pitch-card > p {
  font-size: 0.94rem;
  line-height: 1.6;
  color: var(--text-muted);
  margin: 0;
}
.pitch-card ul {
  list-style: none;
  margin: auto 0 0;
  padding: 18px 0 0;
  display: grid;
  gap: 9px;
  border-top: 1px solid var(--border);
}
.pitch-card li {
  position: relative;
  padding-left: 24px;
  font-size: 0.88rem;
  color: var(--text-muted);
}
.pitch-card li::before {
  content: '\2014';
  position: absolute;
  left: 0;
  color: var(--coral-soft);
}
.pitch-kicker {
  font-family: var(--mono);
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  color: var(--text-muted);
}
.pitch-card.featured {
  border-color: rgba(0, 229, 255, 0.45);
  background:
    radial-gradient(120% 80% at 50% 0%, rgba(0, 229, 255, 0.14), transparent 60%),
    rgba(14, 18, 28, 0.7);
  box-shadow: 0 24px 70px -30px rgba(0, 229, 255, 0.55);
}
.pitch-card.featured .pitch-kicker,
.pitch-card.featured h3 {
  color: var(--cyan);
}
.pitch-card.featured li::before {
  content: '\2713';
  color: var(--emerald);
  font-weight: 700;
}
.pitch-cta {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  align-self: flex-start;
  margin-top: 6px;
  font-family: var(--display);
  font-size: 0.9rem;
  font-weight: 700;
  color: var(--cyan);
  text-decoration: none;
}
.pitch-cta svg {
  width: 16px;
  height: 16px;
  transition: transform 0.2s var(--ease);
}
.pitch-cta:hover svg {
  transform: translateX(4px);
}
.pitch-stats {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 12px;
  margin-top: 28px;
  padding: 22px 24px;
  border: 1px solid var(--border);
  border-radius: var(--radius-m);
  background: rgba(14, 18, 28, 0.5);
  text-align: center;
}
.pitch-stats b {
  display: block;
  font-family: var(--display);
  font-size: 1.5rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: var(--text);
}
.pitch-stats span {
  display: block;
  margin-top: 2px;
  font-size: 0.76rem;
  color: var(--text-muted);
}
@media (max-width: 1024px) {
  .pitch-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
  .pitch-card.featured {
    grid-column: span 2;
  }
  .pitch-stats {
    grid-template-columns: repeat(3, minmax(0, 1fr));
    row-gap: 20px;
  }
}
@media (max-width: 640px) {
  .pitch-grid {
    grid-template-columns: 1fr;
  }
  .pitch-card.featured {
    grid-column: auto;
  }
  .pitch-card {
    padding: 24px;
  }
  .pitch-stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>
