import { createClient, type SupabaseClient } from '@supabase/supabase-js'

/**
 * Acces a la base.
 *
 * Deux clients, deux usages :
 *  - `asUser` porte le jeton de l'appelant, donc toutes les politiques RLS
 *    s'appliquent. C'est celui a utiliser par defaut.
 *  - `asService` contourne RLS. Il est reserve aux operations que l'appelant
 *    n'a pas le droit de faire lui-meme : corriger un test (il ne doit pas
 *    voir les bonnes reponses), delivrer une certification, lire le profil
 *    d'un enseignant pour calculer un score.
 */

const url = process.env.SUPABASE_URL
const anonKey = process.env.SUPABASE_ANON_KEY
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY

export const isConfigured = Boolean(url && anonKey)

export class ConfigError extends Error {
  constructor() {
    super(
      'Base non configuree : renseignez SUPABASE_URL et SUPABASE_ANON_KEY.',
    )
  }
}

/** Client agissant au nom de l'utilisateur : RLS actif. */
export function asUser(accessToken?: string): SupabaseClient {
  if (!url || !anonKey) throw new ConfigError()
  return createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: accessToken
      ? { headers: { Authorization: `Bearer ${accessToken}` } }
      : undefined,
  })
}

/**
 * Client privilegie. A n'employer que pour une raison explicite, jamais par
 * commodite : il ouvre l'ensemble des donnees.
 */
export function asService(): SupabaseClient {
  if (!url || !serviceKey) {
    throw new Error(
      'Operation privilegiee indisponible : SUPABASE_SERVICE_ROLE_KEY manquante.',
    )
  }
  return createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}

/** Jeton porte par la requete, le cas echeant. */
export function bearer(header: string | undefined | null): string | undefined {
  if (!header) return undefined
  const [scheme, token] = header.split(' ')
  return scheme?.toLowerCase() === 'bearer' && token ? token : undefined
}
