// Modèle éditable de la fiche PDF (Admin → Paramètres → Modèle de la fiche PDF).
// Stocké dans settings.cle = 'fiche_pdf_modele'. Tout ce qui n'est pas renseigné
// retombe sur les valeurs par défaut ci-dessous (anciennes installations OK).

export type BlocType =
  | 'logo' | 'titre' | 'date_numero' | 'info' | 'materiel'
  | 'cgu' | 'signatures' | 'qr' | 'texte'

export interface BlocConfig {
  id: string
  type: BlocType
  visible: boolean
  // pour les blocs « texte » libres uniquement
  texte?: string
  taille?: number
  align?: 'left' | 'center' | 'right'
  gras?: boolean
}

export interface FicheModele {
  couleur_principale: string
  couleur_titre: string
  logo_largeur: number
  titre: string // vide = nom du type de fiche
  labels: {
    date: string; direction: string; service: string; utilisateur: string
    materiel: string; caracteristiques: string; observations: string
    ns: string; cle: string
  }
  cgu_titre: string
  signature_gauche: string
  signature_droite: string
  signature_droite_note: string
  qr_legende: string
  url_base: string // adresse publique du site encodée dans le QR (vide = adresse par défaut)
  footer_gauche: string // {code} = code de vérification
  footer_droite: string // {page} = numéro de page
  blocs: BlocConfig[]
}

export const BLOCS_STANDARD: { id: string; type: BlocType; nom: string }[] = [
  { id: 'logo', type: 'logo', nom: 'Logo' },
  { id: 'titre', type: 'titre', nom: 'Bandeau titre' },
  { id: 'date_numero', type: 'date_numero', nom: 'Date et numéro' },
  { id: 'info', type: 'info', nom: 'Direction / Service / Utilisateur' },
  { id: 'materiel', type: 'materiel', nom: 'Matériel / Caractéristiques / Observations' },
  { id: 'cgu', type: 'cgu', nom: 'Conditions générales d\'utilisation' },
  { id: 'signatures', type: 'signatures', nom: 'Signatures' },
  { id: 'qr', type: 'qr', nom: 'QR code de vérification' },
]

export function modeleParDefaut(): FicheModele {
  return {
    couleur_principale: '#1a7a3c',
    couleur_titre: '#0f5c2a',
    logo_largeur: 80,
    titre: '',
    labels: {
      date: 'DATE :', direction: 'DIRECTION', service: 'SERVICE', utilisateur: 'UTILISATEUR',
      materiel: 'MATERIEL', caracteristiques: 'CARACTERISTIQUES', observations: 'OBSERVATIONS',
      ns: 'NS:', cle: 'CLEF:',
    },
    cgu_titre: "CONDITIONS GÉNÉRALES D'UTILISATION",
    signature_gauche: 'Gestionnaire du parc informatique',
    signature_droite: 'Utilisateur',
    signature_droite_note: '*Précédé de la mention lu et approuvé',
    qr_legende: 'Scanner pour vérifier',
    url_base: '',
    footer_gauche: 'Vérification : {code}',
    footer_droite: 'Page {page}',
    blocs: BLOCS_STANDARD.map(b => ({ id: b.id, type: b.type, visible: true })),
  }
}

// Fusionne la valeur enregistrée avec les défauts (et ajoute les blocs manquants).
export function fusionnerModele(stocke: any): FicheModele {
  const d = modeleParDefaut()
  if (!stocke || typeof stocke !== 'object') return d
  const m: FicheModele = {
    ...d, ...stocke,
    labels: { ...d.labels, ...(stocke.labels ?? {}) },
  }
  const blocs: BlocConfig[] = Array.isArray(stocke.blocs) ? stocke.blocs.map((b: any) => ({ ...b })) : []
  for (const std of d.blocs) {
    if (!blocs.some(b => b.id === std.id)) blocs.push({ ...std })
  }
  m.blocs = blocs
  return m
}

export interface ContexteFiche {
  numero: string
  dateCreation: string
  typeNom: string
  direction: string
  service: string
  utilisateur: string
  materielTitre: string
  caracteristiques: string
  observations: string
  numeroSerie?: string
  cleActivation?: string
  cguTexte: string
  logoData: string
  qrDataUrl: string
  codeVerif: string
}

