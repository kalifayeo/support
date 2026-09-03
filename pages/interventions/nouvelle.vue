<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin', 'technicien', 'stagiaire', 'chef_service'] })

const supabase = useSupabaseClient()
const { profile } = useProfile()
const router = useRouter()

const types = ref<any[]>([])
const directions = ref<any[]>([])
const services = ref<any[]>([])
const agents = ref<any[]>([])
const equipements = ref<any[]>([])

const saving = ref(false)
const error = ref('')

const form = reactive({
  type_id: '', priorite: 'normale', titre: '', description: '',
  direction_id: '', service_id: '', agent_concerne_id: '', equipment_id: '',
  matricule_recherche: '',
})

onMounted(async () => {
  const [{ data: t }, { data: dirs }] = await Promise.all([
    supabase.from('intervention_types').select('*').eq('actif', true).order('nom'),
    supabase.from('directions').select('*').order('nom'),
  ])
  types.value = t ?? []
  directions.value = dirs ?? []

  if (profile.value) {
    form.direction_id = profile.value.direction_id ?? ''
    form.service_id = profile.value.service_id ?? ''
    if (form.direction_id) await chargerServices()
  }
})

async function chargerServices() {
  const { data } = await supabase.from('services').select('*').eq('direction_id', form.direction_id).order('nom')
  services.value = data ?? []
}
watch(() => form.direction_id, chargerServices)

async function chargerAgents() {
  if (!form.service_id) { agents.value = []; return }
  const { data } = await supabase.from('agents').select('id, nom, prenom, matricule').eq('service_id', form.service_id).order('nom')
  agents.value = data ?? []
}
watch(() => form.service_id, chargerAgents)

async function rechercherParMatricule() {
  error.value = ''
  if (!form.matricule_recherche) return
  const { data } = await supabase.from('agents').select('id, nom, prenom, matricule, direction_id, service_id')
    .eq('matricule', form.matricule_recherche.toUpperCase()).maybeSingle()
  if (data) {
    form.direction_id = data.direction_id
    await chargerServices()
    form.service_id = data.service_id
    await chargerAgents()
    form.agent_concerne_id = data.id
  } else {
    error.value = 'Aucun agent trouvé pour ce matricule.'
  }
}

async function rechercherEquipement(q: string) {
  if (q.trim().length < 2) { equipements.value = []; return }
  const { data } = await supabase.from('equipments')
    .select('id, numero_inventaire, marque, modele')
    .or(`numero_inventaire.ilike.%${q}%,marque.ilike.%${q}%,modele.ilike.%${q}%`)
    .limit(8)
  equipements.value = data ?? []
}
const rechercheEquipement = ref('')
let te: ReturnType<typeof setTimeout>
watch(rechercheEquipement, (v) => { clearTimeout(te); te = setTimeout(() => rechercherEquipement(v), 300) })

const equipementSelectionne = computed(() => equipements.value.find(e => e.id === form.equipment_id))

