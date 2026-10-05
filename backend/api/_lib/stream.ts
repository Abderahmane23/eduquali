/**
 * Cloudflare Stream — le seul module qui parle à l'hébergeur vidéo.
 *
 * Point de sortie unique, comme LiveKit, Djomy et R2.
 *
 * --- Pourquoi Cloudflare Stream, et plus Bunny ----------------------------
 *
 * La chaîne d'enregistrement est :
 *
 *   LiveKit Egress ──écrit──▶ Cloudflare R2 ──ingère──▶ Cloudflare Stream
 *
 * L'egress de LiveKit produit un `.mp4` monolithique : il n'écrit que vers du
 * stockage compatible S3, et R2 en est. Un `.mp4` de 90 minutes servi tel quel
 * est inregardable sur une ligne guinéenne — le lecteur télécharge au débit du
 * fichier, pas du réseau, et s'arrête à chaque creux.
 *
 * Stream le découpe en HLS multi-débits (360p à 1080p) : la lecture démarre sur
 * un fragment de deux secondes très compressé, et la qualité se dégrade au lieu
 * de s'interrompre quand le signal faiblit. C'est la différence entre « le cours
 * se revoit » et « le cours se revoit chez quelqu'un qui a la fibre ».
 *
 * Ce que le passage de Bunny à Stream apporte concrètement :
 *
 *   * **R2 et Stream sont sur le même réseau interne.** Faire passer le fichier
 *     de l'un à l'autre ne traverse pas Internet, donc ne coûte pas d'egress.
 *     Avec Bunny, le fichier sortait de R2 pour entrer chez un tiers ;
 *   * **un fournisseur de moins.** Une facture, un jeton, une console, un
 *     incident possible en moins — et le reste de l'infrastructure (le Worker,
 *     R2) est déjà chez Cloudflare ;
 *   * **la signature est faite par eux.** Bunny demandait de calculer
 *     `SHA256(tokenKey + videoId + expiration)` à la main, avec un mode « chemin »
 *     qui changeait la chaîne signée — une note `⚠ à vérifier` traînait dans
 *     l'ancien module. Stream émet le jeton par API : il n'y a plus de formule à
 *     deviner.
 */

const API = 'https://api.cloudflare.com/client/v4'

export interface StreamConfig {
  accountId: string
  /** Jeton d'API avec la permission « Stream : Edit ». */
  apiToken: string
  /**
   * Le sous-domaine de lecture, `customer-xxxxxxxx`.
   *
   * Visible dans le tableau de bord Stream, et aussi dans les URL que l'API
   * rend. On le configure plutôt que de le déduire d'une réponse : la première
   * lecture d'une vidéo doit pouvoir se faire sans un appel supplémentaire.
   */
  customerCode: string
}

export class StreamError extends Error {
  readonly status: number

  constructor(message: string, status = 502) {
    super(message)
    this.status = status
    this.name = 'StreamError'
  }
}

/**
 * Les noms de champs de l'API, rassemblés.
 *
 * Même raison que pour Djomy : ce sont les seules valeurs que la documentation
 * peut contredire. Les isoler fait qu'une correction tient en une ligne au lieu
 * d'une chasse dans tout le fichier.
 */
const CHAMPS = {
  /** L'identifiant d'une vidéo dans la réponse de `copy`. */
  videoId: 'uid',
  /** L'état du traitement : `pendingupload` → `inprogress` → `ready`. */
  state: 'state',
} as const

/** Les états que Stream rend, traduits dans le vocabulaire du schéma. */
export type StreamState = 'TRANSFERRING' | 'READY' | 'FAILED'

export class CloudflareStream {
  private readonly config: StreamConfig

  constructor(config: StreamConfig) {
    this.config = config
  }

  static isConfigured(config: Partial<StreamConfig>): config is StreamConfig {
    return Boolean(config.accountId && config.apiToken && config.customerCode)
  }

  /**
   * Les URL de lecture sont-elles protégées ?
   *
   * Toujours vrai ici, et c'est structurel : `requireSignedURLs` est posé à
   * l'ingestion, donc une vidéo de cours n'est jamais lisible sans jeton. Chez
   * Bunny, l'équivalent était une option de zone qu'on pouvait oublier
   * d'activer — le module journalisait un avertissement pour cela.
   */
  get signsUrls(): boolean {
    return true
  }

  private get base(): string {
    return `${API}/accounts/${this.config.accountId}/stream`
  }

  private async call(
    chemin: string,
    options: { method: 'GET' | 'POST' | 'DELETE'; body?: unknown } = {
      method: 'GET',
    },
  ): Promise<Record<string, unknown>> {
    let reponse: Response
    try {
      reponse = await fetch(`${this.base}${chemin}`, {
        method: options.method,
        headers: {
          Authorization: `Bearer ${this.config.apiToken}`,
          'Content-Type': 'application/json',
        },
        body:
          options.body === undefined ? undefined : JSON.stringify(options.body),
      })
    } catch (cause) {
      throw new StreamError(
        `Cloudflare Stream injoignable : ${cause instanceof Error ? cause.message : cause}`,
        503,
      )
    }

    const donnees = (await reponse.json().catch(() => ({}))) as Record<
      string,
      unknown
    >

    /*
     * L'API v4 rend toujours 200 avec `success: false` sur une erreur métier :
     * se fier au code HTTP seul laisserait passer un refus silencieux.
     */
    if (!reponse.ok || donnees.success === false) {
      const erreurs = Array.isArray(donnees.errors) ? donnees.errors : []
      const premier = erreurs[0] as Record<string, unknown> | undefined
      throw new StreamError(
        (premier?.message as string) ??
          `Cloudflare Stream a refusé la demande (${reponse.status}).`,
        reponse.ok ? 502 : reponse.status,
      )
    }

    return (donnees.result as Record<string, unknown>) ?? {}
  }

