<script setup>
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');
</script>

<template>
  <img
    v-if="globalConfig.logoThumbnail"
    v-bind="attrs"
    :src="globalConfig.logoThumbnail"
  />
  <svg
    v-else
    v-once
    v-bind="attrs"
    width="20"
    height="20"
    viewBox="0 0 512 512"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <defs>
      <linearGradient
        id="giantucchi-vue-grad"
        x1="0%"
        y1="0%"
        x2="100%"
        y2="100%"
      >
        <stop offset="0%" stop-color="#3b82f6" />
        <stop offset="25%" stop-color="#8b5cf6" />
        <stop offset="50%" stop-color="#ec4899" />
        <stop offset="75%" stop-color="#f97316" />
        <stop offset="100%" stop-color="#eab308" />
      </linearGradient>
    </defs>
    <rect width="512" height="512" rx="128" fill="#050505" />
    <rect
      width="496"
      height="496"
      x="8"
      y="8"
      rx="120"
      stroke="url(#giantucchi-vue-grad)"
      stroke-width="16"
      stroke-opacity="0.8"
    />
    <g transform="translate(106, 116)">
      <path
        d="M150 20 L260 250 H205 L150 130 L95 250 H40 L150 20 Z"
        fill="url(#giantucchi-vue-grad)"
      />
      <circle
        cx="150"
        cy="180"
        r="28"
        fill="#050505"
        stroke="url(#giantucchi-vue-grad)"
        stroke-width="12"
      />
      <circle cx="150" cy="180" r="10" fill="#3b82f6" />
      <circle cx="40" cy="250" r="12" fill="#3b82f6" />
      <circle cx="260" cy="250" r="12" fill="#ec4899" />
      <circle cx="150" cy="20" r="14" fill="#8b5cf6" />
    </g>
  </svg>
</template>
