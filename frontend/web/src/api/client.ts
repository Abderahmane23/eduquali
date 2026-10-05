import type {
  Application,
  CourseChapterPreview,
  EnrolmentResult,
  Institution,
  JobOffer,
  JobSearchQuery,
  LiveCourse,
  LiveCourseInput,
  LivePresence,
  LiveSession,
  MySession,
  Promotion,
  PurchaseRequest,
  PurchaseState,
  RankedCandidate,
  Checkpoint,
  CheckpointAnswer,
  CheckpointCounts,
  CheckpointsView,
  RefItem,
  RoomState,
  Session,
  SessionReplay,
  StudySummary,
  TeacherProfile,
  TeacherSearchQuery,
  TestQuestion,
  TestResult,
  TestSummary,
  TutoringOffer,
  VideoCourse,
  WalletMethod,
} from './types'

/**
 * Contrat de l'API (§47).
 *
 * Une seule interface, deux implementations : le serveur REST decrit au §47,
 * et un backend simule qui rejoue les memes données de démonstration que
 * l'application mobile. Les ecrans ne savent pas laquelle est active — c'est
 * ce qui permettra de brancher le vrai serveur sans les toucher.
 */
export interface VeriprofApi {
  // /auth
  login(phone: string, password: string): Promise<Session>
  register(input: RegisterInput): Promise<Session>

  /**
   * La session en cours, ou `null`.
   *
   * Interrogee au demarrage plutot que relue dans `localStorage` : quand
   * l'authentification vit ailleurs — Supabase detient le jeton et le
   * rafraichit — une copie locale diverge des la premiere expiration, et
   * l'application se croit connectee devant un serveur qui la refuse.
   */
  currentSession(): Promise<Session | null>

  logout(): Promise<void>

  // /subjects, /levels
  subjects(): Promise<RefItem[]>
  levels(): Promise<RefItem[]>
  cities(): Promise<string[]>

  // /jobs
  jobs(query?: JobSearchQuery): Promise<JobOffer[]>
  job(id: string): Promise<JobOffer | null>

  // /applications
  applications(teacherId: string): Promise<Application[]>
  apply(teacherId: string, jobId: string, note?: string): Promise<Application>

  // /institutions
  institutions(query?: { city?: string; type?: string }): Promise<Institution[]>

  // /teachers
  teacher(id: string): Promise<TeacherProfile | null>
  searchTeachers(query: TeacherSearchQuery): Promise<RankedCandidate[]>

  /**
   * Demande l'achat d'un cours.
   *
   * N'envoie que l'identifiant : le prix est releu par le serveur. Rend une
   * demande `PENDING` — l'encaissement n'existe pas encore.
   */
  buyCourse(
    courseId: string,
    wallet?: { method: WalletMethod; payerPhone?: string },
  ): Promise<PurchaseRequest>

  /** L'etat d'une demande d'achat, relu depuis le serveur. */
  purchaseState(purchaseId: string): Promise<PurchaseState>

  // --- Cours en direct ---------------------------------------------------

  /**
   * Les seances a venir, pour la grille.
   *
   * Publique : on consulte l'emploi du temps avant d'ouvrir un compte, comme on
   * consulte le programme d'un cours video.
   */
  liveSessions(query?: {
    subjectId?: string
    levelId?: string
    days?: number
  }): Promise<LiveSession[]>

  /**
   * Le jeton d'entree dans la salle d'une seance.
   *
   * Emis par le serveur, qui verifie l'inscription payee et la fenetre horaire :
   * LiveKit n'a pas de notion de compte et fait confiance a ce jeton.
   */
  roomToken(sessionId: string): Promise<{
    token: string
    url: string
    room: string
    role: 'teacher' | 'student'
    /**
     * L'etat de l'enregistrement, pour que la salle puisse le dire.
     *
     * Quinze eleves filmes pendant 90 minutes doivent savoir qu'ils le sont.
     * Cette valeur existe pour que l'information vienne du serveur et non d'une
     * supposition de l'ecran.
     */
    recording: string | null
  }>

