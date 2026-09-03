<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin'] })
const supabase = useSupabaseClient()

const users = ref<any[]>([])
const directions = ref<any[]>([])
const services = ref<any[]>([])
const loading = ref(true)
const search = ref('')
const roleFiltre = ref('')

const roles = ['super_admin', 'admin', 'directeur', 'chef_service', 'technicien', 'stagiaire', 'agent']
const roleLabels: Record<string, string> = {
  super_admin: 'Super admin', admin: 'Admin', directeur: 'Directeur',
  chef_service: 'Chef de service', technicien: 'Technicien', stagiaire: 'Stagiaire', agent: 'Agent',
}
const statutLabels: Record<string, string> = {
  en_attente: 'En attente', actif: 'Actif', suspendu: 'Suspendu', desactive: 'Désactivé', archive: 'Archivé',
}
const statutStyle: Record<string, string> = {
  en_attente: 'bg-amber-50 text-amber-700', actif: 'bg-emerald-50 text-emerald-700',
  suspendu: 'bg-orange-50 text-orange-700', desactive: 'bg-slate-100 dark:bg-slate-800 text-slate-500', archive: 'bg-slate-100 dark:bg-slate-800 text-slate-400',
}

async function charger() {
  loading.value = true
  let q = supabase.from('profiles').select('*').order('nom')
  if (roleFiltre.value) q = q.eq('role', roleFiltre.value)
  if (search.value.trim()) q = q.or(`nom.ilike.%${search.value}%,prenom.ilike.%${search.value}%,matricule.ilike.%${search.value}%`)
  const { data } = await q.limit(100)
  users.value = data ?? []
  loading.value = false
}
onMounted(async () => {
  const [{ data: d }, { data: s }] = await Promise.all([
    supabase.from('directions').select('*').order('nom'),
    supabase.from('services').select('*').order('nom'),
  ])
  directions.value = d ?? []
  services.value = s ?? []
  await charger()
})
watch(roleFiltre, charger)
let t: ReturnType<typeof setTimeout>
watch(search, () => { clearTimeout(t); t = setTimeout(charger, 350) })

async function changerStatut(u: any, statut: string) {
  const payload: any = { status: statut }
  if (statut === 'actif' && !u.date_activation) payload.date_activation = new Date().toISOString()
  const { error } = await supabase.from('profiles').update(payload).eq('id', u.id)
  if (!error) { u.status = statut; if (payload.date_activation) u.date_activation = payload.date_activation }
}

async function changerRole(u: any, role: string) {
  await supabase.from('profiles').update({ role }).eq('id', u.id)
  u.role = role
}

function motDePasseAleatoire() {
  const s = Math.random().toString(36).slice(-8)
  return s.charAt(0).toUpperCase() + s.slice(1) + '!1'
}

const servicesFiltresPour = (directionId: string) =>
  directionId ? services.value.filter(s => s.direction_id === directionId) : services.value

// --- Création d'un nouvel utilisateur ---
const creationOuverte = ref(false)
const creating = ref(false)
const createError = ref('')
const nouveau = reactive({
  matricule: '', nom: '', prenom: '', email_pro: '', telephone: '',
  direction_id: '', service_id: '', fonction: '', role: 'agent',
  mot_de_passe: motDePasseAleatoire(),
})
const servicesFiltresCreation = computed(() => servicesFiltresPour(nouveau.direction_id))

function ouvrirCreation() {
  Object.assign(nouveau, {
    matricule: '', nom: '', prenom: '', email_pro: '', telephone: '',
    direction_id: '', service_id: '', fonction: '', role: 'agent',
    mot_de_passe: motDePasseAleatoire(),
  })
  createError.value = ''
  creationOuverte.value = true
}

async function creerUtilisateur() {
  createError.value = ''
  if (!nouveau.matricule || !nouveau.nom || !nouveau.prenom || !nouveau.email_pro) {
    createError.value = 'Matricule, nom, prénom et email professionnel sont obligatoires.'
    return
  }
  creating.value = true
  try {
    await $fetch('/api/admin/create-user', { method: 'POST', body: { ...nouveau, matricule: nouveau.matricule.toUpperCase() } })
    creationOuverte.value = false
    await charger()
  } catch (e: any) {
    createError.value = e?.data?.statusMessage || e?.message || 'Erreur lors de la création.'
  } finally {
    creating.value = false
  }
}

