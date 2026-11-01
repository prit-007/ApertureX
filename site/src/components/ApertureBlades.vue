<template>
  <div class="aperture-blades" aria-hidden="true">
    <svg
      viewBox="-200 -200 400 400"
      width="100%"
      height="100%"
      style="display:block"
    >
      <defs>
        <linearGradient id="bl" x1="0" x2="1" y1="0" y2="1">
          <stop offset="0" stop-color="#1b2438" />
          <stop offset="1" stop-color="#0b0f1a" />
        </linearGradient>
      </defs>
      <g id="blades">
        <g
          v-for="k in 8"
          :key="k"
          :transform="`rotate(${k * 45})`"
        >
          <polygon
            class="bd"
            points="0,-190 190,-90 190,120 0,40"
            fill="url(#bl)"
            stroke="#00E5FF"
            stroke-opacity="0.3"
            stroke-width="1.5"
          />
        </g>
      </g>
      <circle r="196" fill="none" stroke="#00E5FF" stroke-width="2" opacity="0.45" />
    </svg>
  </div>
</template>

<script setup>
</script>

<style scoped>
.aperture-blades {
  width: 100%;
  height: 320px;
  overflow: hidden;
}

.aperture-blades svg {
  width: 100%;
  height: 100%;
}

@media (prefers-reduced-motion: reduce) {
  .aperture-blades .bd {
    animation: none;
  }
}
</style>
