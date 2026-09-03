export type AppRole =
  | 'super_admin' | 'admin' | 'directeur' | 'chef_service'
  | 'technicien' | 'stagiaire' | 'agent'

export interface Profile {
  id: string
  matricule: string
  nom: string
  prenom: string
  telephone: string | null
  email_pro: string
  direction_id: string | null
  service_id: string | null
  fonction: string | null
  role: AppRole
  status: 'en_attente' | 'actif' | 'suspendu' | 'desactive' | 'archive'
  date_inscription: string
  date_activation: string | null
  derniere_connexion: string | null
}

// Profil courant partagé dans toute l'app (chargé une fois après login)
const profile = ref<Profile | null>(null)
const loading = ref(false)

export function useProfile() {
  const supabase = useSupabaseClient()
  const user = useSupabaseUser()

  async function fetchProfile() {
    if (!user.value) {
      profile.value = null
      return
    }
    loading.value = true
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.value.id)
      .single()
    if (!error) profile.value = data as Profile
    loading.value = false
  }

  // Permissions dérivées du rôle — utilisées côté UI pour afficher/masquer.
  // La vraie barrière de sécurité reste les policies RLS côté Supabase.
  const isAdmin = computed(() => ['admin', 'super_admin'].includes(profile.value?.role ?? ''))
  const isSuperAdmin = computed(() => profile.value?.role === 'super_admin')
  const canValidate = computed(() =>
    ['admin', 'super_admin', 'directeur', 'chef_service'].includes(profile.value?.role ?? ''))
  const canCreateFiche = computed(() =>
    ['admin', 'super_admin', 'technicien', 'stagiaire', 'chef_service'].includes(profile.value?.role ?? ''))
  const canManageParc = computed(() =>
    ['admin', 'super_admin', 'technicien'].includes(profile.value?.role ?? ''))

  return {
    profile: readonly(profile),
    loading: readonly(loading),
    fetchProfile,
    isAdmin,
    isSuperAdmin,
    canValidate,
    canCreateFiche,
    canManageParc,
  }
}