async function soumettre() {
  error.value = ''
  if (!form.titre.trim()) { error.value = "Le titre de l'intervention est requis."; return }
  if (!form.type_id) { error.value = "Choisissez un type d'intervention."; return }

  saving.value = true
  try {
    const { data, error: e } = await supabase.from('interventions').insert({
      type_id: form.type_id,
      priorite: form.priorite,
      titre: form.titre.trim(),
      description: form.description || null,
      direction_id: form.direction_id || null,
      service_id: form.service_id || null,
      agent_concerne_id: form.agent_concerne_id || null,
      equipment_id: form.equipment_id || null,
      technicien_id: profile.value!.id, // le créateur se l'assigne par défaut, réassignable ensuite
      cree_par: profile.value!.id,
    }).select().single()
    if (e) throw e
    router.push(`/interventions/${data.id}`)
  } catch (e: any) {
    error.value = e.message ?? 'Une erreur est survenue.'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl space-y-5">
    <NuxtLink to="/interventions" class="text-sm text-brand-600">← Retour aux interventions</NuxtLink>

    <div>
      <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Nouvelle intervention</h1>
      <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Support technique sur le terrain.</p>
    </div>

    <div class="card p-5 space-y-4">
      <div>
        <label class="label">Titre *</label>
        <input v-model="form.titre" class="input" placeholder="Ex: Ordinateur qui ne démarre plus" />
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="label">Type d'intervention *</label>
          <select v-model="form.type_id" class="input">
            <option value="" disabled>Choisir...</option>
            <option v-for="t in types" :key="t.id" :value="t.id">{{ t.nom }}</option>
          </select>
        </div>
        <div>
          <label class="label">Priorité</label>
          <select v-model="form.priorite" class="input">
            <option value="basse">Basse</option>
            <option value="normale">Normale</option>
            <option value="haute">Haute</option>
            <option value="urgente">Urgente</option>
          </select>
        </div>
      </div>
      <div>
        <label class="label">Description</label>
        <textarea v-model="form.description" rows="3" maxlength="800" class="input" placeholder="Détail du problème rencontré..." />
      </div>
    </div>

    <div class="card p-5 space-y-4">
      <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Utilisateur concerné (optionnel)</h2>
      <div class="flex gap-2">
        <input v-model="form.matricule_recherche" placeholder="Rechercher par matricule (ex: I001)"
               class="input uppercase" @keyup.enter="rechercherParMatricule" />
        <button type="button" class="btn-secondary shrink-0" @click="rechercherParMatricule">Trouver</button>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div>
          <label class="label">Direction</label>
          <select v-model="form.direction_id" class="input">
            <option value="">—</option>
            <option v-for="d in directions" :key="d.id" :value="d.id">{{ d.nom }}</option>
          </select>
        </div>
        <div>
          <label class="label">Service</label>
          <select v-model="form.service_id" class="input" :disabled="!form.direction_id">
            <option value="">—</option>
            <option v-for="s in services" :key="s.id" :value="s.id">{{ s.nom }}</option>
          </select>
        </div>
        <div>
          <label class="label">Agent</label>
          <select v-model="form.agent_concerne_id" class="input" :disabled="!form.service_id">
            <option value="">—</option>
            <option v-for="a in agents" :key="a.id" :value="a.id">{{ a.prenom }} {{ a.nom }}</option>
          </select>
        </div>
      </div>
    </div>

    <div class="card p-5 space-y-3">
      <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Équipement concerné (optionnel)</h2>
      <input v-model="rechercheEquipement" placeholder="Rechercher un équipement (marque, modèle, n° inventaire)..." class="input" />
      <div v-if="equipements.length" class="space-y-1">
        <button v-for="e in equipements" :key="e.id" type="button"
          class="w-full text-left px-3 py-2 rounded-lg text-sm hover:bg-slate-50 dark:hover:bg-slate-800"
          :class="form.equipment_id === e.id && 'bg-brand-50 dark:bg-brand-950'"
          @click="form.equipment_id = e.id; rechercheEquipement = ''; equipements = []">
          {{ e.marque }} {{ e.modele }} <span class="text-slate-400 dark:text-slate-500">· {{ e.numero_inventaire }}</span>
        </button>
      </div>
      <div v-if="equipementSelectionne" class="rounded-xl bg-brand-50 dark:bg-brand-950 p-3 text-sm text-brand-800 dark:text-brand-300 flex justify-between items-center">
        {{ equipementSelectionne.marque }} {{ equipementSelectionne.modele }} · {{ equipementSelectionne.numero_inventaire }}
        <button type="button" class="text-brand-600 dark:text-brand-400" @click="form.equipment_id = ''">✕</button>
      </div>
    </div>

    <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

    <button class="btn-primary w-full" :disabled="saving" @click="soumettre">
      {{ saving ? 'Création...' : "Créer l'intervention" }}
    </button>
  </div>
</template>
