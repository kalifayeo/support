<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin'] })
const supabase = useSupabaseClient()

const categories = ref<any[]>([])
const nouvelleCategorie = reactive({ nom: '', necessite_imei: false })
const erreur = ref('')

async function charger() {
  const { data } = await supabase.from('equipment_categories').select('*').order('nom')
  categories.value = data ?? []
}
onMounted(charger)

async function ajouter() {
  if (!nouvelleCategorie.nom.trim()) return
  await supabase.from('equipment_categories').insert({ nom: nouvelleCategorie.nom.trim(), necessite_imei: nouvelleCategorie.necessite_imei })
  nouvelleCategorie.nom = ''
  nouvelleCategorie.necessite_imei = false
  await charger()
}

function messageErreurSuppression(e: any) {
  if (e?.code === '23503') return "Impossible de supprimer : des équipements utilisent encore cette catégorie."
  return e?.message ?? 'Suppression impossible.'
}

async function supprimer(c: any) {
  if (!confirm(`Supprimer la catégorie "${c.nom}" ?`)) return
  erreur.value = ''
  const { error } = await supabase.from('equipment_categories').delete().eq('id', c.id)
  if (error) { erreur.value = messageErreurSuppression(error); return }
  await charger()
}
</script>

<template>
  <AdminShell>
    <p v-if="erreur" class="text-sm text-red-600 mb-3">{{ erreur }}</p>
    <div class="card p-5 space-y-3 max-w-xl">
      <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Catégories de matériel</h2>
      <div class="flex flex-col sm:flex-row gap-2">
        <input v-model="nouvelleCategorie.nom" placeholder="Nouvelle catégorie (ex: Casque audio)" class="input" @keyup.enter="ajouter" />
        <label class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-400 px-1 shrink-0">
          <input v-model="nouvelleCategorie.necessite_imei" type="checkbox" class="rounded" /> Nécessite IMEI
        </label>
        <button class="btn-secondary shrink-0" @click="ajouter">Ajouter</button>
      </div>
      <ul class="divide-y divide-slate-100 dark:divide-slate-800">
        <li v-for="c in categories" :key="c.id" class="py-2 text-sm flex items-center justify-between gap-2">
          <span>{{ c.nom }} <span v-if="c.necessite_imei" class="badge bg-brand-50 text-brand-700 dark:bg-brand-950 dark:text-brand-400 ml-1">IMEI</span></span>
          <button class="text-red-500 hover:text-red-700 shrink-0" title="Supprimer" @click="supprimer(c)">
            <Icon name="trash" class="w-4 h-4" />
          </button>
        </li>
      </ul>
    </div>
  </AdminShell>
</template>