  /**
   * Les seances reservees par la famille connectee, passees comprises.
   *
   * Sans cette liste, une seance payee n'existe plus pour la famille des que sa
   * date est passee : ni rediffusion, ni trace de l'achat. La grille publique,
   * elle, ne montre que ce qui vient.
   */
  mySessions(): Promise<MySession[]>

  /**
   * Le professeur ouvre et ferme sa salle.
   *
   * Deux gestes explicites, et non une ouverture automatique a l'heure dite :
   * c'est l'ouverture qui demarre l'enregistrement, et un cours qui commence
   * cinq minutes en retard ne doit pas enregistrer cinq minutes de salle vide.
   *
   * `openRoom` est rejouable : un professeur dont le navigateur plante reclique
   * sans relancer un second enregistrement.
   */
  openRoom(sessionId: string): Promise<RoomState>
  closeRoom(sessionId: string): Promise<RoomState>

  /**
   * Les points de controle d'une seance : ouvrir, repondre, fermer, relire.
   *
   * C'est ce qui distingue ce format d'une video enregistree. Dans une classe de
   * quinze adolescents, personne ne dit « je n'ai pas compris » — trois boutons,
   * si.
   *
   * `closeCheckpoint` rend le decompte **et** la phrase de synthese : les
   * demander separement ferait arriver la seconde trop tard, la pause ne durant
   * que cinq minutes.
   */
  openCheckpoint(sessionId: string, moduleIndex: number): Promise<Checkpoint>
  answerCheckpoint(
    checkpointId: string,
    answer: CheckpointAnswer,
    enrolmentId?: string,
  ): Promise<void>
  closeCheckpoint(
    checkpointId: string,
  ): Promise<{ counts: CheckpointCounts; summary?: string }>
  checkpoints(sessionId: string): Promise<CheckpointsView>

  /**
   * La rediffusion d'une seance.
   *
   * Reservee aux memes personnes que la salle — les inscrits payes et le
   * professeur. C'est la reponse a « j'ai eu une coupure de courant », qui est
   * la premiere raison de rater un cours ici.
   */
  sessionReplay(sessionId: string): Promise<SessionReplay>

  /**
   * Qui, parmi les siens, suit un cours en ce moment.
   *
   * La presence est constatee par le serveur de visioconference, jamais
   * declaree par un client : un onglet ferme n'envoie pas de depart, et un
   * eleve qui voudrait faire croire qu'il suit le cours n'aurait qu'a mentir.
   *
   * **Jamais la camera de l'enfant.** C'est une presence, pas une surveillance
   * video, et la distinction se tient dans le dessin comme dans le code.
   */
  livePresence(): Promise<LivePresence[]>

  /**
   * Le temps de cours cumule, par defaut depuis lundi.
   *
   * Le chiffre qui justifie l'abonnement d'un parent : il ne demande pas un
   * tableau de bord, il demande si son enfant travaille.
   */
  studyMinutes(options?: { since?: string }): Promise<StudySummary>

  /** Les cours recurrents d'un professeur, brouillons compris. */
  myLiveCourses(teacherId: string): Promise<LiveCourse[]>

  /** Declare un cours recurrent. Les seances sont generees ensuite. */
  createLiveCourse(input: LiveCourseInput): Promise<LiveCourse>

  /**
   * S'inscrit a une seance et lance le paiement.
   *
   * Passe par le serveur : c'est lui qui prend la place de maniere atomique et
   * qui relit le prix. Un client qui ecrirait directement contournerait les
   * deux.
   */
  enrolInSession(
    sessionId: string,
    options?: { childId?: string; method?: WalletMethod; payerPhone?: string },
  ): Promise<EnrolmentResult>

  /** Les mises en avant actives, toutes ecoles confondues. */
  promotions(query?: { city?: string }): Promise<Promotion[]>

  /** Les offres de cours a domicile d'un enseignant. */
  tutoringOffers(teacherId: string): Promise<TutoringOffer[]>

