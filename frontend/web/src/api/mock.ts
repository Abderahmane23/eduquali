import type { RegisterInput, VeriprofApi } from './client'
import { ApiError } from './client'
import { scoreMatch } from './matching'
import type {
  Application,
  ApplicationStatus,
  Certification,
  CourseChapterPreview,
  CourseItemPreview,
  EnrolmentResult,
  Institution,
  JobOffer,
  JobSearchQuery,
  LiveCourse,
  LivePresence,
  LiveSession,
  Child,
  MaPromotion,
  MySession,
  PresenceProof,
  Promotion,
  PurchaseRequest,
  PurchaseState,
  RankedCandidate,
  Checkpoint,
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
  TrustBadges,
  TutoringOffer,
  VideoCourse,
  WalletMethod,
} from './types'

/**
 * Backend simule, alimente par les memes fichiers de données que
 * l'application mobile (`public/data`).
 *
 * Il n'existe pas encore de serveur : plutot que d'inventer des ecrans a
 * partir de données fictives propres au web, on rejoue le referentiel et les
 * offres embarques dans le mobile. Les deux clients montrent donc la meme
 * chose, et le jour ou l'API du §47 existe, seule la fabrique de `client.ts`
 * change.
 */

interface RawCatalog {
  subjects: { id: string; name: string; code: string; order: number }[]
  levels: {
    id: string
    name: string
    code: string
    category: string
    /** Le palier : PRIMAIRE | COLLEGE | LYCEE | SUPERIEUR | DIPLOME. */
    cycle: string
  }[]
  tests: { id: string; subjectId: string; levelId: string; bank: string }[]
  institutions: {
    id: string
    name: string
    type: string
    city: string
    address?: string
    description?: string
    verificationStatus: string
  }[]
  promotions?: {
    id: string
    institutionId: string
    title: string
    message?: string
    status: string
  }[]
  tutoringServices?: {
    id: string
    teacherId: string
    subjectId: string
    levelIds: string[]
    mode: string
    hourlyRate?: number
    city?: string
    districts?: string[]
    availabilityNote?: string
    description?: string
  }[]
  videoCourses?: {
    id: string
    teacherId: string
    subjectId?: string
    title: string
    description?: string
    levelIds: string[]
    price: number
    status: string
    chapters: {
      title: string
      description?: string
      items: { kind: string; title: string; durationSeconds?: number }[]
    }[]
  }[]
  jobs: {
    id: string
    institutionId: string
    title: string
    subjectId: string
    levelIds: string[]
    city: string
    contractType: string
    description?: string
    salaryMin?: number
    salaryMax?: number
    salaryPublished?: boolean
    minExperience?: number
    requiresCertification?: boolean
    publishedDaysAgo?: number
  }[]
  demoTeachers: {
    id: string
    firstName: string
    lastName: string
    city: string
    headline: string
    bio?: string
    yearsExperience: number
    availability: string
    identityStatus: string
    diplomaStatus: string
    subjects: string[]
    levels: [string, string][]
    certifications: { subjectId: string; levelId: string; score: number }[]
    experiences: {
      institutionName: string
      position: string
      city?: string
      startYear: number
      endYear: number | null
      verified: boolean
    }[]
  }[]
}

interface RawBank {
  title: string
  durationMinutes: number
  passingScore: number
  rules?: string
  questions: {
    q: string
    o: string[]
    a: string
    d: string
    e?: string
  }[]
}

const DATA = '/data'

/** Latence simulee : sans elle, les etats de chargement ne sont jamais vus. */
const delay = (ms = 220) => new Promise((r) => setTimeout(r, ms))

export class MockApi implements VeriprofApi {
  private catalog?: RawCatalog
  private banks = new Map<string, RawBank>()
  private submitted: Application[] = []
  private certifications = new Map<string, Certification[]>()

