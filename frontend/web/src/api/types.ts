/**
 * Types du domaine, alignes sur les entites de l'application mobile.
 *
 * Les deux clients parlent le meme langage : un enseignant, une offre ou une
 * candidature ont ici exactement la forme decrite au §48. Toute divergence de
 * nommage entre le web et le mobile finirait par se payer cote serveur.
 */

export type VerificationStatus =
  | 'NONE'
  | 'PENDING'
  | 'IN_REVIEW'
  | 'VERIFIED'
  | 'REJECTED'
  | 'NEEDS_FIX'

export type Availability = 'AVAILABLE' | 'AVAILABLE_SOON' | 'UNAVAILABLE'

export type ContractType = 'PERMANENT' | 'FIXED_TERM' | 'HOURLY' | 'INTERNSHIP'

export type InstitutionType =
  | 'SCHOOL'
  | 'HIGH_SCHOOL'
  | 'UNIVERSITY'
  | 'INSTITUTE'
  | 'TRAINING_CENTER'
  | 'OTHER'

/** Statuts de candidature (§18). */
export type ApplicationStatus =
  | 'SENT'
  | 'VIEWED'
  | 'SHORTLISTED'
  | 'INTERVIEW'
  | 'OFFER_RECEIVED'
  | 'ACCEPTED'
  | 'REJECTED'
  | 'HIRED'

export interface RefItem {
  id: string
  name: string
  code?: string
  /** Pour un niveau : PRIMARY | SECONDARY | UNIVERSITY | GRADUATE. */
  category?: string
  /**
   * Pour un niveau : le palier — PRIMAIRE | COLLEGE | LYCEE | SUPERIEUR |
   * DIPLOME.
   *
   * Distinct de `category`, et c'est la raison de son existence : `category`
   * range college et lycee dans le meme « SECONDARY », alors que ce sont deux
   * paliers que personne ne confond. C'est `cycle` que `optionsFilter` compare.
   */
  cycle?: string
}

export interface Certification {
  id: string
  subject: RefItem
  level: RefItem
  score: number
  issuedAt: string
}

export interface Expérience {
  id: string
  institutionName: string
  position: string
  city?: string
  startYear: number
  endYear?: number | null
  verified: boolean
}

/** Badges de confiance (§14). */
export interface TrustBadges {
  identity: boolean
  diploma: boolean
  competency: boolean
  experience: boolean
  profile: boolean
}

export interface TeacherProfile {
  id: string
  firstName: string
  lastName: string
  fullName: string
  headline: string
  bio?: string
  city?: string
  photoUrl?: string
  yearsExperience: number
  availability: Availability
  identityStatus: VerificationStatus
  diplomaStatus: VerificationStatus
  subjects: RefItem[]
  levels: RefItem[]
  certifications: Certification[]
  experiences: Expérience[]
  badges: TrustBadges
  /** Indicateur de confiance agrege (§62). */
  trustScore: number
  completionRate: number
}

export interface Institution {
  id: string
  name: string
  type: InstitutionType
  city: string
  address?: string
  description?: string
  verified: boolean
}

export interface JobOffer {
  id: string
  title: string
  institution: Institution
  subject: RefItem
  levels: RefItem[]
  city: string
  contractType: ContractType
  description?: string
  salaryMin?: number
  salaryMax?: number
  salaryPublished: boolean
  minExperience: number
  requiresCertification: boolean
  publishedAt: string
  applicationCount: number
}

/** Contribution d'un critère au score, pour rester explicable (§22). */
export interface MatchFactor {
  key: string
  label: string
  points: number
  max: number
  detail: string
}

export interface MatchScore {
  value: number
  factors: MatchFactor[]
}

export interface RankedCandidate {
  profile: TeacherProfile
  match: MatchScore
}

export interface Application {
  id: string
  job: JobOffer
  status: ApplicationStatus
  appliedAt: string
  matchScore?: number
}

export interface TestQuestion {
  id: string
  statement: string
  options: { key: string; text: string }[]
  domain: string
  /** Absente tant que le test n'est pas termine. */
  correctKey?: string
  explanation?: string
}

export interface TestSummary {
  id: string
  title: string
  subject: RefItem
  level: RefItem
  questionCount: number
  durationMinutes: number
  passingScore: number
  rules?: string
  certification?: Certification
}

export interface DomainScore {
  domain: string
  correct: number
  total: number
  percentage: number
}

