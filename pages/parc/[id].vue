<script setup lang="ts">
import { resolveLogoDataUri } from '~/utils/pdfLogo'
import { telechargerPdf } from '~/utils/telechargerPdf'

const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()
const { logoUrl } = useSettings()
const { isAdmin, canManageParc, profile } = useProfile()

const equipement = ref<any>(null)
const mouvements = ref<any[]>([])
const loading = ref(true)
const erreur = ref('')
const generatingPdf = ref(false)

const typeLabels: Record<string, string> = {
  affectation: 'Affecté', restitution: 'Restitué', transfert: 'Transféré',
  maintenance_envoi: 'Envoyé en maintenance', maintenance_retour: 'Retour de maintenance',
  reforme: 'Réformé', perte: 'Déclaré perdu',
}
const etatLabels: Record<string, string> = {
  neuf: 'Neuf', bon_etat: 'Bon état', usage: 'Usagé', defectueux: 'Défectueux',
  en_reparation: 'En réparation', reforme: 'Réformé',
}

async function charger() {
  const { data } = await supabase.from('equipments')
    .select('*, categorie:equipment_categories(nom), utilisateur:agents!equipments_utilisateur_actuel_id_fkey(id, nom, prenom, matricule)')
    .eq('id', route.params.id).single()
  equipement.value = data

  const { data: mv } = await supabase.from('equipment_movements')
    .select('*, utilisateur:agents!equipment_movements_utilisateur_id_fkey(nom, prenom), effectue_par:profiles!equipment_movements_effectue_par_fkey(nom, prenom), forms(numero)')
    .eq('equipment_id', route.params.id).order('created_at', { ascending: false })
  mouvements.value = mv ?? []
  loading.value = false
}
onMounted(charger)

// Personnes distinctes ayant déjà utilisé l'équipement (historique des porteurs)
const anciensUtilisateurs = computed(() => {
  const vus = new Set<string>()
  const liste: any[] = []
  for (const m of mouvements.value) {
    if (m.utilisateur && !vus.has(m.utilisateur.nom + m.utilisateur.prenom)) {
      vus.add(m.utilisateur.nom + m.utilisateur.prenom)
      liste.push(m.utilisateur)
    }
  }
  return liste
})

// --- Affectation / restitution en direct ---
const modalAffectationOuverte = ref(false)
const agents = ref<any[]>([])
const matriculeRecherche = ref('')
const agentSelectionneId = ref('')
const affectationEnCours = ref(false)

async function rechercherAgent() {
  erreur.value = ''
  if (!matriculeRecherche.value) return
  const { data } = await supabase.from('agents').select('id, nom, prenom, matricule')
    .eq('matricule', matriculeRecherche.value.toUpperCase()).maybeSingle()
  if (data) {
    agents.value = [data]
    agentSelectionneId.value = data.id
  } else {
    erreur.value = 'Aucun agent trouvé pour ce matricule.'
  }
}

async function confirmerAffectation() {
  if (!agentSelectionneId.value) return
  affectationEnCours.value = true
  try {
    await supabase.from('equipment_movements').insert({
      equipment_id: equipement.value.id, type: 'affectation',
      utilisateur_id: agentSelectionneId.value, effectue_par: profile.value!.id,
    })
    await supabase.from('equipments').update({ utilisateur_actuel_id: agentSelectionneId.value }).eq('id', equipement.value.id)
    modalAffectationOuverte.value = false
    matriculeRecherche.value = ''
    agentSelectionneId.value = ''
    await charger()
  } finally {
    affectationEnCours.value = false
  }
}

async function marquerRestitue() {
  if (!confirm(`Confirmer la restitution par ${equipement.value.utilisateur?.prenom} ${equipement.value.utilisateur?.nom} ?`)) return
  await supabase.from('equipment_movements').insert({
    equipment_id: equipement.value.id, type: 'restitution',
    utilisateur_id: equipement.value.utilisateur_actuel_id, effectue_par: profile.value!.id,
  })
  await supabase.from('equipments').update({ utilisateur_actuel_id: null }).eq('id', equipement.value.id)
  await charger()
}

async function supprimerEquipement() {
  if (!equipement.value) return
  if (!confirm(`Supprimer définitivement "${equipement.value.marque} ${equipement.value.modele}" (${equipement.value.numero_inventaire}) ?`)) return
  erreur.value = ''
  const { error } = await supabase.from('equipments').delete().eq('id', equipement.value.id)
  if (error) {
    erreur.value = error.code === '23503'
      ? "Impossible de supprimer : cet équipement est référencé dans une fiche existante."
      : error.message
    return
  }
  router.push('/parc')
}

