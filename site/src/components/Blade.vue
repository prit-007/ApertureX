<template>
  <g :transform="`rotate(${angle})`">
    <polygon
      class="blade"
      points="0,-200 220,-100 220,100 0,50"
      fill="url(#apertureGrad)"
      stroke="#00E5FF"
      stroke-opacity="0.25"
      stroke-width="1.5"
    />
  </g>
</template>

<script setup>
defineProps({
  angle: { type: Number, required: true },
})
</script>
