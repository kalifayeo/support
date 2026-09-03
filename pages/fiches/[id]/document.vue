<script setup lang="ts">
// Génère un PDF professionnel A4 de la fiche + un QR code de vérification.
// pdfmake tourne côté client (pas de serveur dédié nécessaire pour le MVP).
import QRCode from 'qrcode'
import { resolveLogoDataUri } from '~/utils/pdfLogo'

const route = useRoute()
const supabase = useSupabaseClient()
const { logoUrl } = useSettings()

const fiche = ref<any>(null)
const contenu = ref<any>(null)
const settings = ref<any>({})
const generating = ref(false)

onMounted(async () => {
  const { data } = await supabase.from('forms').select(`
      *, form_types(nom),
      cree_par:profiles!forms_cree_par_fkey(nom, prenom, matricule),
      utilisateur:agents!forms_utilisateur_concerne_id_fkey(nom, prenom, matricule, fonction),
      directions(nom), services(nom)
    `).eq('id', route.params.id).single()
  fiche.value = data

  const { data: fd } = await supabase.from('form_data').select('contenu').eq('form_id', fiche.value.id).single()
  contenu.value = fd?.contenu ?? {}

  const { data: s } = await supabase.from('settings').select('*').in('cle', ['organisation', 'conditions_generales_utilisation'])
  for (const row of s ?? []) settings.value[row.cle] = row.valeur
})

