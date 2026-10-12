import { ApiError } from './client'

/**
 * Les appels au serveur Eduquali, pour ce que PostgREST ne peut pas faire.
 *
 * --- Pourquoi un module à part, et non vingt méthodes dans `VeriprofApi` --
 *
 * L'interface `VeriprofApi` a trois implémentations : Supabase en direct,
 * REST, et le backend simulé. Chaque méthode ajoutée se paie donc trois fois.
 * C'est un bon prix pour une lecture qu'un navigateur peut faire lui-même —
 * la liste des professeurs, la grille des cours — parce que le mode simulé
 * garde alors le site parcourable hors ligne.
 *
 * Ce n'est pas un bon prix pour ce qui suit. Ces appels **ne peuvent pas**
 * exister ailleurs que sur le serveur :
 *
 *   * les revenus traversent des tables dont les politiques appartiennent aux
 *     familles, pas au professeur qui encaisse ;
 *   * un retrait se vérifie contre un solde que le client ne doit pas
 *     calculer lui-même ;
 *   * l'assistant tient l'unique clé Gemini, qui ne peut pas descendre dans
 *     un navigateur ;
 *   * une adresse de dépôt est signée avec les clés R2 ;
 *   * le prix d'un cours est relu côté serveur, c'est toute la raison pour
 *     laquelle `sync.ts` refuse qu'un client écrive `video_courses`.
 *
 * Les simuler donnerait un site qui a l'air de marcher sans serveur et ne
 * marche pas avec. Sans serveur, chaque appel lève une phrase qui le dit.
 *
 * --- Le jeton -------------------------------------------------------------
 *
 * Il vient du client Supabase, qui le rafraîchit. Le lire à chaque appel
 * plutôt que de le garder : un jeton capturé au montage de la page est
 * périmé une heure plus tard, et l'écran affiche alors « reconnectez-vous »
 * à quelqu'un qui est connecté.
 */

type Lecteur = () => Promise<string | null>

let lireJeton: Lecteur = async () => null

/**
 * Branche la source du jeton. Appelé une fois, par `api/index.ts`.
 *
 * Une fonction plutôt que la valeur : au moment où ce module est chargé,
 * personne n'est encore connecté.
 */
export function brancherJeton(lecteur: Lecteur): void {
  lireJeton = lecteur
}

const base = () => {
  const url = import.meta.env.VITE_API_BASE_URL?.trim()
  if (url) return url.replace(/\/$/, '')
  // Déployé derrière une API, le chemin relatif suffit et évite toute
  // question de CORS.
  return import.meta.env.PROD ? '/api/v1' : null
}

/** Vrai quand il y a un serveur à qui parler. */
export const serveurDisponible = base() !== null

async function appel<T>(
  chemin: string,
  options: {
    method?: 'GET' | 'POST' | 'PATCH' | 'DELETE'
    body?: unknown
    /** Les appels publics n'exigent pas de session. */
    public?: boolean
  } = {},
): Promise<T> {
  const racine = base()
  if (!racine) {
    throw new ApiError(
      'Cette page demande le serveur Eduquali, qui n’est pas relié à ce site.',
      501,
    )
  }

  const jeton = await lireJeton()
  if (!jeton && !options.public) {
    throw new ApiError('Connectez-vous pour continuer.', 401)
  }

  let reponse: Response
  try {
    reponse = await fetch(`${racine}${chemin}`, {
      method: options.method ?? 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...(jeton ? { Authorization: `Bearer ${jeton}` } : {}),
      },
      body:
        options.body === undefined ? undefined : JSON.stringify(options.body),
    })
  } catch {
    throw new ApiError(
      'Pas de connexion au serveur. Vérifiez votre réseau et réessayez.',
    )
  }

  const corps = (await reponse.json().catch(() => ({}))) as Record<
    string,
    unknown
  >

  if (!reponse.ok) {
    // Le message du serveur, pas un message générique : il est écrit pour
    // être affiché, et il dit ce qu'il faut faire — « vous avez déjà une
    // demande en cours » vaut mieux que « erreur 409 ».
    throw new ApiError(
      (corps.error as string) ?? 'La demande n’a pas abouti.',
      reponse.status,
    )
  }
  return corps as T
}

/* ===========================================================================
 * Le dossier : pièces et diplômes
 * ===========================================================================*/

export type TypePiece = 'ID_FRONT' | 'ID_BACK' | 'SELFIE' | 'DIPLOMA' | 'CV'

export interface Piece {
  id: string
  type: TypePiece
  status: string
  sizeBytes: number | null
  createdAt: string
  updatedAt: string
}

