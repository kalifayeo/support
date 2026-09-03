<script setup lang="ts">
defineProps<{ name: string }>()

const paths: Record<string, string> = {
  home: 'M3 11.5 12 4l9 7.5M5 10v9a1 1 0 0 0 1 1h4v-6h4v6h4a1 1 0 0 0 1-1v-9',
  file: 'M7 3h7l5 5v13a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1ZM14 3v5h5',
  server: 'M4 4h16v6H4V4Zm0 10h16v6H4v-6Zm3 3h.01M7 7h.01',
  bell: 'M6 9a6 6 0 1 1 12 0c0 5 2 6 2 6H4s2-1 2-6Zm4.3 10a1.8 1.8 0 0 0 3.4 0',
  menu: 'M4 6h16M4 12h16M4 18h16',
  shield: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6l8-3Z',
  search: 'M11 19a8 8 0 1 1 0-16 8 8 0 0 1 0 16Zm10 2-4.35-4.35',
  plus: 'M12 5v14M5 12h14',
  check: 'M20 6 9 17l-5-5',
  x: 'M18 6 6 18M6 6l12 12',
  'chevron-right': 'm9 18 6-6-6-6',
  users: 'M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm8 10v-2a4 4 0 0 0-3-3.87M15 3.13a4 4 0 0 1 0 7.75',
  clock: 'M12 7v5l3 3M12 21a9 9 0 1 1 0-18 9 9 0 0 1 0 18Z',
  building: 'M4 21V4a1 1 0 0 1 1-1h9a1 1 0 0 1 1 1v17M14 8h6v13M4 21h16M8 7h1m3 0h1m-5 4h1m3 0h1m-5 4h1m3 0h1',
  qrcode: 'M4 4h6v6H4V4Zm10 0h6v6h-6V4ZM4 14h6v6H4v-6Zm10 4h6m-6-3h1m3 3h2m-6 3h6',
  download: 'M12 4v12m0 0 4-4m-4 4-4-4M4 20h16',
  edit: 'M12 20h9M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5Z',
  trash: 'M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0-1 14a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1L6 6h12Z',
  sun: 'M12 3v2m0 14v2M5 5l1.5 1.5M17.5 17.5 19 19M3 12h2m14 0h2M5 19l1.5-1.5M17.5 6.5 19 5M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Z',
  moon: 'M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5Z',
  'chevron-left': 'm15 18-6-6 6-6',
  'panel-left': 'M4 4h16v16H4V4Zm5 0v16',
  wrench: 'M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.8 2.8-2-2 2.8-2.8Z',
  clipboard: 'M9 4h6a1 1 0 0 1 1 1v1H8V5a1 1 0 0 1 1-1ZM6 6h12a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1Zm3 6h6m-6 4h6',
  'alert-triangle': 'M12 4 2 20h20L12 4Zm0 6v4m0 4h.01',
  info: 'M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20Zm0-13v.01M12 11v6',
}
</script>

<template>
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
       stroke-linecap="round" stroke-linejoin="round" class="shrink-0">
    <path :d="paths[name] || paths.file" />
  </svg>
</template>