// --- Modification d'un utilisateur existant ---
const editionOuverte = ref(false)
const editing = ref(false)
const editError = ref('')
const edite = reactive({
  id: '', matricule: '', nom: '', prenom: '', email_pro: '', telephone: '',
  direction_id: '', service_id: '', fonction: '',
})
const servicesFiltresEdition = computed(() => servicesFiltresPour(edite.direction_id))

function ouvrirEdition(u: any) {
  Object.assign(edite, {
    id: u.id, matricule: u.matricule, nom: u.nom, prenom: u.prenom, email_pro: u.email_pro,
    telephone: u.telephone || '', direction_id: u.direction_id || '', service_id: u.service_id || '',
    fonction: u.fonction || '',
  })
  editError.value = ''
  editionOuverte.value = true
}

async function modifierUtilisateur() {
  editError.value = ''
  if (!edite.matricule || !edite.nom || !edite.prenom || !edite.email_pro) {
    editError.value = 'Matricule, nom, prénom et email professionnel sont obligatoires.'
    return
  }
  editing.value = true
  try {
    await $fetch('/api/admin/update-user', { method: 'POST', body: { ...edite, matricule: edite.matricule.toUpperCase() } })
    editionOuverte.value = false
    await charger()
  } catch (e: any) {
    editError.value = e?.data?.statusMessage || e?.message || 'Erreur lors de la modification.'
  } finally {
    editing.value = false
  }
}

// --- Réinitialisation de mot de passe (utilisateur qui a oublié) ---
const resetOuvert = ref(false)
const resetting = ref(false)
const resetError = ref('')
const resetCible = reactive({ id: '', nomComplet: '', matricule: '', mot_de_passe: '' })

function ouvrirReset(u: any) {
  resetCible.id = u.id
  resetCible.nomComplet = `${u.prenom} ${u.nom}`
  resetCible.matricule = u.matricule
  resetCible.mot_de_passe = motDePasseAleatoire()
  resetError.value = ''
  resetOuvert.value = true
}

async function reinitialiserMotDePasse() {
  resetError.value = ''
  resetting.value = true
  try {
    await $fetch('/api/admin/reset-password', { method: 'POST', body: { id: resetCible.id, mot_de_passe: resetCible.mot_de_passe } })
    // Reste ouvert pour laisser l'admin copier/communiquer le mot de passe généré
  } catch (e: any) {
    resetError.value = e?.data?.statusMessage || e?.message || 'Erreur lors de la réinitialisation.'
  } finally {
    resetting.value = false
  }
}
</script>

