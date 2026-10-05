/**
 * LiveKit — le seul module qui parle à la visioconférence.
 *
 * Point de sortie unique, comme pour Djomy : changer de fournisseur ne doit
 * toucher que ce fichier.
 *
 * --- Pourquoi LiveKit ------------------------------------------------------
 *
 * Serveur de diffusion sélective : il n'envoie à chaque élève que ce que sa
 * connexion supporte, et dégrade le flux plutôt que de le couper. Sur une ligne
 * guinéenne, c'est ce qui décide si un cours a lieu. Une architecture en maillage
 * (chacun envoie à tous) demanderait à un élève de téléverser quatorze flux :
 * impossible ici.
 *
 * --- Comment l'accès fonctionne -------------------------------------------
 *
 * LiveKit n'a pas de notion de compte : il fait confiance à un **jeton JWT que
 * nous signons** avec le secret du projet. Tout le contrôle d'accès est donc
 * chez nous, et c'est une responsabilité, pas une commodité — un jeton émis
 * sans vérifier l'inscription laisse entrer n'importe qui dans une classe
 * payante.
 *
 * Trois règles tiennent cette porte :
 *
 *   1. le jeton est **nominatif** (`sub` = identifiant du compte), donc une
 *      place ne se partage pas ;
 *   2. il est **court** — il expire peu après la fin de la séance, pas dans un
 *      mois ;
 *   3. seul le professeur reçoit le droit de publier sa caméra par défaut ; un
 *      élève publie lorsqu'il a la parole.
 */

export interface LiveKitConfig {
  /** `wss://<projet>.livekit.cloud` */
  url: string
  apiKey: string
  apiSecret: string
}

/** Ce qu'un participant a le droit de faire. */
export type RoomRole = 'teacher' | 'student'

export class LiveKitError extends Error {
  readonly status: number

  constructor(message: string, status = 502) {
    super(message)
    this.status = status
  }
}

// --- Outils cryptographiques ----------------------------------------------

const encoder = new TextEncoder()

