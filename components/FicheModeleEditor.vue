<script setup lang="ts">
// Éditeur du modèle de la fiche PDF : textes, libellés, couleurs, signatures,
// pied de page, ordre / visibilité des blocs, blocs de texte libres.
import QRCode from 'qrcode'
import { resolveLogoDataUri } from '~/utils/pdfLogo'
import {
  BLOCS_STANDARD, urlVerification, fusionnerModele, modeleParDefaut, construireDocDefinition, creerPdf,
  type FicheModele, type BlocConfig,
} from '~/utils/fichePdfModele'
import { telechargerPdf } from '~/utils/telechargerPdf'

const supabase = useSupabaseClient()
const { logoUrl, fetchSettings } = useSettings()

const modele = ref<FicheModele>(modeleParDefaut())
const cgu = ref('')
const loading = ref(true)
const saving = ref(false)
const apercu = ref(false)
const message = ref('')
const erreur = ref('')

onMounted(async () => {
  const { data } = await supabase.from('settings').select('*').in('cle', ['fiche_pdf_modele', 'conditions_generales_utilisation'])
  for (const row of data ?? []) {
    if (row.cle === 'fiche_pdf_modele') modele.value = fusionnerModele(row.valeur)
    if (row.cle === 'conditions_generales_utilisation') cgu.value = row.valeur?.texte ?? ''
  }
  loading.value = false
})

const nomBloc = (b: BlocConfig) =>
  BLOCS_STANDARD.find(s => s.id === b.id)?.nom ?? `Texte libre${b.texte ? ` — ${b.texte.slice(0, 25)}` : ''}`

function deplacer(i: number, dir: -1 | 1) {
  const j = i + dir
  const blocs = modele.value.blocs
  if (j < 0 || j >= blocs.length) return
  ;[blocs[i], blocs[j]] = [blocs[j], blocs[i]]
}
function ajouterTexte() {
  modele.value.blocs.push({ id: `texte-${Date.now()}`, type: 'texte', visible: true, texte: '', taille: 10, align: 'left', gras: false })
}
function supprimer(i: number) { modele.value.blocs.splice(i, 1) }
function reinitialiser() {
  if (confirm('Revenir au modèle par défaut ? (non enregistré tant que vous ne cliquez pas sur Enregistrer)')) modele.value = modeleParDefaut()
}

async function enregistrer() {
  saving.value = true; erreur.value = ''
  const { error } = await supabase.from('settings').upsert(
    [{ cle: 'fiche_pdf_modele', valeur: JSON.parse(JSON.stringify(modele.value)) }],
    { onConflict: 'cle' },
  )
  saving.value = false
  if (error) { erreur.value = `Échec : ${error.message}`; return }
  await fetchSettings()
  message.value = 'Modèle enregistré.'
  setTimeout(() => message.value = '', 3000)
}

async function apercuPdf() {
  apercu.value = true; erreur.value = ''
  try {
    const qrDataUrl = await QRCode.toDataURL(urlVerification(modele.value, useRuntimeConfig().public.siteUrl as string, 'APERCU'), { margin: 1, width: 240 })
    const logoData = await resolveLogoDataUri(logoUrl.value)
    const doc = construireDocDefinition(modele.value, {
      numero: 'FA-2026-00000', dateCreation: new Date().toLocaleDateString('fr-FR'),
      typeNom: "FICHE D'AFFECTATION DE MATÉRIEL",
      direction: 'Moyens Généraux', service: 'Achats Ventes', utilisateur: 'NOM PRÉNOM',
      materielTitre: 'HP PRO BOOK',
      caracteristiques: 'RAM : 8 Gb\nStockage : 512 GB SSD\nSystème : Win 11 Professionnel\nAccessoires : Chargeur',
      observations: '', numeroSerie: '5CD0000000', cleActivation: 'XXXXX-XXXXX-XXXXX-XXXXX-XXXXX', cguTexte: cgu.value, logoData, qrDataUrl, codeVerif: 'APERCU00',
    })
    await telechargerPdf(await creerPdf(doc), 'apercu-fiche.pdf', supabase)
  } catch (e: any) {
    erreur.value = `Aperçu impossible : ${e?.message ?? e}`
  } finally { apercu.value = false }
}
</script>

