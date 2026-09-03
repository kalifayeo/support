<script setup lang="ts">
import { useStorage } from '@vueuse/core'

const { profile, fetchProfile, isAdmin } = useProfile()
const supabase = useSupabaseClient()
const router = useRouter()
const colorMode = useColorMode()
const { logoUrl, animationsActives, annonceActive, annonceTexte, annonceType, fetchSettings } = useSettings()

if (!profile.value) await fetchProfile()
await fetchSettings()

// Bascule globale des animations (contrôlée par l'admin) : ajoute une classe
// qui neutralise toutes les transitions/animations CSS de l'app.
watchEffect(() => {
  if (typeof document !== 'undefined') {
    document.documentElement.classList.toggle('no-animations', !animationsActives.value)
  }
})

const mobileMenuOpen = ref(false)
// Persisté localement : la sidebar reste repliée/dépliée d'une session à l'autre
const sidebarCollapsed = useStorage('support-sidebar-collapsed', false)

const notifNonLues = ref(0)
async function chargerNotifNonLues() {
  if (!profile.value) return
  const { count } = await supabase.from('notifications').select('id', { count: 'exact', head: true })
    .eq('destinataire_id', profile.value.id).eq('lu', false)
  notifNonLues.value = count ?? 0
}
onMounted(chargerNotifNonLues)
// Rafraîchit le badge à chaque navigation (ex: retour depuis /notifications où on vient de tout lire)
const route = useRoute()
watch(() => route.fullPath, chargerNotifNonLues)

// Bannière d'annonce : fermable, mémorisée pour la session tant que le texte
// ne change pas (une nouvelle annonce réapparaît même si l'ancienne a été fermée).
const annonceFermeeCle = computed(() => `support-annonce-fermee-${annonceTexte.value}`)
const annonceFermee = useStorage(annonceFermeeCle, false, sessionStorage)
const annonceVisible = computed(() => annonceActive.value && !annonceFermee.value)

const annonceStyles: Record<string, { bg: string; icon: string }> = {
  info: { bg: 'bg-brand-600', icon: 'info' },
  avertissement: { bg: 'bg-amber-500', icon: 'alert-triangle' },
  urgent: { bg: 'bg-red-600', icon: 'alert-triangle' },
}

function toggleDark() {
  colorMode.preference = colorMode.value === 'dark' ? 'light' : 'dark'
}

const navItems = computed(() => {
  const items = [
    { to: '/', label: 'Tableau de bord', icon: 'home' },
    { to: '/interventions', label: 'Interventions', icon: 'wrench' },
    { to: '/rapports', label: 'Rapports', icon: 'clipboard' },
    { to: '/fiches', label: 'Mes fiches', icon: 'file' },
    { to: '/parc', label: 'Parc informatique', icon: 'server' },
    { to: '/notifications', label: 'Notifications', icon: 'bell' },
  ]
  if (isAdmin.value) items.push({ to: '/admin', label: 'Administration', icon: 'shield' })
  return items
})

async function logout() {
  await supabase.auth.signOut()
  router.push('/login')
}
</script>

