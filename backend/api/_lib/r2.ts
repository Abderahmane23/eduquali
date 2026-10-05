/**
 * Cloudflare R2 — le dépôt des enregistrements, signé en S3 version 4.
 *
 * Point de sortie unique pour le stockage objet. R2 parle le protocole S3, donc
 * ce module vaudrait pour n'importe quel service compatible — mais il est écrit
 * pour R2, et deux choses en dépendent : la région vaut `auto`, et le point
 * d'entrée est `https://<compte>.r2.cloudflarestorage.com`.
 *
 * --- Pourquoi ce fichier existe -------------------------------------------
 *
 * L'enregistrement d'une séance fait un détour obligé :
 *
 *   LiveKit (egress) ──écrit──▶ Cloudflare R2 ──ingère──▶ Cloudflare Stream
 *
 * L'egress de LiveKit produit un `.mp4` monolithique et n'écrit que vers du
 * stockage compatible S3 ; R2 en est, nativement. Stream, de son côté, sait
 * aller chercher une vidéo à une URL. Il faut donc **une URL lisible par Stream,
 * et par personne d'autre**.
 *
 * R2 et Stream étant sur le même réseau Cloudflare, ce transfert ne traverse pas
 * Internet et ne coûte pas d'egress — ce qui n'était pas le cas quand la vidéo
 * sortait vers un tiers.
 *
 * Deux façons de l'obtenir :
 *
 *   1. rendre le dépôt public. Dix lignes de moins, et un cours à 45 000 GNF
 *      téléchargeable par quiconque devine un nom de fichier. Les noms sont
 *      dérivés d'identifiants, pas de secrets : c'est de l'obscurité, pas de la
 *      sécurité. Et il suffit d'une fuite pour que le lien circule sur WhatsApp
 *      comme circule l'APK.
 *   2. signer une URL temporaire. C'est ce qui est fait ici : deux heures, le
 *      temps que Stream ingère, puis le lien ne vaut plus rien.
 *
 * La deuxième coûte ce fichier. C'est le bon prix.
 *
 * --- Pourquoi pas le SDK AWS ----------------------------------------------
 *
 * `@aws-sdk/client-s3` pèse quelques mégaoctets et suppose un environnement
 * Node complet. Le Worker n'a besoin que de signer : HMAC et SHA-256 sont dans
 * WebCrypto, présent à l'identique sur Cloudflare et sous Node 18+.
 */

export interface R2Config {
  /** `https://<compte>.r2.cloudflarestorage.com` — sans le nom du dépôt. */
  endpoint: string
  bucket: string
  accessKey: string
  secret: string
  /** `auto` chez R2 ; une vraie région sur un autre service compatible S3. */
  region: string
}

const encoder = new TextEncoder()

const hex = (octets: ArrayBuffer): string =>
  [...new Uint8Array(octets)]
    .map((o) => o.toString(16).padStart(2, '0'))
    .join('')

async function sha256Hex(texte: string): Promise<string> {
  return hex(await crypto.subtle.digest('SHA-256', encoder.encode(texte)))
}

