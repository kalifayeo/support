<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin'] })
const supabase = useSupabaseClient()

const types = ref<any[]>([])
const nouveau = reactive({ code: '', nom: '', prefixe_numero: '' })
const erreur = ref('')

async function charger() {
  const { data } = await supabase.from('form_types').select('*').order('nom')
  types.value = data ?? []
}
onMounted(charger)

async function ajouter() {
  if (!nouveau.code.trim() || !nouveau.nom.trim() || !nouveau.prefixe_numero.trim()) return
  await supabase.from('form_types').insert({
    code: nouveau.code.trim().toUpperCase(),
    nom: nouveau.nom.trim(),
    prefixe_numero: nouveau.prefixe_numero.trim().toUpperCase(),
    workflow: ['technicien', 'chef_service'],
  })
  Object.assign(nouveau, { code: '', nom: '', prefixe_numero: '' })
  await charger()
}

async function toggleActif(t: any) {
  await supabase.from('form_types').update({ actif: !t.actif }).eq('id', t.id)
  t.actif = !t.actif
}

function messageErreurSuppression(e: any) {
  if (e?.code === '23503') return "Impossible de supprimer : des fiches existent déjà avec ce type. Désactivez-le plutôt."
  return e?.message ?? 'Suppression impossible.'
}

async function supprimer(t: any) {
  if (!confirm(`Supprimer le type de fiche "${t.nom}" ?`)) return
  erreur.value = ''
  const { error } = await supabase.from('form_types').delete().eq('id', t.id)
  if (error) { erreur.value = messageErreurSuppression(error); return }
  await charger()
}
</script>

<template>
  <AdminShell>
    <p v-if="erreur" class="text-sm text-red-600 mb-3">{{ erreur }}</p>
    <div class="card p-5 space-y-4 max-w-2xl">
      <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Types de fiches</h2>
      <div class="grid grid-cols-1 sm:grid-cols-4 gap-2">
        <input v-model="nouveau.code" placeholder="Code (ex: MA)" class="input uppercase" maxlength="4" />
        <input v-model="nouveau.nom" placeholder="Nom (ex: Fiche de maintenance)" class="input sm:col-span-2" />
        <input v-model="nouveau.prefixe_numero" placeholder="Préfixe (ex: MA)" class="input uppercase" maxlength="6" />
      </div>
      <button class="btn-secondary" @click="ajouter">Ajouter un type</button>

      <table class="w-full text-sm mt-2">
        <thead class="text-left text-xs text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
          <tr><th class="p-2">Code</th><th class="p-2">Nom</th><th class="p-2">Préfixe</th><th class="p-2">Actif</th><th class="p-2"></th></tr>
        </thead>
        <tbody>
          <tr v-for="t in types" :key="t.id" class="border-b border-slate-50 dark:border-slate-800 last:border-0">
            <td class="p-2 font-mono">{{ t.code }}</td>
            <td class="p-2">{{ t.nom }}</td>
            <td class="p-2 font-mono">{{ t.prefixe_numero }}</td>
            <td class="p-2">
              <button class="badge" :class="t.actif ? 'bg-emerald-50 text-emerald-700' : 'bg-slate-100 dark:bg-slate-800 text-slate-500'" @click="toggleActif(t)">
                {{ t.actif ? 'Actif' : 'Inactif' }}
              </button>
            </td>
            <td class="p-2 text-right">
              <button class="text-red-500 hover:text-red-700" title="Supprimer" @click="supprimer(t)">
                <Icon name="trash" class="w-4 h-4" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </AdminShell>
</template>
