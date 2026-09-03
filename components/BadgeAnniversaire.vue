<script setup lang="ts">
const { badgeUrl, badgeActif, fetchSettings, loaded } = useSettings()
if (!loaded.value) await fetchSettings()
</script>

<template>
  <div v-if="badgeActif" class="fixed right-3 bottom-20 lg:bottom-6 lg:right-6 z-30 pointer-events-none select-none">
    <div class="relative">
      <!-- Halo sombre derrière le badge pour le faire ressortir sur fond clair comme sombre -->
      <div class="absolute inset-0 rounded-full bg-slate-900/70 blur-xl scale-90" />
      <img
        :src="badgeUrl"
        alt=""
        class="relative w-14 h-14 md:w-20 md:h-20 lg:w-24 lg:h-24 object-contain opacity-90 drop-shadow-lg"
      />
    </div>
  </div>
</template>
