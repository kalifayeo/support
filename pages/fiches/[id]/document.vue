<script setup lang="ts">
// Génère un PDF A4 de la fiche + un QR code de vérification.
// La mise en page vient du modèle éditable (Admin → Paramètres → Modèle de la fiche PDF).
import QRCode from 'qrcode'
import { resolveLogoDataUri } from '~/utils/pdfLogo'
import { fusionnerModele, construireDocDefinition, creerPdf, urlVerification } from '~/utils/fichePdfModele'
import { telechargerPdf } from '~/utils/telechargerPdf'

const route = useRoute()
const supabase = useSupabaseClient()
const user = useSupabaseUser()
const { logoUrl } = useSettings()

const fiche = ref<any>(null)
const contenu = ref<any>(null)
const settings = ref<any>({})
const generating = ref(false)
const erreur = ref('')

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

  const { data: s } = await supabase.from('settings').select('*').in('cle', ['organisation', 'conditions_generales_utilisation', 'fiche_pdf_modele'])
  for (const row of s ?? []) settings.value[row.cle] = row.valeur
})

async function genererPdf() {
  generating.value = true
  erreur.value = ''
  try {
    const codeVerif = crypto.randomUUID().slice(0, 8).toUpperCase()
    const modele = fusionnerModele(settings.value.fiche_pdf_modele)
    const urlVerif = urlVerification(modele, useRuntimeConfig().public.siteUrl as string, codeVerif)
    const qrDataUrl = await QRCode.toDataURL(urlVerif, { margin: 1, width: 240 })
    const logoData = await resolveLogoDataUri(logoUrl.value)

    const m = contenu.value?.materiel ?? {}
    const caracteristiques = [
      m.ram ? `RAM : ${m.ram}` : '',
      m.stockage ? `Stockage : ${m.stockage}` : '',
      m.capacite ? `Capacité : ${m.capacite}` : '',
      m.os ? `Système : ${m.os}` : '',
      m.reference ? `Référence : ${m.reference}` : '',
      m.accessoires ? `Accessoires : ${m.accessoires}` : '',
    ].filter(Boolean).join('\n')
    const observations = [
      m.imei ? `IMEI: ${m.imei}` : '',
      contenu.value?.observations || '',
    ].filter(Boolean).join('\n')

    const docDefinition = construireDocDefinition(modele, {
      numero: fiche.value.numero,
      dateCreation: new Date(fiche.value.created_at).toLocaleDateString('fr-FR'),
      typeNom: fiche.value.form_types?.nom ?? 'FICHE',
      direction: fiche.value.directions?.nom ?? '',
      service: fiche.value.services?.nom ?? '',
      utilisateur: `${fiche.value.utilisateur?.prenom ?? ''} ${fiche.value.utilisateur?.nom ?? ''}`.trim().toUpperCase(),
      materielTitre: (m.marque ? `${m.marque} ${m.modele || ''}` : (m.modele || '—')).toUpperCase(),
      caracteristiques, observations,
      numeroSerie: m.numero_serie || '', cleActivation: m.cle_activation || '',
      cguTexte: settings.value.conditions_generales_utilisation?.texte ?? '',
      logoData, qrDataUrl, codeVerif,
    })

    // Le document doit exister en base AVANT que le QR code soit scanné.
    const { error: errDoc } = await supabase.from('documents').insert({
      form_id: fiche.value.id,
      fichier_url: `local:${fiche.value.numero}.pdf`,
      code_verification: codeVerif,
      genere_par: user.value?.id ?? null,
    })
    if (errDoc) throw new Error(`Enregistrement du document impossible (le QR code ne serait pas valide) : ${errDoc.message}`)

    const pdfDoc = await creerPdf(docDefinition)
    await telechargerPdf(pdfDoc, `${fiche.value.numero}.pdf`, supabase)
  } catch (e: any) {
    console.error(e)
    erreur.value = `Le PDF n'a pas pu être téléchargé : ${e?.message ?? e}`
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
      <p v-if="erreur" class="text-sm text-red-600">{{ erreur }}</p>
    </div>
  </div>
</template>
