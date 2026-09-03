// Réinitialise le mot de passe d'un utilisateur (ex: mot de passe oublié).
// Fonctionne exactement comme le mot de passe temporaire de création :
// doit_changer_mdp repasse à true, donc à sa prochaine connexion l'utilisateur
// pourra le garder ou le changer immédiatement (3 champs).
export default defineEventHandler(async (event) => {
  const { admin } = await requireAdmin(event)

  const body = await readBody(event)
  const { id, mot_de_passe } = body

  if (!id || !mot_de_passe) {
    throw createError({ statusCode: 400, statusMessage: 'Champs obligatoires manquants.' })
  }
  if (mot_de_passe.length < 6) {
    throw createError({ statusCode: 400, statusMessage: 'Le mot de passe doit contenir au moins 6 caractères.' })
  }

  const { error: authError } = await admin.auth.admin.updateUserById(id, { password: mot_de_passe })
  if (authError) throw createError({ statusCode: 400, statusMessage: authError.message })

  const { error: profileError } = await admin.from('profiles').update({ doit_changer_mdp: true }).eq('id', id)
  if (profileError) throw createError({ statusCode: 400, statusMessage: profileError.message })

  return { success: true }
})