  /**
   * Le backend simule ne tient pas de session entre deux chargements.
   *
   * Il rend donc `null` et laisse `SessionProvider` reprendre sa copie
   * locale : c'est le seul mode ou cette copie fait autorite, parce qu'il
   * n'existe aucun serveur pour la contredire.
   */
  async currentSession() {
    return null
  }

  async logout() {
    this.submitted = []
  }

  private async load(): Promise<RawCatalog> {
    if (!this.catalog) {
      const response = await fetch(`${DATA}/catalog.json`)
      if (!response.ok) throw new ApiError('Données de démonstration absentes.')
      this.catalog = (await response.json()) as RawCatalog
    }
    return this.catalog
  }

  private async bank(testId: string): Promise<RawBank> {
    const cached = this.banks.get(testId)
    if (cached) return cached
    const catalog = await this.load()
    const entry = catalog.tests.find((t) => t.id === testId)
    if (!entry) throw new ApiError('Test introuvable.', 404)
    const response = await fetch(`${DATA}/${entry.bank}`)
    const bank = (await response.json()) as RawBank
    this.banks.set(testId, bank)
    return bank
  }

  // --- Referentiel ------------------------------------------------------

  async subjects(): Promise<RefItem[]> {
    const c = await this.load()
    return c.subjects.map((s) => ({ id: s.id, name: s.name, code: s.code }))
  }

  async levels(): Promise<RefItem[]> {
    const c = await this.load()
    return c.levels.map((l) => ({
      id: l.id,
      name: l.name,
      code: l.code,
      category: l.category,
      cycle: l.cycle,
    }))
  }

  async cities(): Promise<string[]> {
    const c = await this.load()
    return [...new Set(c.jobs.map((j) => j.city))].sort()
  }

  // --- Authentification -------------------------------------------------

  async login(phone: string, password: string): Promise<Session> {
    await delay()
    if (!phone || !password) {
      throw new ApiError('Renseignez votre numéro et votre mot de passe.')
    }
    const c = await this.load()
    const teacher = c.demoTeachers[0]
    return {
      userId: `user_${teacher.id}`,
      role: 'TEACHER',
      teacherId: teacher.id,
      displayName: `${teacher.firstName} ${teacher.lastName}`,
    }
  }

  async register(input: RegisterInput): Promise<Session> {
    // Le backend simule accepte tout, mais pas un mot de passe trop court : un
    // parcours qui passe en demonstration et echoue en production ne sert a
    // rien.
    if ((input.password ?? '').length < 8) {
      throw new ApiError('Mot de passe trop court (8 caractères minimum).', 400)
    }
    await delay()
    const c = await this.load()
    return {
      userId: `user_${Date.now()}`,
      role: input.role,
      teacherId: input.role === 'TEACHER' ? c.demoTeachers[0].id : undefined,
      institutionId:
        input.role === 'INSTITUTION' ? c.institutions[0].id : undefined,
      city: input.city,
      displayName: `${input.firstName} ${input.lastName}`.trim(),
    }
  }

  // --- Offres -----------------------------------------------------------

  async jobs(query: JobSearchQuery = {}): Promise<JobOffer[]> {
    await delay()
    const c = await this.load()
    const now = Date.now()

    let offers = c.jobs.map((raw) => this.toJob(raw, c, now))

    if (query.subjectId) {
      offers = offers.filter((o) => o.subject.id === query.subjectId)
    }
    if (query.levelId) {
      offers = offers.filter((o) =>
        o.levels.some((l) => l.id === query.levelId),
      )
    }
    if (query.city) offers = offers.filter((o) => o.city === query.city)
    if (query.contractType) {
      offers = offers.filter((o) => o.contractType === query.contractType)
    }
    if (query.query) {
      const needle = query.query.toLowerCase()
      offers = offers.filter(
        (o) =>
          o.title.toLowerCase().includes(needle) ||
          o.institution.name.toLowerCase().includes(needle) ||
          o.subject.name.toLowerCase().includes(needle),
      )
    }

    return offers.sort(
      (a, b) => Date.parse(b.publishedAt) - Date.parse(a.publishedAt),
    )
  }