export const dossier = {
  pieces: () => appel<{ documents: Piece[] }>('/teacher/documents'),

  /**
   * Dépose une pièce.
   *
   * Trois temps, et c'est voulu : le serveur signe une adresse, le navigateur
   * y envoie les octets, puis déclare que c'est fait. Le fichier ne traverse
   * jamais le Worker — un diplôme scanné pèse 4 Mo, et le faire passer par un
   * serveur facturé au temps de calcul reviendrait à payer pour recopier un
   * fichier d'un tuyau dans un autre.
   */
  async deposer(type: TypePiece, fichier: File): Promise<Piece> {
    const { id, uploadUrl } = await appel<{ id: string; uploadUrl: string }>(
      '/teacher/documents',
      {
        method: 'POST',
        body: {
          type,
          contentType: fichier.type,
          sizeBytes: fichier.size,
        },
      },
    )

    const envoi = await fetch(uploadUrl, {
      method: 'PUT',
      // Le type doit être celui annoncé : R2 le stocke et le renvoie à la
      // lecture, et un PDF servi en `application/octet-stream` se télécharge
      // au lieu de s'ouvrir.
      headers: { 'Content-Type': fichier.type },
      body: fichier,
    }).catch(() => null)

    if (!envoi || !envoi.ok) {
      throw new ApiError(
        'L’envoi du fichier a échoué. Vérifiez votre connexion et '
          + 'recommencez — rien n’a été enregistré.',
      )
    }

    return appel<Piece>(
      `/teacher/documents/${encodeURIComponent(id)}/uploaded`,
      { method: 'POST' },
    )
  },
}

/* ===========================================================================
 * Les revenus
 * ===========================================================================*/

export interface Retrait {
  id: string
  amount: number
  method: 'ORANGE' | 'MTN' | 'CASH'
  status: 'REQUESTED' | 'APPROVED' | 'PAID' | 'REJECTED'
  note: string | null
  requestedAt: string
  settledAt: string | null
}

export interface Revenus {
  earned: { live: number; videos: number; contracts: number; total: number }
  seats: number
  purchases: number
  paidOut: number
  pending: number
  available: number
  minimum: number
  payouts: Retrait[]
}

export const revenus = {
  lire: () => appel<Revenus>('/teacher/revenue'),
  demander: (input: {
    amount: number
    method: 'ORANGE' | 'MTN' | 'CASH'
    last4?: string
  }) => appel<Retrait>('/teacher/payouts', { method: 'POST', body: input }),
}

/* ===========================================================================
 * Les cours à domicile
 * ===========================================================================*/

export type ModeDomicile = 'AT_STUDENT' | 'AT_TEACHER' | 'ONLINE'

export interface OffreDomicile {
  id: string
  teacherId: string
  teacherName: string
  headline: string | null
  yearsExperience: number
  subject: { id: string; name: string }
  levelIds: string[]
  mode: ModeDomicile
  hourlyRate: number | null
  city: string | null
  districts: string[]
  availabilityNote: string | null
  description: string | null
}

export interface MonOffreDomicile {
  id: string
  subject: { id: string; name: string }
  levelIds: string[]
  mode: ModeDomicile
  hourlyRate: number | null
  city: string | null
  districts: string[]
  availabilityNote: string | null
  description: string | null
  active: boolean
  createdAt: string
}

export interface DemandeDomicile {
  id: string
  serviceId: string
  status: string
  message: string | null
  preferredStart: string | null
  createdAt: string
  respondedAt: string | null
  childName: string
  subject: string | null
}

export const domicile = {
  // Publique : on regarde avant d'ouvrir un compte.
  catalogue: (query: { city?: string; subjectId?: string } = {}) => {
    const params = new URLSearchParams()
    if (query.city) params.set('city', query.city)
    if (query.subjectId) params.set('subjectId', query.subjectId)
    const qs = params.toString()
    return appel<{ offers: OffreDomicile[] }>(
      `/tutoring/offers${qs ? `?${qs}` : ''}`,
      { public: true },
    )
  },

  miennes: () => appel<{ services: MonOffreDomicile[] }>(
    '/tutoring/services/mine',
  ),

  publier: (input: {
    subjectId: string
    levelIds: string[]
    mode: ModeDomicile
    hourlyRate?: number
    city?: string
    districts?: string[]
    availabilityNote?: string
    description?: string
  }) => appel<{ id: string }>('/tutoring/services', {
    method: 'POST',
    body: input,
  }),

  basculer: (id: string, active: boolean) =>
    appel<{ id: string; active: boolean }>(
      `/tutoring/services/${encodeURIComponent(id)}`,
      { method: 'PATCH', body: { active } },
    ),

  demandes: () => appel<{ requests: DemandeDomicile[] }>('/tutoring/requests'),

  repondre: (id: string, status: 'ACCEPTED' | 'DECLINED') =>
    appel<{ id: string; status: string }>(
      `/tutoring/requests/${encodeURIComponent(id)}`,
      { method: 'PATCH', body: { status } },
    ),
}

