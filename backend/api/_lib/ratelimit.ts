/**
 * Limitation de debit (§5 du code_skill).
 *
 * ⚠ Compteur en memoire du processus.
 *
 * Sur Vercel, chaque instance de fonction a sa propre memoire : avec N
 * instances chaudes, la limite reelle vaut N fois la limite configuree. Cela
 * reste tres au-dessus de rien — un script qui enumere les offres depuis une
 * seule machine est arrete — mais ce n'est pas une defense contre un attaquant
 * distribue.
 *
 * Le jour ou cela compte, une seule fonction change : `hit()`. La remplacer
 * par un `INCR` Redis avec expiration, ou par une table Postgres a fenetre
 * glissante, ne touche aucun appelant.
 */

export interface RateLimitRule {
  /** Nombre de requetes autorisees dans la fenetre. */
  limit: number
  /** Largeur de la fenetre, en secondes. */
  windowSeconds: number
}

export interface RateLimitVerdict {
  allowed: boolean
  limit: number
  remaining: number
  /** Date de remise a zero, en secondes epoch. */
  resetAt: number
  /** Secondes a attendre — seulement quand la requete est refusee. */
  retryAfter: number
}

/**
 * Baremes par famille de routes.
 *
 * `auth` est volontairement severe : c'est la seule surface ou une tentative
 * ratee coute quelque chose (un SMS OTP est facture, et un numero enumere est
 * une fuite). `submit` protege la correction des tests — sans plafond, un
 * candidat peut rejouer ses reponses jusqu'a passer.
 */
export const RULES = {
  auth: { limit: 5, windowSeconds: 60 },
  submit: { limit: 10, windowSeconds: 60 },
  write: { limit: 30, windowSeconds: 60 },
  read: { limit: 100, windowSeconds: 60 },
  /*
   * Les webhooks d'un fournisseur.
   *
   * Plafond haut, et ce n'est pas un relachement : ces routes **verifient une
   * signature avant de regarder le corps**, donc un flot non signe est rejete
   * en amont de la base de toute facon. Ce qui les distingue, c'est leur forme :
   * une classe de seize eleves qui entrent a 18 h produit seize evenements de
   * presence dans la meme minute, et plusieurs classes commencent au meme
   * creneau. Au barome `write`, la limitation de debit aurait mange la presence
   * — et un evenement de presence perdu, c'est un temps de cours faux chez le
   * parent, sans aucune trace de la cause.
   *
   * L'identite n'etant pas un jeton ici mais une adresse IP, tous les webhooks
   * d'un meme fournisseur partagent ce compteur. Le plafond est dimensionne
   * pour cela.
   */
  webhook: { limit: 300, windowSeconds: 60 },
} as const satisfies Record<string, RateLimitRule>

export type RuleName = keyof typeof RULES

interface Window {
  count: number
  /** Fin de fenetre, en millisecondes epoch. */
  expiresAt: number
}

const windows = new Map<string, Window>()

/** Empeche la table de grossir indefiniment sur une instance longue duree. */
const MAX_TRACKED_KEYS = 10_000

function sweep(now: number): void {
  for (const [key, window] of windows) {
    if (window.expiresAt <= now) windows.delete(key)
  }
}

/**
 * Enregistre une requete et dit si elle passe.
 *
 * Fenetre fixe : simple, previsible, et son defaut connu (deux fois la limite
 * a cheval sur deux fenetres) est sans consequence aux ordres de grandeur
 * utilises ici.
 */
export function hit(
  identity: string,
  rule: RuleName,
  now: number = Date.now(),
): RateLimitVerdict {
  const { limit, windowSeconds } = RULES[rule]
  const key = `${rule}:${identity}`

  if (windows.size > MAX_TRACKED_KEYS) sweep(now)

  let window = windows.get(key)
  if (!window || window.expiresAt <= now) {
    window = { count: 0, expiresAt: now + windowSeconds * 1000 }
    windows.set(key, window)
  }

  window.count++

  const remaining = Math.max(0, limit - window.count)
  const resetAt = Math.ceil(window.expiresAt / 1000)

  return {
    allowed: window.count <= limit,
    limit,
    remaining,
    resetAt,
    retryAfter: Math.max(1, Math.ceil((window.expiresAt - now) / 1000)),
  }
}

/** Remet les compteurs a zero. Reserve aux tests. */
export function reset(): void {
  windows.clear()
}

/**
 * Identite de l'appelant pour le comptage.
 *
 * Le jeton prime sur l'IP : derriere un operateur mobile guineen, des milliers
 * d'abonnes partagent une poignee d'adresses publiques (CGNAT). Compter par IP
 * seule ferait tomber une ville entiere sur la limite d'un seul utilisateur
 * bavard.
 */
export function identify(
  token: string | undefined,
  headers: { get(name: string): string | null | undefined },
): string {
  if (token) {
    // On ne garde jamais le jeton entier : une empreinte courte suffit a
    // compter, et ne reconstitue pas un identifiant de session.
    return `t:${fingerprint(token)}`
  }
  const forwarded = headers.get('x-forwarded-for') ?? ''
  const ip = forwarded.split(',')[0]?.trim() || 'inconnu'
  return `ip:${ip}`
}

/** Empreinte non reversible et compacte (FNV-1a 32 bits). */
function fingerprint(value: string): string {
  let hash = 0x811c9dc5
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i)
    hash = Math.imul(hash, 0x01000193) >>> 0
  }
  return hash.toString(36)
}

/** Choisit le bareme applicable a une requete. */
export function ruleFor(method: string, path: string): RuleName {
  if (path.startsWith('/auth')) return 'auth'
  if (path.includes('/webhook')) return 'webhook'
  if (path.includes('/submit')) return 'submit'
  return method === 'GET' || method === 'HEAD' ? 'read' : 'write'
}
