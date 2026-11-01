<template>
  <g :transform="`rotate(${angle})`">
    <polygon
      class="blade"
      points="0,-190 190,-90 190,120 0,40"
      fill="url(#apertureGrad)"
      stroke="#00E5FF"
      stroke-opacity="0.3"
      stroke-width="1.5"
    />
  </g>
</template>

<script setup>
defineProps({
  angle: { type: Number, required: true },
})
</script>
