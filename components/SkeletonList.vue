<script setup lang="ts">
withDefaults(defineProps<{ rows?: number }>(), { rows: 4 })
</script>

<template>
  <div class="divide-y divide-slate-100 dark:divide-slate-800">
    <div v-for="i in rows" :key="i" class="p-4 flex items-center justify-between gap-3">
      <div class="min-w-0 flex-1 space-y-2">
        <div class="skeleton h-4 w-1/3" />
        <div class="skeleton h-3 w-1/2" />
      </div>
      <div class="skeleton h-6 w-16 rounded-full shrink-0" />
    </div>
  </div>
</template>
