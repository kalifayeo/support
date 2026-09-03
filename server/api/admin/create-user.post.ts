// Cette route s'exécute UNIQUEMENT côté serveur Nuxt. Elle utilise la clé
// service_role (jamais exposée au navigateur) pour créer un compte
// Supabase Auth + son profil, avec un mot de passe temporaire défini par
// l'administrateur (section 4/28 : le matricule n'est jamais un mot de passe,
// c'est bien un mot de passe distinct qui est généré ici).
export default defineEventHandler(async (event) => {
  const { admin, caller } = await requireAdmin(event)

  const body = await readBody(event)
  const { matricule, nom, prenom, email_pro, telephone, direction_id, service_id, fonction, role, mot_de_passe } = body

  if (!matricule || !nom || !prenom || !email_pro || !role || !mot_de_passe) {
    throw createError({ statusCode: 400, statusMessage: 'Champs obligatoires manquants.' })
  }
  if (!/^[A-Z][0-9]{3,5}$/.test(matricule.toUpperCase())) {
    throw createError({ statusCode: 400, statusMessage: 'Format de matricule invalide.' })
  }
  if (mot_de_passe.length < 6) {
    throw createError({ statusCode: 400, statusMessage: 'Le mot de passe doit contenir au moins 6 caractères.' })
  }

  // 1. Créer le compte Supabase Auth (email + mot de passe temporaire), auto-confirmé
  const { data: created, error: authError } = await admin.auth.admin.createUser({
    email: email_pro,
    password: mot_de_passe,
    email_confirm: true,
  })
  if (authError || !created.user) {
    throw createError({ statusCode: 400, statusMessage: authError?.message ?? "Échec de création du compte." })
  }

  // 2. Créer la ligne profil associée — doit_changer_mdp = true par défaut
  const { error: profileError } = await admin.from('profiles').insert({
    id: created.user.id,
    matricule: matricule.toUpperCase(),
    nom, prenom, telephone: telephone || null, email_pro,
    direction_id: direction_id || null,
    service_id: service_id || null,
    fonction: fonction || null,
    role,
    status: 'actif',
    date_activation: new Date().toISOString(),
    doit_changer_mdp: true,
    created_by: caller.id,
  })

  if (profileError) {
    // Nettoyage si la création du profil échoue (ex: matricule déjà pris)
    await admin.auth.admin.deleteUser(created.user.id)
    throw createError({ statusCode: 400, statusMessage: profileError.message })
  }

  return { success: true, id: created.user.id }
})