  async job(id: string): Promise<JobOffer | null> {
    const offers = await this.jobs()
    return offers.find((o) => o.id === id) ?? null
  }

  private toJob(
    raw: RawCatalog['jobs'][number],
    c: RawCatalog,
    now: number,
  ): JobOffer {
    const subject = c.subjects.find((s) => s.id === raw.subjectId)!
    const institution = c.institutions.find((i) => i.id === raw.institutionId)!
    return {
      id: raw.id,
      title: raw.title,
      institution: this.toInstitution(institution),
      subject: { id: subject.id, name: subject.name },
      levels: raw.levelIds.map((id) => {
        const level = c.levels.find((l) => l.id === id)!
        return { id: level.id, name: level.name }
      }),
      city: raw.city,
      contractType: raw.contractType as JobOffer['contractType'],
      description: raw.description,
      salaryMin: raw.salaryMin,
      salaryMax: raw.salaryMax,
      salaryPublished: raw.salaryPublished ?? false,
      minExperience: raw.minExperience ?? 0,
      requiresCertification: raw.requiresCertification ?? false,
      publishedAt: new Date(
        now - (raw.publishedDaysAgo ?? 0) * 86_400_000,
      ).toISOString(),
      applicationCount: 0,
    }
  }

  // --- Achat d'un cours -------------------------------------------------

  /** Les demandes posees pendant la session de demonstration. */
  private readonly requested = new Map<string, PurchaseRequest>()

  async buyCourse(
    courseId: string,
    wallet?: { method: WalletMethod; payerPhone?: string },
  ): Promise<PurchaseRequest> {
    await delay()
    const deja = this.requested.get(courseId)
    if (deja) return { ...deja, alreadyRequested: true }

    const cours = await this.videoCourse(courseId)
    if (!cours) throw new ApiError('Cours introuvable.', 404)

    const demande: PurchaseRequest = {
      id: `demo_${courseId}`,
      // `PENDING` comme en production : une demonstration qui rendrait `PAID`
      // montrerait un parcours qui n'existe pas encore.
      status: 'PENDING',
      amount: cours.price,
      alreadyRequested: false,
      // Le backend simule n'appelle aucun operateur. Annoncer une
      // confirmation a venir ferait attendre un SMS qui ne partira pas.
      payment: 'none',
      paymentError: wallet
        ? 'Aucun encaissement en mode démonstration.'
        : undefined,
    }
    this.requested.set(courseId, demande)
    return demande
  }

  async purchaseState(purchaseId: string): Promise<PurchaseState> {
    await delay()
    const demande = [...this.requested.values()].find((d) => d.id === purchaseId)
    if (!demande) throw new ApiError('Demande introuvable.', 404)
    const courseId =
      [...this.requested.entries()].find(([, d]) => d.id === purchaseId)?.[0] ??
      ''
    return {
      id: demande.id,
      courseId,
      status: demande.status,
      amount: demande.amount,
    }
  }

  // --- Cours en direct --------------------------------------------------
  //
  // Le backend simule ne genere pas de seances : il n'a ni cron ni base. Il rend
  // une grille vide et le dit. Fabriquer de fausses seances ferait croire que la
  // fonction marche, et l'ecran n'afficherait l'absence qu'en production.

  async liveSessions(): Promise<LiveSession[]> {
    await delay()
    return []
  }

  async roomToken(): Promise<{
    token: string
    url: string
    room: string
    role: 'teacher' | 'student'
    recording: string | null
  }> {
    // Aucune salle sans fournisseur : le dire vaut mieux qu'un jeton invente
    // que LiveKit refuserait sans expliquer pourquoi.
    throw new ApiError(
      'La visioconference demande le serveur et LiveKit. Configurez-les.',
      501,
    )
  }

  async mySessions(): Promise<MySession[]> {
    await delay()
    // Rien a reserver sans base : la grille est vide, les reservations aussi.
    return []
  }

