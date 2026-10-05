/**
 * Qui a le droit d'appeler l'API depuis un navigateur.
 *
 * --- Pourquoi ceci est un fichier a part ---------------------------------
 *
 * La regle etait une fermeture anonyme dans la declaration du middleware :
 * correcte, mais impossible a eprouver sans monter tout le routeur — qui importe
 * Supabase, Djomy, LiveKit et le reste. Une politique d'acces qu'on ne peut pas
 * tester est une politique qu'on relit en esperant.
 *
 * Fonction pure, donc : trois arguments, un retour, et chaque cas limite
 * s'eprouve seul.
 *
 * --- CORS ne protege pas l'API -----------------------------------------
 *
 * Il faut le dire ici parce que c'est la source d'une erreur tenace : **CORS est
 * une regle que le navigateur s'impose**, pas une barriere serveur. Un client
 * natif — l'application Flutter, `curl`, un script — n'envoie pas d'`Origin` et
 * n'est soumis a rien. Ce qui protege les donnees, c'est l'authentification et
 * RLS.
 *
 * CORS sert a une seule chose : empecher qu'un **autre site web** fasse
 * executer des requetes authentifiees par le navigateur de la personne, avec ses
 * jetons. D'ou la liste explicite, et jamais d'etoile.
 */

/** Ce que le middleware `cors` de Hono attend en retour. */
export type OriginVerdict = string | null | undefined

export interface CorsPolicy {
  /** Les origines declarees, deja decoupees et nettoyees. */
  allowed: string[]
  /** Hors production, les adresses de developpement sont ajoutees. */
  isProduction: boolean
}

/**
 * Les origines de developpement, ajoutees hors production.
 *
 * Les deux formes de localhost : un navigateur envoie exactement ce que la barre
 * d'adresse contient, et `127.0.0.1` n'est pas `localhost` pour CORS.
 */
export const DEV_ORIGINS = [
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  // Flutter web en developpement choisit un port au hasard ; celui-ci est le
  // defaut quand on le fixe (`flutter run -d chrome --web-port=5174`).
  'http://localhost:5174',
]

/** Decoupe la variable d'environnement en liste d'origines. */
export const parseOrigins = (brut: string | undefined): string[] =>
  (brut ?? '')
    .split(',')
    .map((origine) => origine.trim())
    .filter(Boolean)

/**
 * Le verdict pour une origine donnee.
 *
 * Trois retours, et ils ne veulent pas dire la meme chose :
 *
 *   * `undefined` — **pas d'origine du tout.** La requete ne vient pas d'un
 *     navigateur : c'est l'application mobile, un script, une sonde. On ne pose
 *     aucun en-tete et **on ne refuse pas** : il n'y a rien a autoriser, et
 *     refuser couperait l'APK du serveur sans qu'aucun ecran ne l'explique.
 *   * l'origine elle-meme — autorisee.
 *   * `null` — refusee. Le navigateur de la personne bloquera la reponse.
 *
 * Jamais `'*'` : avec `credentials: true` le navigateur rejette la combinaison,
 * et surtout une etoile laisserait tout le web appeler l'API avec les jetons de
 * la personne.
 */
export function resolveOrigin(
  origin: string | undefined,
  policy: CorsPolicy,
): OriginVerdict {
  if (!origin) return undefined
  if (policy.allowed.includes(origin)) return origin
  if (!policy.isProduction && DEV_ORIGINS.includes(origin)) return origin
  return null
}