async function genererPdf() {
  generating.value = true
  try {
    const codeVerif = crypto.randomUUID().slice(0, 8).toUpperCase()
    const urlVerif = `${location.origin}/verifier?code=${codeVerif}`
    const qrDataUrl = await QRCode.toDataURL(urlVerif, { margin: 1, width: 180 })

    const pdfMake = (await import('pdfmake/build/pdfmake')).default
    const pdfFonts = (await import('pdfmake/build/vfs_fonts')).default
    // @ts-ignore
    pdfMake.vfs = pdfFonts.pdfMake ? pdfFonts.pdfMake.vfs : pdfFonts.vfs

    const logoData = await resolveLogoDataUri(logoUrl.value)

    const m = contenu.value?.materiel ?? {}
    const caracLignes = [
      m.ram ? `RAM : ${m.ram}` : '',
      m.stockage ? `Stockage : ${m.stockage}` : '',
      m.capacite ? `Capacité : ${m.capacite}` : '',
      m.os ? `Système : ${m.os}` : '',
      m.reference ? `Référence : ${m.reference}` : '',
      m.accessoires ? `Accessoires : ${m.accessoires}` : '',
    ].filter(Boolean).join('\n')
    const obs = [
      m.numero_serie ? `NS: ${m.numero_serie}` : '',
      m.imei ? `IMEI: ${m.imei}` : '',
      contenu.value?.observations || '',
    ].filter(Boolean).join('\n')

    // Vert Fratmat.info
    const GREEN = '#1a7a3c'
    const GREEN_DARK = '#0f5c2a'

    function labelCell(text: string) {
      return { text, fillColor: GREEN, color: 'white', bold: true, fontSize: 12, margin: [8, 6, 8, 6] }
    }
    function valueCell(text: string, opts: any = {}) {
      return { text, fillColor: 'white', fontSize: 12, bold: true, color: '#222', alignment: 'center', margin: [8, 6, 8, 6], ...opts }
    }

    const docDefinition: any = {
      pageSize: 'A4',
      pageMargins: [40, 32, 40, 36],
      content: [
        // En-tête : logo seul
        { image: logoData, width: 80 },
        { text: ' ', margin: [0, 3] },

        // Bandeau titre
        {
          table: { widths: ['*'], body: [[{ text: (fiche.value.form_types?.nom ?? 'FICHE').toUpperCase(), fillColor: GREEN_DARK, color: 'white', bold: true, fontSize: 15, alignment: 'center', margin: [0, 7, 0, 7] }]] },
          layout: 'noBorders',
        },
        { text: ' ', margin: [0, 3] },

        // Date + numéro
        { columns: [
          { text: [{ text: 'DATE : ', bold: true }, new Date(fiche.value.created_at).toLocaleDateString('fr-FR')], fontSize: 11 },
          { text: fiche.value.numero, fontSize: 11, alignment: 'right', color: '#666' },
        ] },
        { text: ' ', margin: [0, 4] },

        // Direction / Service / Utilisateur
        {
          table: { widths: ['30%', '70%'], body: [
            [labelCell('DIRECTION'), valueCell(fiche.value.directions?.nom ?? '')],
            [labelCell('SERVICE'), valueCell(fiche.value.services?.nom ?? '')],
            [labelCell('UTILISATEUR'), valueCell(`${fiche.value.utilisateur?.prenom ?? ''} ${fiche.value.utilisateur?.nom ?? ''}`.toUpperCase())],
          ]},
          layout: { hLineWidth: () => 1, vLineWidth: () => 1, hLineColor: () => '#cde5d3', vLineColor: () => '#cde5d3' },
        },
        { text: ' ', margin: [0, 2] },

        // Matériel / Caractéristiques / Observations
        {
          table: { widths: ['30%', '70%'], body: [
            [labelCell('MATERIEL'), valueCell((m.marque ? `${m.marque} ${m.modele || ''}` : (m.modele || '—')).toUpperCase())],
            [labelCell('CARACTERISTIQUES'), valueCell(caracLignes || '—', { alignment: 'left', bold: false, fontSize: 10.5, lineHeight: 1.3 })],
            [labelCell('OBSERVATIONS'), valueCell(obs || '—', { alignment: 'left', bold: false, fontSize: 10 })],
          ]},
          layout: { hLineWidth: () => 1, vLineWidth: () => 1, hLineColor: () => '#cde5d3', vLineColor: () => '#cde5d3' },
        },
        { text: ' ', margin: [0, 8] },

        // Bandeau conditions générales
        {
          table: { widths: ['*'], body: [[{ text: "CONDITIONS GÉNÉRALES D'UTILISATION", fillColor: GREEN_DARK, color: 'white', bold: true, fontSize: 12, alignment: 'center', margin: [0, 6, 0, 6] }]] },
          layout: 'noBorders',
        },
        {
          table: { widths: ['*'], body: [[{
            text: settings.value.conditions_generales_utilisation?.texte ?? '',
            fillColor: '#eef7f0', color: '#1a3d24', fontSize: 9, margin: [10, 8, 10, 8],
          }]] },
          layout: 'noBorders',
        },
        { text: ' ', margin: [0, 16] },

        // Signatures — labels uniquement, pas de nom imprimé (espace laissé pour la signature manuscrite)
        { columns: [
          { stack: [
            { text: 'Gestionnaire du parc informatique', bold: true, fontSize: 10.5, decoration: 'underline' },
            { text: ' ', margin: [0, 20] },
          ]},
          { stack: [
            { text: 'Utilisateur qui doit réceptionner l\'équipement', bold: true, fontSize: 10.5, alignment: 'right' },
            { text: '*Précédé de la mention lu et approuvé', fontSize: 8, italics: true, alignment: 'right', color: '#666' },
            { text: ' ', margin: [0, 14] },
          ]},
        ] },

        { text: ' ', margin: [0, 6] },
        { columns: [
          { text: '' },
          { stack: [{ image: qrDataUrl, width: 62, alignment: 'center' }, { text: 'Scanner pour vérifier', fontSize: 7, color: '#999', alignment: 'center', margin: [0, 2, 0, 0] }], width: 80 },
        ] },
      ],
      footer: (currentPage: number) => ({
        columns: [
          { text: `Vérification : ${codeVerif}`, fontSize: 7, color: '#999', margin: [40, 0, 0, 0] },
          { text: `Page ${currentPage}`, fontSize: 7, color: '#999', alignment: 'right', margin: [0, 0, 40, 0] },
        ],
      }),
    }

    pdfMake.createPdf(docDefinition).download(`${fiche.value.numero}.pdf`)

    await supabase.from('documents').insert({
      form_id: fiche.value.id,
      fichier_url: `local:${fiche.value.numero}.pdf`,
      code_verification: codeVerif,
    })
  } finally {
    generating.value = false
  }
}
</script>

<template>
  <div class="max-w-xl space-y-5">
    <NuxtLink :to="`/fiches/${route.params.id}`" class="text-sm text-brand-600">← Retour à la fiche</NuxtLink>
    <div class="card p-6 text-center space-y-4">
      <h1 class="text-lg font-bold">Générer le document</h1>
      <p class="text-sm text-slate-500 dark:text-slate-400">Le PDF reprendra les informations validées de la fiche {{ fiche?.numero }}, avec un QR code de vérification.</p>
      <button class="btn-primary mx-auto" :disabled="generating || !fiche" @click="genererPdf">
        <Icon name="download" class="w-4 h-4" /> {{ generating ? 'Génération...' : 'Télécharger le PDF' }}
      </button>
    </div>
  </div>
</template>
