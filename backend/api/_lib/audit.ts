import { createHash } from 'node:crypto'

/**
 * Journal d'audit (§5 du code_skill, §51 du cahier des charges).
 *
 * Une plateforme qui delivre des certifications et manipule des pieces
 * d'identite doit pouvoir repondre a « qui a fait quoi, quand, depuis ou ».
 * Sans ce journal, une certification contestee est indefendable.
 *
 * Deux regles tiennent tout le fichier :
 *  1. On journalise la forme de la charge utile, jamais son contenu sensible.
 *     Les mots de passe, jetons et reponses de test sont remplaces avant
 *     toute ecriture — et avant meme le calcul de l'empreinte, sinon
 *     l'empreinte devient elle-meme un oracle.
 *  2. Une panne du journal ne fait jamais echouer la requete metier. Un audit
 *     qui casse la production finit desactive.
 */

/** Cles dont la valeur ne doit jamais atteindre le journal. */
const REDACTED_KEYS = [
  'password',
  'motdepasse',
  'mot_de_passe',
  'pin',
  'token',
  'access_token',
  'accessToken',
  'refresh_token',
  'refreshToken',
  'api_key',
  'apiKey',
  'authorization',
  'secret',
  'otp',
  'code',
  'answers', // les reponses d'un test : les journaliser, c'est publier le corrige
  'correct_key',
  'signature',
]

const REDACTED = '[redacted]'
const MAX_DEPTH = 6
const MAX_STRING = 512

const isRedacted = (key: string): boolean =>
  REDACTED_KEYS.some((k) => key.toLowerCase() === k.toLowerCase())

/**
 * Copie assainie d'une charge utile.
 *
 * Les valeurs sensibles disparaissent ; les chaines trop longues sont
 * tronquees pour qu'un client ne puisse pas faire grossir la table d'audit a
 * volonte.
 */
export function sanitize(value: unknown, depth = 0): unknown {
  if (value === null || value === undefined) return value
  if (depth >= MAX_DEPTH) return '[profond]'

  if (typeof value === 'string') {
    return value.length > MAX_STRING
      ? `${value.slice(0, MAX_STRING)}…[${value.length} car.]`
      : value
  }
  if (typeof value === 'number' || typeof value === 'boolean') return value

  if (Array.isArray(value)) {
    // Un tableau long n'apprend rien de plus : on garde la tete et la taille.
    const head = value.slice(0, 20).map((v) => sanitize(v, depth + 1))
    return value.length > 20 ? [...head, `…${value.length - 20} de plus`] : head
  }

  if (typeof value === 'object') {
    const out: Record<string, unknown> = {}
    for (const [key, child] of Object.entries(value as object)) {
      out[key] = isRedacted(key) ? REDACTED : sanitize(child, depth + 1)
    }
    return out
  }

  return '[non serialisable]'
}

/** Empreinte de la charge utile assainie — comparable, non reversible. */
export function digest(payload: unknown): string {
  return createHash('sha256')
    .update(JSON.stringify(payload ?? null))
    .digest('hex')
}

export interface AuditEntry {
  method: string
  path: string
  status: number
  /** Identifiant de l'appelant, quand il est connu. */
  userId?: string
  ip?: string
  userAgent?: string
  durationMs: number
  payload?: unknown
}

export interface AuditRow {
  method: string
  path: string
  status: number
  user_id: string | null
  ip: string | null
  user_agent: string | null
  duration_ms: number
  payload: unknown
  payload_sha256: string
  created_at: string
}

/** Transforme une requete observee en ligne prete a inserer. */
export function toRow(entry: AuditEntry): AuditRow {
  const payload = sanitize(entry.payload)
  return {
    method: entry.method,
    path: entry.path,
    status: entry.status,
    user_id: entry.userId ?? null,
    ip: entry.ip ?? null,
    // Un user-agent est declaratif et peut etre enorme : on le borne.
    user_agent: entry.userAgent ? entry.userAgent.slice(0, 256) : null,
    duration_ms: Math.round(entry.durationMs),
    payload,
    payload_sha256: digest(payload),
    created_at: new Date().toISOString(),
  }
}

/**
 * Les requetes qui ne meritent pas une ligne.
 *
 * `/health` est appele par les sondes toutes les minutes : le journaliser
 * noierait les evenements reels et ferait grossir la table pour rien.
 */
export function isAuditable(method: string, path: string): boolean {
  if (path === '/health') return false
  // Toute mutation, et les lectures de donnees personnelles.
  if (method !== 'GET' && method !== 'HEAD') return true
  /*
   * Les lectures qui portent des donnees personnelles.
   *
   * `/teachers` rend des fiches. `/operations` rend la file des retraits —
   * qui attend combien d'argent, et sur quel numero l'envoyer. C'est la
   * seule partie du produit qui rend un numero de telephone complet, et une
   * consultation doit y laisser la meme trace qu'une decision.
   */
  return path.startsWith('/teachers') || path.startsWith('/operations')
}

type Insert = (row: AuditRow) => Promise<unknown>

/**
 * Ecrit une entree sans jamais faire echouer l'appelant.
 *
 * Le journal est une preuve, pas une dependance : si la base d'audit tombe,
 * la candidature part quand meme et l'incident part dans les logs.
 */
export async function writeEvent(
  insert: Insert,
  entry: AuditEntry,
): Promise<void> {
  try {
    await insert(toRow(entry))
  } catch (error) {
    console.error('[audit] ecriture impossible', error)
  }
}