<template>
  <AdminShell>
    <div class="space-y-4">
      <div class="flex flex-col sm:flex-row gap-3 items-start sm:items-center">
        <input v-model="search" placeholder="Nom, prénom, matricule..." class="input sm:max-w-xs" />
        <select v-model="roleFiltre" class="input sm:max-w-[180px]">
          <option value="">Tous les rôles</option>
          <option v-for="r in roles" :key="r" :value="r">{{ roleLabels[r] }}</option>
        </select>
        <button class="btn-primary sm:ml-auto" @click="ouvrirCreation">
          <Icon name="plus" class="w-4 h-4" /> Créer un utilisateur
        </button>
      </div>

      <div class="card overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="text-left text-xs text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
            <tr><th class="p-3">Utilisateur</th><th class="p-3">Matricule</th><th class="p-3">Rôle</th><th class="p-3">Statut</th><th class="p-3">Actions</th></tr>
          </thead>
          <tbody>
            <tr v-if="loading"><td colspan="5" class="p-6 text-center text-slate-400 dark:text-slate-500">Chargement...</td></tr>
            <tr v-for="u in users" :key="u.id" class="border-b border-slate-50 dark:border-slate-800 last:border-0">
              <td class="p-3"><p class="font-medium">{{ u.prenom }} {{ u.nom }}</p><p class="text-xs text-slate-400 dark:text-slate-500">{{ u.email_pro }}</p></td>
              <td class="p-3 whitespace-nowrap">{{ u.matricule }}</td>
              <td class="p-3">
                <select :value="u.role" class="input !py-1.5 !text-xs" @change="changerRole(u, ($event.target as HTMLSelectElement).value)">
                  <option v-for="r in roles" :key="r" :value="r">{{ roleLabels[r] }}</option>
                </select>
              </td>
              <td class="p-3"><span class="badge" :class="statutStyle[u.status]">{{ statutLabels[u.status] }}</span></td>
              <td class="p-3">
                <div class="flex flex-wrap gap-1.5">
                  <button class="btn-secondary !px-2.5 !py-1.5 !text-xs" title="Modifier" @click="ouvrirEdition(u)">
                    <Icon name="edit" class="w-3.5 h-3.5" />
                  </button>
                  <button class="btn-secondary !px-2.5 !py-1.5 !text-xs" title="Réinitialiser le mot de passe" @click="ouvrirReset(u)">
                    <Icon name="shield" class="w-3.5 h-3.5" />
                  </button>
                  <button v-if="u.status !== 'actif'" class="btn-secondary !px-2.5 !py-1.5 !text-xs" @click="changerStatut(u, 'actif')">Activer</button>
                  <button v-if="u.status === 'actif'" class="btn-secondary !px-2.5 !py-1.5 !text-xs" @click="changerStatut(u, 'suspendu')">Suspendre</button>
                  <button v-if="u.status !== 'desactive'" class="btn-danger !px-2.5 !py-1.5 !text-xs" @click="changerStatut(u, 'desactive')">Désactiver</button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Modal création utilisateur -->
    <Transition name="fade">
      <div v-if="creationOuverte" class="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" @click.self="creationOuverte = false">
        <div class="card w-full max-w-lg max-h-[90vh] overflow-y-auto p-5 space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="font-semibold text-slate-800 dark:text-slate-100">Créer un utilisateur</h2>
            <button class="btn-secondary !px-2.5 !py-1.5" @click="creationOuverte = false"><Icon name="x" class="w-4 h-4" /></button>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div><label class="label">Matricule *</label><input v-model="nouveau.matricule" class="input uppercase" placeholder="I001" maxlength="6" /></div>
            <div>
              <label class="label">Rôle *</label>
              <select v-model="nouveau.role" class="input">
                <option v-for="r in roles" :key="r" :value="r">{{ roleLabels[r] }}</option>
              </select>
            </div>
            <div><label class="label">Nom *</label><input v-model="nouveau.nom" class="input" /></div>
            <div><label class="label">Prénom *</label><input v-model="nouveau.prenom" class="input" /></div>
            <div class="sm:col-span-2"><label class="label">Email professionnel *</label><input v-model="nouveau.email_pro" type="email" class="input" /></div>
            <div><label class="label">Téléphone</label><input v-model="nouveau.telephone" class="input" /></div>
            <div><label class="label">Fonction</label><input v-model="nouveau.fonction" class="input" /></div>
            <div>
              <label class="label">Direction</label>
              <select v-model="nouveau.direction_id" class="input">
                <option value="">—</option>
                <option v-for="d in directions" :key="d.id" :value="d.id">{{ d.nom }}</option>
              </select>
            </div>
            <div>
              <label class="label">Service</label>
              <select v-model="nouveau.service_id" class="input">
                <option value="">—</option>
                <option v-for="s in servicesFiltresCreation" :key="s.id" :value="s.id">{{ s.nom }}</option>
              </select>
            </div>
          </div>

          <div class="rounded-xl bg-brand-50 dark:bg-brand-950 p-3 space-y-2">
            <label class="label !mb-0">Mot de passe temporaire</label>
            <div class="flex gap-2">
              <input v-model="nouveau.mot_de_passe" class="input font-mono" />
              <button type="button" class="btn-secondary shrink-0" @click="nouveau.mot_de_passe = motDePasseAleatoire()">Régénérer</button>
            </div>
            <p class="text-xs text-brand-800 dark:text-brand-300">
              Communiquez ce mot de passe à l'utilisateur avec son matricule <strong>{{ nouveau.matricule || '...' }}</strong>.
              À sa première connexion, il pourra le conserver ou le changer immédiatement.
            </p>
          </div>

          <p v-if="createError" class="text-sm text-red-600">{{ createError }}</p>

          <div class="flex gap-3">
            <button class="btn-secondary flex-1" @click="creationOuverte = false">Annuler</button>
            <button class="btn-primary flex-1" :disabled="creating" @click="creerUtilisateur">
              {{ creating ? 'Création...' : 'Créer le compte' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- Modal modification utilisateur -->
    <Transition name="fade">
      <div v-if="editionOuverte" class="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" @click.self="editionOuverte = false">
        <div class="card w-full max-w-lg max-h-[90vh] overflow-y-auto p-5 space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="font-semibold text-slate-800 dark:text-slate-100">Modifier {{ edite.prenom }} {{ edite.nom }}</h2>
            <button class="btn-secondary !px-2.5 !py-1.5" @click="editionOuverte = false"><Icon name="x" class="w-4 h-4" /></button>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div><label class="label">Matricule *</label><input v-model="edite.matricule" class="input uppercase" maxlength="6" /></div>
            <div><label class="label">Téléphone</label><input v-model="edite.telephone" class="input" /></div>
            <div><label class="label">Nom *</label><input v-model="edite.nom" class="input" /></div>
            <div><label class="label">Prénom *</label><input v-model="edite.prenom" class="input" /></div>
            <div class="sm:col-span-2">
              <label class="label">Email professionnel *</label>
              <input v-model="edite.email_pro" type="email" class="input" />
              <p class="text-xs text-slate-400 dark:text-slate-500 mt-1">Modifier l'email met aussi à jour l'identifiant de connexion.</p>
            </div>
            <div><label class="label">Fonction</label><input v-model="edite.fonction" class="input" /></div>
            <div>
              <label class="label">Direction</label>
              <select v-model="edite.direction_id" class="input">
                <option value="">—</option>
                <option v-for="d in directions" :key="d.id" :value="d.id">{{ d.nom }}</option>
              </select>
            </div>
            <div>
              <label class="label">Service</label>
              <select v-model="edite.service_id" class="input">
                <option value="">—</option>
                <option v-for="s in servicesFiltresEdition" :key="s.id" :value="s.id">{{ s.nom }}</option>
              </select>
            </div>
          </div>

          <p v-if="editError" class="text-sm text-red-600">{{ editError }}</p>

          <div class="flex gap-3">
            <button class="btn-secondary flex-1" @click="editionOuverte = false">Annuler</button>
            <button class="btn-primary flex-1" :disabled="editing" @click="modifierUtilisateur">
              {{ editing ? 'Enregistrement...' : 'Enregistrer' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- Modal réinitialisation mot de passe -->
    <Transition name="fade">
      <div v-if="resetOuvert" class="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" @click.self="resetOuvert = false">
        <div class="card w-full max-w-md p-5 space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="font-semibold text-slate-800 dark:text-slate-100">Réinitialiser le mot de passe</h2>
            <button class="btn-secondary !px-2.5 !py-1.5" @click="resetOuvert = false"><Icon name="x" class="w-4 h-4" /></button>
          </div>
          <p class="text-sm text-slate-500 dark:text-slate-400">
            Pour <strong>{{ resetCible.nomComplet }}</strong> ({{ resetCible.matricule }}) — utile en cas de mot de passe oublié.
          </p>

          <div class="rounded-xl bg-brand-50 dark:bg-brand-950 p-3 space-y-2">
            <label class="label !mb-0">Nouveau mot de passe</label>
            <div class="flex gap-2">
              <input v-model="resetCible.mot_de_passe" class="input font-mono" />
              <button type="button" class="btn-secondary shrink-0" @click="resetCible.mot_de_passe = motDePasseAleatoire()">Régénérer</button>
            </div>
            <p class="text-xs text-brand-800 dark:text-brand-300">
              Communiquez ce mot de passe à l'utilisateur. À sa prochaine connexion, il pourra le garder ou le modifier.
            </p>
          </div>

          <p v-if="resetError" class="text-sm text-red-600">{{ resetError }}</p>

          <div class="flex gap-3">
            <button class="btn-secondary flex-1" @click="resetOuvert = false">Fermer</button>
            <button class="btn-primary flex-1" :disabled="resetting" @click="reinitialiserMotDePasse">
              {{ resetting ? 'Réinitialisation...' : 'Réinitialiser' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </AdminShell>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: opacity 0.15s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
