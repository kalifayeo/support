<script setup lang="ts">
const { profile } = useProfile()
const supabase = useSupabaseClient()

const statutLabels: Record<string, string> = {
  en_attente: 'En attente', actif: 'Actif', suspendu: 'Suspendu', desactive: 'Désactivé', archive: 'Archivé',
}
const roleLabels: Record<string, string> = {
  super_admin: 'Super administrateur', admin: 'Administrateur', directeur: 'Directeur',
  chef_service: 'Chef de service', technicien: 'Technicien', stagiaire: 'Stagiaire', agent: 'Agent',
}
</script>

<template>
  <div class="max-w-xl space-y-5">
    <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Mon espace</h1>

    <div class="card p-5 flex items-center gap-4">
      <div class="w-16 h-16 rounded-full bg-brand-100 text-brand-700 flex items-center justify-center text-xl font-semibold shrink-0">
        {{ profile?.prenom?.[0] }}{{ profile?.nom?.[0] }}
      </div>
      <div>
        <p class="font-semibold text-slate-800 dark:text-slate-100">{{ profile?.prenom }} {{ profile?.nom }}</p>
        <p class="text-sm text-slate-500 dark:text-slate-400">{{ profile?.fonction }}</p>
        <span class="badge bg-brand-50 text-brand-700 mt-1">{{ roleLabels[profile?.role ?? ''] }}</span>
      </div>
    </div>

    <div class="card p-5 grid grid-cols-2 gap-4 text-sm">
      <div><p class="text-slate-400 dark:text-slate-500 text-xs">Matricule</p><p class="font-medium">{{ profile?.matricule }}</p></div>
      <div><p class="text-slate-400 dark:text-slate-500 text-xs">Statut</p><p class="font-medium">{{ statutLabels[profile?.status ?? ''] }}</p></div>
      <div><p class="text-slate-400 dark:text-slate-500 text-xs">Email professionnel</p><p class="font-medium">{{ profile?.email_pro }}</p></div>
      <div><p class="text-slate-400 dark:text-slate-500 text-xs">Téléphone</p><p class="font-medium">{{ profile?.telephone || '—' }}</p></div>
      <div><p class="text-slate-400 dark:text-slate-500 text-xs">Dernière connexion</p><p class="font-medium">{{ profile?.derniere_connexion ? new Date(profile.derniere_connexion).toLocaleString('fr-FR') : '—' }}</p></div>
    </div>

    <div class="grid grid-cols-2 gap-3">
      <NuxtLink to="/fiches" class="card p-4 text-center hover:border-brand-300">
        <p class="text-sm font-medium">Mes fiches</p>
      </NuxtLink>
      <NuxtLink to="/parc?mine=1" class="card p-4 text-center hover:border-brand-300">
        <p class="text-sm font-medium">Mes équipements</p>
      </NuxtLink>
    </div>
  </div>
</template>