/** base64url sans remplissage, la forme attendue dans un JWT. */
function base64url(bytes: Uint8Array): string {
  let brut = ''
  for (const octet of bytes) brut += String.fromCharCode(octet)
  return btoa(brut).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

const base64urlText = (texte: string): string =>
  base64url(encoder.encode(texte))

/**
 * Signe un JWT en HS256.
 *
 * WebCrypto plutôt que `node:crypto` : la même API sur Cloudflare Workers et
 * sous Node 18+, donc ce module se teste hors du Worker sans adaptation.
 */
async function signJwt(
  payload: Record<string, unknown>,
  secret: string,
): Promise<string> {
  const entete = base64urlText(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
  const corps = base64urlText(JSON.stringify(payload))
  const aSigner = `${entete}.${corps}`

  const cle = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'HMAC',
    cle,
    encoder.encode(aSigner),
  )
  return `${aSigner}.${base64url(new Uint8Array(signature))}`
}

// --- Le client -------------------------------------------------------------

export class LiveKit {
  private readonly config: LiveKitConfig

  constructor(config: LiveKitConfig) {
    this.config = config
  }

  static isConfigured(config: Partial<LiveKitConfig>): config is LiveKitConfig {
    return Boolean(config.url && config.apiKey && config.apiSecret)
  }

  get url(): string {
    return this.config.url
  }

  /**
   * Le nom de la salle d'une séance.
   *
   * Dérivé de l'identifiant de la séance, et non tiré au hasard : il doit être
   * recalculable sans lecture en base, pour qu'un jeton émis deux fois mène à la
   * même salle. Préfixé pour qu'un nom de salle ne puisse pas être confondu
   * avec autre chose dans la console LiveKit.
   */
  static roomFor(sessionId: string): string {
    return `seance-${sessionId}`
  }

  /**
   * L'identité d'un participant dans la salle.
   *
   * **Pourquoi la place et non le compte.** LiveKit déconnecte le premier
   * participant quand un second arrive avec la même identité. Si l'identité
   * était le compte, deux enfants d'une même famille inscrits à la même séance —
   * deux places payées, deux tablettes — se chasseraient l'un l'autre. La place
   * est donc l'identité, et cette propriété devient utile : **une place payée,
   * une connexion**, un partage de mot de passe ne donne pas deux entrées.
   *
   * Le professeur n'a pas de place ; il porte son identifiant d'enseignant.
   */
  static identityFor(
    input:
      | { role: 'student'; enrolmentId: string }
      | { role: 'teacher'; teacherId: string },
  ): string {
    return input.role === 'teacher'
      ? `prof-${input.teacherId}`
      : `place-${input.enrolmentId}`
  }

  /** L'inverse : ce qu'une identité désigne, ou `null` si elle est étrangère. */
  static parseIdentity(
    identity: string,
  ):
    | { role: 'student'; enrolmentId: string }
    | { role: 'teacher'; teacherId: string }
    | null {
    if (identity.startsWith('place-')) {
      const id = identity.slice('place-'.length)
      return id === '' ? null : { role: 'student', enrolmentId: id }
    }
    if (identity.startsWith('prof-')) {
      const id = identity.slice('prof-'.length)
      return id === '' ? null : { role: 'teacher', teacherId: id }
    }
    return null
  }

  /**
   * Émet un jeton d'entrée.
   *
   * `ttlSeconds` doit couvrir la séance et un peu plus — un élève qui perd le
   * réseau à la 80ᵉ minute doit pouvoir revenir — mais pas des heures : un jeton
   * qui traîne est une porte ouverte.
   *
   * Le professeur publie d'emblée. Un élève **ne publie pas** par défaut : il
   * demande la parole, et c'est le professeur qui la donne. Donner le droit de
   * publier à quinze adolescents dès l'entrée rendrait le cours impossible à
   * tenir.
   */
  async joinToken(input: {
    sessionId: string
    identity: string
    name: string
    role: RoomRole
    ttlSeconds: number
  }): Promise<{ token: string; url: string; room: string }> {
    const room = LiveKit.roomFor(input.sessionId)
    const maintenant = Math.floor(Date.now() / 1000)
    const professeur = input.role === 'teacher'

    const token = await signJwt(
      {
        iss: this.config.apiKey,
        sub: input.identity,
        // `nbf` reculé d'une minute : l'horloge d'un téléphone guinéen n'est pas
        // toujours juste, et un jeton « pas encore valable » se lit comme une
        // panne.
        nbf: maintenant - 60,
        exp: maintenant + input.ttlSeconds,
        name: input.name,
        video: {
          room,
          roomJoin: true,
          canSubscribe: true,
          canPublish: professeur,
          canPublishData: true,
          // Le professeur anime : il peut couper un micro et gérer la salle.
          roomAdmin: professeur,
        },
      },
      this.config.apiSecret,
    )

    return { token, url: this.config.url, room }
  }

  /**
   * Un jeton de service pour les appels d'administration.
   *
   * Même secret, mais des droits de serveur et une durée très courte : il ne
   * quitte jamais le Worker.
   */
  private serviceToken(): Promise<string> {
    const maintenant = Math.floor(Date.now() / 1000)
    return signJwt(
      {
        iss: this.config.apiKey,
        sub: this.config.apiKey,
        nbf: maintenant - 60,
        exp: maintenant + 120,
        video: { roomList: true, roomCreate: true, roomAdmin: true },
      },
      this.config.apiSecret,
    )
  }

  /** L'adresse HTTPS de l'API, déduite de l'URL WebSocket. */
  private get httpBase(): string {
    return this.config.url.replace(/^wss:/, 'https:').replace(/^ws:/, 'http:')
  }

  /** Un appel au service LiveKit, en Twirp. */
  private async call(
    service: string,
    methode: string,
    corps: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    const jeton = await this.serviceToken()
    let reponse: Response
    try {
      reponse = await fetch(`${this.httpBase}/twirp/${service}/${methode}`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${jeton}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(corps),
      })
    } catch (cause) {
      throw new LiveKitError(
        `LiveKit injoignable : ${cause instanceof Error ? cause.message : cause}`,
        503,
      )
    }

    const donnees = (await reponse.json().catch(() => ({}))) as Record<
      string,
      unknown
    >
    if (!reponse.ok) {
      throw new LiveKitError(
        (donnees.msg as string) ??
          (donnees.message as string) ??
          `LiveKit a refusé la demande (${reponse.status}).`,
        reponse.status,
      )
    }
    return donnees
  }

  /** Qui est dans la salle, selon LiveKit. */
  async participants(sessionId: string): Promise<string[]> {
    const reponse = await this.call('livekit.RoomService', 'ListParticipants', {
      room: LiveKit.roomFor(sessionId),
    })
    const liste = Array.isArray(reponse.participants) ? reponse.participants : []
    return liste
      .map((p) => (p as Record<string, unknown>).identity)
      .filter((i): i is string => typeof i === 'string')
  }

  /** Ferme une salle : tout le monde sort. */
  async closeRoom(sessionId: string): Promise<void> {
    await this.call('livekit.RoomService', 'DeleteRoom', {
      room: LiveKit.roomFor(sessionId),
    })
  }

  /**
   * Démarre l'enregistrement d'une séance vers un stockage compatible S3.
   *
   * **Pourquoi un dépôt et non l'hébergeur vidéo directement :** l'egress de
   * LiveKit écrit vers du stockage compatible S3, GCP, Azure ou Alibaba — jamais
   * vers un service de diffusion. Cloudflare R2 parle S3 nativement, donc le
   * fichier y atterrit, puis Cloudflare Stream vient l'ingérer par URL
   * (`_lib/stream.ts`).
   *
   * Deux étapes, et elles ne coûtent rien de plus : R2 et Stream sont sur le même
   * réseau Cloudflare, donc le transfert ne traverse pas Internet. Le découpage
   * HLS multi-débits reste chez Stream, qui le fait mieux que nous — un `.mp4`
   * monolithique de 90 minutes s'arrête à chaque creux de réseau.
   *
   * Rend l'identifiant d'egress, à conserver pour pouvoir arrêter.
   */
  async startRecording(input: {
    sessionId: string
    s3: {
      endpoint: string
      bucket: string
      accessKey: string
      secret: string
      region?: string
    }
    filename: string
  }): Promise<string> {
    const reponse = await this.call('livekit.Egress', 'StartRoomCompositeEgress', {
      room_name: LiveKit.roomFor(input.sessionId),
      // Mise en page « orateur » : le professeur occupe l'écran. Une grille de
      // quinze vignettes ne se regarde pas en rediffusion.
      layout: 'speaker',
      file_outputs: [
        {
          filepath: input.filename,
          s3: {
            access_key: input.s3.accessKey,
            secret: input.s3.secret,
            bucket: input.s3.bucket,
            endpoint: input.s3.endpoint,
            region: input.s3.region ?? 'auto',
            force_path_style: true,
          },
        },
      ],
    })
    const id = reponse.egress_id
    if (typeof id !== 'string') {
      throw new LiveKitError('LiveKit n’a pas rendu d’identifiant d’egress.')
    }
    return id
  }

  /** Arrête un enregistrement. */
  async stopRecording(egressId: string): Promise<void> {
    await this.call('livekit.Egress', 'StopEgress', { egress_id: egressId })
  }

  /**
   * Vérifie un webhook LiveKit et rend l'évènement.
   *
   * --- Comment LiveKit signe ------------------------------------------------
   *
   * Pas d'en-tête `X-Signature` comme chez Djomy : LiveKit met dans
   * `Authorization` **un JWT signé avec le secret du projet**, dont la
   * revendication `sha256` contient l'empreinte du corps, en base64. Vérifier
   * suppose donc deux choses, et les deux comptent :
   *
   *   1. la signature du jeton — sinon n'importe qui annonce « la séance est
   *      finie » ou « cet élève est parti », et le temps de cours que le parent
   *      lit devient faux ;
   *   2. l'empreinte du corps — sinon un jeton valable intercepté permet de
   *      remplacer le corps par un autre.
   *
   * Le corps doit être le **texte brut reçu**, pas un objet réanalysé : passer
   * par `JSON.parse` puis `JSON.stringify` change les espaces et l'ordre des
   * clés, et l'empreinte ne correspond plus. C'est l'erreur qui fait croire à un
   * secret erroné.
   */
  async verifyWebhook(
    authorization: string | undefined,
    rawBody: string,
  ): Promise<LiveKitEvent> {
    const jeton = (authorization ?? '').replace(/^Bearer\s+/i, '').trim()
    if (!jeton) throw new LiveKitError('Webhook sans jeton.', 401)

    const morceaux = jeton.split('.')
    if (morceaux.length !== 3) {
      throw new LiveKitError('Jeton de webhook mal forme.', 401)
    }
    const [entete, corps, signature] = morceaux

    const cle = await crypto.subtle.importKey(
      'raw',
      encoder.encode(this.config.apiSecret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    )
    const attendue = base64url(
      new Uint8Array(
        await crypto.subtle.sign(
          'HMAC',
          cle,
          encoder.encode(`${entete}.${corps}`),
        ),
      ),
    )
    // Comparaison à temps constant : comparer deux signatures avec `===` laisse
    // fuir, par la durée, le nombre de caractères devines.
    if (!equalsConstantTime(signature, attendue)) {
      throw new LiveKitError('Signature de webhook invalide.', 401)
    }

    const revendications = JSON.parse(decodeBase64url(corps)) as Record<
      string,
      unknown
    >

    const maintenant = Math.floor(Date.now() / 1000)
    if (
      typeof revendications.exp === 'number' &&
      revendications.exp + 60 < maintenant
    ) {
      throw new LiveKitError('Jeton de webhook expire.', 401)
    }

    const empreinte = new Uint8Array(
      await crypto.subtle.digest('SHA-256', encoder.encode(rawBody)),
    )
    // LiveKit publie l'empreinte en base64 standard ; on compare sur une forme
    // unique pour ne pas dépendre du remplissage.
    const normalise = (valeur: string) =>
      valeur.replace(/-/g, '+').replace(/_/g, '/').replace(/=+$/, '')
    let brut = ''
    for (const octet of empreinte) brut += String.fromCharCode(octet)
    if (
      typeof revendications.sha256 !== 'string' ||
      !equalsConstantTime(normalise(revendications.sha256), normalise(btoa(brut)))
    ) {
      throw new LiveKitError('Corps du webhook altere.', 401)
    }

    return JSON.parse(rawBody) as LiveKitEvent
  }
}

/** Les évènements que nous traitons ; LiveKit en envoie d'autres. */
export interface LiveKitEvent {
  event: string
  /** Présent sur les évènements de salle et de participant. */
  room?: { name?: string; sid?: string }
  participant?: { identity?: string; name?: string }
  egressInfo?: {
    egress_id?: string
    egressId?: string
    status?: string
    file?: { filename?: string; location?: string }
    file_results?: Array<{ filename?: string; location?: string }>
    fileResults?: Array<{ filename?: string; location?: string }>
  }
  /** Horodatage LiveKit, en secondes. Absent sur certains évènements. */
  createdAt?: number | string
  id?: string
}

/**
 * La séance derrière un nom de salle.
 *
 * L'inverse de `LiveKit.roomFor`. Rend `null` sur un nom inconnu plutôt que de
 * deviner : un webhook pour une salle qui n'est pas la nôtre doit être ignoré,
 * pas traité au hasard.
 */
export function sessionFromRoom(room: string | undefined): string | null {
  if (!room || !room.startsWith('seance-')) return null
  const id = room.slice('seance-'.length)
  return id === '' ? null : id
}

function decodeBase64url(valeur: string): string {
  const base64 = valeur.replace(/-/g, '+').replace(/_/g, '/')
  const comble = base64 + '='.repeat((4 - (base64.length % 4)) % 4)
  return atob(comble)
}

function equalsConstantTime(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let difference = 0
  for (let i = 0; i < a.length; i += 1) {
    difference |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return difference === 0
}