/* ===========================================================================
 * La discussion
 * ===========================================================================*/

export interface Groupe {
  id: string
  kind: 'COURSE' | 'CONTRACT'
  sourceId: string
  name: string
  lastBody: string | null
  lastAt: string | null
}

export interface MessageGroupe {
  id: string
  groupId: string
  authorId: string
  authorName: string
  authorRole: string
  body: string
  sentAt: string
}

export const discussion = {
  groupes: () => appel<{ groups: Groupe[] }>('/chat/groups'),
  messages: (id: string, before?: string) => {
    const qs = before ? `?before=${encodeURIComponent(before)}` : ''
    return appel<{ messages: MessageGroupe[] }>(
      `/chat/groups/${encodeURIComponent(id)}/messages${qs}`,
    )
  },
  /**
   * Le serveur ne rend que l'identifiant et l'heure : il n'a pas à renvoyer
   * un message que l'écran vient d'écrire. C'est l'écran qui compose la
   * bulle, et c'est pourquoi elle apparaît sans attendre la réponse.
   */
  envoyer: (id: string, body: string) =>
    appel<{ id: string; sentAt: string }>(
      `/chat/groups/${encodeURIComponent(id)}/messages`,
      { method: 'POST', body: { body } },
    ),
}

/* ===========================================================================
 * Le tableau de bord du professeur
 * ===========================================================================*/

export interface SeanceProf {
  id: string
  startsAt: string
  durationMinutes: number
  status: string
  seatsTaken: number
  seats: number
  title: string | null
  subject: string | null
}

export interface Inscrit {
  enrolmentId: string
  name: string
  present: boolean
  minutes: number
}

export interface MonCoursVideo {
  id: string
  title: string
  description: string | null
  subject: string | null
  levelIds: string[]
  price: number
  status: 'DRAFT' | 'PUBLISHED' | 'HIDDEN'
  purchaseCount: number
  chapters: number
  items: number
  createdAt: string
}

export const prof = {
  seances: () => appel<{ sessions: SeanceProf[] }>('/live/teacher/sessions'),

  inscrits: (sessionId: string) =>
    appel<{ expected: number; present: number; roster: Inscrit[] }>(
      `/live/sessions/${encodeURIComponent(sessionId)}/roster`,
    ),

  /** Prévenir une place, ou toutes. */
  prevenir: (sessionId: string, cible: { enrolmentIds?: string[]; all?: boolean }) =>
    appel<{ notified: number }>(
      `/live/sessions/${encodeURIComponent(sessionId)}/notify`,
      { method: 'POST', body: cible },
    ),

  contacts: () =>
    appel<{ contacts: { parentId: string; name: string; sources: string[] }[] }>(
      '/live/teacher/contacts',
    ),

  mesCoursVideo: () => appel<{ courses: MonCoursVideo[] }>('/courses/mine'),
}

/* ===========================================================================
 * La création d'un cours vidéo
 * ===========================================================================*/

export interface ChapitreCree {
  id: string
  title: string
  position: number
}

export const studio = {
  creer: (input: {
    title: string
    description?: string
    subjectId: string
    levelIds: string[]
    price: number
    chapters: { title: string; description?: string }[]
  }) => appel<{ id: string; status: string; chapters: ChapitreCree[] }>(
    '/courses',
    { method: 'POST', body: input },
  ),

  contenu: (id: string) =>
    appel<{
      id: string
      title: string
      status: string
      price: number
      chapters: {
        id: string
        title: string
        description: string | null
        position: number
        items: {
          id: string
          kind: string
          title: string
          position: number
          durationSeconds: number | null
          status: string | null
        }[]
      }[]
    }>(`/courses/${encodeURIComponent(id)}/content`),

  /**
   * Dépose une vidéo de chapitre.
   *
   * Même chemin que pour une pièce, avec une fenêtre de trente minutes : une
   * vidéo de 300 Mo sur une connexion à 2 Mbit/s met vingt minutes, et une
   * adresse expirée au milieu du dépôt perd le transfert entier.
   */
  async deposerVideo(
    chapterId: string,
    titre: string,
    fichier: File,
    onProgress?: (pourcent: number) => void,
  ): Promise<{ id: string; status: string }> {
    const { id, uploadUrl } = await appel<{ id: string; uploadUrl: string }>(
      '/courses/items',
      {
        method: 'POST',
        body: {
          chapterId,
          title: titre,
          contentType: fichier.type,
          sizeBytes: fichier.size,
        },
      },
    )

    await envoiSuivi(uploadUrl, fichier, onProgress)

    return appel<{ id: string; status: string }>(
      `/courses/items/${encodeURIComponent(id)}/uploaded`,
      { method: 'POST' },
    )
  },

  publier: (id: string, status: 'PUBLISHED' | 'HIDDEN' | 'DRAFT') =>
    appel<{ id: string; status: string }>(
      `/courses/${encodeURIComponent(id)}`,
      { method: 'PATCH', body: { status } },
    ),
}

