// Paramètres globaux administrables (logo, badge, annonce, apparence...),
// chargés une fois et partagés dans toute l'app — comme useProfile.
const settings = ref<Record<string, any>>({})
const loaded = ref(false)

export function useSettings() {
  const supabase = useSupabaseClient()

  async function fetchSettings() {
    const { data } = await supabase.from('settings').select('*')
    const obj: Record<string, any> = {}
    for (const row of data ?? []) obj[row.cle] = row.valeur
    settings.value = obj
    loaded.value = true
  }

  const logoUrl = computed(() => settings.value.organisation?.logo_url || '/logo-fratmat.png')
  const badgeUrl = computed(() => settings.value.badge?.url || '/badge-61ans.png')
  const badgeActif = computed(() => settings.value.badge?.actif ?? true)
  const annonceTexte = computed(() => settings.value.annonce?.texte || '')
  const annonceType = computed(() => settings.value.annonce?.type || 'info') // info | avertissement | urgent
  const annonceExpiration = computed(() => settings.value.annonce?.expiration || '')
  const annonceExpiree = computed(() => {
    if (!annonceExpiration.value) return false
    return new Date(annonceExpiration.value) < new Date()
  })
  const annonceActive = computed(() => !!(settings.value.annonce?.actif && annonceTexte.value && !annonceExpiree.value))
  const animationsActives = computed(() => settings.value.apparence?.animations ?? true)
  const contactEmail = computed(() => settings.value.contact?.email || '')
  const contactTelephone = computed(() => settings.value.contact?.telephone || '')
  const maintenanceActif = computed(() => settings.value.maintenance?.actif ?? false)
  const maintenanceMessage = computed(() => settings.value.maintenance?.message || "L'application est en maintenance. Merci de réessayer plus tard.")

  return {
    settings: readonly(settings), loaded: readonly(loaded), fetchSettings,
    logoUrl, badgeUrl, badgeActif,
    annonceTexte, annonceType, annonceExpiration, annonceActive,
    animationsActives, contactEmail, contactTelephone,
    maintenanceActif, maintenanceMessage,
  }
}
