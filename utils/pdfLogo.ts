import { LOGO_DATA_URI } from './logoData'

// pdfmake a besoin d'une data URI, pas d'une URL distante. Si l'admin n'a pas
// changé le logo (valeur par défaut), on utilise la version pré-encodée en
// base64 (rapide, sans réseau). S'il a téléversé un logo personnalisé, on le
// télécharge et on le convertit à la volée.
export async function resolveLogoDataUri(url: string): Promise<string> {
  if (!url || url === '/logo-fratmat.png') return LOGO_DATA_URI
  try {
    const res = await fetch(url)
    const blob = await res.blob()
    return await new Promise<string>((resolve, reject) => {
      const reader = new FileReader()
      reader.onloadend = () => resolve(reader.result as string)
      reader.onerror = reject
      reader.readAsDataURL(blob)
    })
  } catch {
    return LOGO_DATA_URI // repli silencieux si le téléchargement échoue
  }
}