  /**
   * Les cours video en vente, et le sommaire de l'un d'eux.
   *
   * Le sommaire est public : on doit savoir ce qu'on achete avant de payer.
   * La lecture, elle, vit dans l'application — c'est la que le fichier se
   * garde hors ligne, et c'est ce que le web ne fera pas.
   */
  videoCourses(query?: { subjectId?: string }): Promise<VideoCourse[]>
  videoCourse(id: string): Promise<VideoCourse | null>
  courseProgramme(courseId: string): Promise<CourseChapterPreview[]>

  /**
   * Les tests de competence.
   *
   * `teacherId` est facultatif : sans lui, c'est le catalogue — ce qui existe,
   * et non ou en est quelqu'un. Un professeur qui n'a pas encore de compte doit
   * pouvoir voir qu'une certification existe dans sa matiere, c'est une des
   * raisons d'en ouvrir un.
   */
  tests(teacherId?: string): Promise<TestSummary[]>
  testQuestions(testId: string): Promise<TestQuestion[]>
  submitTest(
    testId: string,
    answers: Record<string, string>,
  ): Promise<TestResult>
}

/**
 * Inscription.
 *
 * **Le mot de passe est obligatoire depuis le 02/10.** Le §5.1 retenait la
 * verification par OTP, et faute de SMS les deux clients ouvraient les comptes
 * avec un secret partage ecrit en clair dans le code : quiconque connaissait un
 * numero entrait dans le compte qui le porte. Un mot de passe choisi ne demande
 * aucun fournisseur, fonctionne de la meme facon sur le site et dans
 * l'application, et rend un compte reellement personnel.
 *
 * L'OTP par SMS reste souhaitable — il verifie que le numero appartient bien a
 * la personne, ce qu'un mot de passe ne dit pas. Les deux sont complementaires,
 * pas concurrents.
 */
export interface RegisterInput {
  firstName: string
  lastName: string
  phone: string
  /**
   * Choisi par la personne, huit caracteres au minimum. Le parcours le
   * collecte a l'etape `credentials`, juste apres le numero.
   */
  password: string
  city?: string

  /**
   * Region administrative et quartier, tels que l'etape de localisation les
   * recueille.
   *
   * Ils etaient collectes par le parcours et jetes ici : seule la ville
   * arrivait, alors que l'etape annonce « Le quartier decide des professeurs
   * qui peuvent venir » (audit du 04/10).
   */
  region?: string
  district?: string

  /**
   * Nom de l'etablissement, pour un compte `INSTITUTION`.
   *
   * Sans ce champ, l'appelant faisait passer le nom du **responsable** en
   * `firstName` et `institutions.name` prenait cette valeur : un etablissement
   * se retrouvait nomme d'apres son directeur. Le mobile, lui, lisait bien
   * `institution_name`.
   */
  institutionName?: string

  /** SCHOOL | HIGH_SCHOOL | UNIVERSITY | INSTITUTE | TRAINING_CENTER | OTHER */
  institutionType?: string

  /**
   * L'apprenant declare pendant le parcours : un enfant pour un parent, la
   * personne elle-meme pour un universitaire.
   *
   * Aucune ligne n'etait creee cote site, alors que le mobile en cree une :
   * le meme questionnaire donnait deux resultats selon la porte d'entree, et
   * la famille inscrite depuis le site arrivait sur un espace vide.
   */
  learner?: {
    firstName: string
    lastName?: string
    levelId?: string
    filiereId?: string
    schoolName?: string
    subjectIds?: string[]
  }

  /**
   * La formule choisie au dernier ecran, **pas encore payee**.
   *
   * Elle n'etait lue par personne : on choisissait PRO et on obtenait un
   * compte FREE, a rechoisir depuis la facturation.
   */
  pendingPlan?: string

  /**
   * `STUDENT` est un etudiant majeur qui s'inscrit pour lui-meme. Il partage
   * l'espace du parent — meme suivi, memes contrats — mais le role reste
   * distinct : c'est lui qui signe, et la regle des 18 ans s'y rattache.
   */
  role: 'TEACHER' | 'INSTITUTION' | 'PARENT' | 'STUDENT'
}

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status?: number,
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

