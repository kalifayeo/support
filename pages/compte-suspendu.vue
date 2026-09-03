<script setup lang="ts">
definePageMeta({ layout: 'auth' })
const supabase = useSupabaseClient()
const router = useRouter()
async function logout() {
  await supabase.auth.signOut()
  router.push('/login')
}
</script>

<template>
  <div class="max-w-sm text-center space-y-4 card-glass p-8">
    <div class="w-14 h-14 rounded-2xl bg-amber-100 text-amber-600 mx-auto flex items-center justify-center text-2xl">!</div>
    <h1 class="text-lg font-bold text-slate-800 dark:text-slate-100">Compte non actif</h1>
    <p class="text-sm text-slate-500 dark:text-slate-400">Votre compte est en attente d'activation, suspendu ou désactivé. Contactez l'administrateur de la DSI.</p>
    <button class="btn-secondary" @click="logout">Se déconnecter</button>
  </div>
</template>
