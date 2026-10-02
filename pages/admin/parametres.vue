<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin'] })
const supabase = useSupabaseClient()
const { fetchSettings } = useSettings()

const orgNom = ref('')
const logoUrl = ref('')
const badgeUrl = ref('')
const badgeActif = ref(true)

const annonceTexte = ref('')
const annonceActive = ref(false)
const annonceType = ref('info')
const annonceExpiration = ref('')

const animationsActives = ref(true)
const cgu = ref('')

const contactEmail = ref('')
const contactTelephone = ref('')

const maintenanceActif = ref(false)
const maintenanceMessage = ref('')

const loading = ref(true)
const saving = ref(false)
const savedMessage = ref('')
const uploadingLogo = ref(false)
const uploadingBadge = ref(false)
const erreur = ref('')

const typesAnnonce = [
  { value: 'info', label: 'Information' },
  { value: 'avertissement', label: 'Avertissement' },
  { value: 'urgent', label: 'Urgent' },
]

async function charger() {
  const { data } = await supabase.from('settings').select('*')
  for (const row of data ?? []) {
    if (row.cle === 'organisation') { orgNom.value = row.valeur.nom ?? ''; logoUrl.value = row.valeur.logo_url ?? '' }
    if (row.cle === 'badge') { badgeUrl.value = row.valeur.url ?? ''; badgeActif.value = row.valeur.actif ?? true }
    if (row.cle === 'annonce') {
      annonceTexte.value = row.valeur.texte ?? ''
      annonceActive.value = row.valeur.actif ?? false
      annonceType.value = row.valeur.type ?? 'info'
      annonceExpiration.value = row.valeur.expiration ?? ''
    }
    if (row.cle === 'apparence') animationsActives.value = row.valeur.animations ?? true
    if (row.cle === 'conditions_generales_utilisation') cgu.value = row.valeur.texte ?? ''
    if (row.cle === 'contact') { contactEmail.value = row.valeur.email ?? ''; contactTelephone.value = row.valeur.telephone ?? '' }
    if (row.cle === 'maintenance') { maintenanceActif.value = row.valeur.actif ?? false; maintenanceMessage.value = row.valeur.message ?? '' }
  }
  loading.value = false
}
onMounted(charger)

async function televerser(file: File, prefix: string): Promise<string | null> {
  erreur.value = ''
  const chemin = `${prefix}-${Date.now()}.${file.name.split('.').pop()}`
  const { error } = await supabase.storage.from('assets').upload(chemin, file, { upsert: true })
  if (error) { erreur.value = `Échec de l'envoi : ${error.message}`; return null }
  const { data } = supabase.storage.from('assets').getPublicUrl(chemin)
  return data.publicUrl
}

async function changerLogo(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!file) return
  uploadingLogo.value = true
  const url = await televerser(file, 'logo')
  if (url) logoUrl.value = url
  uploadingLogo.value = false
}

async function changerBadge(e: Event) {
  const file = (e.target as HTMLInputElement).files?.[0]
  if (!file) return
  uploadingBadge.value = true
  const url = await televerser(file, 'badge')
  if (url) badgeUrl.value = url
  uploadingBadge.value = false
}

async function enregistrer() {
  saving.value = true
  erreur.value = ''
  await Promise.all([
    supabase.from('settings').update({ valeur: { nom: orgNom.value, logo_url: logoUrl.value || null } }).eq('cle', 'organisation'),
    supabase.from('settings').update({ valeur: { url: badgeUrl.value || '/badge-61ans.png', actif: badgeActif.value } }).eq('cle', 'badge'),
    supabase.from('settings').update({ valeur: { texte: annonceTexte.value, actif: annonceActive.value, type: annonceType.value, expiration: annonceExpiration.value || null } }).eq('cle', 'annonce'),
    supabase.from('settings').update({ valeur: { animations: animationsActives.value } }).eq('cle', 'apparence'),
    supabase.from('settings').update({ valeur: { texte: cgu.value } }).eq('cle', 'conditions_generales_utilisation'),
    supabase.from('settings').update({ valeur: { email: contactEmail.value, telephone: contactTelephone.value } }).eq('cle', 'contact'),
    supabase.from('settings').update({ valeur: { actif: maintenanceActif.value, message: maintenanceMessage.value } }).eq('cle', 'maintenance'),
  ])
  await fetchSettings()
  saving.value = false
  savedMessage.value = 'Modifications enregistrées.'
  setTimeout(() => savedMessage.value = '', 3000)
}
</script>

