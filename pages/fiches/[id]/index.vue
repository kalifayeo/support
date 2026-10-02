<script setup lang="ts">
const route = useRoute()
const supabase = useSupabaseClient()
const { profile, canValidate, isAdmin } = useProfile()

const fiche = ref<any>(null)
const contenu = ref<any>(null)
const historique = ref<any[]>([])
const loading = ref(true)
const notFound = ref(false)

const grantMatricule = ref('')
const grantError = ref('')

async function charger() {
  loading.value = true
  const { data, error } = await supabase
    .from('forms')
    .select(`
      *, form_types(nom, code, workflow),
      cree_par:profiles!forms_cree_par_fkey(nom, prenom, matricule),
      utilisateur:agents!forms_utilisateur_concerne_id_fkey(nom, prenom, matricule, fonction),
      directions(nom), services(nom)
    `)
    .eq('id', route.params.id)
    .maybeSingle()

  if (error || !data) { notFound.value = true; loading.value = false; return }
  fiche.value = data

  const [{ data: fd }, { data: hist }] = await Promise.all([
    supabase.from('form_data').select('*').eq('form_id', fiche.value.id).maybeSingle(),
    supabase.from('form_validations').select('*, validateur:profiles(nom, prenom)').eq('form_id', fiche.value.id).order('created_at'),
  ])
  contenu.value = fd?.contenu ?? {}
  historique.value = hist ?? []
  loading.value = false
}
onMounted(charger)

const statutLabels: Record<string, string> = {
  brouillon: 'Brouillon', en_attente: 'En attente', en_validation: 'En validation',
  validee: 'Validée', rejetee: 'Rejetée', annulee: 'Annulée', archivee: 'Archivée',
}

async function changerStatut(nouveau: string) {
  const { error } = await supabase.from('forms').update({ statut: nouveau }).eq('id', fiche.value.id)
  if (!error) await charger()
}

// Autoriser explicitement un tiers à consulter la fiche (section 32) —
// uniquement le créateur ou un admin peut le faire (appliqué aussi côté RLS).
async function autoriserAcces() {
  grantError.value = ''
  if (!grantMatricule.value) return
  const { data: user } = await supabase.from('profiles').select('id').eq('matricule', grantMatricule.value.toUpperCase()).maybeSingle()
  if (!user) { grantError.value = 'Matricule introuvable.'; return }
  const { error } = await supabase.from('form_access_grants').insert({
    form_id: fiche.value.id, beneficiaire_id: user.id, accorde_par: profile.value!.id,
  })
  if (error) grantError.value = "Impossible d'accorder l'accès (déjà autorisé ?)."
  else grantMatricule.value = ''
}

const router = useRouter()

async function supprimerFiche() {
  if (!confirm(`Supprimer définitivement la fiche ${fiche.value.numero} ? Cette action est irréversible.`)) return
  const { error } = await supabase.from('forms').delete().eq('id', fiche.value.id)
  if (error) { grantError.value = error.message; return }
  router.push('/fiches')
}

const peutEditer = computed(() =>
  fiche.value && (isAdmin.value || (fiche.value.cree_par?.matricule === profile.value?.matricule && ['brouillon', 'rejetee'].includes(fiche.value.statut))))

const peutModifier = computed(() =>
  fiche.value && (isAdmin.value || fiche.value.cree_par?.matricule === profile.value?.matricule))

const peutValider = computed(() =>
  fiche.value && canValidate.value && ['en_attente', 'en_validation'].includes(fiche.value.statut))
</script>