/** Client REST — actif des qu'une URL d'API est configuree. */
export class HttpApi implements VeriprofApi {
  constructor(
    private readonly baseUrl: string,
    private token?: string,
  ) {}

  private async request<T>(path: string, init?: RequestInit): Promise<T> {
    let response: Response
    try {
      response = await fetch(`${this.baseUrl}${path}`, {
        ...init,
        headers: {
          'Content-Type': 'application/json',
          ...(this.token ? { Authorization: `Bearer ${this.token}` } : {}),
          ...init?.headers,
        },
      })
    } catch {
      // Le message s'adresse a l'utilisateur : il decrit la situation et ne
      // lui reproche rien.
      throw new ApiError(
        'Pas de connexion au serveur. Vérifiez votre réseau et réessayez.',
      )
    }

    // Un message par situation : « erreur » sans suite laisse l'utilisateur
    // sans rien a faire (§5 du design_skill).
    if (response.status === 401) {
      throw new ApiError('Votre session a expiré. Reconnectez-vous.', 401)
    }
    if (response.status === 403) {
      throw new ApiError(
        'Votre compte n’a pas accès à cette page.',
        403,
      )
    }
    if (response.status === 404) {
      throw new ApiError('Cette page n’existe plus.', 404)
    }
    if (response.status === 409) {
      throw new ApiError('Vous avez déjà postulé à cette offre.', 409)
    }
    if (response.status === 429) {
      throw new ApiError(
        'Trop de tentatives. Patientez une minute avant de réessayer.',
        429,
      )
    }
    if (!response.ok) {
      throw new ApiError(
        'Le serveur n’a pas pu traiter la demande. Réessayez dans un instant.',
        response.status,
      )
    }
    return (await response.json()) as T
  }

