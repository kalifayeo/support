<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin'] })
const supabase = useSupabaseClient()

const agents = ref<any[]>([])
const directions = ref<any[]>([])
const services = ref<any[]>([])
const loading = ref(true)
const search = ref('')
const serviceFiltre = ref('')
const erreur = ref('')

async function charger() {
  loading.value = true
  let q = supabase.from('agents').select('*, directions(nom), services(nom)').order('nom')
  if (serviceFiltre.value) q = q.eq('service_id', serviceFiltre.value)
  if (search.value.trim()) q = q.or(`nom.ilike.%${search.value}%,prenom.ilike.%${search.value}%,matricule.ilike.%${search.value}%`)
  const { data } = await q.limit(200)
  agents.value = data ?? []
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
watch(serviceFiltre, charger)
let t: ReturnType<typeof setTimeout>
watch(search, () => { clearTimeout(t); t = setTimeout(charger, 350) })

async function supprimer(a: any) {
  if (!confirm(`Supprimer l'agent "${a.prenom} ${a.nom}" du répertoire ?`)) return
  erreur.value = ''
  const { error } = await supabase.from('agents').delete().eq('id', a.id)
  if (error) {
    erreur.value = error.code === '23503'
      ? "Impossible de supprimer : cet agent est référencé dans une fiche, une intervention ou un équipement."
      : error.message
    return
  }
  await charger()
}
</script>

<template>
  <AdminShell>
  <div class="space-y-4 max-w-4xl">
    <div>
      <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Répertoire des agents</h1>
      <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
        Toutes les personnes pouvant recevoir du matériel ou être concernées par une fiche/intervention —
        avec ou sans compte de connexion à l'application.
      </p>
    </div>

    <p v-if="erreur" class="text-sm text-red-600">{{ erreur }}</p>

    <div class="flex flex-col sm:flex-row gap-3">
      <input v-model="search" placeholder="Nom, prénom, matricule..." class="input sm:max-w-xs" />
      <select v-model="serviceFiltre" class="input sm:max-w-[200px]">
        <option value="">Tous les services</option>
        <option v-for="s in services" :key="s.id" :value="s.id">{{ s.nom }}</option>
      </select>
    </div>

    <div class="card overflow-x-auto">
      <table class="w-full text-sm">
        <thead class="text-left text-xs text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
          <tr><th class="p-3">Agent</th><th class="p-3">Matricule</th><th class="p-3">Service</th><th class="p-3">Compte</th><th class="p-3"></th></tr>
        </thead>
        <tbody>
          <tr v-if="loading"><td colspan="5" class="p-6 text-center text-slate-400 dark:text-slate-500">Chargement...</td></tr>
          <tr v-else-if="agents.length === 0"><td colspan="5" class="p-6 text-center text-slate-400 dark:text-slate-500">Aucun agent enregistré.</td></tr>
          <tr v-for="a in agents" :key="a.id" class="border-b border-slate-50 dark:border-slate-800 last:border-0">
            <td class="p-3"><p class="font-medium">{{ a.prenom }} {{ a.nom }}</p><p class="text-xs text-slate-400 dark:text-slate-500">{{ a.fonction || '—' }}</p></td>
            <td class="p-3 whitespace-nowrap">{{ a.matricule || '—' }}</td>
            <td class="p-3">{{ a.services?.nom || '—' }}</td>
            <td class="p-3">
              <span class="badge" :class="a.a_un_compte ? 'bg-emerald-50 text-emerald-700' : 'bg-slate-100 dark:bg-slate-800 text-slate-500'">
                {{ a.a_un_compte ? 'Oui' : 'Non' }}
              </span>
            </td>
            <td class="p-3 text-right">
              <button v-if="!a.a_un_compte" class="text-red-500 hover:text-red-700" title="Supprimer" @click="supprimer(a)">
                <Icon name="trash" class="w-4 h-4" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
  </AdminShell>
</template>
