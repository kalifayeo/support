<script setup lang="ts">
const supabase = useSupabaseClient()
const { canCreateFiche, isAdmin } = useProfile()

const rapports = ref<any[]>([])
const loading = ref(true)
const search = ref('')
const statutFiltre = ref('')

const statuts = [
  { value: '', label: 'Tous les statuts' },
  { value: 'brouillon', label: 'Brouillon' },
  { value: 'soumis', label: 'Soumis' },
  { value: 'valide', label: 'Validé' },
]
const statutStyle: Record<string, string> = {
  brouillon: 'bg-slate-100 dark:bg-slate-800 text-slate-500',
  soumis: 'bg-amber-50 text-amber-700',
  valide: 'bg-emerald-50 text-emerald-700',
}

async function charger() {
  loading.value = true
  let query = supabase.from('rapports_travail')
    .select('id, numero, titre, statut, periode_debut, periode_fin, technicien:profiles!rapports_travail_technicien_id_fkey(nom, prenom)')
    .order('created_at', { ascending: false })

  if (statutFiltre.value) query = query.eq('statut', statutFiltre.value)
  if (search.value.trim()) query = query.or(`numero.ilike.%${search.value}%,titre.ilike.%${search.value}%`)

  const { data } = await query.limit(50)
  rapports.value = data ?? []
  loading.value = false
}
onMounted(charger)
watch(statutFiltre, charger)
let t: ReturnType<typeof setTimeout>
watch(search, () => { clearTimeout(t); t = setTimeout(charger, 350) })

async function supprimer(r: any) {
  if (!confirm(`Supprimer le rapport ${r.numero} ?`)) return
  const { error } = await supabase.from('rapports_travail').delete().eq('id', r.id)
  if (!error) rapports.value = rapports.value.filter(x => x.id !== r.id)
}
</script>

<template>
  <div class="space-y-4 max-w-4xl">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <div>
        <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Rapports de travail</h1>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Synthèse périodique des interventions réalisées.</p>
      </div>
      <NuxtLink v-if="canCreateFiche" to="/rapports/nouveau" class="btn-primary">
        <Icon name="plus" class="w-4 h-4" /> Nouveau rapport
      </NuxtLink>
    </div>

    <div class="flex flex-col sm:flex-row gap-3">
      <input v-model="search" type="search" placeholder="Rechercher par numéro ou titre..." class="input sm:max-w-xs" />
      <select v-model="statutFiltre" class="input sm:max-w-[180px]">
        <option v-for="s in statuts" :key="s.value" :value="s.value">{{ s.label }}</option>
      </select>
    </div>

    <div class="card divide-y divide-slate-100 dark:divide-slate-800">
      <SkeletonList v-if="loading" :rows="5" />
      <div v-else-if="rapports.length === 0" class="p-10 text-center space-y-2">
        <Icon name="clipboard" class="w-8 h-8 mx-auto text-slate-300 dark:text-slate-600" />
        <p class="text-sm text-slate-400 dark:text-slate-500">Aucun rapport pour le moment.</p>
      </div>
      <div v-for="r in rapports" :key="r.id" class="p-4 flex items-center justify-between gap-3 hover:bg-slate-50 dark:hover:bg-slate-800/60 transition-colors">
        <NuxtLink :to="`/rapports/${r.id}`" class="min-w-0 flex-1">
          <p class="text-sm font-semibold text-slate-800 dark:text-slate-100">{{ r.numero }} — {{ r.titre }}</p>
          <p class="text-xs text-slate-400 dark:text-slate-500 truncate">
            {{ r.technicien?.prenom }} {{ r.technicien?.nom }} · {{ new Date(r.periode_debut).toLocaleDateString('fr-FR') }} → {{ new Date(r.periode_fin).toLocaleDateString('fr-FR') }}
          </p>
        </NuxtLink>
        <div class="flex items-center gap-2 shrink-0">
          <span class="badge" :class="statutStyle[r.statut]">{{ statuts.find(s => s.value === r.statut)?.label }}</span>
          <button v-if="isAdmin" class="text-red-500 hover:text-red-700" title="Supprimer" @click="supprimer(r)">
            <Icon name="trash" class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
