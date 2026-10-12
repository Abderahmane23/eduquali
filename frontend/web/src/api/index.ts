import { HttpApi, type VeriprofApi } from './client'
import { MockApi } from './mock'
import { brancherJeton } from './server'
import { createSupabaseApi } from './supabase'

/**
 * Choix de l'implementation.
 *
 * Trois, dans cet ordre de priorite :
 *
 *   1. **Supabase en direct** des que `VITE_SUPABASE_URL` et
 *      `VITE_SUPABASE_ANON_KEY` sont renseignees. C'est le mode retenu le
 *      25/09 : la base est hebergee chez Supabase et le navigateur lui parle
 *      sans serveur intermediaire. La securite repose entierement sur RLS —
 *      voir l'en-tete de `supabase.ts`.
 *   2. **REST** si `VITE_API_BASE_URL` est renseignee, pour le jour ou une
 *      API propre existera devant la base.
 *   3. **Simule**, sinon : l'application reste entierement parcourable sans
 *      serveur, ce qui garde le developpement possible hors ligne.
 *
 * Aucun ecran ne sait laquelle est active. C'est tout l'interet d'avoir une
 * seule interface : brancher la vraie base n'a touche aucun ecran.
 */
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL?.trim()
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim()
const configured = import.meta.env.VITE_API_BASE_URL?.trim()

const supabase = createSupabaseApi(supabaseUrl, supabaseKey)

// Deploye derriere une API, le chemin relatif suffit et evite toute question
// de CORS. Sans Supabase ni variable, on retombe sur le backend simule.
const baseUrl = configured ?? (import.meta.env.PROD ? '/api/v1' : undefined)

export const api: VeriprofApi =
  supabase ?? (baseUrl ? new HttpApi(baseUrl.replace(/\/$/, '')) : new MockApi())

/** Vrai lorsque les données affichees sont celles de démonstration. */
export const isMockBackend = api instanceof MockApi

/** Vrai lorsque le navigateur parle directement a Supabase. */
export const isSupabaseBackend = supabase !== null

/**
 * Vrai quand le backend actif sait corriger un test.
 *
 * --- Ce qui a change le 11/10 ------------------------------------------
 *
 * Ce drapeau valait `!isSupabaseBackend`, et le raisonnement etait juste :
 * corriger dans le navigateur demanderait de lui livrer les bonnes reponses,
 * et une note qu'on peut recalculer soi-meme ne certifie rien.
 *
 * Mais la conclusion ne suivait plus. Corriger **n'a jamais eu besoin** de se
 * faire dans le navigateur : la route `POST /tests/:id/submit` lit les bonnes
 * reponses sous la cle de service et rend la note. Ce qui manquait n'etait pas
 * la regle, c'etait l'appel — et un candidat pouvait repondre a soixante
 * questions sans jamais etre note.
 *
 * La vraie condition est donc : y a-t-il un serveur a qui demander ? Sans
 * `VITE_API_BASE_URL`, `callApi` leve, et l'ecran doit le dire avant la
 * premiere question plutot qu'apres la derniere.
 */
export const canGradeTests = !isSupabaseBackend || Boolean(configured)

/*
 * Le jeton, branché une fois.
 *
 * `api/server.ts` porte les appels que PostgREST ne peut pas faire — revenus,
 * retraits, assistant, dépôt de pièces. Il lui faut le jeton de la session,
 * et c'est Supabase qui le détient et le rafraîchit.
 *
 * Lu à chaque appel et non capturé : un jeton pris au montage d'une page est
 * périmé une heure plus tard, et l'écran dirait « reconnectez-vous » à
 * quelqu'un qui est connecté.
 *
 * Sans Supabase — mode REST ou simulé — il n'y a pas de jeton à lire, et ces
 * appels lèvent une phrase qui le dit plutôt que de partir sans en-tête.
 */
brancherJeton(async () => {
  if (!supabase) return null
  return supabase.accessToken()
})

export type { VeriprofApi } from './client'
export { ApiError } from './client'
