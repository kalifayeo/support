<script setup lang="ts">
const { badgeUrl, logoUrl, fetchSettings, loaded } = useSettings()
if (!loaded.value) await fetchSettings()
</script>

<template>
  <div class="min-h-screen flex" style="padding-top: env(safe-area-inset-top)">

    <!-- Panneau visuel — visible uniquement sur grand écran -->
    <div class="hidden lg:flex lg:w-[45%] relative overflow-hidden items-center justify-center p-12
                bg-gradient-to-br from-brand-600 via-brand-700 to-emerald-800">
      <img :src="badgeUrl" alt="" class="pointer-events-none select-none absolute -right-16 -top-16 w-80 max-w-none opacity-20 rotate-12" />
      <img :src="badgeUrl" alt="" class="pointer-events-none select-none absolute -left-24 -bottom-24 w-96 max-w-none opacity-10 -rotate-12" />
      <div class="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent" />

      <div class="relative z-10 max-w-md text-center space-y-6">
        <div class="w-24 h-24 mx-auto rounded-3xl bg-white/15 backdrop-blur-md flex items-center justify-center p-4 shadow-xl">
          <img :src="logoUrl" alt="Logo" class="w-full h-full object-contain" />
        </div>
        <div>
          <h1 class="text-3xl font-bold text-white tracking-tight">Support</h1>
          <p class="text-brand-100 mt-1 font-medium">Plateforme numérique de la DSI</p>
        </div>
        <p class="text-brand-50/90 text-sm leading-relaxed">
          Gestion des fiches, du parc informatique, des interventions techniques
          et des rapports de travail — tout au même endroit.
        </p>
      </div>
    </div>

    <!-- Panneau formulaire -->
    <div class="flex-1 relative flex items-center justify-center p-4 overflow-hidden bg-slate-50 dark:bg-slate-950">
      <!-- Décor discret pour l'écran mobile, où le panneau visuel est masqué -->
      <img :src="badgeUrl" alt="" class="lg:hidden pointer-events-none select-none absolute -right-16 -top-16 w-64 max-w-none opacity-[0.06] dark:opacity-[0.1] rotate-12" />
      <div class="pointer-events-none absolute top-1/4 left-1/2 -translate-x-1/2 w-[500px] h-[500px] bg-brand-400/10 dark:bg-brand-600/10 rounded-full blur-3xl" />

      <div class="relative z-10 w-full flex items-center justify-center">
        <slot />
      </div>

      <BadgeAnniversaire />
    </div>
  </div>
</template>