  async children(): Promise<Child[]> {
    await delay()
    // Pas de compte, pas d'enfants. Vide, et non une erreur : c'est aussi ce
    // que lit un etudiant majeur sur un vrai serveur.
    return []
  }

  async ecolesConnues(): Promise<{ value: string; label: string }[]> {
    await delay()
    const c = await this.load()
    // Les ecoles du jeu de demonstration : la saisie libre reste possible,
    // et c'est elle qui compte sans base.
    const noms = new Set<string>()
    for (const ecole of c.institutions ?? []) noms.add(ecole.name)
    return [...noms].sort().map((nom) => ({ value: nom, label: nom }))
  }

  async presenceProof(): Promise<PresenceProof> {
    /*
     * Pas de preuve inventee.
     *
     * Le reste de la demonstration affiche des professeurs et des ecoles
     * fictifs, et l'ossature le dit en toutes lettres. Une preuve de presence
     * fictive serait d'une autre nature : c'est le document qui atteste qu'un
     * enfant etait en cours, et en fabriquer un apprendrait a s'en mefier.
     */
    throw new ApiError(
      'La preuve de presence demande le serveur. Configurez-le.',
      501,
    )
  }

  async openRoom(): Promise<RoomState> {
    throw new ApiError(
      'Ouvrir une salle demande le serveur et LiveKit. Configurez-les.',
      501,
    )
  }

  async closeRoom(): Promise<RoomState> {
    throw new ApiError(
      'Fermer une salle demande le serveur et LiveKit. Configurez-les.',
      501,
    )
  }

  async openCheckpoint(): Promise<Checkpoint> {
    throw new ApiError(
      'Les points de controle demandent le serveur. Configurez-le.',
      501,
    )
  }

  async answerCheckpoint(): Promise<void> {
    throw new ApiError(
      'Les points de controle demandent le serveur. Configurez-le.',
      501,
    )
  }

  async closeCheckpoint(): Promise<{
    counts: CheckpointCounts
    summary?: string
  }> {
    throw new ApiError(
      'Les points de controle demandent le serveur. Configurez-le.',
      501,
    )
  }

  async checkpoints(): Promise<CheckpointsView> {
    await delay()
    // Liste vide plutot qu'une erreur : la salle doit pouvoir s'afficher en
    // demonstration, simplement sans point de controle.
    return { role: 'student', checkpoints: [] }
  }

  async sessionReplay(): Promise<SessionReplay> {
    await delay()
    // Pas d'erreur ici, et c'est une difference voulue avec les deux ci-dessus :
    // une rediffusion absente est un etat normal — la seance n'a pas encore eu
    // lieu, ou n'a pas ete enregistree. L'ecran sait l'afficher.
    return { status: 'NONE', available: false }
  }

  async livePresence(): Promise<LivePresence[]> {
    await delay()
    // Personne en cours : sans serveur de visioconference, il ne peut y avoir
    // aucune presence. Inventer un enfant « en direct depuis 23 min » ferait
    // croire que la fonction marche, et l'absence ne se decouvrirait qu'en
    // production — un soir de cours.
    return []
  }

  async studyMinutes(options: { since?: string } = {}): Promise<StudySummary> {
    await delay()
    return {
      since: options.since ?? new Date().toISOString(),
      totalMinutes: 0,
      sessions: 0,
      perChild: [],
      perSubject: [],
    }
  }

  async myLiveCourses(): Promise<LiveCourse[]> {
    await delay()
    return []
  }

  async createLiveCourse(): Promise<LiveCourse> {
    throw new ApiError(
      'Les cours en direct demandent une base de donnees. Configurez Supabase.',
      501,
    )
  }

  async enrolInSession(): Promise<EnrolmentResult> {
    throw new ApiError(
      'L’inscription demande le serveur. Configurez VITE_API_BASE_URL.',
      501,
    )
  }

