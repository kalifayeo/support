<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin'] })
const supabase = useSupabaseClient()

const types = ref<any[]>([])
const nouveauNom = ref('')
const erreur = ref('')

async function charger() {
  const { data } = await supabase.from('rapport_types').select('*').order('nom')
  types.value = data ?? []
}
onMounted(charger)

async function ajouter() {
  if (!nouveauNom.value.trim()) return
  await supabase.from('rapport_types').insert({ nom: nouveauNom.value.trim() })
  nouveauNom.value = ''
  await charger()
}

async function toggleActif(t: any) {
  await supabase.from('rapport_types').update({ actif: !t.actif }).eq('id', t.id)
  t.actif = !t.actif
}

async function supprimer(t: any) {
  if (!confirm(`Supprimer le type "${t.nom}" ?`)) return
  erreur.value = ''
  const { error } = await supabase.from('rapport_types').delete().eq('id', t.id)
  if (error) {
    erreur.value = error.code === '23503'
      ? "Impossible de supprimer : des rapports existent déjà avec ce type. Désactivez-le plutôt."
      : error.message
    return
  }
  await charger()
}
</script>

<template>
  <AdminShell>
    <p v-if="erreur" class="text-sm text-red-600 mb-3">{{ erreur }}</p>
    <div class="card p-5 space-y-3 max-w-xl">
      <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Types de rapport</h2>
      <p class="text-xs text-slate-400 dark:text-slate-500">
        Les catégories de rapports de travail que la DSI utilise — ajoute ou retire librement.
      </p>
      <div class="flex gap-2">
        <input v-model="nouveauNom" placeholder="Ex: Rapport trimestriel" class="input" @keyup.enter="ajouter" />
        <button class="btn-secondary shrink-0" @click="ajouter">Ajouter</button>
      </div>
      <ul class="divide-y divide-slate-100 dark:divide-slate-800">
        <li v-for="t in types" :key="t.id" class="py-2 text-sm flex items-center justify-between gap-2">
          <span>{{ t.nom }}</span>
          <div class="flex items-center gap-2 shrink-0">
            <button class="badge" :class="t.actif ? 'bg-emerald-50 text-emerald-700' : 'bg-slate-100 dark:bg-slate-800 text-slate-500'" @click="toggleActif(t)">
              {{ t.actif ? 'Actif' : 'Inactif' }}
            </button>
            <button class="text-red-500 hover:text-red-700" title="Supprimer" @click="supprimer(t)">
              <Icon name="trash" class="w-4 h-4" />
            </button>
          </div>
        </li>
      </ul>
    </div>
  </AdminShell>
</template>
