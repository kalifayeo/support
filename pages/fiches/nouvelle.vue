<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin', 'technicien', 'stagiaire', 'chef_service'] })

const supabase = useSupabaseClient()
const { profile } = useProfile()
const route = useRoute()
const router = useRouter()

const typeCode = (route.query.type as string) || 'FA'
const formType = ref<any>(null)

const directions = ref<any[]>([])
const services = ref<any[]>([])
const agents = ref<any[]>([])
const categories = ref<any[]>([])

const saving = ref(false)
const error = ref('')

const form = reactive({
  direction_id: '',
  service_id: '',
  utilisateur_concerne_id: '',
  matricule_recherche: '',
})

// Bénéficiaire non trouvé dans le répertoire : proposer une création rapide
// (section 9 : sélection intelligente, mais un nouvel agent doit pouvoir être
// ajouté à la volée sans repasser par l'administration).
const creationAgentOuverte = ref(false)
const nouvelAgent = reactive({ matricule: '', nom: '', prenom: '', fonction: '' })
const creationAgentEnCours = ref(false)

const materiel = reactive({
  categorie_id: '', marque: '', modele: '', reference: '',
  numero_serie: '', imei: '', capacite: '', ram: '', stockage: '', os: '', accessoires: '',
})

const observations = ref('')