  // --- Mises en avant ---------------------------------------------------

  async mesPromotions(): Promise<MaPromotion[]> {
    await delay()
    // Aucune ecole sans base : la liste est vide, et c'est aussi ce que voit
    // un vrai compte qui n'a encore rien publie.
    return []
  }

  async creerPromotion(): Promise<never> {
    throw new ApiError(
      'Publier une mise en avant demande le serveur. Configurez-le.',
      501,
    )
  }

  async terminerPromotion(): Promise<void> {
    throw new ApiError(
      'Retirer une mise en avant demande le serveur. Configurez-le.',
      501,
    )
  }

  async promotions(query: { city?: string } = {}): Promise<Promotion[]> {
    await delay()
    const c = await this.load()
    return (c.promotions ?? [])
      .filter((raw) => raw.status === 'ACTIVE')
      .map((raw) => {
        const ecole = c.institutions.find((i) => i.id === raw.institutionId)
        return {
          id: raw.id,
          institutionId: raw.institutionId,
          institutionName: ecole?.name ?? 'Établissement',
          city: ecole?.city,
          title: raw.title,
          message: raw.message,
        }
      })
      .filter((promo) => !query.city || promo.city === query.city)
  }

  // --- Cours a domicile -------------------------------------------------

  async tutoringOffers(teacherId: string): Promise<TutoringOffer[]> {
    await delay()
    const c = await this.load()
    const subjects = await this.subjects()
    const levels = await this.levels()

    return (c.tutoringServices ?? [])
      .filter((raw) => raw.teacherId === teacherId)
      .map((raw) => ({
        id: raw.id,
        teacherId: raw.teacherId,
        subject:
          subjects.find((s) => s.id === raw.subjectId) ??
          { id: raw.subjectId, name: raw.subjectId },
        levels: levels.filter((l) => raw.levelIds.includes(l.id)),
        mode:
          raw.mode === 'AT_TEACHER' || raw.mode === 'ONLINE'
            ? raw.mode
            : ('AT_STUDENT' as const),
        hourlyRate: raw.hourlyRate,
        city: raw.city,
        districts: raw.districts ?? [],
        availabilityNote: raw.availabilityNote,
        description: raw.description,
      }))
  }

  // --- Cours video ------------------------------------------------------

  /**
   * La vitrine des cours.
   *
   * Lit le meme `catalog.json` que l'application mobile : trois cours de
   * demonstration avec leurs chapitres. Les videos n'ont pas de fichier, et
   * c'est sans consequence ici — la vitrine ne montre que le programme.
   */
  async videoCourses(query: { subjectId?: string } = {}): Promise<VideoCourse[]> {
    await delay()
    const c = await this.load()
    const subjects = await this.subjects()
    const levels = await this.levels()

    return (c.videoCourses ?? [])
      .filter((raw) => raw.status === 'PUBLISHED')
      .filter((raw) => !query.subjectId || raw.subjectId === query.subjectId)
      .map((raw) => {
        const teacher = c.demoTeachers.find((t) => t.id === raw.teacherId)
        const videos = raw.chapters.flatMap((ch) =>
          ch.items.filter((i) => i.kind === 'VIDEO'),
        )
        return {
          id: raw.id,
          title: raw.title,
          description: raw.description,
          teacherId: raw.teacherId,
          teacherName: teacher
            ? `${teacher.firstName} ${teacher.lastName}`
            : 'Professeur EduQuali',
          subject: subjects.find((s) => s.id === raw.subjectId),
          levels: levels.filter((l) => raw.levelIds.includes(l.id)),
          price: raw.price,
          net: Math.round(raw.price * 0.8),
          chapterCount: raw.chapters.length,
          videoCount: videos.length,
          totalSeconds: videos.reduce(
            (total, v) => total + (v.durationSeconds ?? 0),
            0,
          ),
        }
      })
  }

  async videoCourse(id: string): Promise<VideoCourse | null> {
    const all = await this.videoCourses()
    return all.find((course) => course.id === id) ?? null
  }

