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
    viewBox="0 0 400 400"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    class="shrink-0"
  >
    <!-- GIANTUCCHI AI (IAN) OFFICIAL BRAND LOGO & ISOTYPE -->
    <rect width="400" height="400" rx="90" fill="#000000" />
    <g transform="translate(200, 200)">
      <!-- CENTRAL SOLID HEXAGON -->
      <polygon
        points="0,-42 36.37,-21 36.37,21 0,42 -36.37,21 -36.37,-21"
        fill="#FFFFFF"
      />

      <!-- 12 RADIAL RAYS AND OUTER NODES -->
      <!-- Angle 0° (Top) -->
      <g>
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-100"
          stroke="#FFFFFF"
          stroke-width="4"
          stroke-linecap="round"
          opacity="0.9"
        />
        <circle cx="0" cy="-125" r="7" fill="#FFFFFF" />
      </g>
      <!-- Angle 30° -->
      <g transform="rotate(30)">
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-90"
          stroke="#FFFFFF"
          stroke-width="3"
          stroke-linecap="round"
          opacity="0.6"
        />
        <circle cx="0" cy="-110" r="5" fill="#FFFFFF" opacity="0.7" />
      </g>
      <!-- Angle 60° -->
      <g transform="rotate(60)">
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-100"
          stroke="#FFFFFF"
          stroke-width="4"
          stroke-linecap="round"
          opacity="0.9"
        />
        <circle cx="0" cy="-125" r="7" fill="#FFFFFF" />
      </g>
      <!-- Angle 90° (Right) -->
      <g transform="rotate(90)">
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-90"
          stroke="#FFFFFF"
          stroke-width="3"
          stroke-linecap="round"
          opacity="0.6"
        />
        <circle cx="0" cy="-110" r="5" fill="#FFFFFF" opacity="0.7" />
      </g>
      <!-- Angle 120° -->
      <g transform="rotate(120)">
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-100"
          stroke="#FFFFFF"
          stroke-width="4"
          stroke-linecap="round"
          opacity="0.9"
        />
        <circle cx="0" cy="-125" r="7" fill="#FFFFFF" />
      </g>
      <!-- Angle 150° -->
      <g transform="rotate(150)">
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-90"
          stroke="#FFFFFF"
          stroke-width="3"
          stroke-linecap="round"
          opacity="0.6"
        />
        <circle cx="0" cy="-110" r="5" fill="#FFFFFF" opacity="0.7" />
      </g>
      <!-- Angle 180° (Bottom) -->
      <g transform="rotate(180)">
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-100"
          stroke="#FFFFFF"
          stroke-width="4"
          stroke-linecap="round"
          opacity="0.9"
        />
        <circle cx="0" cy="-125" r="7" fill="#FFFFFF" />
      </g>
      <!-- Angle 210° -->
      <g transform="rotate(210)">
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-90"
          stroke="#FFFFFF"
          stroke-width="3"
          stroke-linecap="round"
          opacity="0.6"
        />
        <circle cx="0" cy="-110" r="5" fill="#FFFFFF" opacity="0.7" />
      </g>
      <!-- Angle 240° -->
      <g transform="rotate(240)">
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-100"
          stroke="#FFFFFF"
          stroke-width="4"
          stroke-linecap="round"
          opacity="0.9"
        />
        <circle cx="0" cy="-125" r="7" fill="#FFFFFF" />
      </g>
      <!-- Angle 270° (Left) -->
      <g transform="rotate(270)">
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-90"
          stroke="#FFFFFF"
          stroke-width="3"
          stroke-linecap="round"
          opacity="0.6"
        />
        <circle cx="0" cy="-110" r="5" fill="#FFFFFF" opacity="0.7" />
      </g>
      <!-- Angle 300° -->
      <g transform="rotate(300)">
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-100"
          stroke="#FFFFFF"
          stroke-width="4"
          stroke-linecap="round"
          opacity="0.9"
        />
        <circle cx="0" cy="-125" r="7" fill="#FFFFFF" />
      </g>
      <!-- Angle 330° -->
      <g transform="rotate(330)">
        <line
          x1="0"
          y1="-56"
          x2="0"
          y2="-90"
          stroke="#FFFFFF"
          stroke-width="3"
          stroke-linecap="round"
          opacity="0.6"
        />
        <circle cx="0" cy="-110" r="5" fill="#FFFFFF" opacity="0.7" />
      </g>
    </g>
  </svg>
</template>