export interface TestResult {
  score: number
  correctCount: number
  totalQuestions: number
  passed: boolean
  passingScore: number
  domainScores: DomainScore[]
}

/**
 * La demande d'achat d'un cours.
 *
 * `PENDING` tant que l'argent n'est pas arrive : il n'y a pas encore
 * d'encaissement, et l'acces aux videos suit `PAID`, jamais la simple
 * existence de la ligne (migration 0012). Le montant vient du serveur, qui le
 * relit dans `video_courses` — un prix envoye par le navigateur serait un prix
 * choisi par le navigateur.
 */
/**
 * Un cours en direct, tel que le professeur le declare une fois.
 *
 * Le prix est **par eleve et par seance** (strategy.md §5.1).
 */
export interface LiveCourse {
  id: string
  teacherId: string
  teacherName: string
  subject: RefItem
  level: RefItem
  title?: string
  description?: string
  price: number
  seats: number
  /** Les creneaux choisis : « WD_18 », « SAT_10 »… */
  slotIds: string[]
  status: 'DRAFT' | 'PUBLISHED' | 'ARCHIVED'
}

/** Une occurrence d'un cours en direct : c'est a elle qu'on s'inscrit. */
export interface LiveSession {
  id: string
  courseId: string
  slotId: string
  /** Date ISO. */
  startsAt: string
  durationMinutes: number
  status: 'PLANNED' | 'LIVE' | 'DONE' | 'CANCELLED'
  /** Ce qu'il reste de places. Zero = complet. */
  seatsLeft: number
  seats: number
  price: number
  subject: RefItem
  level: RefItem
  teacherId: string
  teacherName: string
  title?: string
}

/** Ce qu'un professeur declare pour creer un cours recurrent. */
export interface LiveCourseInput {
  subjectId: string
  levelId: string
  title?: string
  description?: string
  price: number
  slotIds: string[]
  /** Publier tout de suite, ou garder en brouillon. */
  publish: boolean
}

/** Le resultat d'une inscription a une seance. */
export interface EnrolmentResult {
  id: string
  purchaseId?: string
  status: 'PENDING' | 'CONFIRMED' | 'CANCELLED'
  amount: number
  /** Combien de minutes la place reste retenue sans paiement. */
  holdsMinutes?: number
  alreadyEnrolled: boolean
  payment?: 'none' | 'awaiting_confirmation' | 'redirect'
  redirectUrl?: string
  paymentError?: string
  sandbox?: boolean
}

export type PurchaseStatus =
  | 'PENDING'
  | 'PAID'
  | 'FAILED'
  | 'CANCELLED'
  | 'REFUNDED'

/** Le portefeuille choisi pour payer. */
export type WalletMethod = 'OM' | 'MOMO'

export interface PurchaseRequest {
  id: string
  status: PurchaseStatus
  amount: number
  /** Vrai quand une demande existait deja pour ce cours et ce compte. */
  alreadyRequested: boolean
  /**
   * Ce que l'acheteur doit faire ensuite :
   *
   * - `none` : rien n'a ete demande a l'operateur — pas de compte marchand
   *   configure, ou aucun portefeuille choisi. La demande est enregistree.
   * - `awaiting_confirmation` : l'operateur a notifie le telephone du payeur.
   *   Il confirme sur son appareil ; nous attendons le webhook.
   * - `redirect` : il faut l'envoyer sur `redirectUrl` (portail, carte).
   */
  payment: 'none' | 'awaiting_confirmation' | 'redirect'
  redirectUrl?: string
  /** Ce qui a empeche la demande de paiement, quand elle a echoue. */
  paymentError?: string
  /**
   * Vrai quand l'encaissement tourne en bac a sable : aucun argent reel ne
   * bouge.
   *
   * L'ecran doit le montrer. Sans cela, une demonstration en bac a sable passe
   * pour un encaissement reel — on croit avoir vendu, et on ne cherche l'argent
   * que des semaines plus tard.
   */
  sandbox?: boolean
}

/** L'etat d'une demande, relu depuis notre serveur. */
export interface PurchaseState {
  id: string
  courseId: string
  status: PurchaseStatus
  amount: number
  method?: string
  paidAt?: string
  /**
   * Ce que l'operateur en dit, quand le webhook n'est pas encore arrive.
   *
   * Information, pas verite : seul un webhook signe modifie l'achat.
   */
  providerStatus?: string
}

