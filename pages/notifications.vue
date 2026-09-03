<script setup lang="ts">
const supabase = useSupabaseClient()
const { profile } = useProfile()
const notifs = ref<any[]>([])
const loading = ref(true)

onMounted(async () => {
  if (!profile.value) return
  const { data } = await supabase.from('notifications').select('*').eq('destinataire_id', profile.value.id).order('created_at', { ascending: false }).limit(50)
  notifs.value = data ?? []
  loading.value = false
})

async function marquerLue(n: any) {
  if (n.lu) return
  n.lu = true
  await supabase.from('notifications').update({ lu: true }).eq('id', n.id)
}
</script>

<template>
  <div class="max-w-xl space-y-4">
    <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Notifications</h1>
    <div class="card divide-y divide-slate-100 dark:divide-slate-800">
      <SkeletonList v-if="loading" :rows="5" />
      <div v-else-if="notifs.length === 0" class="p-6 text-center text-sm text-slate-400 dark:text-slate-500">Aucune notification.</div>
      <NuxtLink v-for="n in notifs" :key="n.id" :to="n.lien || '#'" class="p-4 flex gap-3 hover:bg-slate-50 dark:hover:bg-slate-800/60 dark:bg-slate-800/60" @click="marquerLue(n)">
        <div class="w-2 h-2 rounded-full mt-2 shrink-0" :class="n.lu ? 'bg-transparent' : 'bg-brand-500'" />
        <div class="min-w-0">
          <p class="text-sm font-medium" :class="n.lu ? 'text-slate-500 dark:text-slate-400' : 'text-slate-800 dark:text-slate-100'">{{ n.titre }}</p>
          <p class="text-xs text-slate-400 dark:text-slate-500 mt-0.5">{{ n.message }}</p>
          <p class="text-[11px] text-slate-300 mt-1">{{ new Date(n.created_at).toLocaleString('fr-FR') }}</p>
        </div>
      </NuxtLink>
    </div>
  </div>
</template>