<template>
  <div class="min-h-screen bg-gradient-to-br from-slate-50 via-slate-50 to-brand-50/40 dark:from-slate-950 dark:via-slate-950 dark:to-slate-900 flex">
    <!-- Sidebar desktop -->
    <aside
      class="hidden lg:flex lg:flex-col shrink-0 border-r border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 transition-[width] duration-200 relative z-10"
      :class="sidebarCollapsed ? 'w-[76px]' : 'w-64'"
    >
      <div class="h-16 flex items-center px-5 border-b border-slate-200 dark:border-slate-800 gap-2.5 overflow-hidden">
        <div class="relative shrink-0">
          <div class="absolute inset-0 rounded-xl bg-brand-500/20 blur-md scale-125" />
          <img :src="logoUrl" alt="Logo" class="relative h-8 w-8 object-contain rounded-lg" />
        </div>
        <Transition name="fade">
          <div v-if="!sidebarCollapsed" class="whitespace-nowrap">
            <span class="font-bold text-brand-700 dark:text-brand-400 tracking-tight">Support</span>
            <span class="ml-2 text-xs text-slate-400 dark:text-slate-500">DSI</span>
          </div>
        </Transition>
      </div>
      <nav class="flex-1 px-3 py-4 space-y-1">
        <NuxtLink v-for="item in navItems" :key="item.to" :to="item.to" class="nav-link relative" :class="sidebarCollapsed && 'justify-center !px-0'" :title="item.label">
          <Icon :name="item.icon" class="w-5 h-5 shrink-0" />
          <span v-if="!sidebarCollapsed" class="whitespace-nowrap">{{ item.label }}</span>
        </NuxtLink>
      </nav>
      <div class="p-3 border-t border-slate-200 dark:border-slate-800 space-y-2">
        <button class="btn-secondary w-full" :class="sidebarCollapsed && '!px-0'" @click="sidebarCollapsed = !sidebarCollapsed">
          <Icon :name="sidebarCollapsed ? 'panel-left' : 'chevron-left'" class="w-4 h-4" />
          <span v-if="!sidebarCollapsed">Réduire</span>
        </button>
        <button class="btn-secondary w-full" :class="sidebarCollapsed && '!px-0'" @click="logout">
          <Icon name="x" class="w-4 h-4" />
          <span v-if="!sidebarCollapsed">Déconnexion</span>
        </button>
      </div>
    </aside>

    <div class="flex-1 flex flex-col min-w-0">
      <!-- Header -->
      <header class="h-16 shrink-0 border-b border-slate-200 dark:border-slate-800 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md flex items-center gap-3 px-4 lg:px-6 transition-colors sticky top-0 z-20">
        <button class="lg:hidden btn-secondary !px-2.5" @click="mobileMenuOpen = true" aria-label="Menu">
          <Icon name="menu" class="w-5 h-5" />
        </button>
        <div class="flex-1 max-w-md hidden sm:block">
          <RechercheGlobale />
        </div>
        <div class="flex-1 sm:hidden font-semibold text-brand-700 dark:text-brand-400">Support</div>

        <!-- Séparateur visuel explicite (grand écran uniquement) -->
        <div class="hidden lg:block w-px h-8 bg-slate-200 dark:bg-slate-700 ml-auto lg:mx-2" />

        <!-- Groupe de droite : nettement regroupé et distinct -->
        <div class="flex items-center gap-2 ml-auto lg:ml-0 bg-slate-100/70 dark:bg-slate-800/70 rounded-full pl-1.5 pr-1.5 py-1.5 lg:pr-1.5">
          <button class="btn-secondary !px-2.5 !bg-white dark:!bg-slate-900 shadow-sm" aria-label="Changer de thème" @click="toggleDark">
            <Icon :name="colorMode.value === 'dark' ? 'sun' : 'moon'" class="w-5 h-5" />
          </button>
          <button class="btn-secondary !px-2.5 !bg-white dark:!bg-slate-900 shadow-sm relative" aria-label="Notifications" @click="router.push('/notifications')">
            <Icon name="bell" class="w-5 h-5" />
            <span v-if="notifNonLues > 0" class="absolute -top-1 -right-1 min-w-[18px] h-[18px] px-1 rounded-full bg-red-500 text-white text-[10px] font-bold flex items-center justify-center animate-pulse">
              {{ notifNonLues > 9 ? '9+' : notifNonLues }}
            </span>
          </button>
          <NuxtLink to="/mon-espace" class="flex items-center gap-2 pl-1 pr-3 py-0.5 rounded-full hover:bg-white dark:hover:bg-slate-900 transition-colors group">
            <div class="w-8 h-8 rounded-full bg-gradient-to-br from-brand-500 to-brand-700 text-white flex items-center justify-center text-xs font-semibold shrink-0 shadow-sm group-hover:shadow-md transition-shadow">
              {{ profile?.prenom?.[0] }}{{ profile?.nom?.[0] }}
            </div>
            <div class="hidden md:block text-left">
              <p class="text-sm font-medium leading-tight">{{ profile?.prenom }} {{ profile?.nom }}</p>
              <p class="text-xs text-slate-400 leading-tight">{{ profile?.matricule }}</p>
            </div>
          </NuxtLink>
        </div>
      </header>

      <!-- Bandeau d'annonce (contrôlé par l'admin, visible par tous, fermable) -->
      <Transition name="fade">
        <div v-if="annonceVisible" class="shrink-0 text-white text-sm px-4 py-2.5 flex items-center gap-2.5" :class="annonceStyles[annonceType]?.bg || annonceStyles.info.bg">
          <Icon :name="annonceStyles[annonceType]?.icon || 'info'" class="w-4 h-4 shrink-0" :class="annonceType === 'urgent' && 'animate-pulse'" />
          <p class="flex-1 text-center">{{ annonceTexte }}</p>
          <button class="shrink-0 opacity-80 hover:opacity-100" aria-label="Fermer" @click="annonceFermee = true">
            <Icon name="x" class="w-4 h-4" />
          </button>
        </div>
      </Transition>

      <!-- Contenu -->
      <main class="flex-1 p-4 lg:p-6 pb-24 lg:pb-6 overflow-y-auto">
        <slot />
      </main>
    </div>

    <!-- Navigation basse mobile -->
    <nav class="lg:hidden fixed bottom-0 inset-x-0 bg-white dark:bg-slate-900 border-t border-slate-200 dark:border-slate-800 flex items-stretch z-40"
         style="padding-bottom: env(safe-area-inset-bottom)">
      <NuxtLink v-for="item in navItems.slice(0, 4)" :key="item.to" :to="item.to"
        class="flex-1 flex flex-col items-center justify-center gap-1 py-2.5 text-slate-500 dark:text-slate-400 transition-all duration-150 active:scale-90 relative"
        active-class="text-brand-600 dark:text-brand-400">
        <span class="relative">
          <Icon :name="item.icon" class="w-5 h-5" />
          <span v-if="item.to === '/notifications' && notifNonLues > 0" class="absolute -top-1 -right-1.5 w-2 h-2 rounded-full bg-red-500" />
        </span>
        <span class="text-[11px]">{{ item.label.split(' ')[0] }}</span>
      </NuxtLink>
    </nav>

    <!-- Menu mobile plein écran -->
    <Transition name="fade">
      <div v-if="mobileMenuOpen" class="lg:hidden fixed inset-0 z-50 bg-black/40" @click.self="mobileMenuOpen = false">
        <div class="w-72 h-full bg-white dark:bg-slate-900 p-4 flex flex-col" style="padding-top: env(safe-area-inset-top)">
          <div class="flex items-center justify-between mb-4">
            <span class="font-bold text-lg text-brand-700 dark:text-brand-400">Support</span>
            <button class="btn-secondary !px-2.5" @click="mobileMenuOpen = false">
              <Icon name="x" class="w-4 h-4" />
            </button>
          </div>
          <nav class="space-y-1 flex-1">
            <NuxtLink v-for="item in navItems" :key="item.to" :to="item.to" @click="mobileMenuOpen = false" class="nav-link">
              <Icon :name="item.icon" class="w-5 h-5" />
              {{ item.label }}
            </NuxtLink>
          </nav>
          <button class="btn-secondary w-full mb-2" @click="toggleDark">
            <Icon :name="colorMode.value === 'dark' ? 'sun' : 'moon'" class="w-4 h-4" />
            {{ colorMode.value === 'dark' ? 'Mode clair' : 'Mode sombre' }}
          </button>
          <button class="btn-secondary w-full" @click="logout">Déconnexion</button>
        </div>
      </div>
    </Transition>

    <BadgeAnniversaire />
  </div>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: opacity 0.15s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
