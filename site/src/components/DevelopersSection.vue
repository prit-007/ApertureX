<template>
  <section id="developers">
    <div class="wrap">
      <div class="section-head center">
        <span class="hud-tag hud-tag-emerald">PEOPLE &amp; PHILOSOPHY</span>
        <h2>About the Developers &amp; Creators</h2>
        <p>
          ApertureX is built by passionate open-source artisans dedicated to reclaiming
          creator independence from monopolistic subscription ecosystems.
        </p>
      </div>

      <div class="bento-grid" style="margin-top: 32px;">
        <!-- Developer's Paradise -->
        <div class="bento-card glass-card bento-span-6">
          <div>
            <div class="bento-icon" style="background: rgba(0, 229, 255, 0.12); color: var(--cyan);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" />
              </svg>
            </div>
            <div class="bento-title">Developer's Paradise</div>
            <div class="bento-desc">
              Open-source software studio and collective committed to building pro-grade,
              privacy-respecting creative tools. Developer's Paradise champions
              <strong>100% on-device computing</strong>, user data sovereignty, zero cloud
              lock-in, and ethical free software under the GNU General Public License v3.0.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag">Open-Source Studio</span>
            <span class="hud-tag hud-tag-emerald">100% Offline Integrity</span>
            <span class="hud-tag">GPL-3.0</span>
          </div>
        </div>

        <!-- Prit Vasani -->
        <div class="bento-card glass-card bento-span-6">
          <div>
            <div class="bento-icon" style="background: rgba(255, 179, 0, 0.12); color: var(--amber);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="7" r="4" />
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
              </svg>
            </div>
            <div class="bento-title">Prit Vasani</div>
            <div class="bento-desc">
              Lead Architect &amp; Creator of ApertureX. Designed the core architectural
              foundations: dual-UI shells over unified non-destructive recipes,
              high-performance compiled Rust engine (<code>rust_lib_aperturex</code>),
              Depth Anything V2 monocular depth integration, 55+ master preset catalog, and
              open Look QR standard.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag hud-tag-amber">Lead Architect &amp; Developer</span>
            <span class="hud-tag">Engine &amp; UI Design</span>
            <span class="hud-tag hud-tag-coral">FOSS Advocate</span>
          </div>
        </div>

        <!-- Third-Party Ecosystem & Open Standards -->
        <div class="bento-card glass-card bento-span-12">
          <div>
            <div class="bento-icon" style="background: rgba(16, 185, 129, 0.12); color: var(--emerald);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
                <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
              </svg>
            </div>
            <div class="bento-title">Third-Party Attribution &amp; Standing on Giants' Shoulders</div>
            <div class="bento-desc">
              ApertureX is powered by foundational open-source engineering:
              <strong>Rust</strong>, <strong>Flutter &amp; Dart</strong>,
              <strong>rawler</strong> (LGPL-2.1 RAW decoding),
              <strong>jpeg-encoder</strong> (MIT/IJG), <strong>zune-jpeg</strong>,
              <strong>miniz_oxide</strong>, <strong>Drift &amp; SQLite</strong> (reactive local
              storage), <strong>Depth Anything V2</strong> (Apache-2.0 monocular depth),
              <strong>YuNet</strong> (MIT face detection),
              <strong>U&sup2;-NetP</strong> (Apache-2.0 salient segmentation),
              <strong>ONNX Runtime Mobile</strong>, <strong>extended_image</strong>, and the
              <strong>pro_image_editor</strong> fork (BSD-3-Clause). Full licensing and audit
              details are documented in
              <a
                href="https://github.com/prit-007/ApertureX/blob/main/THIRD_PARTY.md"
                target="_blank"
                rel="noopener"
                style="color: var(--cyan); font-weight: 600; text-decoration: underline;"
              >THIRD_PARTY.md</a>.
            </div>
          </div>
          <div class="bento-tag-row">
            <span class="hud-tag">FOSS Components</span>
            <span class="hud-tag">THIRD_PARTY.md</span>
            <span class="hud-tag hud-tag-amber">Zero Closed Blobs</span>
            <span class="hud-tag hud-tag-emerald">GPL-3.0-or-later</span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