  async courseLecture(): Promise<CourseChapterPreview[]> {
    await delay()
    // Rien n'est achete sans base : le sommaire reste ferme, ce qui est
    // aussi ce que voit un vrai compte qui n'a pas paye.
    return []
  }

  async courseProgramme(courseId: string): Promise<CourseChapterPreview[]> {
    await delay()
    const c = await this.load()
    const course = (c.videoCourses ?? []).find((v) => v.id === courseId)
    if (!course) return []

    // Identifiants deduits du rang, comme le semis du telephone : les deux
    // clients designent le meme chapitre par le meme identifiant.
    return course.chapters.map((chapter, rang) => ({
      id: `${courseId}_ch${rang + 1}`,
      title: chapter.title,
      description: chapter.description,
      position: rang,
      items: chapter.items.map((item, i) => ({
        id: `${courseId}_ch${rang + 1}_it${i + 1}`,
        kind: (item.kind === 'DOCUMENT' || item.kind === 'LINK'
          ? item.kind
          : 'VIDEO') as CourseItemPreview['kind'],
        title: item.title,
        durationSeconds: item.durationSeconds,
      })),
    }))
  }

  async institutions(
    query: { city?: string; type?: string } = {},
  ): Promise<Institution[]> {
    await delay()
    const c = await this.load()
    let list = c.institutions.map((raw) => this.toInstitution(raw))
    if (query.city) list = list.filter((i) => i.city === query.city)
    if (query.type) list = list.filter((i) => i.type === query.type)
    // Un etablissement verifie passe devant : c'est la seule hierarchie que
    // l'eleve peut verifier lui-meme.
    return list.sort(
      (a, b) =>
        Number(b.verified) - Number(a.verified) || a.name.localeCompare(b.name),
    )
  }

  private toInstitution(raw: RawCatalog['institutions'][number]): Institution {
    return {
      id: raw.id,
      name: raw.name,
      type: raw.type as Institution['type'],
      city: raw.city,
      address: raw.address,
      description: raw.description,
      verified: raw.verificationStatus === 'VERIFIED',
    }
  }

  // --- Candidatures -----------------------------------------------------

  async applications(_teacherId: string): Promise<Application[]> {
    await delay(120)
    return [...this.submitted].sort(
      (a, b) => Date.parse(b.appliedAt) - Date.parse(a.appliedAt),
    )
  }

  async apply(
    teacherId: string,
    jobId: string,
    _note?: string,
  ): Promise<Application> {
    await delay()
    const job = await this.job(jobId)
    if (!job) throw new ApiError('Offre introuvable.', 404)
    if (this.submitted.some((a) => a.job.id === jobId)) {
      throw new ApiError('Vous avez déjà postule a cette offre.')
    }

    const profile = await this.teacher(teacherId)
    const application: Application = {
      id: `app_${Date.now()}`,
      job,
      status: 'SENT' as ApplicationStatus,
      appliedAt: new Date().toISOString(),
      matchScore: profile ? scoreMatch(job, profile).value : undefined,
    }
    this.submitted.push(application)
    return application
  }

  // --- Enseignants ------------------------------------------------------

  async teacher(id: string): Promise<TeacherProfile | null> {
    const c = await this.load()
    const raw = c.demoTeachers.find((t) => t.id === id)
    return raw ? this.toProfile(raw, c) : null
  }

