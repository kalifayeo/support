<script setup lang="ts">
// Recherche globale : matricule, nom, numéro de fiche, n° inventaire, n° série, IMEI...
// section 20. Le résultat respecte strictement les RLS : un utilisateur ne
// voit jamais une fiche à laquelle il n'a pas droit, même via la recherche.
const supabase = useSupabaseClient()
const router = useRouter()

const q = ref('')
const results = ref<{ type: 'fiche' | 'equipement'; id: string; label: string; sub: string }[]>([])
const open = ref(false)
let debounceTimer: ReturnType<typeof setTimeout>

watch(q, (val) => {
  clearTimeout(debounceTimer)
  if (val.trim().length < 2) { results.value = []; open.value = false; return }
  debounceTimer = setTimeout(() => runSearch(val.trim()), 300)
})

async function runSearch(term: string) {
  const [{ data: fiches }, { data: equipements }] = await Promise.all([
    supabase.from('forms').select('id, numero, statut').ilike('numero', `%${term}%`).limit(5),
    supabase.from('equipments')
      .select('id, numero_inventaire, numero_serie, imei, marque, modele')
      .or(`numero_inventaire.ilike.%${term}%,numero_serie.ilike.%${term}%,imei.ilike.%${term}%`)
      .limit(5),
  ])

  results.value = [
    ...(fiches ?? []).map(f => ({ type: 'fiche' as const, id: f.id, label: f.numero, sub: f.statut })),
    ...(equipements ?? []).map(e => ({
      type: 'equipement' as const, id: e.id,
      label: `${e.marque ?? ''} ${e.modele ?? ''}`.trim() || e.numero_inventaire,
      sub: e.numero_inventaire,
    })),
  ]
  open.value = results.value.length > 0
}

function goTo(r: typeof results.value[number]) {
  open.value = false
  q.value = ''
  router.push(r.type === 'fiche' ? `/fiches/${r.id}` : `/parc/${r.id}`)
}
</script>

<template>
  <div class="relative">
    <div class="relative">
      <Icon name="search" class="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 dark:text-slate-500" />
      <input v-model="q" type="search" placeholder="Rechercher une fiche, un matériel, un matricule..."
             class="input !pl-9" @focus="open = results.length > 0" @blur="setTimeout(() => open = false, 150)" />
    </div>
    <div v-if="open" class="absolute mt-1 w-full card p-1 z-50 max-h-72 overflow-y-auto">
      <button v-for="r in results" :key="r.type + r.id" class="w-full text-left px-3 py-2 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800/60 dark:bg-slate-800/60 flex justify-between items-center"
              @mousedown.prevent="goTo(r)">
        <span class="text-sm font-medium">{{ r.label }}</span>
        <span class="text-xs text-slate-400 dark:text-slate-500">{{ r.sub }}</span>
      </button>
    </div>
  </div>
</template>
