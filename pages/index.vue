<script setup lang="ts">
const { profile, canCreateFiche, canValidate, isAdmin } = useProfile()
const supabase = useSupabaseClient()

const stats = ref({
  creees: 0, attente: 0, validees: 0, mesEquipements: 0,
  mesInterventions: 0, aValider: 0, utilisateursEnAttente: 0, equipementsEnPanne: 0,
})
const activites = ref<any[]>([])
const interventionsUrgentes = ref<any[]>([])

onMounted(async () => {
  if (!profile.value) return
  const uid = profile.value.id

  const requetes: Promise<any>[] = [
    supabase.from('forms').select('id', { count: 'exact', head: true }).eq('cree_par', uid),
    supabase.from('forms').select('id', { count: 'exact', head: true }).eq('cree_par', uid).in('statut', ['en_attente', 'en_validation']),
    supabase.from('forms').select('id', { count: 'exact', head: true }).eq('cree_par', uid).eq('statut', 'validee'),
    supabase.from('equipments').select('id', { count: 'exact', head: true }).eq('utilisateur_actuel_id', uid),
    supabase.from('interventions').select('id', { count: 'exact', head: true }).eq('technicien_id', uid).in('statut', ['nouvelle', 'en_cours', 'en_attente_piece']),
  ]
  const [{ count: creees }, { count: attente }, { count: validees }, { count: equip }, { count: mesInterv }] = await Promise.all(requetes)

  let aValider = 0
  if (canValidate.value) {
    let q = supabase.from('forms').select('id', { count: 'exact', head: true }).in('statut', ['en_attente', 'en_validation'])
    if (!isAdmin.value && profile.value.service_id) q = q.eq('service_id', profile.value.service_id)
    const { count } = await q
    aValider = count ?? 0
  }

  let utilisateursEnAttente = 0
  let equipementsEnPanne = 0
  if (isAdmin.value) {
    const [{ count: uw }, { count: ep }] = await Promise.all([
      supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('status', 'en_attente'),
      supabase.from('equipments').select('id', { count: 'exact', head: true }).in('etat', ['defectueux', 'en_reparation']),
    ])
    utilisateursEnAttente = uw ?? 0
    equipementsEnPanne = ep ?? 0
  }

  stats.value = {
    creees: creees ?? 0, attente: attente ?? 0, validees: validees ?? 0, mesEquipements: equip ?? 0,
    mesInterventions: mesInterv ?? 0, aValider, utilisateursEnAttente, equipementsEnPanne,
  }

  const { data } = await supabase
    .from('form_validations')
    .select('id, nouveau_statut, created_at, forms(numero)')
    .order('created_at', { ascending: false })
    .limit(6)
  activites.value = data ?? []

  const { data: urgentes } = await supabase.from('interventions')
    .select('id, numero, titre, priorite')
    .eq('technicien_id', uid).in('statut', ['nouvelle', 'en_cours'])
    .in('priorite', ['haute', 'urgente'])
    .order('created_at', { ascending: false }).limit(4)
  interventionsUrgentes.value = urgentes ?? []
})

const actions = computed(() => {
  const list = []
  list.push({ to: '/interventions/nouvelle', label: 'Nouvelle intervention', icon: 'wrench' })
  list.push({ to: '/interventions', label: 'Mes interventions', icon: 'wrench' })
  list.push({ to: '/rapports/nouveau', label: 'Nouveau rapport de travail', icon: 'clipboard' })
  if (canCreateFiche.value) {
    list.push({ to: '/fiches/nouvelle?type=FA', label: 'Nouvelle fiche d\'affectation', icon: 'plus' })
    list.push({ to: '/fiches/nouvelle?type=RE', label: 'Déclarer une restitution', icon: 'file' })
  }
  list.push({ to: '/fiches', label: 'Consulter mes fiches', icon: 'file' })
  list.push({ to: '/parc?mine=1', label: 'Consulter mon matériel', icon: 'server' })
  list.push({ to: '/fiches?search=1', label: 'Rechercher une fiche', icon: 'search' })
  list.push({ to: '/notifications', label: 'Consulter les notifications', icon: 'bell' })
  list.push({ to: '/mon-espace', label: 'Mon profil', icon: 'users' })
  return list
})

const statutLabels: Record<string, string> = {
  brouillon: 'Brouillon', en_attente: 'En attente', en_validation: 'En validation',
  validee: 'Validée', rejetee: 'Rejetée', annulee: 'Annulée', archivee: 'Archivée',
}
const prioriteLabels: Record<string, string> = { basse: 'Basse', normale: 'Normale', haute: 'Haute', urgente: 'Urgente' }
</script>

