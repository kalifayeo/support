<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin'] })
const supabase = useSupabaseClient()

const stats = ref({
  utilisateurs: 0, actifs: 0, enAttente: 0,
  fiches: 0, fichesAttente: 0, fichesValidees: 0,
  equipements: 0, equipementsAffectes: 0,
})

onMounted(async () => {
  const [u, ua, uw, f, fw, fv, e, ea] = await Promise.all([
    supabase.from('profiles').select('id', { count: 'exact', head: true }),
    supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('status', 'actif'),
    supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('status', 'en_attente'),
    supabase.from('forms').select('id', { count: 'exact', head: true }),
    supabase.from('forms').select('id', { count: 'exact', head: true }).in('statut', ['en_attente', 'en_validation']),
    supabase.from('forms').select('id', { count: 'exact', head: true }).eq('statut', 'validee'),
    supabase.from('equipments').select('id', { count: 'exact', head: true }),
    supabase.from('equipments').select('id', { count: 'exact', head: true }).not('utilisateur_actuel_id', 'is', null),
  ])
  stats.value = {
    utilisateurs: u.count ?? 0, actifs: ua.count ?? 0, enAttente: uw.count ?? 0,
    fiches: f.count ?? 0, fichesAttente: fw.count ?? 0, fichesValidees: fv.count ?? 0,
    equipements: e.count ?? 0, equipementsAffectes: ea.count ?? 0,
  }
})
</script>

<template>
  <AdminShell>
    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
      <div class="card p-4"><p class="text-2xl font-bold">{{ stats.utilisateurs }}</p><p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Utilisateurs</p></div>
      <div class="card p-4"><p class="text-2xl font-bold text-emerald-600">{{ stats.actifs }}</p><p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Actifs</p></div>
      <div class="card p-4"><p class="text-2xl font-bold text-amber-600">{{ stats.enAttente }}</p><p class="text-xs text-slate-500 dark:text-slate-400 mt-1">En attente</p></div>
      <div class="card p-4"><p class="text-2xl font-bold">{{ stats.fiches }}</p><p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Fiches totales</p></div>
      <div class="card p-4"><p class="text-2xl font-bold text-amber-600">{{ stats.fichesAttente }}</p><p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Fiches en attente</p></div>
      <div class="card p-4"><p class="text-2xl font-bold text-emerald-600">{{ stats.fichesValidees }}</p><p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Fiches validées</p></div>
      <div class="card p-4"><p class="text-2xl font-bold">{{ stats.equipements }}</p><p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Équipements</p></div>
      <div class="card p-4"><p class="text-2xl font-bold text-brand-600">{{ stats.equipementsAffectes }}</p><p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Affectés</p></div>
    </div>
  </AdminShell>
</template>