  private post<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>(path, { method: 'POST', body: JSON.stringify(body) })
  }

  private query(params: Record<string, unknown>): string {
    const search = new URLSearchParams()
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null && value !== '') {
        search.set(key, String(value))
      }
    }
    const qs = search.toString()
    return qs ? `?${qs}` : ''
  }

  async login(phone: string, password: string) {
    const session = await this.post<Session & { accessToken?: string }>(
      '/auth/login',
      { phone, password },
    )
    this.token = session.accessToken
    return session
  }

  async register(input: RegisterInput) {
    const session = await this.post<Session & { accessToken?: string }>(
      '/auth/register',
      input,
    )
    this.token = session.accessToken
    return session
  }

  /**
   * Le serveur REST ne tient pas de session cote client : le jeton vit dans
   * un cookie `httpOnly`, et c'est lui qui repond.
   */
  async currentSession() {
    try {
      return await this.request<Session | null>('/auth/session')
    } catch {
      // Un 401 au demarrage n'est pas une panne : c'est un visiteur.
      return null
    }
  }

  async logout() {
    this.token = undefined
    try {
      await this.post<void>('/auth/logout', {})
    } catch {
      // Le serveur injoignable ne doit pas empecher de quitter son compte :
      // le jeton local est deja oublie.
    }
  }

  subjects() {
    return this.request<RefItem[]>('/subjects')
  }
  levels() {
    return this.request<RefItem[]>('/levels')
  }
  cities() {
    return this.request<string[]>('/levels/cities')
  }

  jobs(query: JobSearchQuery = {}) {
    return this.request<JobOffer[]>(`/jobs${this.query({ ...query })}`)
  }
  job(id: string) {
    return this.request<JobOffer | null>(`/jobs/${id}`)
  }

  applications(teacherId: string) {
    return this.request<Application[]>(
      `/applications${this.query({ teacherId })}`,
    )
  }
  apply(teacherId: string, jobId: string, note?: string) {
    return this.post<Application>('/applications', { teacherId, jobId, note })
  }

  institutions(query: { city?: string; type?: string } = {}) {
    return this.request<Institution[]>(`/institutions${this.query({ ...query })}`)
  }

  teacher(id: string) {
    return this.request<TeacherProfile | null>(`/teachers/${id}`)
  }
  searchTeachers(query: TeacherSearchQuery) {
    return this.request<RankedCandidate[]>(
      `/teachers${this.query({ ...query })}`,
    )
  }

  buyCourse(
    courseId: string,
    wallet?: { method: WalletMethod; payerPhone?: string },
  ) {
    return this.post<PurchaseRequest>('/purchases', { courseId, ...wallet })
  }

  purchaseState(purchaseId: string) {
    return this.request<PurchaseState>(`/purchases/${purchaseId}`)
  }

  liveSessions(query: { subjectId?: string; levelId?: string; days?: number } = {}) {
    return this.request<LiveSession[]>(
      `/live/sessions${this.query({ ...query })}`,
    )
  }
  roomToken(sessionId: string) {
    return this.post<{
      token: string
      url: string
      room: string
      role: 'teacher' | 'student'
      recording: string | null
    }>(`/live/sessions/${sessionId}/token`, {})
  }
  mySessions() {
    return this.request<MySession[]>('/live/my-sessions')
  }
  openRoom(sessionId: string) {
    return this.post<RoomState>(`/live/sessions/${sessionId}/open`, {})
  }
  closeRoom(sessionId: string) {
    return this.post<RoomState>(`/live/sessions/${sessionId}/close`, {})
  }
  sessionReplay(sessionId: string) {
    return this.request<SessionReplay>(`/live/sessions/${sessionId}/replay`)
  }
  openCheckpoint(sessionId: string, moduleIndex: number) {
    return this.post<Checkpoint>(`/live/sessions/${sessionId}/checkpoints`, {
      moduleIndex,
    })
  }
  answerCheckpoint(
    checkpointId: string,
    answer: CheckpointAnswer,
    enrolmentId?: string,
  ) {
    return this.post<void>(`/live/checkpoints/${checkpointId}/answer`, {
      answer,
      ...(enrolmentId ? { enrolmentId } : {}),
    })
  }
  closeCheckpoint(checkpointId: string) {
    return this.post<{ counts: CheckpointCounts; summary?: string }>(
      `/live/checkpoints/${checkpointId}/close`,
      {},
    )
  }
  checkpoints(sessionId: string) {
    return this.request<CheckpointsView>(
      `/live/sessions/${sessionId}/checkpoints`,
    )
  }
  livePresence() {
    return this.request<LivePresence[]>('/live/presence')
  }
  studyMinutes(options: { since?: string } = {}) {
    return this.request<StudySummary>(
      `/live/study-minutes${this.query({ ...options })}`,
    )
  }
  myLiveCourses(teacherId: string) {
    return this.request<LiveCourse[]>(
      `/live/courses${this.query({ teacherId })}`,
    )
  }
  createLiveCourse(input: LiveCourseInput) {
    return this.post<LiveCourse>('/live/courses', input)
  }
  enrolInSession(
    sessionId: string,
    options: { childId?: string; method?: WalletMethod; payerPhone?: string } = {},
  ) {
    return this.post<EnrolmentResult>('/live/enrol', { sessionId, ...options })
  }

  promotions(query: { city?: string } = {}) {
    return this.request<Promotion[]>(`/promotions${this.query({ ...query })}`)
  }

  tutoringOffers(teacherId: string) {
    return this.request<TutoringOffer[]>(
      `/tutoring${this.query({ teacherId })}`,
    )
  }

  videoCourses(query: { subjectId?: string } = {}) {
    return this.request<VideoCourse[]>(`/courses${this.query({ ...query })}`)
  }
  videoCourse(id: string) {
    return this.request<VideoCourse | null>(`/courses/${id}`)
  }
  courseProgramme(courseId: string) {
    return this.request<CourseChapterPreview[]>(`/courses/${courseId}/programme`)
  }

  tests(teacherId?: string) {
    return this.request<TestSummary[]>(`/tests${this.query({ teacherId })}`)
  }
  testQuestions(testId: string) {
    return this.request<TestQuestion[]>(`/tests/${testId}/questions`)
  }
  submitTest(testId: string, answers: Record<string, string>) {
    return this.post<TestResult>(`/tests/${testId}/submit`, { answers })
  }
}