<template>
  <div class="space-y-6 max-w-5xl">
    <div>
      <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Bonjour {{ profile?.prenom }} 👋</h1>
      <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
        {{ profile?.fonction || 'Agent DSI' }} · Matricule {{ profile?.matricule }}
      </p>
    </div>

    <!-- Alerte fiches à valider (chef de service / directeur / admin) -->
    <NuxtLink v-if="canValidate && stats.aValider > 0" to="/fiches" class="card p-4 flex items-center justify-between bg-amber-50 dark:bg-amber-950 border-amber-200 dark:border-amber-900 hover:shadow transition">
      <div class="flex items-center gap-3">
        <div class="w-9 h-9 rounded-xl bg-amber-100 dark:bg-amber-900 text-amber-700 dark:text-amber-400 flex items-center justify-center shrink-0">
          <Icon name="clock" class="w-5 h-5" />
        </div>
        <p class="text-sm font-medium text-amber-800 dark:text-amber-300">{{ stats.aValider }} fiche(s) en attente de votre validation</p>
      </div>
      <Icon name="chevron-right" class="w-4 h-4 text-amber-600" />
    </NuxtLink>

    <!-- Alerte admin -->
    <div v-if="isAdmin && (stats.utilisateursEnAttente > 0 || stats.equipementsEnPanne > 0)" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
      <NuxtLink v-if="stats.utilisateursEnAttente > 0" to="/admin/utilisateurs" class="card p-4 flex items-center justify-between hover:shadow transition">
        <p class="text-sm font-medium text-slate-700 dark:text-slate-300">{{ stats.utilisateursEnAttente }} compte(s) en attente d'activation</p>
        <Icon name="chevron-right" class="w-4 h-4 text-slate-300" />
      </NuxtLink>
      <NuxtLink v-if="stats.equipementsEnPanne > 0" to="/parc?etat=defectueux" class="card p-4 flex items-center justify-between hover:shadow transition">
        <p class="text-sm font-medium text-slate-700 dark:text-slate-300">{{ stats.equipementsEnPanne }} équipement(s) en panne / réparation</p>
        <Icon name="chevron-right" class="w-4 h-4 text-slate-300" />
      </NuxtLink>
    </div>

    <!-- Interventions urgentes assignées -->
    <div v-if="interventionsUrgentes.length" class="card p-4 space-y-2">
      <p class="text-xs font-semibold text-red-600 uppercase">Interventions prioritaires qui vous sont assignées</p>
      <NuxtLink v-for="i in interventionsUrgentes" :key="i.id" :to="`/interventions/${i.id}`" class="flex items-center justify-between py-1.5 hover:bg-slate-50 dark:hover:bg-slate-800/60 rounded-lg px-2 -mx-2">
        <p class="text-sm">{{ i.numero }} — {{ i.titre }}</p>
        <span class="badge bg-red-50 text-red-700">{{ prioriteLabels[i.priorite] }}</span>
      </NuxtLink>
    </div>

    <!-- Statistiques -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <div class="stat-card">
        <p class="text-2xl font-bold text-slate-800 dark:text-slate-100">{{ stats.creees }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Fiches créées</p>
      </div>
      <div class="stat-card">
        <p class="text-2xl font-bold text-amber-600">{{ stats.attente }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">En attente</p>
      </div>
      <div class="stat-card">
        <p class="text-2xl font-bold text-emerald-600">{{ stats.validees }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Validées</p>
      </div>
      <div class="stat-card">
        <p class="text-2xl font-bold text-brand-600">{{ stats.mesEquipements }}</p>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Mon matériel</p>
      </div>
    </div>

    <!-- Actions rapides -->
    <div>
      <h2 class="text-sm font-semibold text-slate-600 dark:text-slate-400 mb-3">Que souhaitez-vous faire ?</h2>
      <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
        <NuxtLink v-for="a in actions" :key="a.to" :to="a.to"
          class="card-link p-4 flex flex-col items-start gap-3 relative">
          <div class="w-9 h-9 rounded-xl bg-brand-50 dark:bg-brand-950 text-brand-600 dark:text-brand-400 flex items-center justify-center">
            <Icon :name="a.icon" class="w-5 h-5" />
          </div>
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300">{{ a.label }}</span>
          <span v-if="a.to === '/interventions' && stats.mesInterventions > 0" class="absolute top-3 right-3 badge bg-red-50 text-red-700 !px-2 !py-0.5 !text-[11px]">{{ stats.mesInterventions }}</span>
        </NuxtLink>
      </div>
    </div>

    <!-- Activité récente -->
    <div>
      <h2 class="text-sm font-semibold text-slate-600 dark:text-slate-400 mb-3">Activités récentes</h2>
      <div class="card divide-y divide-slate-100 dark:divide-slate-800">
        <div v-if="activites.length === 0" class="p-4 text-sm text-slate-400 dark:text-slate-500">Aucune activité récente.</div>
        <div v-for="a in activites" :key="a.id" class="p-4 flex items-center justify-between">
          <div>
            <p class="text-sm font-medium text-slate-700 dark:text-slate-300">{{ a.forms?.numero }}</p>
            <p class="text-xs text-slate-400 dark:text-slate-500">{{ new Date(a.created_at).toLocaleString('fr-FR') }}</p>
          </div>
          <span class="badge bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400">{{ statutLabels[a.nouveau_statut] }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
