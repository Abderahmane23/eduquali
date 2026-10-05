/**
 * Djomy — le seul module qui parle a la plateforme de paiement.
 *
 * Point de sortie unique : changer d'agregateur ne doit toucher que ce
 * fichier. Rien d'autre dans le depot ne connait l'existence de Djomy, ni la
 * forme de ses reponses, ni ses codes de statut.
 *
 * --- Ce que la documentation fournit -------------------------------------
 *
 * - `X-API-KEY: <clientId>:<HMAC-SHA256(clientId, clientSecret)>` en
 *   hexadecimal. La signature **ne varie pas** d'une requete a l'autre : c'est
 *   un mot de passe derive, pas une signature de requete. Elle n'empeche donc
 *   pas le rejeu — raison de plus pour ne jamais faire confiance a ce qui
 *   revient par l'URL de retour (voir `verifyWebhook`).
 * - Un jeton Bearer obtenu par `POST /v1/auth`, avec cette meme en-tete.
 * - Toutes les reponses partagent une enveloppe
 *   `{ success, message, data, error, errors, status }`.
 * - Les montants sont en GNF entiers (l'exemple de webhook donne
 *   `paidAmount: 10000`, `currency: "GNF"`). Pas de sous-unite.
 * - Les numeros sont au format `00224623707722` : prefixe **00**, pas `+`.
 *
 * --- Ce qu'elle ne fournit pas, et qui reste a confirmer -----------------
 *
 * Le fichier recu s'arrete avant les schemas de reponse. Trois noms de champs
 * sont donc des hypotheses, rassemblees dans `CHAMPS` ci-dessous pour qu'une
 * correction tienne en une ligne : le jeton rendu par `/v1/auth`, et
 * l'identifiant de transaction et l'URL de redirection rendus par les deux
 * points d'entree de paiement. Le module accepte plusieurs orthographes
 * plutot que de parier sur une seule.
 *
 * Manque aussi l'URL de base — elle vient de la configuration — et la duree de
 * vie du jeton, d'ou le renouvellement sur 401 plutot que sur une horloge.
 */

/**
 * Bac a sable ou production.
 *
 * **Declare, jamais devine.** On pourrait le deduire de l'URL — chercher
 * « sandbox » dans le nom d'hote — et c'est precisement ainsi qu'on se trompe :
 * un hote de test sans ce mot passerait pour la production, et l'inverse. Un
 * champ explicite oblige a dire ce qu'on fait.
 *
 * Ce qui en depend : la banniere « paiement de test » cote acheteur, et ce que
 * `/health` annonce. Pas l'URL, qui vient de la configuration elle-meme.
 */
export type DjomyEnvironment = 'sandbox' | 'production'

/** Ce que le marchand configure. Rien ici ne doit atteindre un client. */
export interface DjomyConfig {
  environment: DjomyEnvironment
  baseUrl: string
  clientId: string
  clientSecret: string
  /**
   * Cle de signature des webhooks. La documentation dit « la cle secrete du
   * marchand (clientSecret) » : par defaut la meme, mais separable au cas ou
   * l'espace developpeur en delivre une distincte.
   */
  webhookSecret: string
  /** Code ISO du pays. `GN` pour la Guinee. */
  countryCode: string
}

/**
 * Noms de champs a confirmer contre le bac a sable.
 *
 * Chaque entree est une liste d'orthographes acceptees, essayees dans l'ordre.
 * Quand la vraie reponse sera connue, on peut reduire chaque liste a une seule
 * valeur — ou la laisser, elle ne coute rien.
 */
const CHAMPS = {
  accessToken: ['accessToken', 'access_token', 'token', 'jwt'],
  transactionId: ['transactionId', 'transaction_id', 'id', 'reference'],
  redirectUrl: [
    'paymentUrl',
    'redirectUrl',
    'paymentLink',
    'url',
    'checkoutUrl',
  ],
} as const

/** Les moyens de paiement que ce module expose. */
export type DjomyMethod = 'OM' | 'MOMO'

/** Les statuts rendus par Djomy. */
export type DjomyStatus =
  | 'CREATED'
  | 'PENDING'
  | 'SUCCESS'
  | 'CANCELLED'
  | 'FAILED'

/** Un paiement initie. */
export interface DjomyPayment {
  transactionId: string
  status: DjomyStatus
  /** Presente seulement pour les flux qui redirigent (portail, KULU). */
  redirectUrl?: string
}

export class DjomyError extends Error {
  readonly status: number

  /** Vrai quand rien n'est parti : reseau, DNS, delai depasse. */
  readonly unreachable: boolean

