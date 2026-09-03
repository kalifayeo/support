<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin'] })

const tabs = [
  { to: '/admin', label: 'Tableau de bord' },
  { to: '/admin/utilisateurs', label: 'Utilisateurs' },
  { to: '/admin/agents', label: 'Agents' },
  { to: '/admin/directions', label: 'Directions & services' },
  { to: '/admin/materiel', label: 'Matériel' },
  { to: '/admin/types-fiches', label: 'Types de fiches' },
  { to: '/admin/types-interventions', label: "Types d'intervention" },
  { to: '/admin/types-rapports', label: 'Types de rapport' },
  { to: '/admin/parametres', label: 'Paramètres' },
]
</script>

<template>
  <div class="space-y-5">
    <div class="flex gap-1 overflow-x-auto pb-1 border-b border-slate-200 dark:border-slate-800">
      <NuxtLink v-for="t in tabs" :key="t.to" :to="t.to"
        class="px-3.5 py-2 text-sm font-medium text-slate-500 dark:text-slate-400 rounded-t-lg whitespace-nowrap"
        active-class="text-brand-700 border-b-2 border-brand-600" exact-active-class="text-brand-700 border-b-2 border-brand-600">
        {{ t.label }}
      </NuxtLink>
    </div>
    <slot />
  </div>
</template>
