// Modifie les informations d'un utilisateur existant (nom, coordonnées,
// direction/service, fonction, matricule). Si l'email professionnel change,
// on synchronise aussi l'email de connexion Supabase Auth pour que le
// matricule continue de résoudre vers le bon compte.
export default defineEventHandler(async (event) => {
  const { admin } = await requireAdmin(event)

  const body = await readBody(event)
  const { id, matricule, nom, prenom, email_pro, telephone, direction_id, service_id, fonction } = body

  if (!id || !matricule || !nom || !prenom || !email_pro) {
    throw createError({ statusCode: 400, statusMessage: 'Champs obligatoires manquants.' })
  }
  if (!/^[A-Z][0-9]{3,5}$/.test(matricule.toUpperCase())) {
    throw createError({ statusCode: 400, statusMessage: 'Format de matricule invalide.' })
  }

  const { data: existant } = await admin.from('profiles').select('email_pro').eq('id', id).single()
  if (!existant) throw createError({ statusCode: 404, statusMessage: 'Utilisateur introuvable.' })

  // Synchroniser l'email de connexion si modifié
  if (existant.email_pro !== email_pro) {
    const { error: authError } = await admin.auth.admin.updateUserById(id, { email: email_pro, email_confirm: true })
    if (authError) throw createError({ statusCode: 400, statusMessage: authError.message })
  }

  const { error: profileError } = await admin.from('profiles').update({
    matricule: matricule.toUpperCase(),
    nom, prenom, telephone: telephone || null, email_pro,
    direction_id: direction_id || null,
    service_id: service_id || null,
    fonction: fonction || null,
  }).eq('id', id)

  if (profileError) throw createError({ statusCode: 400, statusMessage: profileError.message })

  return { success: true }
})
