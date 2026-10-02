<script setup lang="ts">
definePageMeta({ layout: 'auth' })
const route = useRoute()
const supabase = useSupabaseClient()
const { logoUrl, fetchSettings, loaded } = useSettings()

const doc = ref<any>(null)
const loading = ref(true)

const statutLabels: Record<string, string> = {
  brouillon: 'Brouillon', en_attente: 'En attente', en_validation: 'En validation',
  validee: 'Validée', rejetee: 'Rejetée', annulee: 'Annulée', archivee: 'Archivée',
}

onMounted(async () => {
  if (!loaded.value) await fetchSettings()
  const code = route.query.code as string
  if (code) {
    const { data } = await supabase.rpc('verifier_document', { p_code: code })
    doc.value = data?.[0] ?? null
  }
  loading.value = false
})
</script>

<template>
  <div class="max-w-lg w-full card-glass p-6 space-y-4">
    <div class="text-center space-y-3">
      <img :src="logoUrl" alt="Logo" class="h-10 mx-auto object-contain" />
      <h1 class="text-lg font-bold text-slate-800 dark:text-slate-100">Vérification de document</h1>
    </div>

    <div v-if="loading" class="text-sm text-slate-400 dark:text-slate-500 text-center">Vérification...</div>

    <template v-else-if="doc">
      <div class="text-center space-y-2">
        <div class="w-12 h-12 rounded-full bg-emerald-50 text-emerald-600 mx-auto flex items-center justify-center">
          <Icon name="check" class="w-6 h-6" />
        </div>
        <p class="text-sm text-slate-600 dark:text-slate-400">Document authentique</p>
      </div>

      <div class="rounded-xl bg-slate-50 dark:bg-slate-800/60 p-4 space-y-3 text-sm">
        <div class="flex justify-between">
          <span class="font-semibold text-slate-800 dark:text-slate-100">{{ doc.numero }}</span>
          <span class="badge bg-emerald-50 text-emerald-700">{{ statutLabels[doc.statut] ?? doc.statut }}</span>
        </div>
        <p class="text-xs text-slate-400 dark:text-slate-500">{{ doc.type_fiche }}</p>

        <div class="grid grid-cols-2 gap-3 pt-2 border-t border-slate-200 dark:border-slate-700">
          <div><p class="text-slate-400 dark:text-slate-500 text-xs">Direction</p><p class="font-medium">{{ doc.direction || '—' }}</p></div>
          <div><p class="text-slate-400 dark:text-slate-500 text-xs">Service</p><p class="font-medium">{{ doc.service || '—' }}</p></div>
          <div><p class="text-slate-400 dark:text-slate-500 text-xs">Établie le</p><p class="font-medium">{{ new Date(doc.cree_le).toLocaleString('fr-FR') }}</p></div>
          <div v-if="doc.valide_le"><p class="text-slate-400 dark:text-slate-500 text-xs">Validée le</p><p class="font-medium">{{ new Date(doc.valide_le).toLocaleString('fr-FR') }}</p></div>
        </div>

        <div class="pt-2 border-t border-slate-200 dark:border-slate-700">
          <p class="text-slate-400 dark:text-slate-500 text-xs mb-1">Établie par</p>
          <p class="font-medium">{{ doc.etabli_par_prenom }} {{ doc.etabli_par_nom }} <span class="text-slate-400 dark:text-slate-500 font-normal">· {{ doc.etabli_par_matricule }}</span></p>
          <p v-if="doc.etabli_par_fonction" class="text-xs text-slate-400 dark:text-slate-500">{{ doc.etabli_par_fonction }}</p>
        </div>

        <div class="pt-2 border-t border-slate-200 dark:border-slate-700">
          <p class="text-slate-400 dark:text-slate-500 text-xs mb-1">Bénéficiaire</p>
          <p class="font-medium">{{ doc.beneficiaire_prenom }} {{ doc.beneficiaire_nom }} <span class="text-slate-400 dark:text-slate-500 font-normal">· {{ doc.beneficiaire_matricule || 's.m.' }}</span></p>
          <p v-if="doc.beneficiaire_fonction" class="text-xs text-slate-400 dark:text-slate-500">{{ doc.beneficiaire_fonction }}</p>
        </div>

        <div v-if="doc.materiel" class="pt-2 border-t border-slate-200 dark:border-slate-700">
          <p class="text-slate-400 dark:text-slate-500 text-xs mb-1">Matériel</p>
          <div class="grid grid-cols-2 gap-2">
            <template v-for="(val, key) in doc.materiel" :key="key">
              <p v-if="val && key !== 'cle_activation'" class="text-xs"><span class="text-slate-400 dark:text-slate-500 capitalize">{{ String(key).replace('_', ' ') }} :</span> {{ val }}</p>
            </template>
          </div>
        </div>

        <div v-if="doc.observations" class="pt-2 border-t border-slate-200 dark:border-slate-700">
          <p class="text-slate-400 dark:text-slate-500 text-xs mb-1">Observations</p>
          <p class="text-sm">{{ doc.observations }}</p>
        </div>
      </div>
    </template>

    <template v-else>
      <div class="text-center space-y-2">
        <div class="w-12 h-12 rounded-full bg-red-50 text-red-600 mx-auto flex items-center justify-center">
          <Icon name="x" class="w-6 h-6" />
        </div>
        <p class="text-sm text-slate-600 dark:text-slate-400">Code de vérification invalide.</p>
      </div>
    </template>
  </div>
</template>