  // Champs declares puis affectes, et non des proprietes de parametre
  // (`constructor(readonly status: number)`) : le lanceur de tests du projet
  // utilise le retrait de types de Node, qui ne les accepte pas.
  constructor(message: string, status: number, unreachable = false) {
    super(message)
    this.status = status
    this.unreachable = unreachable
  }
}

/** L'enveloppe commune a toutes les reponses. */
interface Envelope {
  success?: boolean
  message?: string
  data?: unknown
  error?: { code?: number; message?: string; details?: string }
  errors?: string[]
  status?: number
}

// --- Outils ----------------------------------------------------------------

/**
 * HMAC-SHA256 en hexadecimal, via WebCrypto.
 *
 * WebCrypto plutot que `node:crypto` : c'est la meme API sur Cloudflare
 * Workers et sous Node 18+, donc le module se teste hors du Worker sans
 * adaptation.
 */
async function hmacHex(message: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(message),
  )
  return [...new Uint8Array(signature)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}

/**
 * Comparaison a duree constante.
 *
 * `a === b` sort au premier caractere different : le temps de reponse revele
 * alors combien de caracteres sont justes, et une signature se devine octet
 * par octet. Le cout d'une comparaison complete est nul a cette taille.
 */
function equalsConstantTime(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let difference = 0
  for (let i = 0; i < a.length; i++) {
    difference |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return difference === 0
}

/**
 * Met un numero guineen au format attendu : `00224…`.
 *
 * Nos numeros sont stockes `+224620000101` ; Djomy veut `00224620000101`. La
 * conversion est explicite et testee, parce qu'un numero mal forme fait echouer
 * le paiement avec un message generique du cote de l'operateur.
 */
export function toDjomyPhone(phone: string): string {
  const chiffres = phone.replace(/\D/g, '')
  // Deja prefixe 00.
  if (chiffres.startsWith('00')) return chiffres
  // Indicatif present sans le 00.
  if (chiffres.startsWith('224')) return `00${chiffres}`
  // Numero local a neuf chiffres.
  return `00224${chiffres}`
}

/** Lit le premier champ present parmi plusieurs orthographes. */
function champ(source: unknown, noms: readonly string[]): string | undefined {
  if (source == null || typeof source !== 'object') return undefined
  const objet = source as Record<string, unknown>
  for (const nom of noms) {
    const valeur = objet[nom]
    if (typeof valeur === 'string' && valeur !== '') return valeur
  }
  return undefined
}

// --- Le client -------------------------------------------------------------

export class Djomy {
  private readonly config: DjomyConfig

  constructor(config: DjomyConfig) {
    this.config = config
  }

  /**
   * Vrai quand la configuration est complete.
   *
   * L'environnement en fait partie, et sans valeur par defaut : « production »
   * par defaut facturerait de vrais clients depuis un poste de developpement,
   * « sandbox » par defaut laisserait une mise en production encaisser dans le
   * vide sans que personne ne le voie. Les deux erreurs sont silencieuses, donc
   * le champ est obligatoire.
   */
  static isConfigured(config: Partial<DjomyConfig>): config is DjomyConfig {
    return Boolean(
      config.baseUrl &&
        config.clientId &&
        config.clientSecret &&
        (config.environment === 'sandbox' ||
          config.environment === 'production'),
    )
  }

  /** L'environnement auquel ce client parle. */
  get environment(): DjomyEnvironment {
    return this.config.environment
  }

  /** Vrai en bac a sable : aucun argent reel ne bouge. */
  get isSandbox(): boolean {
    return this.config.environment === 'sandbox'
  }

  /**
   * Le jeton Bearer, garde en memoire entre deux appels.
   *
   * La duree de vie n'est pas documentee : on ne programme donc aucune
   * expiration, et on renouvelle sur un 401. Un jeton garde trop longtemps
   * coute un aller-retour de plus une fois ; une horloge fausse coute un echec
   * de paiement.
   *
   * La memoire d'un Worker ne survit pas a son recyclage, donc le pire cas est
   * une authentification de plus par isolat. Acceptable, et sans etat partage a
   * invalider.
   */
  private token?: string

  private async apiKeyHeader(): Promise<string> {
    const signature = await hmacHex(
      this.config.clientId,
      this.config.clientSecret,
    )
    return `${this.config.clientId}:${signature}`
  }

  /** Demande un jeton d'acces. */
  private async authenticate(): Promise<string> {
    const enveloppe = await this.call('/v1/auth', {
      method: 'POST',
      // Le corps est decrit comme `object (RequestAuthentication)` sans schema.
      // L'en-tete porte deja l'identite ; un objet vide est l'hypothese la
      // moins surprenante, et un 400 dira le contraire sans ambiguite.
      body: {},
      authenticated: false,
    })

    const jeton =
      champ(enveloppe.data, CHAMPS.accessToken) ??
      champ(enveloppe, CHAMPS.accessToken)
    if (!jeton) {
      throw new DjomyError(
        'Djomy a repondu sans jeton d’acces. Vérifier le nom du champ dans ' +
          'CHAMPS.accessToken contre la réponse réelle.',
        502,
      )
    }
    this.token = jeton
    return jeton
  }

  /**
   * Un appel a l'API, enveloppe deballee.
   *
   * Renouvelle le jeton une fois sur 401 : un jeton expire est le cas normal,
   * pas une panne, et faire remonter l'erreur obligerait chaque appelant a
   * gerer la reprise.
   */
  private async call(
    chemin: string,
    options: {
      method: 'GET' | 'POST'
      body?: unknown
      authenticated?: boolean
      retryOnUnauthorized?: boolean
    },
  ): Promise<Envelope> {
    const authentifie = options.authenticated !== false
    const entetes: Record<string, string> = {
      'Content-Type': 'application/json',
      'X-API-KEY': await this.apiKeyHeader(),
    }
    if (authentifie) {
      entetes.Authorization = `Bearer ${this.token ?? (await this.authenticate())}`
    }

    let reponse: Response
    try {
      reponse = await fetch(`${this.config.baseUrl}${chemin}`, {
        method: options.method,
        headers: entetes,
        body: options.body === undefined ? undefined : JSON.stringify(options.body),
      })
    } catch (cause) {
      // Rien n'est parti. L'appelant doit pouvoir le distinguer d'un refus :
      // une demande de paiement perdue en route se reessaie, un refus non.
      throw new DjomyError(
        `Djomy injoignable : ${cause instanceof Error ? cause.message : cause}`,
        503,
        true,
      )
    }

    if (
      reponse.status === 401 &&
      authentifie &&
      options.retryOnUnauthorized !== false
    ) {
      this.token = undefined
      return this.call(chemin, { ...options, retryOnUnauthorized: false })
    }

    const enveloppe = (await reponse.json().catch(() => ({}))) as Envelope

    if (!reponse.ok || enveloppe.success === false) {
      const message =
        enveloppe.error?.message ??
        enveloppe.message ??
        enveloppe.errors?.[0] ??
        `Djomy a refusé la demande (${reponse.status}).`
      throw new DjomyError(message, reponse.status)
    }
    return enveloppe
  }

  /**
   * Demande un paiement par portefeuille, sans quitter notre site.
   *
   * Pour OM et MOMO, la documentation decrit le flux ainsi : « Le payeur est
   * notifie par SMS ou via l'application Orange Money / MTN MoMo, afin de
   * confirmer le paiement directement depuis son telephone. » C'est le meilleur
   * parcours possible ici — l'acheteur ne quitte pas la page, il confirme sur
   * son propre appareil — et c'est pourquoi ce point d'entree est prefere au
   * portail. Le portail reste necessaire pour les cartes, que ce point d'entree
   * refuse.
   */
  async chargeWallet(input: {
    method: DjomyMethod
    payerPhone: string
    amount: number
    reference: string
    description?: string
    metadata?: Record<string, string | number | boolean>
  }): Promise<DjomyPayment> {
    const enveloppe = await this.call('/v1/payments', {
      method: 'POST',
      body: {
        paymentMethod: input.method,
        payerIdentifier: toDjomyPhone(input.payerPhone),
        amount: input.amount,
        countryCode: this.config.countryCode,
        description: input.description?.slice(0, 255),
        merchantPaymentReference: input.reference,
        metadata: input.metadata,
      },
    })
    return this.readPayment(enveloppe)
  }

  /**
   * Demande un paiement avec redirection vers le portail Djomy.
   *
   * Le seul chemin ouvert aux cartes (VISA, MasterCard). `returnUrl` doit etre
   * en https, sinon Djomy repond 400.
   */
  async chargeByGateway(input: {
    payerPhone: string
    amount: number
    reference: string
    returnUrl: string
    cancelUrl?: string
    description?: string
    allowedMethods?: string[]
    metadata?: Record<string, string | number | boolean>
  }): Promise<DjomyPayment> {
    const enveloppe = await this.call('/v1/payments/gateway', {
      method: 'POST',
      body: {
        amount: input.amount,
        countryCode: this.config.countryCode,
        payerNumber: toDjomyPhone(input.payerPhone),
        allowedPaymentMethods: input.allowedMethods,
        description: input.description?.slice(0, 255),
        merchantPaymentReference: input.reference,
        returnUrl: input.returnUrl,
        cancelUrl: input.cancelUrl ?? input.returnUrl,
        metadata: input.metadata,
      },
    })
    return this.readPayment(enveloppe)
  }

  /**
   * L'etat courant d'un paiement, demande a Djomy.
   *
   * Sert de filet au webhook : s'il n'arrive pas — URL mal configuree, Worker
   * indisponible au mauvais moment — c'est cet appel qui rattrape, depuis la
   * page de retour ou un travail de reprise.
   */
  async paymentStatus(transactionId: string): Promise<DjomyStatus> {
    const enveloppe = await this.call(
      `/v1/payments/${encodeURIComponent(transactionId)}/status`,
      { method: 'GET' },
    )
    const brut =
      champ(enveloppe.data, ['status']) ?? champ(enveloppe, ['status'])
    return normalizeStatus(brut)
  }

  private readPayment(enveloppe: Envelope): DjomyPayment {
    const source = enveloppe.data ?? enveloppe
    const transactionId = champ(source, CHAMPS.transactionId)
    if (!transactionId) {
      throw new DjomyError(
        'Djomy a répondu sans identifiant de transaction. Vérifier ' +
          'CHAMPS.transactionId contre la réponse réelle.',
        502,
      )
    }
    return {
      transactionId,
      status: normalizeStatus(champ(source, ['status'])),
      redirectUrl: champ(source, CHAMPS.redirectUrl),
    }
  }

  /**
   * Verifie la signature d'un webhook.
   *
   * **Sur le corps brut, avant tout analyse JSON.** Re-serialiser un objet
   * change les octets — ordre des cles, espaces, echappements — et la signature
   * ne correspond plus. C'est l'erreur classique de cette integration.
   *
   * En-tete attendue : `X-Webhook-Signature: v1:<hmac>`.
   */
  verifyWebhook(rawBody: string, header: string | undefined): Promise<boolean> {
    return this.verifyWebhookWith(rawBody, header, this.config.webhookSecret)
  }

  private async verifyWebhookWith(
    rawBody: string,
    header: string | undefined,
    secret: string,
  ): Promise<boolean> {
    if (!header || !secret) return false
    // Le prefixe de version est porte par la configuration webhook, pas par
    // nous : on accepte `v1:sig` comme `sig` nu, et on compare la partie utile.
    const fournie = header.includes(':')
      ? header.slice(header.indexOf(':') + 1).trim()
      : header.trim()
    if (fournie === '') return false
    const attendue = await hmacHex(rawBody, secret)
    return equalsConstantTime(fournie.toLowerCase(), attendue.toLowerCase())
  }
}

/** Ramene un statut inconnu a `PENDING` plutot que de lever. */
export function normalizeStatus(brut: string | undefined): DjomyStatus {
  switch ((brut ?? '').toUpperCase()) {
    case 'SUCCESS':
      return 'SUCCESS'
    case 'FAILED':
      return 'FAILED'
    case 'CANCELLED':
    case 'CANCELED':
      return 'CANCELLED'
    case 'CREATED':
      return 'CREATED'
    default:
      return 'PENDING'
  }
}

/**
 * Le statut que nous enregistrons, deduit du type d'evenement.
 *
 * On lit `eventType` et non `data.status` : c'est lui qui distingue un
 * remboursement d'un echec, et un depassement de delai d'une annulation par le
 * client. Le champ `status` ne porte pas ces nuances.
 */
export function purchaseStatusFor(
  eventType: string,
): 'PENDING' | 'PAID' | 'FAILED' | 'CANCELLED' | 'REFUNDED' | null {
  switch (eventType) {
    case 'payment.success':
      return 'PAID'
    case 'payment.refunded':
      return 'REFUNDED'
    case 'payment.cancelled':
      return 'CANCELLED'
    // Un paiement expire sans reponse du client n'a pas abouti. Il se
    // distingue d'une annulation dans le journal par son `eventType`, conserve
    // tel quel.
    case 'payment.failed':
    case 'payment.timeout':
      return 'FAILED'
    case 'payment.created':
    case 'payment.redirected':
    case 'payment.pending':
      return 'PENDING'
    default:
      // Un evenement inconnu — un `payout.*` sur une configuration V2, un type
      // ajoute plus tard — ne doit pas toucher l'achat.
      return null
  }
}

/**
 * Faut-il appliquer ce nouveau statut a un achat deja dans cet etat ?
 *
 * Les webhooks arrivent dans un ordre quelconque : un `payment.pending` reçu
 * apres un `payment.success` ne doit pas retirer un cours deja paye. Seul un
 * remboursement fait sortir de `PAID`.
 */
export function canTransition(
  from: string,
  to: 'PENDING' | 'PAID' | 'FAILED' | 'CANCELLED' | 'REFUNDED',
): boolean {
  if (from === to) return false
  if (from === 'REFUNDED') return false
  if (from === 'PAID') return to === 'REFUNDED'
  // Un achat echoue ou annule peut repartir : le payeur reessaie, et Djomy
  // renvoie alors `payment.pending` puis `payment.success`.
  return true
}
