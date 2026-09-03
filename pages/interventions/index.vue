<script setup lang="ts">
const supabase = useSupabaseClient()
const { canCreateFiche, isAdmin } = useProfile()

const interventions = ref<any[]>([])
const types = ref<any[]>([])
const loading = ref(true)
const search = ref('')
const statutFiltre = ref('')
const typeFiltre = ref('')
const prioriteFiltre = ref('')

const statuts = [
  { value: '', label: 'Tous les statuts' },
  { value: 'nouvelle', label: 'Nouvelle' },
  { value: 'en_cours', label: 'En cours' },
  { value: 'en_attente_piece', label: 'En attente de pièce' },
  { value: 'resolue', label: 'Résolue' },
  { value: 'annulee', label: 'Annulée' },
]
const statutStyle: Record<string, string> = {
  nouvelle: 'bg-blue-50 text-blue-700',
  en_cours: 'bg-amber-50 text-amber-700',
  en_attente_piece: 'bg-orange-50 text-orange-700',
  resolue: 'bg-emerald-50 text-emerald-700',
  annulee: 'bg-slate-100 dark:bg-slate-800 text-slate-500',
}
const prioriteStyle: Record<string, string> = {
  basse: 'bg-slate-100 dark:bg-slate-800 text-slate-500',
  normale: 'bg-blue-50 text-blue-700',
  haute: 'bg-orange-50 text-orange-700',
  urgente: 'bg-red-50 text-red-700',
}
const prioriteLabels: Record<string, string> = { basse: 'Basse', normale: 'Normale', haute: 'Haute', urgente: 'Urgente' }

async function charger() {
  loading.value = true
  let query = supabase
    .from('interventions')
    .select('id, numero, titre, statut, priorite, created_at, intervention_types(id, nom), agents(nom, prenom)')
    .order('created_at', { ascending: false })

  if (statutFiltre.value) query = query.eq('statut', statutFiltre.value)
  if (typeFiltre.value) query = query.eq('type_id', typeFiltre.value)
  if (prioriteFiltre.value) query = query.eq('priorite', prioriteFiltre.value)
  if (search.value.trim()) query = query.or(`numero.ilike.%${search.value}%,titre.ilike.%${search.value}%`)

  const { data } = await query.limit(50)
  interventions.value = data ?? []
  loading.value = false
}
onMounted(async () => {
  const { data } = await supabase.from('intervention_types').select('*').order('nom')
  types.value = data ?? []
  await charger()
})
watch([statutFiltre, typeFiltre, prioriteFiltre], charger)
let t: ReturnType<typeof setTimeout>
watch(search, () => { clearTimeout(t); t = setTimeout(charger, 350) })

async function supprimer(i: any) {
  if (!confirm(`Supprimer l'intervention ${i.numero} ?`)) return
  const { error } = await supabase.from('interventions').delete().eq('id', i.id)
  if (!error) interventions.value = interventions.value.filter(x => x.id !== i.id)
}
</script>

<template>
  <div class="space-y-4 max-w-4xl">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <div>
        <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Interventions</h1>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Dépannage et support technique sur le terrain.</p>
      </div>
      <NuxtLink v-if="canCreateFiche" to="/interventions/nouvelle" class="btn-primary">
        <Icon name="plus" class="w-4 h-4" /> Nouvelle intervention
      </NuxtLink>
    </div>

    <div class="flex flex-col sm:flex-row gap-3 flex-wrap">
      <input v-model="search" type="search" placeholder="Rechercher par numéro ou titre..." class="input sm:max-w-xs" />
      <select v-model="statutFiltre" class="input sm:max-w-[180px]">
        <option v-for="s in statuts" :key="s.value" :value="s.value">{{ s.label }}</option>
      </select>
      <select v-model="typeFiltre" class="input sm:max-w-[180px]">
        <option value="">Tous les types</option>
        <option v-for="t in types" :key="t.id" :value="t.id">{{ t.nom }}</option>
      </select>
      <select v-model="prioriteFiltre" class="input sm:max-w-[150px]">
        <option value="">Toutes priorités</option>
        <option v-for="(label, key) in prioriteLabels" :key="key" :value="key">{{ label }}</option>
      </select>
    </div>

    <div class="card divide-y divide-slate-100 dark:divide-slate-800">
      <SkeletonList v-if="loading" :rows="5" />
      <div v-else-if="interventions.length === 0" class="p-10 text-center space-y-2">
        <Icon name="wrench" class="w-8 h-8 mx-auto text-slate-300 dark:text-slate-600" />
        <p class="text-sm text-slate-400 dark:text-slate-500">Aucune intervention pour le moment.</p>
      </div>
      <div v-for="i in interventions" :key="i.id" class="p-4 flex items-center justify-between gap-3 hover:bg-slate-50 dark:hover:bg-slate-800/60 transition-colors">
        <NuxtLink :to="`/interventions/${i.id}`" class="min-w-0 flex-1">
          <p class="text-sm font-semibold text-slate-800 dark:text-slate-100">{{ i.numero }} — {{ i.titre }}</p>
          <p class="text-xs text-slate-400 dark:text-slate-500 truncate">
            {{ i.intervention_types?.nom }}
            <span v-if="i.agents">· {{ i.agents.prenom }} {{ i.agents.nom }}</span>
          </p>
        </NuxtLink>
        <div class="flex items-center gap-2 shrink-0">
          <span class="badge" :class="prioriteStyle[i.priorite]">{{ prioriteLabels[i.priorite] }}</span>
          <span class="badge" :class="statutStyle[i.statut]">{{ statuts.find(s => s.value === i.statut)?.label }}</span>
          <button v-if="isAdmin" class="text-red-500 hover:text-red-700" title="Supprimer" @click="supprimer(i)">
            <Icon name="trash" class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