// Construit le document pdfmake à partir du modèle + des données.
export function construireDocDefinition(m: FicheModele, c: ContexteFiche): any {
  const GREEN = m.couleur_principale
  const GREEN_DARK = m.couleur_titre
  const BORD = '#cde5d3'

  const labelCell = (text: string) => ({ text, fillColor: GREEN, color: 'white', bold: true, fontSize: 11.5, margin: [8, 5, 8, 5] })
  const valueCell = (text: any, opts: any = {}) => ({ text, fillColor: 'white', fontSize: 11.5, bold: true, color: '#222', alignment: 'center', margin: [8, 5, 8, 5], ...opts })
  const layoutTab = { hLineWidth: () => 1, vLineWidth: () => 1, hLineColor: () => BORD, vLineColor: () => BORD }
  const espace = (h: number) => ({ text: ' ', fontSize: 4, margin: [0, h / 2] })

  // « NS: xxx  CLEF: yyy » (libellés en gras) puis les autres remarques
  const observationsRiches = (): any => {
    const parts: any[] = []
    if (c.numeroSerie) parts.push({ text: `${m.labels.ns} `, bold: true }, { text: c.numeroSerie })
    if (c.cleActivation) {
      if (parts.length) parts.push({ text: '   ' })
      parts.push({ text: `${m.labels.cle} `, bold: true }, { text: c.cleActivation })
    }
    if (c.observations) {
      if (parts.length) parts.push({ text: '\n' })
      parts.push({ text: c.observations })
    }
    return parts.length ? parts : '—'
  }

  const rendre = (b: BlocConfig): any[] => {
    switch (b.type) {
      case 'logo':
        return [{ image: c.logoData, width: m.logo_largeur }, espace(3)]
      case 'titre':
        return [{
          table: { widths: ['*'], body: [[{ text: (m.titre || c.typeNom || 'FICHE').toUpperCase(), fillColor: GREEN_DARK, color: 'white', bold: true, fontSize: 15, alignment: 'center', margin: [0, 5, 0, 5] }]] },
          layout: 'noBorders',
        }, espace(3)]
      case 'date_numero':
        return [{ columns: [
          { text: [{ text: `${m.labels.date} `, bold: true }, c.dateCreation], fontSize: 11 },
          { text: c.numero, fontSize: 11, alignment: 'right', color: '#666' },
        ] }, espace(4)]
      case 'info':
        return [{
          table: { widths: ['30%', '70%'], body: [
            [labelCell(m.labels.direction), valueCell(c.direction)],
            [labelCell(m.labels.service), valueCell(c.service)],
            [labelCell(m.labels.utilisateur), valueCell(c.utilisateur)],
          ] }, layout: layoutTab,
        }, espace(2)]
      case 'materiel':
        return [{
          table: { widths: ['30%', '70%'], body: [
            [labelCell(m.labels.materiel), valueCell(c.materielTitre)],
            [labelCell(m.labels.caracteristiques), valueCell(c.caracteristiques || '—', { alignment: 'left', bold: false, fontSize: 10.5, lineHeight: 1.3 })],
            [labelCell(m.labels.observations), valueCell(observationsRiches(), { alignment: 'left', bold: false, fontSize: 10.5, lineHeight: 1.3 })],
          ] }, layout: layoutTab,
        }, espace(6)]
      case 'cgu':
        return [
          { table: { widths: ['*'], body: [[{ text: m.cgu_titre, fillColor: GREEN_DARK, color: 'white', bold: true, fontSize: 12, alignment: 'center', margin: [0, 4, 0, 4] }]] }, layout: 'noBorders' },
          { table: { widths: ['*'], body: [[{ text: c.cguTexte, fillColor: '#eef7f0', color: '#1a3d24', fontSize: 9, margin: [10, 7, 10, 7] }]] }, layout: 'noBorders' },
          espace(12),
        ]
      case 'signatures': {
        const gauche: any[] = []
        if (m.signature_gauche) gauche.push({ text: m.signature_gauche, bold: true, fontSize: 10.5, decoration: 'underline' })
        gauche.push({ text: ' ', margin: [0, 24] })
        const droite: any[] = []
        if (m.signature_droite) droite.push({ text: m.signature_droite, bold: true, fontSize: 10.5, alignment: 'right' })
        if (m.signature_droite_note) droite.push({ text: m.signature_droite_note, fontSize: 8, italics: true, alignment: 'right', color: '#666' })
        droite.push({ text: ' ', margin: [0, 18] })
        return [{ columns: [{ stack: gauche }, { stack: droite }] }, espace(6)]
      }
      case 'qr':
        return [espace(28), { columns: [
          { text: '' },
          { stack: [
            { image: c.qrDataUrl, width: 58, alignment: 'center' },
            ...(m.qr_legende ? [{ text: m.qr_legende, fontSize: 7, color: '#999', alignment: 'center', margin: [0, 2, 0, 0] }] : []),
          ], width: 80 },
        ] }]
      case 'texte':
        return [{ text: b.texte ?? '', fontSize: b.taille ?? 10, alignment: b.align ?? 'left', bold: !!b.gras }, espace(4)]
      default:
        return []
    }
  }

  return {
    pageSize: 'A4',
    pageMargins: [40, 26, 40, 30],
    content: m.blocs.filter(b => b.visible).flatMap(rendre),
    footer: (currentPage: number) => ({
      columns: [
        { text: m.footer_gauche.replace('{code}', c.codeVerif), fontSize: 7, color: '#999', margin: [40, 0, 0, 0] },
        { text: m.footer_droite.replace('{page}', String(currentPage)), fontSize: 7, color: '#999', alignment: 'right', margin: [0, 0, 40, 0] },
      ],
    }),
  }
}

// Charge pdfmake (client uniquement) et crée le document.
export async function creerPdf(docDefinition: any): Promise<any> {
  const pdfMake = (await import('pdfmake/build/pdfmake')).default
  const pdfFonts = (await import('pdfmake/build/vfs_fonts')).default
  // @ts-ignore
  pdfMake.vfs = pdfFonts.pdfMake ? pdfFonts.pdfMake.vfs : pdfFonts.vfs
  return pdfMake.createPdf(docDefinition)
}

// Adresse publique utilisée dans le QR code. Elle ne doit JAMAIS être « localhost »
// (sinon le téléphone qui scanne ne trouve pas le serveur).
export const URL_SITE_PAR_DEFAUT = 'https://support-kappa-eight.vercel.app'

export function urlVerification(m: FicheModele, siteUrlConfig: string | undefined, code: string): string {
  const invalide = (u: string) => !u || /localhost|127\.0\.0\.1|^capacitor:|^file:|192\.168\.|10\.\d+\.\d+\.\d+/.test(u)
  const candidats = [m.url_base, siteUrlConfig, typeof location !== 'undefined' ? location.origin : '']
  const base = (candidats.find(u => u && !invalide(u)) || URL_SITE_PAR_DEFAUT).replace(/\/+$/, '')
  return `${base}/verifier?code=${code}`
}