/**
 * La mise en avant d'un etablissement.
 *
 * C'est ce qu'il achete avec la formule Master, et ce qu'il achete est
 * precisement d'etre vu par des gens qui n'ont pas de compte : la meme annonce
 * derriere une authentification ne touche personne.
 *
 * `views` n'y figure pas. Le compteur appartient a l'etablissement qui a paye,
 * pas au visiteur, et l'exposer permettrait a un concurrent de mesurer son
 * audience.
 */
export interface Promotion {
  id: string
  institutionId: string
  institutionName: string
  city?: string
  title: string
  message?: string
}

/**
 * Une offre de cours a domicile.
 *
 * C'est ce qu'une famille vient chercher en premier, et c'est publiable : le
 * serveur ouvre les offres actives a tout le monde (migration 0002, « cours :
 * offres actives visibles »). Le tarif y figure — le cacher obligerait a
 * ecrire pour le demander, ce qui est precisement le geste qu'on veut eviter
 * d'imposer avant d'avoir choisi.
 */
export interface TutoringOffer {
  id: string
  teacherId: string
  subject: RefItem
  levels: RefItem[]
  /** AT_STUDENT (chez l'eleve), AT_TEACHER (chez le professeur), ONLINE. */
  mode: 'AT_STUDENT' | 'AT_TEACHER' | 'ONLINE'
  hourlyRate?: number
  city?: string
  /** Quartiers desservis — ce qui decide si un professeur peut venir. */
  districts: string[]
  availabilityNote?: string
  description?: string
}

/**
 * Un cours video, tel que la vitrine le montre.
 *
 * Ce qui n'y est pas : le fichier. `local_path` et `remote_url` sont fermes a
 * qui n'a pas achete (migration 0010), et c'est voulu — le programme est la
 * vitrine, la video est la marchandise. Un type qui porterait l'adresse du
 * fichier inviterait a l'afficher.
 */
export interface VideoCourse {
  id: string
  title: string
  description?: string
  teacherId: string
  teacherName: string
  subject?: RefItem
  levels: RefItem[]
  price: number
  /** Ce que touche le professeur, commission de 20 % deduite. */
  net: number
  chapterCount: number
  videoCount: number
  /** Duree totale en secondes, quand les durees sont connues. */
  totalSeconds: number
}

/** Un element du sommaire : une video, un document, un lien. */
export interface CourseItemPreview {
  id: string
  kind: 'VIDEO' | 'DOCUMENT' | 'LINK'
  title: string
  durationSeconds?: number
}

export interface CourseChapterPreview {
  id: string
  title: string
  description?: string
  position: number
  items: CourseItemPreview[]
}

export interface JobSearchQuery {
  subjectId?: string
  levelId?: string
  city?: string
  contractType?: ContractType
  query?: string
}

export interface TeacherSearchQuery {
  subjectId?: string
  levelId?: string
  /**
   * Le palier : PRIMAIRE | COLLEGE | LYCEE | SUPERIEUR | DIPLOME.
   *
   * Filtre **dur** cote serveur, et non une simple ponderation : un professeur
   * d'universite n'est pas une reponse moins bonne pour un eleve de 9eme, c'est
   * une mauvaise reponse. Il n'apparait pas.
   */
  stage?: string
  /**
   * `AT_STUDENT` | `AT_TEACHER` | `ONLINE`.
   *
   * Les ecrans famille posent `AT_STUDENT` par defaut : une famille d'eleve
   * cherche quelqu'un qui vient a la maison, et lui faire parcourir une liste
   * dont la moitie ne se deplace pas est la premiere liste qu'elle voit du
   * produit.
   */
  mode?: string
  city?: string
  certifiedOnly?: boolean
  minScore?: number
  minExperience?: number
}

export interface Session {
  userId: string
  role: 'TEACHER' | 'INSTITUTION' | 'PARENT' | 'STUDENT' | 'ADMIN'
  teacherId?: string
  institutionId?: string
  /** Fiche parent, presente pour un compte PARENT. */
  parentId?: string
  /** Ville declaree : sert a restreindre les listes a la zone de l'usager. */
  city?: string
  displayName: string
}

/**
 * Une présence en cours, telle que le bandeau parent la lit.
 *
 * `minutes` vient du serveur, pas de l'horloge du navigateur : celle d'un
 * téléphone n'est pas toujours juste, et « en direct depuis 23 min » doit être
 * exact — c'est le chiffre sur lequel un parent juge si l'abonnement sert.
 */
export interface LivePresence {
  id: string
  sessionId: string
  /** Le prénom de l'enfant quand la place en porte un. */
  childName?: string
  subjectName?: string
  courseTitle?: string
  minutes: number
  startsAt: string
}