// --- Export PDF : fiche d'inventaire + historique complet, façon fiche officielle ---
async function genererPdf() {
  generatingPdf.value = true
  try {
    const pdfMake = (await import('pdfmake/build/pdfmake')).default
    const pdfFonts = (await import('pdfmake/build/vfs_fonts')).default
    // @ts-ignore
    pdfMake.vfs = pdfFonts.pdfMake ? pdfFonts.pdfMake.vfs : pdfFonts.vfs

    const logoData = await resolveLogoDataUri(logoUrl.value)

    const GREEN = '#1a7a3c'
    const GREEN_DARK = '#0f5c2a'
    const e = equipement.value

    function labelCell(text: string) {
      return { text, fillColor: GREEN, color: 'white', bold: true, fontSize: 12, margin: [8, 7, 8, 7] }
    }
    function valueCell(text: string) {
      return { text, fillColor: 'white', fontSize: 12, bold: true, color: '#222', margin: [8, 7, 8, 7] }
    }

    const historiqueBody = [
      [{ text: 'Date', bold: true, fontSize: 9, fillColor: GREEN, color: 'white' },
       { text: 'Opération', bold: true, fontSize: 9, fillColor: GREEN, color: 'white' },
       { text: 'Personne', bold: true, fontSize: 9, fillColor: GREEN, color: 'white' },
       { text: 'Effectué par', bold: true, fontSize: 9, fillColor: GREEN, color: 'white' }],
      ...mouvements.value.map(m => [
        { text: new Date(m.created_at).toLocaleDateString('fr-FR'), fontSize: 9 },
        { text: typeLabels[m.type] ?? m.type, fontSize: 9 },
        { text: m.utilisateur ? `${m.utilisateur.prenom} ${m.utilisateur.nom}` : '—', fontSize: 9 },
        { text: m.effectue_par ? `${m.effectue_par.prenom} ${m.effectue_par.nom}` : '—', fontSize: 9 },
      ]),
    ]

    const docDefinition: any = {
      pageSize: 'A4',
      pageMargins: [40, 40, 40, 50],
      content: [
        { columns: [
          { image: logoData, width: 90 },
          { text: 'DSI', fontSize: 10, color: '#666', alignment: 'right', margin: [0, 10, 0, 0] },
        ] },
        { text: ' ', margin: [0, 6] },
        { table: { widths: ['*'], body: [[{ text: "FICHE D'INVENTAIRE MATÉRIEL", fillColor: GREEN_DARK, color: 'white', bold: true, fontSize: 16, alignment: 'center', margin: [0, 10, 0, 10] }]] }, layout: 'noBorders' },
        { text: ' ', margin: [0, 6] },
        { text: [{ text: 'N° inventaire : ', bold: true }, e.numero_inventaire], fontSize: 11 },
        { text: ' ', margin: [0, 6] },
        {
          table: { widths: ['30%', '70%'], body: [
            [labelCell('CATÉGORIE'), valueCell(e.categorie?.nom ?? '—')],
            [labelCell('MARQUE / MODÈLE'), valueCell(`${e.marque ?? ''} ${e.modele ?? ''}`.trim() || '—')],
            [labelCell('N° DE SÉRIE'), valueCell(e.numero_serie ?? '—')],
            [labelCell('ÉTAT'), valueCell(etatLabels[e.etat] ?? e.etat)],
            [labelCell('LOCALISATION'), valueCell(e.localisation ?? '—')],
            [labelCell('UTILISATEUR ACTUEL'), valueCell(e.utilisateur ? `${e.utilisateur.prenom} ${e.utilisateur.nom}` : 'Disponible (non affecté)')],
          ]},
          layout: { hLineWidth: () => 1, vLineWidth: () => 1, hLineColor: () => '#cde5d3', vLineColor: () => '#cde5d3' },
        },
        { text: ' ', margin: [0, 16] },
        { table: { widths: ['*'], body: [[{ text: 'HISTORIQUE DES MOUVEMENTS', fillColor: GREEN_DARK, color: 'white', bold: true, fontSize: 12, alignment: 'center', margin: [0, 6, 0, 6] }]] }, layout: 'noBorders' },
        { table: { widths: ['20%', '25%', '30%', '25%'], body: historiqueBody }, layout: { hLineWidth: () => 0.5, vLineWidth: () => 0.5, hLineColor: () => '#cde5d3', vLineColor: () => '#cde5d3' } },
      ],
      footer: (currentPage: number) => ({
        columns: [
          { text: `Généré le ${new Date().toLocaleDateString('fr-FR')}`, fontSize: 7, color: '#999', margin: [40, 0, 0, 0] },
          { text: `Page ${currentPage}`, fontSize: 7, color: '#999', alignment: 'right', margin: [0, 0, 40, 0] },
        ],
      }),
    }

    await telechargerPdf(pdfMake.createPdf(docDefinition), `${e.numero_inventaire}.pdf`, supabase)
  } catch (e: any) {
    console.error(e)
    alert(`Le PDF n'a pas pu être téléchargé : ${e?.message ?? e}`)
  } finally {
    generatingPdf.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl space-y-5">
    <NuxtLink to="/parc" class="text-sm text-brand-600">← Retour au parc</NuxtLink>

    <div v-if="loading" class="text-sm text-slate-400 dark:text-slate-500">Chargement...</div>
    <template v-else-if="equipement">
      <div class="flex items-start justify-between gap-3 flex-wrap">
        <div>
          <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">{{ equipement.marque }} {{ equipement.modele }}</h1>
          <p class="text-sm text-slate-500 dark:text-slate-400">{{ equipement.categorie?.nom }} · {{ equipement.numero_inventaire }}</p>
        </div>
        <div class="flex gap-2">
          <button class="btn-secondary" :disabled="generatingPdf" @click="genererPdf">
            <Icon name="download" class="w-4 h-4" /> {{ generatingPdf ? 'Génération...' : 'Imprimer / PDF' }}
          </button>
          <button v-if="isAdmin" class="btn-danger !px-2.5" title="Supprimer" @click="supprimerEquipement">
            <Icon name="trash" class="w-4 h-4" />
          </button>
        </div>
      </div>
      <p v-if="erreur" class="text-sm text-red-600">{{ erreur }}</p>

      <div class="card p-5 grid grid-cols-2 sm:grid-cols-3 gap-4 text-sm">
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">N° de série</p><p class="font-medium">{{ equipement.numero_serie || '—' }}</p></div>
        <div v-if="equipement.imei"><p class="text-slate-400 dark:text-slate-500 text-xs">IMEI</p><p class="font-medium">{{ equipement.imei }}</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">État</p><p class="font-medium">{{ etatLabels[equipement.etat] }}</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Localisation</p><p class="font-medium">{{ equipement.localisation || '—' }}</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Utilisateur actuel</p><p class="font-medium">{{ equipement.utilisateur ? `${equipement.utilisateur.prenom} ${equipement.utilisateur.nom}` : 'Disponible' }}</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Garantie</p><p class="font-medium">{{ equipement.garantie_fin || '—' }}</p></div>
      </div>

      <!-- Affectation / restitution en direct -->
      <div v-if="canManageParc" class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Affectation</h2>
        <div v-if="equipement.utilisateur" class="flex items-center justify-between flex-wrap gap-3">
          <p class="text-sm">Actuellement affecté à <strong>{{ equipement.utilisateur.prenom }} {{ equipement.utilisateur.nom }}</strong> ({{ equipement.utilisateur.matricule || 's.m.' }})</p>
          <button class="btn-secondary" @click="marquerRestitue">Marquer restitué</button>
        </div>
        <button v-else class="btn-primary" @click="modalAffectationOuverte = true">
          <Icon name="plus" class="w-4 h-4" /> Affecter à un agent
        </button>
      </div>

      <!-- Anciens porteurs -->
      <div v-if="anciensUtilisateurs.length" class="card p-5">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">Personnes ayant utilisé cet équipement</h2>
        <div class="flex flex-wrap gap-2">
          <span v-for="(u, i) in anciensUtilisateurs" :key="i" class="badge bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400">
            {{ u.prenom }} {{ u.nom }}
          </span>
        </div>
      </div>

      <!-- Historique -->
      <div class="card p-5">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">Historique des mouvements</h2>
        <div v-if="mouvements.length === 0" class="text-sm text-slate-400 dark:text-slate-500">Aucun mouvement enregistré.</div>
        <div class="space-y-4">
          <div v-for="m in mouvements" :key="m.id" class="flex items-start gap-3 text-sm">
            <div class="w-2 h-2 rounded-full bg-brand-400 mt-1.5 shrink-0" />
            <div>
              <p class="font-medium">{{ typeLabels[m.type] }}
                <span v-if="m.utilisateur" class="text-slate-400 dark:text-slate-500 font-normal">— {{ m.utilisateur.prenom }} {{ m.utilisateur.nom }}</span>
              </p>
              <p class="text-xs text-slate-400 dark:text-slate-500">
                {{ new Date(m.created_at).toLocaleString('fr-FR') }}
                <span v-if="m.effectue_par">· par {{ m.effectue_par.prenom }} {{ m.effectue_par.nom }}</span>
              </p>
            </div>
          </div>
        </div>
      </div>
    </template>

    <!-- Modal affectation -->
    <Transition name="fade">
      <div v-if="modalAffectationOuverte" class="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4" @click.self="modalAffectationOuverte = false">
        <div class="card w-full max-w-sm p-5 space-y-4">
          <h2 class="font-semibold text-slate-800 dark:text-slate-100">Affecter à un agent</h2>
          <div class="flex gap-2">
            <input v-model="matriculeRecherche" placeholder="Matricule (ex: I001)" class="input uppercase" @keyup.enter="rechercherAgent" />
            <button class="btn-secondary shrink-0" @click="rechercherAgent">Trouver</button>
          </div>
          <div v-if="agents.length" class="rounded-xl bg-brand-50 dark:bg-brand-950 p-3 text-sm text-brand-800 dark:text-brand-300">
            {{ agents[0].prenom }} {{ agents[0].nom }} ({{ agents[0].matricule }})
          </div>
          <p v-if="erreur" class="text-xs text-red-600">{{ erreur }}</p>
          <div class="flex gap-2">
            <button class="btn-secondary flex-1" @click="modalAffectationOuverte = false">Annuler</button>
            <button class="btn-primary flex-1" :disabled="!agentSelectionneId || affectationEnCours" @click="confirmerAffectation">
              {{ affectationEnCours ? 'Affectation...' : 'Confirmer' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: opacity 0.15s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
