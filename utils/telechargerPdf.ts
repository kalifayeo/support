// Téléchargement fiable d'un PDF pdfmake.
// - pdfmake 0.2 ne signale PAS ses erreurs de génération : en cas de problème
//   (image invalide, police manquante…) le callback n'est jamais appelé et
//   l'écran reste bloqué sur « Génération... ». On surveille donc les erreurs
//   levées pendant la génération et on impose un délai maximum.
// - Navigateur : lien <a download> sur un Blob.
// - App mobile (WebView Capacitor) : les téléchargements Blob sont bloqués par
//   Android -> envoi dans Supabase Storage (bucket privé « fiches ») puis
//   ouverture d'un lien signé temporaire.
function obtenirBlob(pdfDoc: any, delaiMs = 25000): Promise<Blob> {
  return new Promise((resolve, reject) => {
    let fini = false
    const nettoyer = () => {
      fini = true
      clearTimeout(timer)
      window.removeEventListener('error', surErreur)
      window.removeEventListener('unhandledrejection', surRejet)
    }
    const echec = (e: any) => { if (fini) return; nettoyer(); reject(e instanceof Error ? e : new Error(String(e))) }
    const surErreur = (ev: ErrorEvent) => echec(ev.error ?? ev.message)
    const surRejet = (ev: PromiseRejectionEvent) => echec(ev.reason)
    const timer = setTimeout(() => echec(new Error('la génération a dépassé le délai (25 s)')), delaiMs)
    window.addEventListener('error', surErreur)
    window.addEventListener('unhandledrejection', surRejet)
    try {
      pdfDoc.getBlob((b: Blob) => { if (fini) return; nettoyer(); resolve(b) })
    } catch (e) { echec(e) }
  })
}

export async function telechargerPdf(pdfDoc: any, nom: string, supabase: any): Promise<string | null> {
  const blob = await obtenirBlob(pdfDoc)

  const natif = !!(window as any).Capacitor?.isNativePlatform?.()

  if (!natif) {
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = nom
    a.rel = 'noopener'
    a.style.display = 'none'
    document.body.appendChild(a)
    a.click()
    setTimeout(() => { a.remove(); URL.revokeObjectURL(url) }, 30000)
    return null
  }

  const chemin = `${crypto.randomUUID()}/${nom.replace(/[^\w.\-]/g, '_')}`
  const { error } = await supabase.storage.from('fiches').upload(chemin, blob, { contentType: 'application/pdf', upsert: true })
  if (error) throw new Error(`Envoi du PDF impossible : ${error.message}`)
  const { data, error: e2 } = await supabase.storage.from('fiches').createSignedUrl(chemin, 600)
  if (e2 || !data?.signedUrl) throw new Error(`Lien de téléchargement indisponible : ${e2?.message ?? ''}`)
  window.open(data.signedUrl, '_blank')
  return chemin
}
