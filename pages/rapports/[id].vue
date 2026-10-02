<script setup lang="ts">
import { resolveLogoDataUri } from '~/utils/pdfLogo'
import { telechargerPdf } from '~/utils/telechargerPdf'

const route = useRoute()
const router = useRouter()
const supabase = useSupabaseClient()
const { logoUrl } = useSettings()
const { profile, isAdmin, canValidate } = useProfile()

const rapport = ref<any>(null)
const interventionsLiees = ref<any[]>([])
const loading = ref(true)
const erreur = ref('')
const generatingPdf = ref(false)

const statuts: Record<string, string> = { brouillon: 'Brouillon', soumis: 'Soumis', valide: 'Validé' }
const statutStyle: Record<string, string> = {
  brouillon: 'bg-slate-100 dark:bg-slate-800 text-slate-500',
  soumis: 'bg-amber-50 text-amber-700',
  valide: 'bg-emerald-50 text-emerald-700',
}

async function charger() {
  loading.value = true
  const { data, error } = await supabase.from('rapports_travail')
    .select(`
      *, technicien:profiles!rapports_travail_technicien_id_fkey(nom, prenom, matricule),
      valide_par_profil:profiles!rapports_travail_valide_par_fkey(nom, prenom),
      directions(nom), services(nom), rapport_types(nom)
    `)
    .eq('id', route.params.id).maybeSingle()

  if (error || !data) { erreur.value = 'Rapport introuvable.'; loading.value = false; return }
  rapport.value = data

  const { data: liens } = await supabase.from('rapport_interventions')
    .select('interventions(id, numero, titre, statut)')
    .eq('rapport_id', rapport.value.id)
  interventionsLiees.value = (liens ?? []).map((l: any) => l.interventions).filter(Boolean)

  loading.value = false
}
onMounted(charger)

const peutModifier = computed(() =>
  rapport.value && rapport.value.technicien_id === profile.value?.id && rapport.value.statut === 'brouillon')
const peutValider = computed(() =>
  rapport.value && rapport.value.statut === 'soumis' && (isAdmin.value || canValidate.value))

