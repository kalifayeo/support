import { LOGO_DATA_URI } from './logoData'

// pdfmake n'accepte que du PNG/JPEG en data URI. Un logo téléversé en WebP, SVG,
// GIF (ou une réponse d'erreur) fait planter la génération sans message.
// On le charge donc dans une image puis on le redessine en PNG via un canvas ;
// au moindre souci, on retombe sur le logo par défaut.
export async function resolveLogoDataUri(url: string): Promise<string> {
  if (!url || url === '/logo-fratmat.png') return LOGO_DATA_URI
  try {
    const res = await fetch(url, { cache: 'no-store' })
    if (!res.ok) return LOGO_DATA_URI
    const blob = await res.blob()
    if (!blob.type.startsWith('image/')) return LOGO_DATA_URI
    const objUrl = URL.createObjectURL(blob)
    try {
      const img = await new Promise<HTMLImageElement>((resolve, reject) => {
        const i = new Image()
        i.onload = () => resolve(i)
        i.onerror = () => reject(new Error('logo illisible'))
        i.src = objUrl
      })
      const w = img.naturalWidth || 300
      const h = img.naturalHeight || 100
      const canvas = document.createElement('canvas')
      canvas.width = w; canvas.height = h
      const ctx = canvas.getContext('2d')
      if (!ctx) return LOGO_DATA_URI
      ctx.drawImage(img, 0, 0, w, h)
      return canvas.toDataURL('image/png')
    } finally {
      URL.revokeObjectURL(objUrl)
    }
  } catch {
    return LOGO_DATA_URI
  }
}