onMounted(async () => {
  const [{ data: ft }, { data: dirs }, { data: cats }] = await Promise.all([
    supabase.from('form_types').select('*').eq('code', typeCode).single(),
    supabase.from('directions').select('*').order('nom'),
    supabase.from('equipment_categories').select('*').order('nom'),
  ])
  formType.value = ft
  directions.value = dirs ?? []
  categories.value = cats ?? []

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

// Le bénéficiaire est cherché dans "agents" : le répertoire de TOUT le
// personnel pouvant recevoir du matériel, avec ou sans compte de connexion.
async function chargerAgents() {
  if (!form.service_id) { agents.value = []; return }
  const { data } = await supabase.from('agents').select('id, nom, prenom, matricule, fonction')
    .eq('service_id', form.service_id).order('nom')
  agents.value = data ?? []
}
watch(() => form.service_id, chargerAgents)

// Recherche directe par matricule (section 9 : sélection intelligente)
async function rechercherParMatricule() {
  error.value = ''
  creationAgentOuverte.value = false
  if (!form.matricule_recherche) return
  const { data } = await supabase.from('agents')
    .select('id, nom, prenom, matricule, fonction, direction_id, service_id')
    .eq('matricule', form.matricule_recherche.toUpperCase()).maybeSingle()
  if (data) {
    form.direction_id = data.direction_id
    await chargerServices()
    form.service_id = data.service_id
    await chargerAgents()
    form.utilisateur_concerne_id = data.id
  } else {
    // Aucun agent existant avec ce matricule : proposer d'en créer un nouveau
    nouvelAgent.matricule = form.matricule_recherche.toUpperCase()
    nouvelAgent.nom = ''
    nouvelAgent.prenom = ''
    nouvelAgent.fonction = ''
    creationAgentOuverte.value = true
  }
}

async function creerAgent() {
  error.value = ''
  if (!nouvelAgent.nom || !nouvelAgent.prenom) {
    error.value = 'Nom et prénom du bénéficiaire sont requis.'
    return
  }
  if (!form.direction_id || !form.service_id) {
    error.value = 'Choisissez la direction et le service du bénéficiaire avant de le créer.'
    return
  }
  creationAgentEnCours.value = true
  try {
    const { data, error: e } = await supabase.from('agents').insert({
      matricule: nouvelAgent.matricule || null,
      nom: nouvelAgent.nom, prenom: nouvelAgent.prenom, fonction: nouvelAgent.fonction || null,
      direction_id: form.direction_id, service_id: form.service_id,
      created_by: profile.value!.id,
    }).select().single()
    if (e) throw e
    await chargerAgents()
    form.utilisateur_concerne_id = data.id
    creationAgentOuverte.value = false
  } catch (e: any) {
    error.value = e.message ?? "Impossible de créer ce bénéficiaire (matricule déjà utilisé ?)."
  } finally {
    creationAgentEnCours.value = false
  }
}

const agentSelectionne = computed(() =>
  agents.value.find(a => a.id === form.utilisateur_concerne_id))

async function soumettre(brouillon: boolean) {
  error.value = ''
  if (!form.utilisateur_concerne_id) { error.value = 'Sélectionnez le bénéficiaire.'; return }
  if (!materiel.categorie_id) { error.value = 'Sélectionnez une catégorie de matériel.'; return }

  saving.value = true
  try {
    const { data: fiche, error: fErr } = await supabase.from('forms').insert({
      form_type_id: formType.value.id,
      direction_id: form.direction_id,
      service_id: form.service_id,
      utilisateur_concerne_id: form.utilisateur_concerne_id,
      cree_par: profile.value!.id,
      statut: brouillon ? 'brouillon' : 'en_attente',
    }).select().single()
    if (fErr) throw fErr

    const { error: dErr } = await supabase.from('form_data').insert({
      form_id: fiche.id,
      contenu: { materiel: { ...materiel }, observations: observations.value },
    })
    if (dErr) throw dErr

    router.push(`/fiches/${fiche.id}`)
  } catch (e: any) {
    error.value = e.message ?? 'Une erreur est survenue.'
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl space-y-5">
    <div>
      <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">{{ formType?.nom || 'Nouvelle fiche' }}</h1>
      <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Les informations existantes en base sont sélectionnées, jamais ressaisies.</p>
    </div>

    <!-- Étape 1 : identification du bénéficiaire -->
    <div class="card p-5 space-y-4">
      <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">1. Bénéficiaire (utilisateur qui reçoit le matériel)</h2>

      <div class="flex gap-2">
        <input v-model="form.matricule_recherche" placeholder="Rechercher par matricule (ex: I001)"
               class="input uppercase" @keyup.enter="rechercherParMatricule" />
        <button type="button" class="btn-secondary shrink-0" @click="rechercherParMatricule">Trouver</button>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div>
          <label class="label">Direction</label>
          <select v-model="form.direction_id" class="input">
            <option value="" disabled>Choisir...</option>
            <option v-for="d in directions" :key="d.id" :value="d.id">{{ d.nom }}</option>
          </select>
        </div>
        <div>
          <label class="label">Service</label>
          <select v-model="form.service_id" class="input" :disabled="!form.direction_id">
            <option value="" disabled>Choisir...</option>
            <option v-for="s in services" :key="s.id" :value="s.id">{{ s.nom }}</option>
          </select>
        </div>
        <div>
          <label class="label">Bénéficiaire</label>
          <select v-model="form.utilisateur_concerne_id" class="input" :disabled="!form.service_id">
            <option value="" disabled>Choisir...</option>
            <option v-for="a in agents" :key="a.id" :value="a.id">{{ a.prenom }} {{ a.nom }} ({{ a.matricule || 's.m.' }})</option>
          </select>
        </div>
      </div>

      <div v-if="agentSelectionne" class="rounded-xl bg-brand-50 dark:bg-brand-950 p-3 text-sm text-brand-800 dark:text-brand-300">
        {{ agentSelectionne.prenom }} {{ agentSelectionne.nom }} — {{ agentSelectionne.fonction }} · {{ agentSelectionne.matricule || 'sans matricule' }}
      </div>

      <!-- Création rapide d'un nouveau bénéficiaire introuvable dans le répertoire -->
      <div v-if="creationAgentOuverte" class="rounded-xl border border-dashed border-brand-300 dark:border-brand-800 p-4 space-y-3">
        <p class="text-sm text-slate-600 dark:text-slate-400">
          Aucun bénéficiaire trouvé pour le matricule <strong>{{ nouvelAgent.matricule || '—' }}</strong>. Créez-le maintenant :
        </p>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div><label class="label">Nom *</label><input v-model="nouvelAgent.nom" class="input" /></div>
          <div><label class="label">Prénom *</label><input v-model="nouvelAgent.prenom" class="input" /></div>
          <div><label class="label">Fonction</label><input v-model="nouvelAgent.fonction" class="input" /></div>
          <div><label class="label">Matricule</label><input v-model="nouvelAgent.matricule" class="input uppercase" placeholder="Optionnel si inconnu" /></div>
        </div>
        <div class="flex gap-2">
          <button type="button" class="btn-secondary" @click="creationAgentOuverte = false">Annuler</button>
          <button type="button" class="btn-primary" :disabled="creationAgentEnCours" @click="creerAgent">
            {{ creationAgentEnCours ? 'Création...' : 'Créer et sélectionner' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Étape 2 : matériel -->
    <div class="card p-5 space-y-4">
      <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">2. Matériel</h2>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="label">Catégorie</label>
          <select v-model="materiel.categorie_id" class="input">
            <option value="" disabled>Choisir...</option>
            <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.nom }}</option>
          </select>
        </div>
        <div><label class="label">Marque</label><input v-model="materiel.marque" class="input" /></div>
        <div><label class="label">Modèle</label><input v-model="materiel.modele" class="input" /></div>
        <div><label class="label">Référence</label><input v-model="materiel.reference" class="input" /></div>
        <div><label class="label">Numéro de série</label><input v-model="materiel.numero_serie" class="input" /></div>
        <div><label class="label">IMEI (si téléphone)</label><input v-model="materiel.imei" class="input" /></div>
        <div><label class="label">RAM</label><input v-model="materiel.ram" class="input" /></div>
        <div><label class="label">Stockage</label><input v-model="materiel.stockage" class="input" /></div>
        <div><label class="label">Système d'exploitation</label><input v-model="materiel.os" class="input" /></div>
        <div><label class="label">Accessoires fournis</label><input v-model="materiel.accessoires" class="input" /></div>
      </div>
    </div>

    <!-- Étape 3 : observations -->
    <div class="card p-5 space-y-3">
      <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">3. Observations</h2>
      <textarea v-model="observations" rows="3" maxlength="500" class="input" placeholder="Remarques éventuelles (500 caractères max)..." />
    </div>

    <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

    <div class="flex gap-3">
      <button class="btn-secondary flex-1" :disabled="saving" @click="soumettre(true)">Enregistrer brouillon</button>
      <button class="btn-primary flex-1" :disabled="saving" @click="soumettre(false)">
        {{ saving ? 'Envoi...' : 'Soumettre la fiche' }}
      </button>
    </div>
  </div>
</template>
