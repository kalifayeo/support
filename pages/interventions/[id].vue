<script setup lang="ts">
const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()
const { profile, isAdmin } = useProfile()

const intervention = ref<any>(null)
const techniciens = ref<any[]>([])
const loading = ref(true)
const erreur = ref('')
const solution = ref('')
const saving = ref(false)

const statuts = [
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
const prioriteLabels: Record<string, string> = { basse: 'Basse', normale: 'Normale', haute: 'Haute', urgente: 'Urgente' }

async function charger() {
  loading.value = true
  const { data, error } = await supabase.from('interventions')
    .select(`
      *, intervention_types(nom),
      agent:agents!interventions_agent_concerne_id_fkey(nom, prenom, matricule, fonction),
      equipement:equipments(numero_inventaire, marque, modele),
      technicien:profiles!interventions_technicien_id_fkey(nom, prenom),
      cree_par:profiles!interventions_cree_par_fkey(nom, prenom)
    `)
    .eq('id', route.params.id).maybeSingle()

  if (error || !data) { erreur.value = 'Intervention introuvable.'; loading.value = false; return }
  intervention.value = data
  solution.value = data.solution || ''
  loading.value = false
}
onMounted(async () => {
  await charger()
  const { data } = await supabase.from('profiles').select('id, nom, prenom')
    .in('role', ['technicien', 'admin', 'super_admin']).eq('status', 'actif').order('nom')
  techniciens.value = data ?? []
})

const peutGerer = computed(() =>
  intervention.value && (isAdmin.value || intervention.value.cree_par?.id === profile.value?.id || intervention.value.technicien_id === profile.value?.id))

async function changerStatut(nouveau: string) {
  saving.value = true
  const payload: any = { statut: nouveau }
  if (nouveau === 'resolue') payload.date_cloture = new Date().toISOString()
  if (solution.value) payload.solution = solution.value
  const { error } = await supabase.from('interventions').update(payload).eq('id', intervention.value.id)
  saving.value = false
  if (!error) await charger()
}

async function assignerTechnicien(technicienId: string) {
  await supabase.from('interventions').update({ technicien_id: technicienId || null }).eq('id', intervention.value.id)
  await charger()
}

async function enregistrerSolution() {
  saving.value = true
  await supabase.from('interventions').update({ solution: solution.value }).eq('id', intervention.value.id)
  saving.value = false
}

async function supprimer() {
  if (!confirm(`Supprimer l'intervention ${intervention.value.numero} ?`)) return
  const { error } = await supabase.from('interventions').delete().eq('id', intervention.value.id)
  if (!error) router.push('/interventions')
}
</script>

<template>
  <div class="max-w-2xl space-y-5">
    <NuxtLink to="/interventions" class="text-sm text-brand-600">← Retour aux interventions</NuxtLink>

    <div v-if="loading" class="text-sm text-slate-400 dark:text-slate-500">Chargement...</div>
    <div v-else-if="erreur && !intervention" class="card p-8 text-center text-sm text-slate-500 dark:text-slate-400">{{ erreur }}</div>

    <template v-else-if="intervention">
      <div class="flex items-start justify-between gap-3 flex-wrap">
        <div>
          <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">{{ intervention.numero }}</h1>
          <p class="text-sm text-slate-500 dark:text-slate-400">{{ intervention.titre }}</p>
        </div>
        <div class="flex items-center gap-2">
          <span class="badge bg-red-50 text-red-700" v-if="intervention.priorite === 'urgente'">Urgente</span>
          <span class="badge" :class="statutStyle[intervention.statut]">{{ statuts.find(s => s.value === intervention.statut)?.label }}</span>
          <button v-if="isAdmin" class="btn-danger !px-2.5" title="Supprimer" @click="supprimer">
            <Icon name="trash" class="w-4 h-4" />
          </button>
        </div>
      </div>

      <div class="card p-5 grid grid-cols-2 sm:grid-cols-3 gap-4 text-sm">
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Type</p><p class="font-medium">{{ intervention.intervention_types?.nom || '—' }}</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Priorité</p><p class="font-medium">{{ prioriteLabels[intervention.priorite] }}</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Ouverte le</p><p class="font-medium">{{ new Date(intervention.date_ouverture).toLocaleDateString('fr-FR') }}</p></div>
        <div v-if="intervention.agent"><p class="text-slate-400 dark:text-slate-500 text-xs">Agent concerné</p><p class="font-medium">{{ intervention.agent.prenom }} {{ intervention.agent.nom }}</p></div>
        <div v-if="intervention.equipement"><p class="text-slate-400 dark:text-slate-500 text-xs">Équipement</p><p class="font-medium">{{ intervention.equipement.marque }} {{ intervention.equipement.modele }}</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Créée par</p><p class="font-medium">{{ intervention.cree_par?.prenom }} {{ intervention.cree_par?.nom }}</p></div>
      </div>

      <div v-if="intervention.description" class="card p-5">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">Description</h2>
        <p class="text-sm text-slate-600 dark:text-slate-400">{{ intervention.description }}</p>
      </div>

      <!-- Assignation technicien -->
      <div v-if="peutGerer" class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Technicien assigné</h2>
        <select :value="intervention.technicien_id ?? ''" class="input" @change="assignerTechnicien(($event.target as HTMLSelectElement).value)">
          <option value="">Non assigné</option>
          <option v-for="t in techniciens" :key="t.id" :value="t.id">{{ t.prenom }} {{ t.nom }}</option>
        </select>
      </div>

      <!-- Statut + solution -->
      <div v-if="peutGerer" class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Suivi</h2>
        <div class="flex flex-wrap gap-2">
          <button v-for="s in statuts" :key="s.value" class="badge"
            :class="intervention.statut === s.value ? statutStyle[s.value] : 'bg-slate-100 dark:bg-slate-800 text-slate-400 dark:text-slate-500'"
            :disabled="saving" @click="changerStatut(s.value)">
            {{ s.label }}
          </button>
        </div>
        <div>
          <label class="label">Solution apportée</label>
          <textarea v-model="solution" rows="3" maxlength="800" class="input" placeholder="Décrire la solution appliquée..." @blur="enregistrerSolution" />
        </div>
      </div>
      <div v-else-if="intervention.solution" class="card p-5">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">Solution apportée</h2>
        <p class="text-sm text-slate-600 dark:text-slate-400">{{ intervention.solution }}</p>
      </div>
    </template>
  </div>
</template>