  /**
   * Demande à Stream d'aller chercher une vidéo à une URL.
   *
   * C'est l'étape qui remplace le téléversement : le fichier ne passe jamais par
   * le Worker, qui a une limite de taille et de durée. On lui donne une URL
   * pré-signée de R2 valable deux heures (voir `_lib/r2.ts`), et il tire.
   *
   * `requireSignedURLs` dès l'ingestion, et non après : entre la création et la
   * pose de l'option, une vidéo de cours serait publique — courte fenêtre, mais
   * une fenêtre.
   */
  async ingestFromUrl(input: {
    url: string
    name: string
  }): Promise<string> {
    const resultat = await this.call('/copy', {
      method: 'POST',
      body: {
        url: input.url,
        meta: { name: input.name },
        requireSignedURLs: true,
      },
    })
    const id = resultat[CHAMPS.videoId]
    if (typeof id !== 'string' || id === '') {
      throw new StreamError(
        'Cloudflare Stream a répondu sans identifiant de vidéo. ' +
          `Vérifier CHAMPS.videoId (« ${CHAMPS.videoId} ») contre la documentation.`,
      )
    }
    return id
  }

  /**
   * Où en est le traitement.
   *
   * Trois états seulement sortent d'ici, parce que le schéma n'en connaît pas
   * plus : en cours, prête, échouée. Les six états internes de Stream
   * (`pendingupload`, `downloading`, `queued`, `inprogress`…) décrivent une
   * mécanique dont l'élève n'a rien à faire.
   */
  async videoState(videoId: string): Promise<StreamState> {
    const resultat = await this.call(`/${encodeURIComponent(videoId)}`)
    const statut = resultat.status as Record<string, unknown> | undefined
    const etat = String(statut?.[CHAMPS.state] ?? '')

    if (etat === 'ready' || resultat.readyToStream === true) return 'READY'
    if (etat === 'error') return 'FAILED'
    return 'TRANSFERRING'
  }

  /**
   * Un jeton de lecture, émis par Cloudflare.
   *
   * **La seule façon correcte de donner une vidéo payée**, appelée après
   * vérification de l'achat et jamais avant.
   *
   * Émis par l'API et non calculé ici : c'est le progrès par rapport à Bunny, où
   * la chaîne à signer dépendait d'un réglage de zone et où le module portait une
   * note « à vérifier au premier appel réel ». Ici, il n'y a pas de formule à se
   * tromper.
   */
  async playbackToken(
    videoId: string,
    options: { ttlSeconds?: number } = {},
  ): Promise<{ token: string; expiresAt: number }> {
    const ttl = options.ttlSeconds ?? 4 * 3600
    const expiration = Math.floor(Date.now() / 1000) + ttl
    const resultat = await this.call(
      `/${encodeURIComponent(videoId)}/token`,
      { method: 'POST', body: { exp: expiration } },
    )
    const token = resultat.token
    if (typeof token !== 'string' || token === '') {
      throw new StreamError('Cloudflare Stream n’a pas rendu de jeton.')
    }
    return { token, expiresAt: expiration }
  }

  /**
   * Les adresses de lecture d'une vidéo signée.
   *
   * Le jeton remplace l'identifiant **dans le chemin** : c'est la forme que
   * Cloudflare attend pour une vidéo en `requireSignedURLs`, et mettre le jeton
   * en paramètre de requête ne marche pas.
   *
   * Deux adresses, parce que les deux clients n'ont pas les mêmes contraintes :
   *
   *   * `iframe` pour le site — Chrome et Firefox ne lisent pas HLS sans
   *     bibliothèque, et embarquer un lecteur pour 90 minutes de vidéo sur une
   *     ligne instable est le code qu'on écrit mal ;
   *   * `hls` pour l'application Flutter, où `video_player` le lit nativement
   *     par ExoPlayer, sans un octet de plus dans l'APK.
   */
  async playbackUrls(
    videoId: string,
    options: { ttlSeconds?: number } = {},
  ): Promise<{
    hls: string
    iframe: string
    signed: boolean
    expiresAt: number
  }> {
    const { token, expiresAt } = await this.playbackToken(videoId, options)
    return { ...this.urlsForToken(token), signed: true, expiresAt }
  }

  /**
   * La forme des adresses, à partir d'un jeton déjà obtenu.
   *
   * Séparée de l'appel réseau pour une raison de test : c'est la **seule** partie
   * de ce module qui s'éprouve hors ligne, et c'est aussi celle où une erreur
   * passe inaperçue — une adresse mal formée rend une vidéo noire, pas une
   * exception.
   */
  urlsForToken(token: string): { hls: string; iframe: string } {
    const racine = `https://${this.config.customerCode}.cloudflarestream.com/${token}`
    return {
      hls: `${racine}/manifest/video.m3u8`,
      iframe: `${racine}/iframe`,
    }
  }

  /** Supprime une vidéo. */
  async deleteVideo(videoId: string): Promise<void> {
    await this.call(`/${encodeURIComponent(videoId)}`, { method: 'DELETE' })
  }
}
