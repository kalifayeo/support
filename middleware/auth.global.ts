// Middleware exécuté sur chaque navigation.
// Redirige vers /login si non connecté, vers /compte-suspendu si le compte
// n'est pas actif (section 6), ou vers /maintenance si le mode maintenance
// est activé par l'admin (sauf pour les admins eux-mêmes).

const PUBLIC_ROUTES = ['/login', '/verifier', '/maintenance']

export default defineNuxtRouteMiddleware(async (to) => {
  const { maintenanceActif, fetchSettings, loaded } = useSettings()
  if (!loaded.value) await fetchSettings()

  const user = useSupabaseUser()
  const { profile, fetchProfile } = useProfile()
  if (user.value && !profile.value) await fetchProfile()

  const estAdmin = profile.value && ['admin', 'super_admin'].includes(profile.value.role)
  const routeExempteeMaintenance = to.path === '/maintenance' || to.path === '/login'
  if (maintenanceActif.value && !estAdmin && !routeExempteeMaintenance) {
    return navigateTo('/maintenance')
  }
  if ((!maintenanceActif.value || estAdmin) && to.path === '/maintenance') {
    return navigateTo('/')
  }

  if (PUBLIC_ROUTES.includes(to.path)) return

  if (!user.value) {
    return navigateTo('/login')
  }

  if (profile.value && profile.value.status !== 'actif' && to.path !== '/compte-suspendu') {
    return navigateTo('/compte-suspendu')
  }
})
