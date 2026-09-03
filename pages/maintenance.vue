<script setup lang="ts">
definePageMeta({ layout: 'auth' })
const { maintenanceMessage, logoUrl, fetchSettings, loaded } = useSettings()
if (!loaded.value) await fetchSettings()
</script>

<template>
  <div class="max-w-sm text-center space-y-4 card-glass p-8">
    <img :src="logoUrl" alt="Logo" class="h-14 mx-auto object-contain" />
    <div class="w-14 h-14 rounded-2xl bg-amber-100 dark:bg-amber-950 text-amber-600 dark:text-amber-400 mx-auto flex items-center justify-center">
      <Icon name="alert-triangle" class="w-6 h-6" />
    </div>
    <h1 class="text-lg font-bold text-slate-800 dark:text-slate-100">Maintenance en cours</h1>
    <p class="text-sm text-slate-500 dark:text-slate-400">{{ maintenanceMessage }}</p>
  </div>
</template>
