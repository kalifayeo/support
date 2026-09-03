<script setup lang="ts">
definePageMeta({ layout: 'auth' })

const supabase = useSupabaseClient()
const router = useRouter()

const { logoUrl, fetchSettings, loaded } = useSettings()
if (!loaded.value) await fetchSettings()

const matricule = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')

// Étapes après une connexion réussie, si le compte a été créé par un admin
// avec un mot de passe temporaire (doit_changer_mdp = true).
const etape = ref<'connexion' | 'proposer' | 'modifier'>('connexion')
const mdpActuel = ref('')
const nouveauMdp = ref('')
const confirmMdp = ref('')
const errorMdp = ref('')
const savingMdp = ref(false)

// Le matricule identifie l'utilisateur mais n'est jamais le mot de passe
// (section 4). On le résout d'abord en email pro via une RPC dédiée,
// puis on authentifie normalement avec Supabase Auth.
async function handleLogin() {
  error.value = ''
  if (!/^[A-Z][0-9]{3,5}$/.test(matricule.value.trim().toUpperCase())) {
    error.value = 'Format de matricule invalide (1 lettre + 3 à 5 chiffres, ex: I001 à I00512).'
    return
  }
  loading.value = true
  try {
    const { data: email, error: rpcError } = await supabase
      .rpc('email_from_matricule', { p_matricule: matricule.value.trim().toUpperCase() })

    if (rpcError || !email) {
      error.value = 'Matricule inconnu.'
      return
    }

    const { error: signInError } = await supabase.auth.signInWithPassword({
      email,
      password: password.value,
    })

    if (signInError) {
      error.value = 'Matricule ou mot de passe incorrect.'
      return
    }

    // Le compte a-t-il été créé par un admin avec un mot de passe temporaire ?
    const { data: { user } } = await supabase.auth.getUser()
    const { data: prof } = await supabase.from('profiles').select('doit_changer_mdp').eq('id', user!.id).single()

    if (prof?.doit_changer_mdp) {
      mdpActuel.value = password.value
      etape.value = 'proposer'
    } else {
      router.push('/')
    }
  } finally {
    loading.value = false
  }
}

async function garderMotDePasse() {
  const { data: { user } } = await supabase.auth.getUser()
  await supabase.from('profiles').update({ doit_changer_mdp: false }).eq('id', user!.id)
  router.push('/')
}

async function confirmerNouveauMdp() {
  errorMdp.value = ''
  if (mdpActuel.value !== password.value) {
    errorMdp.value = 'Le mot de passe actuel ne correspond pas à celui utilisé pour vous connecter.'
    return
  }
  if (nouveauMdp.value.length < 6) {
    errorMdp.value = 'Le nouveau mot de passe doit contenir au moins 6 caractères.'
    return
  }
  if (nouveauMdp.value !== confirmMdp.value) {
    errorMdp.value = 'La confirmation ne correspond pas au nouveau mot de passe.'
    return
  }
  savingMdp.value = true
  try {
    const { error: updateError } = await supabase.auth.updateUser({ password: nouveauMdp.value })
    if (updateError) { errorMdp.value = updateError.message; return }

    const { data: { user } } = await supabase.auth.getUser()
    await supabase.from('profiles').update({ doit_changer_mdp: false }).eq('id', user!.id)
    router.push('/')
  } finally {
    savingMdp.value = false
  }
}
</script>

<template>
  <div class="w-full max-w-sm">
    <div class="text-center mb-8">
      <div class="relative inline-block mb-3">
        <div class="absolute inset-0 rounded-2xl bg-brand-400/30 blur-xl scale-125" />
        <img :src="logoUrl" alt="Logo" class="relative h-16 mx-auto object-contain drop-shadow-sm" />
      </div>
      <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">Support</h1>
      <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Plateforme numérique de la DSI</p>
    </div>

    <!-- Étape 1 : connexion -->
    <form v-if="etape === 'connexion'" class="card-glass p-6 space-y-4" @submit.prevent="handleLogin">
      <div>
        <label class="label" for="matricule">Matricule</label>
        <input id="matricule" v-model="matricule" type="text" placeholder="I001"
               class="input uppercase" maxlength="6" autocomplete="username" />
      </div>
      <div>
        <label class="label" for="password">Mot de passe</label>
        <input id="password" v-model="password" type="password" class="input" autocomplete="current-password" />
      </div>

      <p v-if="error" class="text-sm text-red-600">{{ error }}</p>

      <button type="submit" class="btn-primary w-full" :disabled="loading">
        {{ loading ? 'Connexion...' : 'Se connecter' }}
      </button>
    </form>

    <!-- Étape 2 : proposition de changer le mot de passe temporaire -->
    <div v-else-if="etape === 'proposer'" class="card-glass p-6 space-y-4 text-center">
      <div class="w-12 h-12 rounded-full bg-brand-50 dark:bg-brand-950 text-brand-600 dark:text-brand-400 mx-auto flex items-center justify-center">
        <Icon name="shield" class="w-6 h-6" />
      </div>
      <h2 class="font-semibold text-slate-800 dark:text-slate-100">Mot de passe temporaire</h2>
      <p class="text-sm text-slate-500 dark:text-slate-400">
        Votre compte a été créé par un administrateur avec un mot de passe temporaire.
        Souhaitez-vous le modifier maintenant ?
      </p>
      <div class="flex flex-col gap-2">
        <button class="btn-primary w-full" @click="etape = 'modifier'">Modifier maintenant</button>
        <button class="btn-secondary w-full" @click="garderMotDePasse">Garder ce mot de passe</button>
      </div>
    </div>

    <!-- Étape 3 : formulaire de changement (3 champs) -->
    <form v-else class="card-glass p-6 space-y-4" @submit.prevent="confirmerNouveauMdp">
      <h2 class="font-semibold text-slate-800 dark:text-slate-100">Modifier le mot de passe</h2>
      <div>
        <label class="label">Mot de passe actuel (par défaut)</label>
        <input v-model="mdpActuel" type="password" class="input" autocomplete="current-password" />
      </div>
      <div>
        <label class="label">Nouveau mot de passe</label>
        <input v-model="nouveauMdp" type="password" class="input" autocomplete="new-password" />
      </div>
      <div>
        <label class="label">Confirmer le nouveau mot de passe</label>
        <input v-model="confirmMdp" type="password" class="input" autocomplete="new-password" />
      </div>

      <p v-if="errorMdp" class="text-sm text-red-600">{{ errorMdp }}</p>

      <div class="flex gap-2">
        <button type="button" class="btn-secondary flex-1" @click="etape = 'proposer'">Retour</button>
        <button type="submit" class="btn-primary flex-1" :disabled="savingMdp">
          {{ savingMdp ? 'Enregistrement...' : 'Valider' }}
        </button>
      </div>
    </form>

    <p class="text-center text-xs text-slate-400 dark:text-slate-500 mt-6">
      Accès réservé au personnel autorisé de la DSI.
    </p>
  </div>
</template>
