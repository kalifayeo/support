// Usage dans une page :
// definePageMeta({ middleware: 'role', roles: ['admin', 'super_admin'] })
export default defineNuxtRouteMiddleware(async (to) => {
  const roles = (to.meta.roles as string[] | undefined) ?? []
  if (roles.length === 0) return

  const { profile, fetchProfile } = useProfile()
  if (!profile.value) await fetchProfile()

  if (!profile.value || !roles.includes(profile.value.role)) {
    return navigateTo('/')
  }
})
