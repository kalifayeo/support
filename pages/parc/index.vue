<script setup lang="ts">
const supabase = useSupabaseClient()
const route = useRoute()
const { canManageParc, profile } = useProfile()

const equipements = ref<any[]>([])
const categories = ref<any[]>([])
const stats = ref({ total: 0, affectes: 0, disponibles: 0, enPanne: 0 })
const loading = ref(true)
const search = ref('')
const categorieFiltre = ref('')
const etatFiltre = ref('')
const mesEquipementsSeulement = ref(route.query.mine === '1')

const etatStyle: Record<string, string> = {
  neuf: 'bg-emerald-50 text-emerald-700',
  bon_etat: 'bg-blue-50 text-blue-700',
  usage: 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400',
  defectueux: 'bg-red-50 text-red-700',
  en_reparation: 'bg-amber-50 text-amber-700',
  reforme: 'bg-slate-200 dark:bg-slate-700 text-slate-500',
}
const etatLabels: Record<string, string> = {
  neuf: 'Neuf', bon_etat: 'Bon état', usage: 'Usagé', defectueux: 'Défectueux',
  en_reparation: 'En réparation', reforme: 'Réformé',
}

async function chargerStats() {
  const [{ count: total }, { count: affectes }, { count: enPanne }] = await Promise.all([
    supabase.from('equipments').select('id', { count: 'exact', head: true }),
    supabase.from('equipments').select('id', { count: 'exact', head: true }).not('utilisateur_actuel_id', 'is', null),
    supabase.from('equipments').select('id', { count: 'exact', head: true }).in('etat', ['defectueux', 'en_reparation']),
  ])
  stats.value = {
    total: total ?? 0, affectes: affectes ?? 0,
    disponibles: (total ?? 0) - (affectes ?? 0), enPanne: enPanne ?? 0,
  }
}

async function charger() {
  loading.value = true
  let query = supabase.from('equipments')
    .select('id, numero_inventaire, marque, modele, numero_serie, etat, categorie:equipment_categories(nom), utilisateur:agents!equipments_utilisateur_actuel_id_fkey(nom, prenom, matricule)')
    .order('created_at', { ascending: false })

  if (categorieFiltre.value) query = query.eq('categorie_id', categorieFiltre.value)
  if (etatFiltre.value) query = query.eq('etat', etatFiltre.value)
  if (mesEquipementsSeulement.value && profile.value) query = query.eq('utilisateur_actuel_id', profile.value.id)
  if (search.value.trim()) query = query.or(`numero_inventaire.ilike.%${search.value}%,numero_serie.ilike.%${search.value}%,marque.ilike.%${search.value}%,modele.ilike.%${search.value}%`)

  const { data } = await query.limit(100)
  equipements.value = data ?? []
  loading.value = false
}

onMounted(async () => {
  const { data } = await supabase.from('equipment_categories').select('*').order('nom')
  categories.value = data ?? []
  await Promise.all([charger(), chargerStats()])
})
watch([categorieFiltre, etatFiltre, mesEquipementsSeulement], charger)
let t: ReturnType<typeof setTimeout>
watch(search, () => { clearTimeout(t); t = setTimeout(charger, 350) })
</script>

<template>
  <div class="space-y-5 max-w-5xl">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <div>
        <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Parc informatique</h1>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Inventaire complet du matériel de la DSI.</p>
      </div>
      <NuxtLink v-if="canManageParc" to="/parc/nouveau" class="btn-primary">
        <Icon name="plus" class="w-4 h-4" /> Ajouter un équipement
      </NuxtLink>
    </div>

    <!-- Statistiques -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div class="stat-card">
        <p class="text-2xl font-bold text-slate-800 dark:text-slate-100">{{ stats.total }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Équipements au total</p>
      </div>
      <div class="stat-card">
        <p class="text-2xl font-bold text-brand-600 dark:text-brand-400">{{ stats.affectes }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Affectés</p>
      </div>
      <div class="stat-card">
        <p class="text-2xl font-bold text-emerald-600 dark:text-emerald-400">{{ stats.disponibles }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Disponibles</p>
      </div>
      <div class="stat-card">
        <p class="text-2xl font-bold text-red-600 dark:text-red-400">{{ stats.enPanne }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">En panne / réparation</p>
      </div>
    </div>

    <div class="flex flex-col sm:flex-row gap-3">
      <input v-model="search" type="search" placeholder="N° inventaire, série, marque..." class="input sm:max-w-xs" />
      <select v-model="categorieFiltre" class="input sm:max-w-[180px]">
        <option value="">Toutes catégories</option>
        <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.nom }}</option>
      </select>
      <select v-model="etatFiltre" class="input sm:max-w-[160px]">
        <option value="">Tous états</option>
        <option v-for="(label, key) in etatLabels" :key="key" :value="key">{{ label }}</option>
      </select>
      <label class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400 px-1 shrink-0">
        <input v-model="mesEquipementsSeulement" type="checkbox" class="rounded" /> Mon matériel
      </label>
    </div>

    <div class="card divide-y divide-slate-100 dark:divide-slate-800">
      <SkeletonList v-if="loading" :rows="5" />
      <div v-else-if="equipements.length === 0" class="p-10 text-center space-y-2">
        <Icon name="server" class="w-8 h-8 mx-auto text-slate-300 dark:text-slate-600" />
        <p class="text-sm text-slate-400 dark:text-slate-500">Aucun équipement trouvé.</p>
      </div>
      <NuxtLink v-for="e in equipements" :key="e.id" :to="`/parc/${e.id}`" class="p-4 flex items-center justify-between gap-3 hover:bg-slate-50 dark:hover:bg-slate-800/60">
        <div class="min-w-0">
          <p class="text-sm font-semibold text-slate-800 dark:text-slate-100">{{ e.marque }} {{ e.modele }} <span class="text-slate-400 dark:text-slate-500 font-normal">· {{ e.categorie?.nom }}</span></p>
          <p class="text-xs text-slate-400 dark:text-slate-500 truncate">
            {{ e.numero_inventaire }}
            <span v-if="e.utilisateur">· Affecté à {{ e.utilisateur.prenom }} {{ e.utilisateur.nom }}</span>
            <span v-else>· Disponible</span>
          </p>
        </div>
        <span class="badge shrink-0" :class="etatStyle[e.etat]">{{ etatLabels[e.etat] }}</span>
      </NuxtLink>
    </div>
  </div>
</template>