async function soumettre() {
  await supabase.from('rapports_travail').update({ statut: 'soumis' }).eq('id', rapport.value.id)
  await charger()
}
async function valider() {
  await supabase.from('rapports_travail').update({
    statut: 'valide', valide_par: profile.value!.id, date_validation: new Date().toISOString(),
  }).eq('id', rapport.value.id)
  await charger()
}
async function supprimer() {
  if (!confirm(`Supprimer le rapport ${rapport.value.numero} ?`)) return
  const { error } = await supabase.from('rapports_travail').delete().eq('id', rapport.value.id)
  if (!error) router.push('/rapports')
}

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
    const r = rapport.value

    const interventionsBody = interventionsLiees.value.length
      ? [
          [{ text: 'N°', bold: true, fontSize: 9, fillColor: GREEN, color: 'white' }, { text: 'Titre', bold: true, fontSize: 9, fillColor: GREEN, color: 'white' }],
          ...interventionsLiees.value.map(i => [{ text: i.numero, fontSize: 9 }, { text: i.titre, fontSize: 9 }]),
        ]
      : null

    const docDefinition: any = {
      pageSize: 'A4',
      pageMargins: [40, 32, 40, 36],
      content: [
        { image: logoData, width: 80 },
        { text: ' ', margin: [0, 3] },
        { table: { widths: ['*'], body: [[{ text: 'RAPPORT DE TRAVAIL', fillColor: GREEN_DARK, color: 'white', bold: true, fontSize: 15, alignment: 'center', margin: [0, 7, 0, 7] }]] }, layout: 'noBorders' },
        { text: ' ', margin: [0, 4] },
        { columns: [
          { text: r.titre, fontSize: 12, bold: true },
          { text: r.numero, fontSize: 11, alignment: 'right', color: '#666' },
        ] },
        { text: `Période du ${new Date(r.periode_debut).toLocaleDateString('fr-FR')} au ${new Date(r.periode_fin).toLocaleDateString('fr-FR')}${r.rapport_types ? ' · ' + r.rapport_types.nom : ''}`, fontSize: 10, color: '#555', margin: [0, 2, 0, 8] },
        { text: `Technicien : ${r.technicien?.prenom} ${r.technicien?.nom} (${r.technicien?.matricule})`, fontSize: 10, margin: [0, 0, 0, 10] },

        { text: 'ACTIVITÉS RÉALISÉES', fontSize: 11, bold: true, color: GREEN_DARK, margin: [0, 4, 0, 4] },
        { text: r.activites_realisees, fontSize: 10, margin: [0, 0, 0, 10] },

        ...(r.difficultes ? [
          { text: 'DIFFICULTÉS RENCONTRÉES', fontSize: 11, bold: true, color: GREEN_DARK, margin: [0, 4, 0, 4] },
          { text: r.difficultes, fontSize: 10, margin: [0, 0, 0, 10] },
        ] : []),

        ...(r.recommandations ? [
          { text: 'RECOMMANDATIONS', fontSize: 11, bold: true, color: GREEN_DARK, margin: [0, 4, 0, 4] },
          { text: r.recommandations, fontSize: 10, margin: [0, 0, 0, 10] },
        ] : []),

        ...(interventionsBody ? [
          { text: 'INTERVENTIONS LIÉES', fontSize: 11, bold: true, color: GREEN_DARK, margin: [0, 4, 0, 4] },
          { table: { widths: ['25%', '75%'], body: interventionsBody }, layout: { hLineWidth: () => 0.5, vLineWidth: () => 0.5, hLineColor: () => '#cde5d3', vLineColor: () => '#cde5d3' } },
        ] : []),

        { text: ' ', margin: [0, 16] },
        { columns: [
          { text: `Statut : ${statuts[r.statut]}`, fontSize: 9, color: '#666' },
          { text: r.date_validation ? `Validé le ${new Date(r.date_validation).toLocaleDateString('fr-FR')} par ${r.valide_par_profil?.prenom} ${r.valide_par_profil?.nom}` : '', fontSize: 9, color: '#666', alignment: 'right' },
        ] },
      ],
      footer: (currentPage: number) => ({
        columns: [
          { text: `Généré le ${new Date().toLocaleDateString('fr-FR')}`, fontSize: 7, color: '#999', margin: [40, 0, 0, 0] },
          { text: `Page ${currentPage}`, fontSize: 7, color: '#999', alignment: 'right', margin: [0, 0, 40, 0] },
        ],
      }),
    }

    await telechargerPdf(pdfMake.createPdf(docDefinition), `${r.numero}.pdf`, supabase)
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
    <NuxtLink to="/rapports" class="text-sm text-brand-600">← Retour aux rapports</NuxtLink>

    <SkeletonList v-if="loading" :rows="3" />
    <div v-else-if="erreur" class="card p-8 text-center text-sm text-slate-500 dark:text-slate-400">{{ erreur }}</div>

    <template v-else-if="rapport">
      <div class="flex items-start justify-between gap-3 flex-wrap">
        <div>
          <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">{{ rapport.numero }}</h1>
          <p class="text-sm text-slate-500 dark:text-slate-400">{{ rapport.titre }}</p>
        </div>
        <div class="flex items-center gap-2">
          <span class="badge" :class="statutStyle[rapport.statut]">{{ statuts[rapport.statut] }}</span>
          <button class="btn-secondary" :disabled="generatingPdf" @click="genererPdf">
            <Icon name="download" class="w-4 h-4" /> {{ generatingPdf ? '...' : 'PDF' }}
          </button>
          <button v-if="isAdmin" class="btn-danger !px-2.5" title="Supprimer" @click="supprimer">
            <Icon name="trash" class="w-4 h-4" />
          </button>
        </div>
      </div>

      <div class="card p-5 grid grid-cols-2 gap-4 text-sm">
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Technicien</p><p class="font-medium">{{ rapport.technicien?.prenom }} {{ rapport.technicien?.nom }}</p></div>
        <div><p class="text-slate-400 dark:text-slate-500 text-xs">Période</p><p class="font-medium">{{ new Date(rapport.periode_debut).toLocaleDateString('fr-FR') }} → {{ new Date(rapport.periode_fin).toLocaleDateString('fr-FR') }}</p></div>
        <div v-if="rapport.rapport_types"><p class="text-slate-400 dark:text-slate-500 text-xs">Type</p><p class="font-medium">{{ rapport.rapport_types.nom }}</p></div>
        <div v-if="rapport.services"><p class="text-slate-400 dark:text-slate-500 text-xs">Service</p><p class="font-medium">{{ rapport.services.nom }}</p></div>
        <div v-if="rapport.date_validation"><p class="text-slate-400 dark:text-slate-500 text-xs">Validé le</p><p class="font-medium">{{ new Date(rapport.date_validation).toLocaleDateString('fr-FR') }}</p></div>
      </div>

      <div class="card p-5">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">Activités réalisées</h2>
        <p class="text-sm text-slate-600 dark:text-slate-400 whitespace-pre-line">{{ rapport.activites_realisees }}</p>
      </div>

      <div v-if="rapport.difficultes" class="card p-5">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">Difficultés rencontrées</h2>
        <p class="text-sm text-slate-600 dark:text-slate-400 whitespace-pre-line">{{ rapport.difficultes }}</p>
      </div>

      <div v-if="rapport.recommandations" class="card p-5">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">Recommandations</h2>
        <p class="text-sm text-slate-600 dark:text-slate-400 whitespace-pre-line">{{ rapport.recommandations }}</p>
      </div>

      <div v-if="interventionsLiees.length" class="card p-5">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">Interventions liées</h2>
        <div class="space-y-1">
          <NuxtLink v-for="i in interventionsLiees" :key="i.id" :to="`/interventions/${i.id}`" class="flex items-center justify-between py-1.5 px-2 -mx-2 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800/60 transition-colors text-sm">
            <span>{{ i.numero }} — {{ i.titre }}</span>
            <Icon name="chevron-right" class="w-4 h-4 text-slate-300" />
          </NuxtLink>
        </div>
      </div>

      <div v-if="peutModifier || peutValider" class="card p-5 space-y-3">
        <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Actions</h2>
        <div class="flex flex-wrap gap-3">
          <button v-if="peutModifier" class="btn-primary" @click="soumettre">Soumettre pour validation</button>
          <button v-if="peutValider" class="btn-primary" @click="valider">
            <Icon name="check" class="w-4 h-4" /> Valider ce rapport
          </button>
        </div>
      </div>
    </template>
  </div>
</template>