/**
 * Un envoi dont on peut suivre l'avancement.
 *
 * `fetch` ne rapporte pas la progression d'un corps sortant ; `XMLHttpRequest`
 * le fait depuis toujours. Pour une pièce de 4 Mo on s'en passe, mais une
 * vidéo de 300 Mo sans barre de progression ressemble à une page figée, et la
 * personne recommence — ce qui double le transfert.
 */
function envoiSuivi(
  url: string,
  fichier: File,
  onProgress?: (pourcent: number) => void,
): Promise<void> {
  return new Promise((resolve, reject) => {
    const requete = new XMLHttpRequest()
    requete.open('PUT', url, true)
    requete.setRequestHeader('Content-Type', fichier.type)

    requete.upload.onprogress = (evenement) => {
      if (!onProgress || !evenement.lengthComputable) return
      onProgress(Math.round((evenement.loaded / evenement.total) * 100))
    }

    requete.onload = () =>
      requete.status >= 200 && requete.status < 300
        ? resolve()
        : reject(
            new ApiError(
              'L’envoi de la vidéo a échoué. Rien n’a été enregistré.',
            ),
          )

    requete.onerror = () =>
      reject(
        new ApiError('Pas de connexion pendant l’envoi. Recommencez.'),
      )

    requete.send(fichier)
  })
}

/* ===========================================================================
 * L'assistant
 * ===========================================================================*/

export type UsageAssistant = 'HOMEWORK' | 'COURSE' | 'GENERAL'

export interface MessageIA {
  id: string
  role: 'USER' | 'MODEL'
  body: string
  createdAt: string
}

export const assistant = {
  quota: () =>
    appel<{
      available: boolean
      used: number
      limit: number
      remaining?: number
    }>('/ai/quota'),

  fils: () =>
    appel<{
      conversations: {
        id: string
        feature: UsageAssistant
        title: string | null
        updatedAt: string
      }[]
    }>('/ai/conversations'),

  fil: (id: string) =>
    appel<{
      id: string
      feature: UsageAssistant
      title: string | null
      messages: MessageIA[]
    }>(`/ai/conversations/${encodeURIComponent(id)}`),

  demander: (input: {
    message: string
    feature: UsageAssistant
    conversationId?: string
  }) => appel<{
    conversationId: string
    id: string | null
    body: string
    createdAt: string
  }>('/ai/chat', { method: 'POST', body: input }),
}

/* ===========================================================================
 * La boutique
 * ===========================================================================*/

/**
 * Un lot du catalogue.
 *
 * La route reprend les colonnes de `shop_items` telles quelles — donc en
 * `snake_case` — et y ajoute trois champs calculés. Les renommer ici
 * donnerait deux vocabulaires pour la même ligne ; mieux vaut un seul, même
 * imparfait, et le dire.
 */
export interface LotBoutique {
  id: string
  name: string
  summary: string | null
  image: string | null
  points_price: number
  value_gnf: number | null
  stock: number | null
  /** ITEM : un objet. DRAW : un tirage, où l'on achète des chances. */
  kind: 'ITEM' | 'DRAW'
  draws_at: string | null
  affordable: boolean
  favorite: boolean
  entries: number
}

export const boutique = {
  /**
   * Le catalogue, le solde et la distance au lot suivant, en un seul appel.
   *
   * Trois appels pour peindre un écran, sur une connexion guinéenne, ce sont
   * trois occasions d'afficher la page à moitié.
   */
  lots: () =>
    appel<{
      items: LotBoutique[]
      balance: number
      nextId: string | null
      missing: number
    }>('/shop/items'),

  /** PUT et DELETE, comme la route : mettre de côté n'est pas un envoi. */
  favori: (id: string, oui: boolean) =>
    appel<{ favorite: boolean }>(
      `/shop/items/${encodeURIComponent(id)}/favorite`,
      { method: oui ? 'POST' : 'DELETE' },
    ),

  echanger: (id: string) =>
    appel<{ redemptionId: string }>(
      `/shop/items/${encodeURIComponent(id)}/redeem`,
      { method: 'POST' },
    ),

  echanges: () =>
    appel<{
      redemptions: {
        id: string
        item_id: string
        points_spent: number
        status: string
        requested_at: string
        note: string | null
      }[]
    }>('/shop/redemptions'),

  solde: () => appel<{ balance: number }>('/points/balance'),
}