  async searchTeachers(query: TeacherSearchQuery): Promise<RankedCandidate[]> {
    await delay()
    const c = await this.load()
    let profiles = c.demoTeachers.map((t) => this.toProfile(t, c))

    if (query.subjectId) {
      profiles = profiles.filter((p) =>
        p.subjects.some((s) => s.id === query.subjectId),
      )
    }
    // Le palier : filtre dur, comme cote serveur. Un professeur d'universite
    // n'est pas une reponse moins bonne pour un eleve de 9eme, c'est une
    // mauvaise reponse.
    if (query.stage) {
      profiles = profiles.filter((p) =>
        p.levels.some((l) => l.cycle === query.stage),
      )
    }
    // La classe, en tolerant une declaration plus large : « College » couvre la
    // 9eme.
    if (query.levelId) {
      profiles = profiles.filter((p) => {
        const demande = p.levels.find((l) => l.id === query.levelId)
        const cycle = demande?.cycle
        return p.levels.some(
          (l) => l.id === query.levelId || (cycle && l.cycle === cycle),
        )
      })
    }
    if (query.mode) {
      // Le mode vit dans les offres de cours a domicile, pas dans la fiche :
      // c'est la que l'enseignant declare s'il se deplace.
      const avecLeMode = new Set(
        (c.tutoringServices ?? [])
          .filter((o) => o.mode === query.mode)
          .map((o) => o.teacherId),
      )
      profiles = profiles.filter((p) => avecLeMode.has(p.id))
    }
    if (query.city) profiles = profiles.filter((p) => p.city === query.city)
    if (query.certifiedOnly) {
      profiles = profiles.filter((p) => p.certifications.length > 0)
    }
    if (query.minExperience) {
      profiles = profiles.filter(
        (p) => p.yearsExperience >= query.minExperience!,
      )
    }
    if (query.minScore) {
      profiles = profiles.filter((p) =>
        p.certifications.some((cert) => cert.score >= query.minScore!),
      )
    }

    return profiles
      .map((profile) => ({
        profile,
        match: scoreMatch(
          {
            subject: query.subjectId ? { id: query.subjectId, name: '' } : undefined,
            levels: query.levelId ? [{ id: query.levelId, name: '' }] : [],
            city: query.city,
            minExperience: query.minExperience ?? 0,
            requiresCertification: query.certifiedOnly ?? false,
          },
          profile,
        ),
      }))
      .sort((a, b) => b.match.value - a.match.value)
  }

  private toProfile(
    raw: RawCatalog['demoTeachers'][number],
    c: RawCatalog,
  ): TeacherProfile {
    const ref = (id: string, list: { id: string; name: string }[]): RefItem => {
      const found = list.find((x) => x.id === id)
      return { id, name: found?.name ?? id }
    }

    const certifications: Certification[] = (
      this.certifications.get(raw.id) ?? []
    ).concat(
      raw.certifications.map((cert) => ({
        id: `${raw.id}_${cert.subjectId}_${cert.levelId}`,
        subject: ref(cert.subjectId, c.subjects),
        level: ref(cert.levelId, c.levels),
        score: cert.score,
        issuedAt: new Date(Date.now() - 90 * 86_400_000).toISOString(),
      })),
    )

    const verifiedExperience = raw.experiences.filter((e) => e.verified).length
    const badges: TrustBadges = {
      identity: raw.identityStatus === 'VERIFIED',
      diploma: raw.diplomaStatus === 'VERIFIED',
      competency: certifications.length > 0,
      experience: verifiedExperience > 0,
      profile: false,
    }
    badges.profile = badges.identity && badges.diploma && badges.competency

    // Trust score : memes ponderations que le mobile (§62).
    const best = certifications.reduce((m, cert) => Math.max(m, cert.score), 0)
    const trustScore = Math.round(
      (badges.identity ? 25 : 0) +
        (badges.diploma ? 20 : 0) +
        (20 * best) / 100 +
        15 * Math.min(1, raw.yearsExperience / 5) +
        (verifiedExperience > 0 ? 5 : 0),
    )

    const levels = [...new Set(raw.levels.map(([, levelId]) => levelId))]

    return {
      id: raw.id,
      firstName: raw.firstName,
      lastName: raw.lastName,
      fullName: `${raw.firstName} ${raw.lastName}`,
      headline: raw.headline,
      bio: raw.bio,
      city: raw.city,
      yearsExperience: raw.yearsExperience,
      availability: raw.availability as TeacherProfile['availability'],
      identityStatus: raw.identityStatus as TeacherProfile['identityStatus'],
      diplomaStatus: raw.diplomaStatus as TeacherProfile['diplomaStatus'],
      subjects: raw.subjects.map((id) => ref(id, c.subjects)),
      levels: levels.map((id) => ref(id, c.levels)),
      certifications,
      experiences: raw.experiences.map((e, i) => ({
        id: `${raw.id}_exp_${i}`,
        institutionName: e.institutionName,
        position: e.position,
        city: e.city,
        startYear: e.startYear,
        endYear: e.endYear,
        verified: e.verified,
      })),
      badges,
      trustScore,
      completionRate: Math.min(
        100,
        40 +
          (badges.identity ? 15 : 0) +
          (badges.diploma ? 15 : 0) +
          (certifications.length > 0 ? 20 : 0) +
          (raw.experiences.length > 0 ? 10 : 0),
      ),
    }
  }

