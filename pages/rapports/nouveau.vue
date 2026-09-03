<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin', 'technicien', 'stagiaire', 'chef_service'] })

const supabase = useSupabaseClient()
const { profile } = useProfile()
const router = useRouter()

const saving = ref(false)
const error = ref('')
const types = ref<any[]>([])

const form = reactive({
  type_id: '', titre: '', periode_debut: '', periode_fin: '',
  activites_realisees: '', difficultes: '', recommandations: '',
})

onMounted(async () => {
  const { data } = await supabase.from('rapport_types').select('*').eq('actif', true).order('nom')
  types.value = data ?? []
})

const interventionsDisponibles = ref<any[]>([])
const interventionsSelectionnees = ref<Set<string>>(new Set())

// Interventions du technicien sur la période choisie — se rechargent dès
// que les deux dates sont renseignées.
async function chargerInterventions() {
  if (!form.periode_debut || !form.periode_fin || !profile.value) { interventionsDisponibles.value = []; return }
  const { data } = await supabase.from('interventions')
    .select('id, numero, titre, statut, date_ouverture')
    .eq('technicien_id', profile.value.id)
    .gte('date_ouverture', form.periode_debut)
    .lte('date_ouverture', form.periode_fin + 'T23:59:59')
    .order('date_ouverture', { ascending: false })
  interventionsDisponibles.value = data ?? []
}
watch([() => form.periode_debut, () => form.periode_fin], chargerInterventions)

function toggleIntervention(id: string) {
  if (interventionsSelectionnees.value.has(id)) interventionsSelectionnees.value.delete(id)
  else interventionsSelectionnees.value.add(id)
}

async function soumettre(statutFinal: 'brouillon' | 'soumis') {
  error.value = ''
  if (!form.titre.trim()) { error.value = 'Le titre est requis.'; return }
  if (!form.periode_debut || !form.periode_fin) { error.value = 'Précisez la période couverte.'; return }
  if (!form.activites_realisees.trim()) { error.value = 'Décrivez les activités réalisées.'; return }

  saving.value = true
  try {
    const { data: rapport, error: e } = await supabase.from('rapports_travail').insert({
      type_id: form.type_id || null,
      titre: form.titre.trim(),
      periode_debut: form.periode_debut,
      periode_fin: form.periode_fin,
      activites_realisees: form.activites_realisees.trim(),
      difficultes: form.difficultes || null,
      recommandations: form.recommandations || null,
      technicien_id: profile.value!.id,
      direction_id: profile.value!.direction_id,
      service_id: profile.value!.service_id,
      statut: statutFinal,
    }).select().single()
    if (e) throw e

    if (interventionsSelectionnees.value.size > 0) {
      const liens = [...interventionsSelectionnees.value].map(intervention_id => ({ rapport_id: rapport.id, intervention_id }))
      await supabase.from('rapport_interventions').insert(liens)
    }

    router.push(`/rapports/${rapport.id}`)
  } catch (e: any) {
    error.value = e.message ?? 'Une erreur est survenue.'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl space-y-5">
    <NuxtLink to="/rapports" class="text-sm text-brand-600">← Retour aux rapports</NuxtLink>

    <div>
      <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Nouveau rapport de travail</h1>
      <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Synthèse de vos interventions sur une période donnée.</p>
    </div>

    <div class="card p-5 space-y-4">
      <div>
        <label class="label">Titre *</label>
        <input v-model="form.titre" class="input" placeholder="Ex: Rapport hebdomadaire semaine 35" />
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="label">Type de rapport</label>
          <select v-model="form.type_id" class="input">
            <option value="">—</option>
            <option v-for="t in types" :key="t.id" :value="t.id">{{ t.nom }}</option>
          </select>
        </div>
      </div>
      <div class="grid grid-cols-2 gap-3">
        <div><label class="label">Période du *</label><input v-model="form.periode_debut" type="date" class="input" /></div>
        <div><label class="label">au *</label><input v-model="form.periode_fin" type="date" class="input" /></div>
      </div>
    </div>

    <div v-if="form.periode_debut && form.periode_fin" class="card p-5 space-y-3">
      <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Interventions à inclure</h2>
      <p v-if="interventionsDisponibles.length === 0" class="text-sm text-slate-400 dark:text-slate-500">
        Aucune intervention trouvée sur cette période.
      </p>
      <label v-for="i in interventionsDisponibles" :key="i.id"
        class="flex items-center gap-3 p-2.5 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800/60 cursor-pointer transition-colors">
        <input type="checkbox" class="rounded" :checked="interventionsSelectionnees.has(i.id)" @change="toggleIntervention(i.id)" />
        <span class="text-sm flex-1">{{ i.numero }} — {{ i.titre }}</span>
        <span class="text-xs text-slate-400 dark:text-slate-500">{{ new Date(i.date_ouverture).toLocaleDateString('fr-FR') }}</span>
      </label>
    </div>

    <div class="card p-5 space-y-4">
      <div>
        <label class="label">Activités réalisées *</label>
        <textarea v-model="form.activites_realisees" rows="4" maxlength="1500" class="input" placeholder="Détaillez les tâches accomplies durant cette période..." />
      </div>
      <div>
        <label class="label">Difficultés rencontrées</label>
        <textarea v-model="form.difficultes" rows="3" maxlength="800" class="input" placeholder="Optionnel..." />
      </div>
      <div>
        <label class="label">Recommandations</label>
        <textarea v-model="form.recommandations" rows="3" maxlength="800" class="input" placeholder="Optionnel..." />
      </div>
    </div>

    <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

    <div class="flex gap-3">
      <button class="btn-secondary flex-1" :disabled="saving" @click="soumettre('brouillon')">Enregistrer brouillon</button>
      <button class="btn-primary flex-1" :disabled="saving" @click="soumettre('soumis')">
        {{ saving ? 'Envoi...' : 'Soumettre pour validation' }}
      </button>
    </div>
  </div>
</template>
