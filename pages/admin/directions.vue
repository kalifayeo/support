<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin'] })
const supabase = useSupabaseClient()

const directions = ref<any[]>([])
const services = ref<any[]>([])
const nouvelleDirection = ref('')
const nouveauService = reactive({ nom: '', direction_id: '' })
const erreur = ref('')

async function charger() {
  const [{ data: d }, { data: s }] = await Promise.all([
    supabase.from('directions').select('*').order('nom'),
    supabase.from('services').select('*, directions(nom)').order('nom'),
  ])
  directions.value = d ?? []
  services.value = s ?? []
}
onMounted(charger)

async function ajouterDirection() {
  if (!nouvelleDirection.value.trim()) return
  await supabase.from('directions').insert({ nom: nouvelleDirection.value.trim() })
  nouvelleDirection.value = ''
  await charger()
}
async function ajouterService() {
  if (!nouveauService.nom.trim() || !nouveauService.direction_id) return
  await supabase.from('services').insert({ nom: nouveauService.nom.trim(), direction_id: nouveauService.direction_id })
  nouveauService.nom = ''
  await charger()
}

// Un message clair si l'élément est encore utilisé ailleurs (contrainte de clé
// étrangère "on delete restrict"), plutôt que l'erreur SQL brute.
function messageErreurSuppression(e: any) {
  if (e?.code === '23503') return "Impossible de supprimer : cet élément est encore utilisé ailleurs (service, utilisateur, fiche...)."
  return e?.message ?? 'Suppression impossible.'
}

async function supprimerDirection(d: any) {
  if (!confirm(`Supprimer la direction "${d.nom}" ?`)) return
  erreur.value = ''
  const { error } = await supabase.from('directions').delete().eq('id', d.id)
  if (error) { erreur.value = messageErreurSuppression(error); return }
  await charger()
}
async function supprimerService(s: any) {
  if (!confirm(`Supprimer le service "${s.nom}" ?`)) return
  erreur.value = ''
  const { error } = await supabase.from('services').delete().eq('id', s.id)
  if (error) { erreur.value = messageErreurSuppression(error); return }
  await charger()
}
</script>

<template>
  <AdminShell>
    <p v-if="erreur" class="text-sm text-red-600 mb-3">{{ erreur }}</p>
    <div class="grid md:grid-cols-2 gap-5">
      <div class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Directions</h2>
        <div class="flex gap-2">
          <input v-model="nouvelleDirection" placeholder="Nouvelle direction" class="input" @keyup.enter="ajouterDirection" />
          <button class="btn-secondary shrink-0" @click="ajouterDirection">Ajouter</button>
        </div>
        <ul class="divide-y divide-slate-100 dark:divide-slate-800">
          <li v-for="d in directions" :key="d.id" class="py-2 text-sm flex items-center justify-between gap-2">
            <span>{{ d.nom }}</span>
            <button class="text-red-500 hover:text-red-700 shrink-0" title="Supprimer" @click="supprimerDirection(d)">
              <Icon name="trash" class="w-4 h-4" />
            </button>
          </li>
        </ul>
      </div>

      <div class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Services</h2>
        <p class="text-xs text-slate-400 dark:text-slate-500">La DSI comprend 3 services : Support informatique, Étude et développement, Exploitation.</p>
        <div class="flex flex-col sm:flex-row gap-2">
          <select v-model="nouveauService.direction_id" class="input">
            <option value="" disabled>Direction...</option>
            <option v-for="d in directions" :key="d.id" :value="d.id">{{ d.nom }}</option>
          </select>
          <input v-model="nouveauService.nom" placeholder="Nom du service" class="input" @keyup.enter="ajouterService" />
          <button class="btn-secondary shrink-0" @click="ajouterService">Ajouter</button>
        </div>
        <ul class="divide-y divide-slate-100 dark:divide-slate-800">
          <li v-for="s in services" :key="s.id" class="py-2 text-sm flex items-center justify-between gap-2">
            <span>{{ s.nom }} <span class="text-slate-400 dark:text-slate-500 text-xs">· {{ s.directions?.nom }}</span></span>
            <button class="text-red-500 hover:text-red-700 shrink-0" title="Supprimer" @click="supprimerService(s)">
              <Icon name="trash" class="w-4 h-4" />
            </button>
          </li>
        </ul>
      </div>
    </div>
  </AdminShell>
</template>
