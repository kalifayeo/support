<script setup lang="ts">
const supabase = useSupabaseClient()
const { canCreateFiche, isAdmin } = useProfile()

const fiches = ref<any[]>([])
const loading = ref(true)
const search = ref('')
const statutFiltre = ref('')
const typeFiltre = ref('')

const statuts = [
  { value: '', label: 'Tous les statuts' },
  { value: 'brouillon', label: 'Brouillon' },
  { value: 'en_attente', label: 'En attente' },
  { value: 'en_validation', label: 'En validation' },
  { value: 'validee', label: 'Validée' },
  { value: 'rejetee', label: 'Rejetée' },
  { value: 'archivee', label: 'Archivée' },
]

const statutStyle: Record<string, string> = {
  brouillon: 'bg-slate-100 text-slate-600',
  en_attente: 'bg-amber-50 text-amber-700',
  en_validation: 'bg-blue-50 text-blue-700',
  validee: 'bg-emerald-50 text-emerald-700',
  rejetee: 'bg-red-50 text-red-700',
  annulee: 'bg-slate-100 text-slate-500',
  archivee: 'bg-slate-100 text-slate-500',
}

async function charger() {
  loading.value = true
  let query = supabase
    .from('forms')
    .select('id, numero, statut, created_at, form_types(nom, code), utilisateur_concerne_id, agents!forms_utilisateur_concerne_id_fkey(nom, prenom)')
    .order('created_at', { ascending: false })

  if (statutFiltre.value) query = query.eq('statut', statutFiltre.value)
  if (typeFiltre.value) query = query.eq('form_types.code', typeFiltre.value)
  if (search.value.trim()) query = query.ilike('numero', `%${search.value.trim()}%`)

  const { data } = await query.limit(50)
  fiches.value = data ?? []
  loading.value = false
}

onMounted(charger)
watch([statutFiltre, typeFiltre], charger)
let t: ReturnType<typeof setTimeout>
watch(search, () => { clearTimeout(t); t = setTimeout(charger, 350) })

async function supprimerFiche(f: any) {
  if (!confirm(`Supprimer définitivement la fiche ${f.numero} ?`)) return
  const { error } = await supabase.from('forms').delete().eq('id', f.id)
  if (!error) fiches.value = fiches.value.filter(x => x.id !== f.id)
}
</script>

<template>
  <div class="space-y-4 max-w-4xl">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Mes fiches</h1>
      <NuxtLink v-if="canCreateFiche" to="/fiches/nouvelle?type=FA" class="btn-primary">
        <Icon name="plus" class="w-4 h-4" /> Nouvelle fiche
      </NuxtLink>
    </div>

    <div class="flex flex-col sm:flex-row gap-3">
      <input v-model="search" type="search" placeholder="Rechercher par numéro de fiche..." class="input sm:max-w-xs" />
      <select v-model="statutFiltre" class="input sm:max-w-[180px]">
        <option v-for="s in statuts" :key="s.value" :value="s.value">{{ s.label }}</option>
      </select>
    </div>

    <div class="card divide-y divide-slate-100 dark:divide-slate-800">
      <SkeletonList v-if="loading" :rows="5" />
      <div v-else-if="fiches.length === 0" class="p-6 text-center text-sm text-slate-400 dark:text-slate-500">Aucune fiche trouvée.</div>
      <div v-for="f in fiches" :key="f.id" class="p-4 flex items-center justify-between gap-3 hover:bg-slate-50 dark:hover:bg-slate-800/60">
        <NuxtLink :to="`/fiches/${f.id}`" class="min-w-0 flex-1">
          <p class="text-sm font-semibold text-slate-800 dark:text-slate-100">{{ f.numero }}</p>
          <p class="text-xs text-slate-400 dark:text-slate-500 truncate">
            {{ f.form_types?.nom }}
            <span v-if="f.agents">· {{ f.agents.prenom }} {{ f.agents.nom }}</span>
          </p>
        </NuxtLink>
        <div class="flex items-center gap-3 shrink-0">
          <span class="badge" :class="statutStyle[f.statut]">{{ statuts.find(s => s.value === f.statut)?.label }}</span>
          <button v-if="isAdmin" class="text-red-500 hover:text-red-700" title="Supprimer" @click="supprimerFiche(f)">
            <Icon name="trash" class="w-4 h-4" />
          </button>
          <NuxtLink :to="`/fiches/${f.id}`"><Icon name="chevron-right" class="w-4 h-4 text-slate-300" /></NuxtLink>
        </div>
      </div>
    </div>
  </div>
</template>