async function hmac(
  cle: ArrayBuffer | Uint8Array,
  message: string,
): Promise<ArrayBuffer> {
  const importee = await crypto.subtle.importKey(
    'raw',
    cle as ArrayBuffer,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  return crypto.subtle.sign('HMAC', importee, encoder.encode(message))
}

/**
 * L'encodage attendu par S3, qui n'est pas celui d'`encodeURIComponent`.
 *
 * S3 exige que `!`, `'`, `(`, `)` et `*` soient encodés — `encodeURIComponent`
 * les laisse passer. Une signature calculée sur un encodage différent de celui
 * de l'URL envoyée est rejetée avec `SignatureDoesNotMatch`, un message qui ne
 * dit jamais lequel des deux est en cause.
 */
const encodeS3 = (valeur: string): string =>
  encodeURIComponent(valeur).replace(
    /[!'()*]/g,
    (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`,
  )

/** Un chemin d'objet encodé segment par segment : les `/` restent des `/`. */
const encodeKey = (cle: string): string =>
  cle.split('/').map(encodeS3).join('/')

/**
 * La signature elle-même, isolée du reste.
 *
 * Exportée pour une raison précise : c'est la seule partie de ce fichier qu'un
 * **vecteur de test publié par AWS** peut vérifier. Le reste — la construction
 * de la requête canonique — dépend du style d'adressage, donc d'un choix qui
 * nous appartient ; la dérivation de la clé et la chaîne à signer, elles, sont
 * identiques pour tout le monde. Les vérifier contre la documentation vaut mieux
 * que de les vérifier contre une seconde version de mon propre raisonnement,
 * qui porterait la même erreur.
 */
export async function sigv4Signature(input: {
  canonicalRequest: string
  /** `AAAAMMJJTHHMMSSZ`. */
  timestamp: string
  /** `AAAAMMJJ/région/service/aws4_request`. */
  scope: string
  secret: string
}): Promise<string> {
  const aSigner = [
    'AWS4-HMAC-SHA256',
    input.timestamp,
    input.scope,
    await sha256Hex(input.canonicalRequest),
  ].join('\n')

  const [jour, region, service] = input.scope.split('/')
  let cle: ArrayBuffer | Uint8Array = encoder.encode(`AWS4${input.secret}`)
  for (const element of [jour, region, service, 'aws4_request']) {
    cle = await hmac(cle, element)
  }
  return hex(await hmac(cle, aSigner))
}

export class R2 {
  private readonly config: R2Config

  constructor(config: R2Config) {
    this.config = config
  }

  static isConfigured(config: Partial<R2Config>): config is R2Config {
    return Boolean(
      config.endpoint && config.bucket && config.accessKey && config.secret,
    )
  }

  /** Ce que l'egress LiveKit doit recevoir pour écrire au bon endroit. */
  get egressTarget(): {
    endpoint: string
    bucket: string
    accessKey: string
    secret: string
    region: string
  } {
    return {
      endpoint: this.config.endpoint,
      bucket: this.config.bucket,
      accessKey: this.config.accessKey,
      secret: this.config.secret,
      region: this.config.region,
    }
  }

  /**
   * Une URL signée, valable `expiresInSeconds`.
   *
   * Style chemin (`/dépôt/clé`) et non style sous-domaine : R2 accepte les deux,
   * un MinIO auto-hébergé n'accepte souvent que le premier, et l'egress LiveKit
   * est déjà configuré en `force_path_style`. Une seule forme partout évite de
   * signer dans un style et de lire dans l'autre.
   */
  async presign(input: {
    method: 'GET' | 'DELETE'
    key: string
    expiresInSeconds: number
    /** Injectable pour les tests ; l'heure courante sinon. */
    now?: Date
  }): Promise<string> {
    const base = new URL(this.config.endpoint)
    const hote = base.host
    const chemin = `/${this.config.bucket}/${encodeKey(input.key)}`

    const maintenant = input.now ?? new Date()
    const horodatage = maintenant
      .toISOString()
      .replace(/[-:]/g, '')
      .replace(/\.\d{3}/, '')
    const jour = horodatage.slice(0, 8)
    const portee = `${jour}/${this.config.region}/s3/aws4_request`

    // Les paramètres doivent être triés par nom — c'est la requête canonique,
    // pas l'URL finale, qui en décide, et S3 refuse un ordre différent.
    const parametres: Array<[string, string]> = [
      ['X-Amz-Algorithm', 'AWS4-HMAC-SHA256'],
      ['X-Amz-Credential', `${this.config.accessKey}/${portee}`],
      ['X-Amz-Date', horodatage],
      ['X-Amz-Expires', String(input.expiresInSeconds)],
      ['X-Amz-SignedHeaders', 'host'],
    ]
    parametres.sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    const requete = parametres
      .map(([nom, valeur]) => `${encodeS3(nom)}=${encodeS3(valeur)}`)
      .join('&')

    const canonique = [
      input.method,
      chemin,
      requete,
      `host:${hote}`,
      '',
      'host',
      // Le corps n'est pas signé : une URL pré-signée est utilisée par un tiers
      // (Bunny) dont nous ne connaissons pas la requête exacte.
      'UNSIGNED-PAYLOAD',
    ].join('\n')

    const signature = await sigv4Signature({
      canonicalRequest: canonique,
      timestamp: horodatage,
      scope: portee,
      secret: this.config.secret,
    })

    return `${base.origin}${chemin}?${requete}&X-Amz-Signature=${signature}`
  }

  /**
   * Supprime un objet.
   *
   * Appelée quand Stream a fini de transcoder : garder le `.mp4` brut après
   * l'ingestion double le stockage sans rien apporter — Stream sert désormais la
   * vidéo, et le fichier d'origine ne se relit jamais. Une erreur ici n'est
   * pas bloquante — un fichier orphelin coûte quelques centimes, pas un cours —
   * donc elle est rendue, pas levée.
   */
  async remove(key: string): Promise<boolean> {
    try {
      const url = await this.presign({
        method: 'DELETE',
        key,
        expiresInSeconds: 60,
      })
      const reponse = await fetch(url, { method: 'DELETE' })
      return reponse.ok || reponse.status === 404
    } catch {
      return false
    }
  }
}