<template>
  <div class="max-w-3xl space-y-5">
    <div v-if="loading" class="text-sm text-slate-400 dark:text-slate-500">Chargement...</div>
    <div v-else-if="notFound" class="card p-8 text-center">
      <p class="text-sm text-slate-500 dark:text-slate-400">Fiche introuvable, ou vous n'avez pas l'autorisation d'y accéder.</p>
      <p class="text-xs text-slate-400 dark:text-slate-500 mt-2">Demandez au créateur de la fiche de vous accorder l'accès.</p>
    </div>

    <template v-else>
      <div class="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">{{ fiche.numero }}</h1>
          <p class="text-sm text-slate-500 dark:text-slate-400">{{ fiche.form_types?.nom }}</p>
        </div>
        <div class="flex items-center gap-2">
          <span class="badge text-sm" :class="{ 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400': ['brouillon','annulee','archivee'].includes(fiche.statut), 'bg-amber-50 text-amber-700': ['en_attente','en_validation'].includes(fiche.statut), 'bg-emerald-50 text-emerald-700': fiche.statut === 'validee', 'bg-red-50 text-red-700': fiche.statut === 'rejetee', }">{{ statutLabels[fiche.statut] }}</span>
          <button v-if="isAdmin" class="btn-danger !px-2.5" title="Supprimer la fiche" @click="supprimerFiche">
            <Icon name="trash" class="w-4 h-4" />
          </button>
        </div>
      </div>

      <!-- Informations générales -->
      <div class="card p-5 grid grid-cols-2 sm:grid-cols-3 gap-4 text-sm">
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Date</p><p class="font-medium">{{ new Date(fiche.created_at).toLocaleDateString('fr-FR') }}</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Direction</p><p class="font-medium">{{ fiche.directions?.nom }}</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Service</p><p class="font-medium">{{ fiche.services?.nom }}</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Établie par</p><p class="font-medium">{{ fiche.cree_par?.prenom }} {{ fiche.cree_par?.nom }} ({{ fiche.cree_par?.matricule }})</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Utilisateur</p><p class="font-medium">{{ fiche.utilisateur?.prenom }} {{ fiche.utilisateur?.nom }} ({{ fiche.utilisateur?.matricule }})</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Fonction</p><p class="font-medium">{{ fiche.utilisateur?.fonction || '—' }}</p></div>
      </div>

      <!-- Matériel -->
      <div v-if="contenu?.materiel" class="card p-5">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">Matériel</h2>
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-4 text-sm">
          <div v-for="(val, key) in contenu.materiel" :key="key">
            <template v-if="val">
              <p class="text-slate-400 dark:text-slate-500 text-xs capitalize">{{ key.replace('_', ' ') }}</p>
              <p class="font-medium">{{ val }}</p>
            </template>
          </div>
        </div>
        <div v-if="contenu.observations" class="mt-4 pt-4 border-t border-slate-100 dark:border-slate-800">
          <p class="text-slate-400 dark:text-slate-500 text-xs">Observations</p>
          <p class="text-sm mt-1">{{ contenu.observations }}</p>
        </div>
      </div>

      <!-- Actions de workflow -->
      <div v-if="peutValider || peutEditer || peutModifier" class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Actions</h2>
        <div class="flex flex-wrap gap-3">
          <button v-if="fiche.statut === 'brouillon'" class="btn-primary" @click="changerStatut('en_attente')">Soumettre</button>
          <button v-if="peutValider" class="btn-primary" @click="changerStatut('validee')">
            <Icon name="check" class="w-4 h-4" /> Valider
          </button>
          <button v-if="peutValider" class="btn-danger" @click="changerStatut('rejetee')">
            <Icon name="x" class="w-4 h-4" /> Rejeter
          </button>
 <NuxtLink v-if="peutModifier" :to="`/fiches/nouvelle?modifier=${fiche.id}`" class="btn-secondary">
            <Icon name="edit" class="w-4 h-4" /> Modifier la fiche
          </NuxtLink>
          <NuxtLink v-if="fiche.statut === 'validee'" :to="`/fiches/${fiche.id}/document`" class="btn-secondary">
            <Icon name="download" class="w-4 h-4" /> Générer le PDF
          </NuxtLink>
        </div>
      </div>

      <!-- Autorisation d'accès (uniquement le créateur / admin) -->
      <div v-if="fiche.cree_par?.matricule === profile?.matricule || isAdmin" class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Autoriser un accès</h2>
        <p class="text-xs text-slate-400 dark:text-slate-500">Par défaut, seuls vous, l'utilisateur concerné, la hiérarchie de validation et l'administration peuvent voir cette fiche.</p>
        <div class="flex gap-2">
          <input v-model="grantMatricule" placeholder="Matricule (ex: I001)" class="input uppercase" />
          <button class="btn-secondary shrink-0" @click="autoriserAcces">Autoriser</button>
        </div>
        <p v-if="grantError" class="text-xs text-red-600">{{ grantError }}</p>
      </div>

      <!-- Historique -->
      <div class="card p-5">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">Historique</h2>
        <div class="space-y-3">
          <div v-for="h in historique" :key="h.id" class="flex items-start gap-3 text-sm">
            <div class="w-2 h-2 rounded-full bg-brand-400 mt-1.5 shrink-0" />
            <div>
              <p>{{ statutLabels[h.nouveau_statut] }} <span v-if="h.validateur" class="text-slate-400 dark:text-slate-500">par {{ h.validateur.prenom }} {{ h.validateur.nom }}</span></p>
              <p class="text-xs text-slate-400 dark:text-slate-500">{{ new Date(h.created_at).toLocaleString('fr-FR') }}</p>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