/** Le temps de cours cumulé sur une période. */
export interface StudySummary {
  /** Début de la période, en ISO. */
  since: string
  totalMinutes: number
  /** Une ligne par enfant, la plus longue d'abord. */
  perChild: Array<{ childName: string; minutes: number }>
  perSubject: Array<{ subjectName: string; minutes: number }>
  /** Nombre de séances distinctes suivies. */
  sessions: number
}

/**
 * La rediffusion d'une séance.
 *
 * `embed` est l'adresse du lecteur Cloudflare Stream, signée et temporaire. Elle n'est
 * présente que lorsque `available` est vrai — un champ toujours là mais parfois
 * vide inviterait à l'afficher dans un `iframe` qui échouerait en silence.
 */
/**
 * Un repère de module dans la rediffusion.
 *
 * Des secondes, pas un fichier : découper la vidéo en quatre aurait demandé un
 * ré-encodage, doublé le stockage facturé et multiplié par quatre les URL
 * signées à tenir. `?t=` répond à la même question — « où commence le module
 * que j'ai manqué ? » — sans rien de tout cela.
 */
export interface ReplayChapter {
  index: number
  label: string
  startSeconds: number
}

export interface SessionReplay {
  status: 'NONE' | 'RECORDING' | 'TRANSFERRING' | 'READY' | 'FAILED'
  available: boolean
  embed?: string
  /**
   * Vide quand la séance n'a eu aucun point de contrôle : on ne coupe pas au
   * hasard. Mieux vaut pas de chapitres que des chapitres qui mentent.
   */
  chapters?: ReplayChapter[]
  /** Expiration du lien, en secondes epoch. */
  expiresAt?: number
  title?: string
  startsAt?: string
}

/** Ce que l'ouverture ou la fermeture d'une salle rend au professeur. */
export interface RoomState {
  status: 'LIVE' | 'DONE'
  alreadyOpen?: boolean
  recording: string | null
}

/**
 * Une séance qu'une famille a réservée.
 *
 * Distincte de `LiveSession`, qui décrit la vitrine : ici s'ajoutent l'état de
 * l'inscription, le prénom de l'enfant concerné et la disponibilité de la
 * rediffusion — trois choses qu'un visiteur anonyme ne doit pas voir.
 *
 * Ce qu'elle ne porte pas : l'identifiant de la vidéo. Il n'est lisible
 * qu'accompagné d'une signature, et le faire figurer ici inviterait à le
 * transmettre.
 */
export interface MySession {
  enrolmentId: string
  enrolmentStatus: 'PENDING' | 'CONFIRMED' | 'CANCELLED'
  /** Fin de la réservation provisoire, quand le paiement n'est pas passé. */
  holdsUntil?: string
  childName?: string
  sessionId: string
  slotId: string
  startsAt: string
  durationMinutes: number
  status: 'PLANNED' | 'LIVE' | 'DONE' | 'CANCELLED'
  /** État de la rediffusion, ou absent s'il n'y en aura pas. */
  replay?: 'RECORDING' | 'TRANSFERRING' | 'READY' | 'FAILED'
  courseId: string
  title?: string
  price: number
  subject?: RefItem
  level?: RefItem
}

/**
 * Un point de contrôle de module.
 *
 * Quatre par séance (`moduleIndex` 0 à 3). `counts` et `summary` ne sont
 * remplis **que pour le professeur** : montrer « 11 sur 15 ont compris » à un
 * élève lui apprendrait aussi qu'il fait partie des quatre, et c'est exactement
 * ce qui le pousserait à répondre « oui » la prochaine fois.
 */
export interface Checkpoint {
  id: string
  moduleIndex: number
  openedAt: string
  closedAt?: string
  /** Professeur seulement. */
  counts?: CheckpointCounts
  /** Professeur seulement. Une aide pour la pause, jamais une note. */
  summary?: string
  /** Élève seulement : ce qu'il a répondu, pour savoir que c'est parti. */
  myAnswer?: CheckpointAnswer
}

export interface CheckpointCounts {
  yes: number
  partly: number
  no: number
}

export type CheckpointAnswer = 'YES' | 'NO' | 'PARTLY'

export interface CheckpointsView {
  role: 'teacher' | 'student'
  checkpoints: Checkpoint[]
  /** Élève : ses places sur cette séance, quand il y en a plusieurs. */
  enrolmentIds?: string[]
}