<template>
  <AdminShell>
    <div v-if="loading" class="text-sm text-slate-400 dark:text-slate-500">Chargement...</div>
    <div v-else class="space-y-5 max-w-xl">

      <!-- Identité visuelle -->
      <div class="card p-5 space-y-4">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Identité visuelle</h2>
        <div>
          <label class="label">Nom de l'organisation</label>
          <input v-model="orgNom" class="input" />
        </div>
        <div>
          <label class="label">Logo (sidebar, page de connexion, fiches PDF)</label>
          <div class="flex items-center gap-3">
            <img v-if="logoUrl" :src="logoUrl" alt="Logo actuel" class="w-14 h-14 object-contain rounded-lg border border-slate-200 dark:border-slate-700 p-1" />
            <img v-else src="/logo-fratmat.png" alt="Logo par défaut" class="w-14 h-14 object-contain rounded-lg border border-slate-200 dark:border-slate-700 p-1" />
            <label class="btn-secondary cursor-pointer">
              <Icon name="edit" class="w-4 h-4" /> {{ uploadingLogo ? 'Envoi...' : 'Changer le logo' }}
              <input type="file" accept="image/*" class="hidden" :disabled="uploadingLogo" @change="changerLogo" />
            </label>
          </div>
        </div>
        <div>
          <label class="label">Badge affiché en filigrane sur toutes les pages</label>
          <div class="flex items-center gap-3 flex-wrap">
            <img v-if="badgeUrl" :src="badgeUrl" alt="Badge actuel" class="w-14 h-14 object-contain rounded-lg border border-slate-200 dark:border-slate-700 p-1" />
            <label class="btn-secondary cursor-pointer">
              <Icon name="edit" class="w-4 h-4" /> {{ uploadingBadge ? 'Envoi...' : 'Changer le badge' }}
              <input type="file" accept="image/*" class="hidden" :disabled="uploadingBadge" @change="changerBadge" />
            </label>
            <label class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400">
              <input v-model="badgeActif" type="checkbox" class="rounded" /> Afficher le badge
            </label>
          </div>
        </div>
      </div>

      <!-- Annonce / bandeau -->
      <div class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Bandeau d'annonce</h2>
        <p class="text-xs text-slate-400 dark:text-slate-500">Message affiché en haut de l'écran pour tous les utilisateurs connectés — chacun peut le fermer, il reste modifiable à tout moment.</p>
        <textarea v-model="annonceTexte" rows="2" maxlength="200" class="input" placeholder="Ex: Maintenance prévue samedi de 8h à 10h." />
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label class="label">Gravité</label>
            <select v-model="annonceType" class="input">
              <option v-for="t in typesAnnonce" :key="t.value" :value="t.value">{{ t.label }}</option>
            </select>
          </div>
          <div>
            <label class="label">Expire le (optionnel)</label>
            <input v-model="annonceExpiration" type="date" class="input" />
          </div>
        </div>
        <label class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400">
          <input v-model="annonceActive" type="checkbox" class="rounded" /> Afficher ce bandeau
        </label>
      </div>

      <!-- Contact support -->
      <div class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Contact support</h2>
        <p class="text-xs text-slate-400 dark:text-slate-500">Affiché aux utilisateurs en cas de compte suspendu ou de besoin d'aide.</p>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div><label class="label">Email</label><input v-model="contactEmail" type="email" class="input" placeholder="support@dsi.ci" /></div>
          <div><label class="label">Téléphone</label><input v-model="contactTelephone" class="input" placeholder="+225 XX XX XX XX" /></div>
        </div>
      </div>

      <!-- Mode maintenance -->
      <div class="card p-5 space-y-3 border-amber-200 dark:border-amber-900">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Mode maintenance</h2>
        <p class="text-xs text-slate-400 dark:text-slate-500">Bloque l'accès à tous les utilisateurs sauf les administrateurs. Utile pendant une intervention technique.</p>
        <textarea v-model="maintenanceMessage" rows="2" maxlength="200" class="input" placeholder="Message affiché pendant la maintenance..." />
        <label class="flex items-center gap-2 text-sm font-medium text-amber-700 dark:text-amber-400">
          <input v-model="maintenanceActif" type="checkbox" class="rounded" /> Activer le mode maintenance
        </label>
      </div>

      <!-- Apparence -->
      <div class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Apparence</h2>
        <label class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400">
          <input v-model="animationsActives" type="checkbox" class="rounded" /> Activer les animations et transitions du site
        </label>
      </div>

      <!-- Conditions générales -->
      <div class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Conditions générales d'utilisation</h2>
        <p class="text-xs text-slate-400 dark:text-slate-500">Affichées automatiquement sur les fiches PDF générées.</p>
        <textarea v-model="cgu" rows="6" class="input" />
      </div>

      <p v-if="erreur" class="text-sm text-red-600">{{ erreur }}</p>
      <p v-if="savedMessage" class="text-sm text-emerald-600">{{ savedMessage }}</p>

      <button class="btn-primary" :disabled="saving" @click="enregistrer">{{ saving ? 'Enregistrement...' : 'Enregistrer tout' }}</button>

      <!-- Modèle de la fiche PDF (organisation, textes, signatures, pied de page) -->
      <FicheModeleEditor />
    </div>
  </AdminShell>
</template>