<template>
  <div class="card p-5 space-y-5">
    <div>
      <h2 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Modèle de la fiche PDF</h2>
      <p class="text-xs text-slate-400 dark:text-slate-500">Modifiez les textes, l'ordre et l'affichage de chaque partie de la fiche. Les données (nom, matériel…) restent remplies automatiquement.</p>
    </div>
    <div v-if="loading" class="text-sm text-slate-400">Chargement...</div>
    <template v-else>
      <!-- Ordre / visibilité -->
      <div class="space-y-2">
        <h3 class="text-xs font-semibold uppercase text-slate-500">Organisation de la page</h3>
        <div v-for="(b, i) in modele.blocs" :key="b.id" class="rounded-lg border border-slate-200 dark:border-slate-700 p-2 space-y-2">
          <div class="flex items-center gap-2">
            <input v-model="b.visible" type="checkbox" class="rounded" title="Afficher" />
            <span class="flex-1 text-sm" :class="b.visible ? '' : 'line-through text-slate-400'">{{ nomBloc(b) }}</span>
            <button type="button" class="btn-secondary !px-2" :disabled="i === 0" @click="deplacer(i, -1)">▲</button>
            <button type="button" class="btn-secondary !px-2" :disabled="i === modele.blocs.length - 1" @click="deplacer(i, 1)">▼</button>
            <button v-if="b.type === 'texte'" type="button" class="btn-secondary !px-2 text-red-600" @click="supprimer(i)">✕</button>
          </div>
          <div v-if="b.type === 'texte'" class="space-y-2">
            <textarea v-model="b.texte" rows="2" class="input" placeholder="Votre texte..." />
            <div class="flex gap-2 flex-wrap items-center text-sm">
              <select v-model="b.align" class="input !w-auto"><option value="left">Gauche</option><option value="center">Centré</option><option value="right">Droite</option></select>
              <input v-model.number="b.taille" type="number" min="6" max="24" class="input !w-20" />
              <label class="flex items-center gap-1"><input v-model="b.gras" type="checkbox" class="rounded" /> Gras</label>
            </div>
          </div>
        </div>
        <button type="button" class="btn-secondary" @click="ajouterTexte">+ Ajouter un texte libre</button>
      </div>

      <!-- Couleurs / logo / titre -->
      <div class="space-y-3">
        <h3 class="text-xs font-semibold uppercase text-slate-500">Style et titre</h3>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <div><label class="label">Couleur des libellés</label><input v-model="modele.couleur_principale" type="color" class="input !p-1 h-10" /></div>
          <div><label class="label">Couleur des bandeaux</label><input v-model="modele.couleur_titre" type="color" class="input !p-1 h-10" /></div>
          <div><label class="label">Largeur du logo</label><input v-model.number="modele.logo_largeur" type="number" min="30" max="250" class="input" /></div>
        </div>
        <div><label class="label">Titre du bandeau (vide = nom du type de fiche)</label><input v-model="modele.titre" class="input" /></div>
        <div><label class="label">Titre du bloc conditions</label><input v-model="modele.cgu_titre" class="input" /></div>
        <div><label class="label">Texte des conditions générales</label><textarea v-model="cgu" rows="5" class="input" disabled /><p class="text-xs text-slate-400">Ce texte se modifie dans le bloc « Conditions générales d'utilisation » plus bas.</p></div>
      </div>

      <!-- Libellés -->
      <div class="space-y-3">
        <h3 class="text-xs font-semibold uppercase text-slate-500">Libellés des lignes</h3>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div v-for="(_, cle) in modele.labels" :key="cle"><label class="label">{{ cle }}</label><input v-model="modele.labels[cle]" class="input" /></div>
        </div>
      </div>

      <!-- Signatures / QR / pied de page -->
      <div class="space-y-3">
        <h3 class="text-xs font-semibold uppercase text-slate-500">Signatures, QR et pied de page</h3>
        <div><label class="label">Signature à gauche (vide = masquée)</label><input v-model="modele.signature_gauche" class="input" /></div>
        <div><label class="label">Signature à droite (vide = masquée)</label><input v-model="modele.signature_droite" class="input" /></div>
        <div><label class="label">Mention sous la signature de droite (vide = masquée)</label><input v-model="modele.signature_droite_note" class="input" /></div>
        <div><label class="label">Légende du QR code</label><input v-model="modele.qr_legende" class="input" /></div>
        <div><label class="label">Adresse du site encodée dans le QR code (vide = adresse par défaut)</label><input v-model="modele.url_base" class="input" placeholder="https://support-kappa-eight.vercel.app" /></div>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div><label class="label">Pied de page gauche ({code})</label><input v-model="modele.footer_gauche" class="input" /></div>
          <div><label class="label">Pied de page droit ({page})</label><input v-model="modele.footer_droite" class="input" /></div>
        </div>
      </div>

      <p v-if="erreur" class="text-sm text-red-600">{{ erreur }}</p>
      <p v-if="message" class="text-sm text-emerald-600">{{ message }}</p>
      <div class="flex gap-2 flex-wrap">
        <button type="button" class="btn-primary" :disabled="saving" @click="enregistrer">{{ saving ? 'Enregistrement...' : 'Enregistrer le modèle' }}</button>
        <button type="button" class="btn-secondary" :disabled="apercu" @click="apercuPdf">{{ apercu ? 'Génération...' : 'Aperçu PDF' }}</button>
        <button type="button" class="btn-secondary" @click="reinitialiser">Réinitialiser</button>
      </div>
    </template>
  </div>
</template>