  // --- Tests ------------------------------------------------------------

  async tests(teacherId?: string): Promise<TestSummary[]> {
    await delay()
    const c = await this.load()
    // Sans enseignant, c'est le catalogue : tous les tests, sans filtre de
    // matiere et sans resultat rattache a personne.
    const profile = teacherId ? await this.teacher(teacherId) : null
    const subjectIds = new Set(profile?.subjects.map((s) => s.id) ?? [])

    const summaries: TestSummary[] = []
    for (const entry of c.tests) {
      // Un enseignant ne passe que les tests de ses matières (§10.1).
      if (subjectIds.size > 0 && !subjectIds.has(entry.subjectId)) continue
      const bank = await this.bank(entry.id)
      const subject = c.subjects.find((s) => s.id === entry.subjectId)!
      const level = c.levels.find((l) => l.id === entry.levelId)!
      summaries.push({
        id: entry.id,
        title: bank.title,
        subject: { id: subject.id, name: subject.name },
        level: { id: level.id, name: level.name },
        questionCount: bank.questions.length,
        durationMinutes: bank.durationMinutes,
        passingScore: bank.passingScore,
        rules: bank.rules,
        certification: profile?.certifications.find(
          (cert) =>
            cert.subject.id === entry.subjectId &&
            cert.level.id === entry.levelId,
        ),
      })
    }
    return summaries
  }

  async testQuestions(testId: string): Promise<TestQuestion[]> {
    const bank = await this.bank(testId)
    // La bonne réponse n'est pas envoyée avant la correction.
    return bank.questions.map((q, i) => ({
      id: `${testId}_q${i + 1}`,
      statement: q.q,
      options: q.o.map((text, index) => ({
        key: String.fromCharCode(65 + index),
        text,
      })),
      domain: q.d,
    }))
  }

  async submitTest(
    testId: string,
    answers: Record<string, string>,
  ): Promise<TestResult> {
    await delay(400)
    const bank = await this.bank(testId)
    const byDomain = new Map<string, { correct: number; total: number }>()
    let correctCount = 0

    bank.questions.forEach((question, i) => {
      const id = `${testId}_q${i + 1}`
      const isCorrect = answers[id] === question.a
      if (isCorrect) correctCount++
      const bucket = byDomain.get(question.d) ?? { correct: 0, total: 0 }
      bucket.total++
      if (isCorrect) bucket.correct++
      byDomain.set(question.d, bucket)
    })

    const total = bank.questions.length
    const score = total === 0 ? 0 : Math.round((correctCount / total) * 100)

    return {
      score,
      correctCount,
      totalQuestions: total,
      passed: score >= bank.passingScore,
      passingScore: bank.passingScore,
      domainScores: [...byDomain.entries()]
        .map(([domain, v]) => ({
          domain,
          correct: v.correct,
          total: v.total,
          percentage: Math.round((v.correct / v.total) * 100),
        }))
        .sort((a, b) => a.domain.localeCompare(b.domain)),
    }
  }
}
