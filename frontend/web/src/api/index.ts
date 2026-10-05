import { HttpApi, type VeriprofApi } from './client'
import { MockApi } from './mock'
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
 * Faux en acces direct a Supabase, et ce n'est pas un manque a combler :
 * corriger dans le navigateur demanderait de lui livrer les bonnes reponses,
 * et une note qu'on peut calculer soi-meme ne certifie rien. `submitTest` leve
 * donc un 501 dans ce mode.
 *
 * L'ecran s'en sert pour ne pas laisser repondre a vingt questions avant
 * d'annoncer que rien ne sera enregistre.
 */
export const canGradeTests = !isSupabaseBackend

export type { VeriprofApi } from './client'
export { ApiError } from './client'
