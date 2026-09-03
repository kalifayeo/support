import { createClient } from '@supabase/supabase-js'
import { serverSupabaseUser } from '#supabase/server'
import type { H3Event } from 'h3'

// Centralise la création du client admin (clé service_role, jamais exposée
// au navigateur) et la vérification que l'appelant est bien admin/super_admin.
// Utilisé par toutes les routes server/api/admin/*.
export async function requireAdmin(event: H3Event) {
  const config = useRuntimeConfig()

  const caller = await serverSupabaseUser(event)
  if (!caller) throw createError({ statusCode: 401, statusMessage: 'Non authentifié.' })

  const admin = createClient(config.public.supabaseUrl as string, config.supabaseServiceRoleKey as string, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: callerProfile } = await admin.from('profiles').select('role').eq('id', caller.id).single()
  if (!callerProfile || !['admin', 'super_admin'].includes(callerProfile.role)) {
    throw createError({ statusCode: 403, statusMessage: 'Réservé aux administrateurs.' })
  }

  return { admin, caller }
}
