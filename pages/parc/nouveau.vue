<script setup lang="ts">
definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin', 'technicien'] })
const supabase = useSupabaseClient()
const router = useRouter()

const categories = ref<any[]>([])
const saving = ref(false)
const error = ref('')

const form = reactive({
  numero_inventaire: '', numero_serie: '', imei: '', categorie_id: '',
  marque: '', modele: '', reference: '', capacite: '', ram: '', stockage: '', os: '',
  etat: 'neuf', localisation: '', date_acquisition: '', garantie_fin: '', observations: '',
})

onMounted(async () => {
  const { data } = await supabase.from('equipment_categories').select('*').order('nom')
  categories.value = data ?? []
})

async function enregistrer() {
  error.value = ''
  if (!form.numero_inventaire || !form.categorie_id) { error.value = "Numéro d'inventaire et catégorie requis."; return }
  saving.value = true
  const payload = { ...form }
  for (const k of ['date_acquisition', 'garantie_fin'] as const) if (!payload[k]) (payload as any)[k] = null
  const { data, error: e } = await supabase.from('equipments').insert(payload).select().single()
  saving.value = false
  if (e) { error.value = e.message; return }
  router.push(`/parc/${data.id}`)
}
</script>

<template>
  <div class="max-w-xl space-y-5">
    <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Ajouter un équipement</h1>
    <div class="card p-5 grid grid-cols-1 sm:grid-cols-2 gap-3">
      <div><label class="label">N° d'inventaire *</label><input v-model="form.numero_inventaire" class="input" /></div>
      <div>
        <label class="label">Catégorie *</label>
        <select v-model="form.categorie_id" class="input">
          <option value="" disabled>Choisir...</option>
          <option v-for="c in categories" :key="c.id" :value="c.id">{{ c.nom }}</option>
        </select>
      </div>
      <div><label class="label">Marque</label><input v-model="form.marque" class="input" /></div>
      <div><label class="label">Modèle</label><input v-model="form.modele" class="input" /></div>
      <div><label class="label">N° de série</label><input v-model="form.numero_serie" class="input" /></div>
      <div><label class="label">IMEI</label><input v-model="form.imei" class="input" /></div>
      <div><label class="label">RAM</label><input v-model="form.ram" class="input" /></div>
      <div><label class="label">Stockage</label><input v-model="form.stockage" class="input" /></div>
      <div>
        <label class="label">État</label>
        <select v-model="form.etat" class="input">
          <option value="neuf">Neuf</option><option value="bon_etat">Bon état</option>
          <option value="usage">Usagé</option><option value="defectueux">Défectueux</option>
        </select>
      </div>
      <div><label class="label">Localisation</label><input v-model="form.localisation" class="input" /></div>
      <div><label class="label">Date d'acquisition</label><input v-model="form.date_acquisition" type="date" class="input" /></div>
      <div><label class="label">Fin de garantie</label><input v-model="form.garantie_fin" type="date" class="input" /></div>
    </div>
    <p v-if="error" class="text-sm text-red-600">{{ error }}</p>
    <button class="btn-primary" :disabled="saving" @click="enregistrer">{{ saving ? 'Enregistrement...' : "Enregistrer l'équipement" }}</button>
  </div>
</template>
