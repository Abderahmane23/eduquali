import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { ApiError, type RegisterInput, type VeriprofApi } from './client'
import { scoreMatch } from './matching'
import {
  maybeText,
  nested,
  text,
  toApplication,
  toCertification,
  toInstitution,
  toJobOffer,
  toRefItem,
  toSession,
  toTeacherProfile,
  toTestQuestion,
  toTestSummary,
  type Row,
} from './supabase-rows'
import type {
  Application,
  CourseChapterPreview,
  CourseItemPreview,
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
  PurchaseStatus,
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
 * Acces direct a Supabase, sans serveur intermediaire.
 *
 * Le navigateur parle a PostgREST avec la cle anonyme, qui est publique par
 * construction : elle part dans le bundle, et n'importe qui peut la lire.
 *
 * **Ce n'est donc pas elle qui protege quoi que ce soit.** La seule barriere
 * est RLS, table par table (`0002_rls.sql`, `0007_rls_parity.sql`). Une
 * table sans RLS est lisible par le monde entier ; une table avec RLS mais
 * sans politique est fermee a tous. Les deux se font ensemble, dans la meme
 * migration, pour qu'on ne puisse pas faire l'un sans l'autre.
 *
 * Corollaire pratique : ce fichier ne verifie aucun droit. Il demande, et
 * Postgres decide. Un filtre ecrit ici serait une commodite d'affichage, pas
 * une securite — et le croire serait la meilleure facon de s'en remettre a
 * un controle que le premier `curl` contourne.
 */
export class SupabaseApi implements VeriprofApi {
  constructor(private readonly db: SupabaseClient) {}

  // --- Outils -------------------------------------------------------------

  /**
   * Traduit une panne PostgREST en phrase utilisable.
   *
   * Les codes valent mieux que les messages : `PGRST301` reste stable quand
   * le texte de l'erreur change de version en version.
   */
  private fail(error: { code?: string; message: string }): never {
    if (error.code === '23505') {
      throw new ApiError('Vous avez déjà postulé à cette offre.', 409)
    }
    if (error.code === '42501' || error.code === 'PGRST301') {
      throw new ApiError('Votre compte n’a pas accès à cette donnée.', 403)
    }
    if (error.message.toLowerCase().includes('failed to fetch')) {
      throw new ApiError(
        'Pas de connexion au serveur. Vérifiez votre réseau et réessayez.',
      )
    }
    throw new ApiError(
      'Le serveur n’a pas pu traiter la demande. Réessayez dans un instant.',
    )
  }

  private async rows(
    build: () => PromiseLike<{
      data: unknown
      error: { code?: string; message: string } | null
    }>,
  ): Promise<Row[]> {
    const { data, error } = await build()
    if (error) this.fail(error)
    return Array.isArray(data) ? (data as Row[]) : []
  }

  /**
   * Le referentiel des niveaux, garde en memoire.
   *
   * Une offre porte ses niveaux dans un tableau d'identifiants, pas dans une
   * relation : sans ce cache, afficher vingt offres ferait vingt requetes
   * pour les memes quinze niveaux.
   */
  private levelsCache?: Map<string, RefItem>

  private async levelsById(): Promise<Map<string, RefItem>> {
    if (this.levelsCache) return this.levelsCache
    const list = await this.levels()
    this.levelsCache = new Map(list.map((l) => [l.id, l]))
    return this.levelsCache
  }

  // --- Session ------------------------------------------------------------

  /**
   * La session courante, telle que Supabase la connait.
   *
   * C'est lui qui detient le jeton et le rafraichit ; une copie dans
   * `localStorage` divergerait des la premiere expiration, et l'application
   * se croirait connectee devant un serveur qui la refuse.
   */
  async currentSession(): Promise<Session | null> {
    const { data } = await this.db.auth.getUser()
    return data.user ? this.sessionOf(data.user.id) : null
  }

  /** Assemble la session a partir du profil et de la fiche du role. */
  private async sessionOf(userId: string): Promise<Session> {
    const { data: profile, error } = await this.db
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle()
    if (error) this.fail(error)
    if (!profile) {
      throw new ApiError('Ce compte n’a pas encore de profil.', 404)
    }

    const role = (profile as Row).role
    // Une seule requete, celle du role concerne : demander les trois ferait
    // deux refus RLS a chaque ouverture de session.
    const [teacher, institution, parent] = await Promise.all([
      role === 'TEACHER' ? this.ownRowId('teachers', 'user_id', userId) : null,
      role === 'INSTITUTION'
        ? this.ownRowId('institutions', 'owner_id', userId)
        : null,
      role === 'PARENT' || role === 'STUDENT'
        ? this.ownRowId('parents', 'user_id', userId)
        : null,
    ])

    return toSession(profile as Row, {
      teacherId: teacher ?? undefined,
      institutionId: institution ?? undefined,
      parentId: parent ?? undefined,
    })
  }

  private async ownRowId(
    table: string,
    column: string,
    userId: string,
  ): Promise<string | null> {
    const { data } = await this.db
      .from(table)
      .select('id')
      .eq(column, userId)
      .maybeSingle()
    return data ? String((data as Row).id) : null
  }

  /**
   * Adresse derivee d'un numero.
   *
   * La confirmation par SMS est retiree pour l'instant (25/09) : elle
   * suppose un fournisseur payant a configurer, et personne ne veut etre
   * bloque par un code en attendant. L'authentification par telephone de
   * Supabase envoie un SMS par construction ; on passe donc par une adresse
   * derivee du numero, qui n'existe nulle part ailleurs et ne sert qu'a
   * identifier le compte.
   *
   * Le numero reste la verite metier : il est dans `profiles.phone`, et
   * c'est lui que voient les ecrans.
   */
  private static emailFor(phone: string): string {
    const chiffres = phone.replace(/\D/g, '')
    return `${chiffres}@telephone.eduquali.gn`
  }

  /**
   * Longueur minimale d'un mot de passe.
   *
   * Huit caracteres : au-dessous, un numero de telephone guineen se devine en
   * quelques essais, et Supabase en exige six. La meme valeur figure dans
   * l'etape `credentials` du parcours — c'est elle qui empeche d'arriver
   * jusqu'ici avec un mot de passe trop court.
   */
  private static readonly minPasswordLength = 8

  async login(phone: string, password: string): Promise<Session> {
    // Plus de repli sur un secret partage. Jusqu'au 02/10, un mot de passe
    // vide ouvrait le compte avec une valeur ecrite dans le bundle : connaitre
    // un numero suffisait pour entrer.
    if (password.trim() === '') {
      throw new ApiError('Entrez votre mot de passe.', 400)
    }

    const { data, error } = await this.db.auth.signInWithPassword({
      email: SupabaseApi.emailFor(phone),
      password,
    })
    if (error) {
      // Un seul message pour « numero inconnu » et « mot de passe faux » :
      // les distinguer dirait a un inconnu quels numeros ont un compte.
      throw new ApiError('Numéro ou mot de passe incorrect.', 401)
    }
    return this.sessionOf(data.user.id)
  }

  /**
   * Inscription.
   *
   * Le compte d'authentification et le profil metier sont deux ecritures :
   * Supabase cree le premier, le second suit. Un declencheur SQL serait plus
   * sur — il les rendrait indissociables — et c'est ce qu'il faudra ecrire
   * cote serveur ; en attendant, l'echec du profil est signale plutot que
   * laisse passer, sans quoi le compte existerait sans identite.
   */
  async register(input: RegisterInput): Promise<Session> {
    // Verifie ici et pas seulement dans le parcours : ce depot est appele par
    // deux ecrans, et un refus du serveur arriverait apres la creation du
    // compte d'authentification — laissant un numero pris sans compte
    // utilisable.
    if (input.password.length < SupabaseApi.minPasswordLength) {
      throw new ApiError(
        `Votre mot de passe doit faire au moins ${SupabaseApi.minPasswordLength} caractères.`,
        400,
      )
    }

    const { data, error } = await this.db.auth.signUp({
      email: SupabaseApi.emailFor(input.phone),
      password: input.password,
    })
    if (error || !data.user) {
      throw new ApiError(
        'Ce numéro a peut-être déjà un compte. Essayez de vous connecter.',
        409,
      )
    }

    const { error: profileError } = await this.db.from('profiles').insert({
      id: data.user.id,
      role: input.role,
      phone: input.phone,
      first_name: input.firstName,
      last_name: input.lastName,
      city: input.city ?? null,
      // La formule choisie au dernier écran, et pas encore payée : rien n'est
      // encaissé à l'inscription, donc l'écrire dans `plan` l'offrirait.
      pending_plan: input.pendingPlan ?? null,
    })
    if (profileError) this.fail(profileError)

    // La fiche du role : c'est elle qui porte les donnees metier, et son
    // identifiant est ce que les ecrans manipulent ensuite.
    if (input.role === 'TEACHER') {
      await this.db.from('teachers').insert({
        user_id: data.user.id,
        city: input.city ?? null,
        // La région et le quartier étaient collectés par le parcours et
        // n'arrivaient pas : seule la ville passait, alors que l'étape dit
        // « Le quartier décide des professeurs qui peuvent venir ».
        region: input.region ?? null,
        district: input.district ?? null,
      })
    } else if (input.role === 'PARENT' || input.role === 'STUDENT') {
      // Un etudiant majeur partage l'espace de la famille — meme suivi, memes
      // demandes de cours, memes contrats — donc la meme fiche. Sans cette
      // ligne, son compte s'ouvrait sans `parentId` et chaque ecran du
      // parcours famille le trouvait vide.
      const { data: parent } = await this.db
        .from('parents')
        .insert({
          user_id: data.user.id,
          city: input.city ?? null,
          region: input.region ?? null,
          district: input.district ?? null,
        })
        .select('id')
        .maybeSingle()

      // L'apprenant déclaré pendant le parcours.
      //
      // Aucune ligne n'était créée ici, alors que le mobile en crée une : le
      // même questionnaire donnait deux résultats selon la porte d'entrée, et
      // la famille inscrite depuis le site arrivait sur un espace vide, sans
      // niveau ni matière — donc sans aucun professeur pertinent à proposer.
      //
      // Après le compte et séparément : un échec ici ne doit pas défaire une
      // inscription réussie, l'apprenant restant ajoutable depuis le profil.
      if (parent?.id && input.learner?.firstName) {
        const { error: learnerError } = await this.db.from('children').insert({
          parent_id: parent.id,
          first_name: input.learner.firstName,
          last_name: input.learner.lastName ?? null,
          level_id: input.learner.levelId ?? null,
          filiere_id: input.learner.filiereId ?? null,
          school_name: input.learner.schoolName ?? null,
          subject_ids: (input.learner.subjectIds ?? []).join(','),
        })
        if (learnerError) {
          console.error('[register] apprenant non enregistré', learnerError)
        }
      }
    } else if (input.role === 'INSTITUTION') {
      await this.db.from('institutions').insert({
        owner_id: data.user.id,
        // Le nom de l'établissement, et non celui de son responsable : cette
        // ligne prenait `input.firstName`, que l'appelant remplissait avec
        // `manager_name`. Un lycée se retrouvait nommé d'après son directeur.
        name: input.institutionName ?? input.firstName,
        type: input.institutionType ?? 'SCHOOL',
        city: input.city ?? '',
        region: input.region ?? null,
        district: input.district ?? null,
        manager_name: input.firstName || null,
      })
    }

    return this.sessionOf(data.user.id)
  }

  async logout(): Promise<void> {
    await this.db.auth.signOut()
  }

  // --- Referentiel --------------------------------------------------------

  async subjects(): Promise<RefItem[]> {
    const rows = await this.rows(() =>
      this.db
        .from('subjects')
        .select('id, name, code')
        .eq('active', true)
        .order('sort_order'),
    )
    return rows.map(toRefItem)
  }

  async levels(): Promise<RefItem[]> {
    const rows = await this.rows(() =>
      this.db
        .from('levels')
        .select('id, name, code, category, cycle')
        .eq('active', true)
        .order('sort_order'),
    )
    return rows.map(toRefItem)
  }

  /**
   * Les villes ou il se passe quelque chose.
   *
   * Tirees des etablissements plutot que d'une liste fixe : une ville sans
   * etablissement ne rend aucun resultat, et la proposer est une impasse.
   */
  async cities(): Promise<string[]> {
    const rows = await this.rows(() =>
      this.db.from('institutions').select('city').order('city'),
    )
    const unique = new Set(
      rows.map((r) => String(r.city ?? '')).filter((c) => c !== ''),
    )
    return [...unique].sort((a, b) => a.localeCompare(b, 'fr'))
  }

  // --- Offres -------------------------------------------------------------

  private readonly jobColumns = `
    id, title, city, contract_type, description, salary_min, salary_max,
    salary_published, min_experience, requires_certification, level_ids,
    published_at, created_at,
    subjects ( id, name, code ),
    institutions ( id, name, type, city, address, description,
                   verification_status ),
    applications ( count )
  `

  async jobs(query: JobSearchQuery = {}): Promise<JobOffer[]> {
    const levels = await this.levelsById()
    const rows = await this.rows(() => {
      let request = this.db
        .from('jobs')
        .select(this.jobColumns)
        .eq('status', 'PUBLISHED')
        .order('published_at', { ascending: false })

      if (query.subjectId) request = request.eq('subject_id', query.subjectId)
      if (query.city) request = request.eq('city', query.city)
      if (query.contractType) {
        request = request.eq('contract_type', query.contractType)
      }
      // Un niveau est dans un tableau Postgres : `contains` s'appuie sur
      // l'operateur `@>`, donc sur l'index, la ou un filtre en memoire
      // obligerait a tout telecharger.
      if (query.levelId) request = request.contains('level_ids', [query.levelId])
      if (query.query) {
        const q = `%${query.query}%`
        request = request.or(`title.ilike.${q},description.ilike.${q}`)
      }
      return request
    })
    return rows.map((row) => toJobOffer(row, levels))
  }

  async job(id: string): Promise<JobOffer | null> {
    const levels = await this.levelsById()
    const { data, error } = await this.db
      .from('jobs')
      .select(this.jobColumns)
      .eq('id', id)
      .maybeSingle()
    if (error) this.fail(error)
    return data ? toJobOffer(data as Row, levels) : null
  }

  // --- Candidatures -------------------------------------------------------

  async applications(teacherId: string): Promise<Application[]> {
    const levels = await this.levelsById()
    const rows = await this.rows(() =>
      this.db
        .from('applications')
        .select(`id, status, applied_at, match_score, jobs ( ${this.jobColumns} )`)
        .eq('teacher_id', teacherId)
        .order('applied_at', { ascending: false }),
    )
    return rows.map((row) => toApplication(row, levels))
  }

  async apply(
    teacherId: string,
    jobId: string,
    note?: string,
  ): Promise<Application> {
    const levels = await this.levelsById()
    const { data, error } = await this.db
      .from('applications')
      .insert({ teacher_id: teacherId, job_id: jobId, cover_note: note ?? null })
      .select(`id, status, applied_at, match_score, jobs ( ${this.jobColumns} )`)
      .single()
    if (error) this.fail(error)
    return toApplication(data as Row, levels)
  }

  // --- Etablissements -----------------------------------------------------

  async institutions(
    query: { city?: string; type?: string } = {},
  ): Promise<Institution[]> {
    const rows = await this.rows(() => {
      let request = this.db
        .from('institutions')
        .select('id, name, type, city, address, description, verification_status')
        .order('name')
      if (query.city) request = request.eq('city', query.city)
      if (query.type) request = request.eq('type', query.type)
      return request
    })
    return rows.map(toInstitution)
  }

  // --- Achat d'un cours ---------------------------------------------------

  /**
   * Demande l'achat d'un cours.
   *
   * **Passe par le serveur, pas par PostgREST.** La migration 0012 a retire la
   * politique d'insertion du client : un achat ecrit directement laisserait le
   * navigateur fixer le montant, et `amount` est ce qui sera reclame a
   * l'operateur de paiement. Le serveur relit le prix dans `video_courses`,
   * calcule la commission et pose l'etat.
   *
   * C'est le premier appel de ce client a l'API : les lectures restent
   * directes, les ecritures d'argent passent par un serveur. Sans
   * `VITE_API_BASE_URL`, il n'y a personne au bout — on le dit plutot que
   * d'echouer sur une URL relative.
   */
  async buyCourse(
    courseId: string,
    wallet?: { method: WalletMethod; payerPhone?: string },
  ): Promise<PurchaseRequest> {
    const corps = await this.callApi('/purchases', {
      method: 'POST',
      body: { courseId, ...wallet },
    })

    return {
      id: String(corps.id ?? ''),
      status: (corps.status as PurchaseStatus) ?? 'PENDING',
      amount: Number(corps.amount ?? 0),
      alreadyRequested: Boolean(corps.alreadyRequested),
      payment:
        (corps.payment as PurchaseRequest['payment']) ?? 'none',
      redirectUrl: (corps.redirectUrl as string) ?? undefined,
      paymentError: (corps.paymentError as string) ?? undefined,
      sandbox: corps.sandbox === true,
    }
  }

  async purchaseState(purchaseId: string): Promise<PurchaseState> {
    const corps = await this.callApi(
      `/purchases/${encodeURIComponent(purchaseId)}`,
      { method: 'GET' },
    )
    return {
      id: String(corps.id ?? ''),
      courseId: String(corps.courseId ?? ''),
      status: (corps.status as PurchaseStatus) ?? 'PENDING',
      amount: Number(corps.amount ?? 0),
      method: (corps.method as string) ?? undefined,
      paidAt: (corps.paidAt as string) ?? undefined,
      providerStatus: (corps.providerStatus as string) ?? undefined,
    }
  }

  /**
   * Un appel a notre serveur, avec le jeton de la session.
   *
   * Les lectures passent en direct par PostgREST ; ce chemin est reserve a ce
   * qui touche a l'argent, ou le serveur seul connait le prix et detient la cle
   * de l'operateur. Sans `VITE_API_BASE_URL`, il n'y a personne au bout — on le
   * dit plutot que d'echouer sur une URL relative.
   */
  private async callApi(
    chemin: string,
    options: { method: 'GET' | 'POST'; body?: unknown } = { method: 'GET' },
  ): Promise<Record<string, unknown>> {
    const base = import.meta.env.VITE_API_BASE_URL?.trim()
    if (!base) {
      throw new ApiError(
        'Cette fonction demande le serveur Eduquali, qui n’est pas encore relié à ce site.',
        501,
      )
    }

    const { data } = await this.db.auth.getSession()
    const jeton = data.session?.access_token
    if (!jeton) {
      throw new ApiError('Connectez-vous pour continuer.', 401)
    }

    const reponse = await fetch(`${base.replace(/\/$/, '')}${chemin}`, {
      method: options.method,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${jeton}`,
      },
      body: options.body === undefined ? undefined : JSON.stringify(options.body),
    })

    const corps = (await reponse.json().catch(() => ({}))) as Record<
      string,
      unknown
    >
    if (!reponse.ok) {
      throw new ApiError(
        (corps.error as string) ?? 'La demande n’a pas abouti.',
        reponse.status,
      )
    }
    return corps
  }

  // --- Cours en direct ----------------------------------------------------

  /**
   * Les seances a venir.
   *
   * Lecture directe : la politique « seance : visible avec son cours » les ouvre
   * des que le cours est publie, donc la grille se consulte sans compte.
   *
   * Le nom du professeur passe par `public_teacher_identities`, pour la meme
   * raison que sur la fiche publique : « profil : lecture de soi » ferme
   * `profiles` a tout le monde sauf son proprietaire, et une grille de cours
   * sans nom de professeur ne se lit pas.
   */
  async liveSessions(
    query: { subjectId?: string; levelId?: string; days?: number } = {},
  ): Promise<LiveSession[]> {
    const jours = query.days ?? 28
    const jusqua = new Date(Date.now() + jours * 86_400_000).toISOString()

    const rows = await this.rows(() => {
      let requete = this.db
        .from('live_sessions')
        .select(
          `id, live_course_id, slot_id, starts_at, duration_minutes, status,
           seats_taken,
           live_courses!inner (
             id, price, seats, title, teacher_id, status,
             subjects ( id, name, code ),
             levels ( id, name, code, category ),
             teachers ( user_id )
           )`,
        )
        .eq('status', 'PLANNED')
        .eq('live_courses.status', 'PUBLISHED')
        .gte('starts_at', new Date().toISOString())
        .lte('starts_at', jusqua)
        .order('starts_at', { ascending: true })

      if (query.subjectId) {
        requete = requete.eq('live_courses.subject_id', query.subjectId)
      }
      if (query.levelId) {
        requete = requete.eq('live_courses.level_id', query.levelId)
      }
      return requete
    })

    if (rows.length === 0) return []

    // Un seul appel pour tous les noms, et non un par seance.
    const premier = (valeur: unknown): Row | null => {
      if (Array.isArray(valeur)) return (valeur[0] as Row) ?? null
      return (valeur as Row) ?? null
    }

    const utilisateurs = new Set<string>()
    for (const row of rows) {
      const cours = premier(row.live_courses)
      const prof = cours ? premier(cours.teachers) : null
      const userId = prof ? maybeText(prof, 'user_id') : undefined
      if (userId) utilisateurs.add(userId)
    }

    const noms = new Map<string, string>()
    if (utilisateurs.size > 0) {
      const { data } = await this.db
        .from('public_teacher_identities')
        .select('id, first_name, last_name')
        .in('id', [...utilisateurs])
      for (const identite of (data ?? []) as Row[]) {
        const id = maybeText(identite, 'id')
        if (!id) continue
        noms.set(
          id,
          `${maybeText(identite, 'first_name') ?? ''} ${
            maybeText(identite, 'last_name') ?? ''
          }`.trim(),
        )
      }
    }

    const niveaux = await this.levels()

    return rows.map((row) => {
      const cours = premier(row.live_courses) ?? {}
      const prof = premier(cours.teachers)
      const userId = prof ? maybeText(prof, 'user_id') : undefined
      const places = typeof cours.seats === 'number' ? cours.seats : 15
      const prises = typeof row.seats_taken === 'number' ? row.seats_taken : 0
      const matiere = premier(cours.subjects)
      const niveau = premier(cours.levels)

      return {
        id: text(row, 'id'),
        courseId: text(row, 'live_course_id'),
        slotId: text(row, 'slot_id'),
        startsAt: text(row, 'starts_at'),
        durationMinutes:
          typeof row.duration_minutes === 'number' ? row.duration_minutes : 90,
        status: 'PLANNED' as const,
        // Jamais negatif : un compteur deregle afficherait « -1 place ».
        seatsLeft: Math.max(places - prises, 0),
        seats: places,
        price: typeof cours.price === 'number' ? cours.price : 0,
        subject: matiere
          ? toRefItem(matiere)
          : { id: '', name: 'Matière non précisée' },
        level: niveau ? toRefItem(niveau) : niveaux[0] ?? { id: '', name: '' },
        teacherId: maybeText(cours, 'teacher_id') ?? '',
        teacherName: (userId ? noms.get(userId) : undefined) ?? '',
        title: maybeText(cours, 'title'),
      }
    })
  }

  /**
   * Le jeton d'entree dans une salle.
   *
   * Par le serveur, jamais en direct : c'est lui qui verifie que la place est
   * payee et qu'on est dans la fenetre de la seance, et lui seul detient le
   * secret qui signe le jeton.
   */
  async roomToken(sessionId: string): Promise<{
    token: string
    url: string
    room: string
    role: 'teacher' | 'student'
    recording: string | null
  }> {
    const corps = await this.callApi(
      `/live/sessions/${encodeURIComponent(sessionId)}/token`,
      { method: 'POST', body: {} },
    )
    return {
      token: String(corps.token ?? ''),
      url: String(corps.url ?? ''),
      room: String(corps.room ?? ''),
      role: corps.role === 'teacher' ? 'teacher' : 'student',
      recording:
        typeof corps.recording === 'string' ? corps.recording : null,
    }
  }

  /**
   * Les seances reservees par la famille connectee.
   *
   * Par le serveur : la jointure traverse inscriptions, seances, cours, matieres
   * et fiches enfants, et elle sert deux clients. La faire deux fois donnerait
   * deux listes qui divergeraient.
   */
  async mySessions(): Promise<MySession[]> {
    const corps = (await this.callApi('/live/my-sessions')) as unknown
    const lignes = (Array.isArray(corps) ? corps : []) as Array<
      Record<string, unknown>
    >

    const etats = ['PENDING', 'CONFIRMED', 'CANCELLED']
    const rediffusions = ['RECORDING', 'TRANSFERRING', 'READY', 'FAILED']
    const ref = (valeur: unknown) => {
      if (!valeur || typeof valeur !== 'object') return undefined
      const objet = valeur as Record<string, unknown>
      return { id: String(objet.id ?? ''), name: String(objet.name ?? '') }
    }

    return lignes.map((ligne) => ({
      enrolmentId: String(ligne.enrolmentId ?? ''),
      enrolmentStatus: etats.includes(String(ligne.enrolmentStatus))
        ? (String(ligne.enrolmentStatus) as MySession['enrolmentStatus'])
        : 'PENDING',
      holdsUntil:
        typeof ligne.holdsUntil === 'string' ? ligne.holdsUntil : undefined,
      childName: typeof ligne.childName === 'string' ? ligne.childName : undefined,
      sessionId: String(ligne.sessionId ?? ''),
      slotId: String(ligne.slotId ?? ''),
      startsAt: String(ligne.startsAt ?? ''),
      durationMinutes: Number(ligne.durationMinutes ?? 90),
      status: ['PLANNED', 'LIVE', 'DONE', 'CANCELLED'].includes(
        String(ligne.status),
      )
        ? (String(ligne.status) as MySession['status'])
        : 'PLANNED',
      replay: rediffusions.includes(String(ligne.replay))
        ? (String(ligne.replay) as MySession['replay'])
        : undefined,
      courseId: String(ligne.courseId ?? ''),
      title: typeof ligne.title === 'string' ? ligne.title : undefined,
      price: Number(ligne.price ?? 0),
      subject: ref(ligne.subject),
      level: ref(ligne.level),
    }))
  }

  /**
   * Ouvrir et fermer la salle.
   *
   * Par le serveur : c'est lui qui demarre l'enregistrement et qui detient les
   * cles de l'egress. Un client ne peut ni l'un ni l'autre.
   */
  async openRoom(sessionId: string): Promise<RoomState> {
    const corps = await this.callApi(
      `/live/sessions/${encodeURIComponent(sessionId)}/open`,
      { method: 'POST', body: {} },
    )
    return {
      status: corps.status === 'DONE' ? 'DONE' : 'LIVE',
      alreadyOpen: Boolean(corps.alreadyOpen),
      recording: (corps.recording as string | null) ?? null,
    }
  }

  async closeRoom(sessionId: string): Promise<RoomState> {
    const corps = await this.callApi(
      `/live/sessions/${encodeURIComponent(sessionId)}/close`,
      { method: 'POST', body: {} },
    )
    return {
      status: 'DONE',
      recording: (corps.recording as string | null) ?? null,
    }
  }

  /**
   * Les points de controle.
   *
   * Tout par le serveur : c'est lui qui verifie que le vote est ouvert, qui
   * decompte, et qui appelle Gemini avec une invite **sans aucune donnee
   * personnelle**. Un client ne peut faire aucun des trois.
   */
  async openCheckpoint(
    sessionId: string,
    moduleIndex: number,
  ): Promise<Checkpoint> {
    const corps = await this.callApi(
      `/live/sessions/${encodeURIComponent(sessionId)}/checkpoints`,
      { method: 'POST', body: { moduleIndex } },
    )
    return {
      id: String(corps.id ?? ''),
      moduleIndex: Number(corps.moduleIndex ?? moduleIndex),
      openedAt: String(corps.openedAt ?? new Date().toISOString()),
      closedAt: typeof corps.closedAt === 'string' ? corps.closedAt : undefined,
    }
  }

  async answerCheckpoint(
    checkpointId: string,
    answer: CheckpointAnswer,
    enrolmentId?: string,
  ): Promise<void> {
    await this.callApi(
      `/live/checkpoints/${encodeURIComponent(checkpointId)}/answer`,
      { method: 'POST', body: { answer, ...(enrolmentId ? { enrolmentId } : {}) } },
    )
  }

  async closeCheckpoint(
    checkpointId: string,
  ): Promise<{ counts: CheckpointCounts; summary?: string }> {
    const corps = await this.callApi(
      `/live/checkpoints/${encodeURIComponent(checkpointId)}/close`,
      { method: 'POST', body: {} },
    )
    const brut = (corps.counts ?? {}) as Record<string, unknown>
    return {
      counts: {
        yes: Number(brut.yes ?? 0),
        partly: Number(brut.partly ?? 0),
        no: Number(brut.no ?? 0),
      },
      summary: typeof corps.summary === 'string' ? corps.summary : undefined,
    }
  }

  async checkpoints(sessionId: string): Promise<CheckpointsView> {
    const corps = await this.callApi(
      `/live/sessions/${encodeURIComponent(sessionId)}/checkpoints`,
    )
    const liste = Array.isArray(corps.checkpoints) ? corps.checkpoints : []
    return {
      role: corps.role === 'teacher' ? 'teacher' : 'student',
      enrolmentIds: Array.isArray(corps.enrolmentIds)
        ? corps.enrolmentIds.map(String)
        : undefined,
      checkpoints: liste.map((ligne: Record<string, unknown>) => {
        const brut = ligne.counts as Record<string, unknown> | undefined
        return {
          id: String(ligne.id ?? ''),
          moduleIndex: Number(ligne.moduleIndex ?? 0),
          openedAt: String(ligne.openedAt ?? ''),
          closedAt:
            typeof ligne.closedAt === 'string' ? ligne.closedAt : undefined,
          counts: brut
            ? {
                yes: Number(brut.yes ?? 0),
                partly: Number(brut.partly ?? 0),
                no: Number(brut.no ?? 0),
              }
            : undefined,
          summary: typeof ligne.summary === 'string' ? ligne.summary : undefined,
          myAnswer: ['YES', 'NO', 'PARTLY'].includes(String(ligne.myAnswer))
            ? (String(ligne.myAnswer) as CheckpointAnswer)
            : undefined,
        }
      }),
    }
  }

  /**
   * La rediffusion.
   *
   * Par le serveur, comme toute video payee : l'adresse du lecteur est signee, et
   * elle n'est signee qu'apres verification de l'inscription. Une lecture directe
   * de la table rendrait l'identifiant de la video, ce qui reviendrait a donner le
   * cours.
   */
  async sessionReplay(sessionId: string): Promise<SessionReplay> {
    const corps = await this.callApi(
      `/live/sessions/${encodeURIComponent(sessionId)}/replay`,
    )
    const etats = ['NONE', 'RECORDING', 'TRANSFERRING', 'READY', 'FAILED']
    const etat = etats.includes(String(corps.status))
      ? (String(corps.status) as SessionReplay['status'])
      : 'NONE'
    return {
      status: etat,
      available: Boolean(corps.available),
      embed: typeof corps.embed === 'string' ? corps.embed : undefined,
      expiresAt:
        typeof corps.expiresAt === 'number' ? corps.expiresAt : undefined,
      title: typeof corps.title === 'string' ? corps.title : undefined,
      startsAt: typeof corps.startsAt === 'string' ? corps.startsAt : undefined,
      chapters: Array.isArray(corps.chapters)
        ? (corps.chapters as Array<Record<string, unknown>>).map((c) => ({
            index: Number(c.index ?? 0),
            label: String(c.label ?? ''),
            startSeconds: Number(c.startSeconds ?? 0),
          }))
        : undefined,
    }
  }

  /**
   * Qui suit un cours en ce moment, et le temps cumule.
   *
   * Par le serveur, et ce n'est pas pour la securite — la vue `attendance_detail`
   * est en `security_invoker`, une lecture directe ne montrerait rien de plus.
   * C'est pour n'avoir **qu'un seul endroit ou les minutes s'additionnent** : le
   * site, l'application et tout ecran a venir lisent le meme chiffre, celui
   * qu'un parent regarde pour juger si l'abonnement sert.
   */
  async livePresence(): Promise<LivePresence[]> {
    // La reponse est une liste, pas un objet : `callApi` rend une forme
    // generique, donc le passage par `unknown` est explicite plutot que force.
    const corps = (await this.callApi('/live/presence')) as unknown
    const lignes = (Array.isArray(corps) ? corps : []) as Array<
      Record<string, unknown>
    >
    return lignes.map((ligne) => ({
      id: String(ligne.id ?? ''),
      sessionId: String(ligne.sessionId ?? ''),
      childName:
        typeof ligne.childName === 'string' ? ligne.childName : undefined,
      subjectName:
        typeof ligne.subjectName === 'string' ? ligne.subjectName : undefined,
      courseTitle:
        typeof ligne.courseTitle === 'string' ? ligne.courseTitle : undefined,
      minutes: Number(ligne.minutes ?? 0),
      startsAt: String(ligne.startsAt ?? ''),
    }))
  }

  async studyMinutes(options: { since?: string } = {}): Promise<StudySummary> {
    const requete = options.since
      ? `/live/study-minutes?since=${encodeURIComponent(options.since)}`
      : '/live/study-minutes'
    const corps = await this.callApi(requete)
    const liste = <T,>(valeur: unknown, forme: (l: Record<string, unknown>) => T) =>
      Array.isArray(valeur)
        ? valeur.map((l) => forme(l as Record<string, unknown>))
        : []
    return {
      since: String(corps.since ?? new Date().toISOString()),
      totalMinutes: Number(corps.totalMinutes ?? 0),
      sessions: Number(corps.sessions ?? 0),
      perChild: liste(corps.perChild, (l) => ({
        childName: String(l.childName ?? ''),
        minutes: Number(l.minutes ?? 0),
      })),
      perSubject: liste(corps.perSubject, (l) => ({
        subjectName: String(l.subjectName ?? ''),
        minutes: Number(l.minutes ?? 0),
      })),
    }
  }

  /** Les cours recurrents d'un professeur, brouillons compris. */
  async myLiveCourses(teacherId: string): Promise<LiveCourse[]> {
    const rows = await this.rows(() =>
      this.db
        .from('live_courses')
        .select(
          `id, teacher_id, price, seats, slot_ids, title, description, status,
           subjects ( id, name, code ),
           levels ( id, name, code, category )`,
        )
        .eq('teacher_id', teacherId)
        .order('created_at', { ascending: false }),
    )

    return rows.map((row) => {
      const matiere = nested(row, 'subjects')
      const niveau = nested(row, 'levels')
      return {
        id: text(row, 'id'),
        teacherId: text(row, 'teacher_id'),
        // Son propre nom ne sert a rien sur sa propre liste.
        teacherName: '',
        subject: matiere ? toRefItem(matiere) : { id: '', name: '' },
        level: niveau ? toRefItem(niveau) : { id: '', name: '' },
        title: maybeText(row, 'title'),
        description: maybeText(row, 'description'),
        price: typeof row.price === 'number' ? row.price : 0,
        seats: typeof row.seats === 'number' ? row.seats : 15,
        slotIds: Array.isArray(row.slot_ids)
          ? (row.slot_ids as unknown[]).map(String)
          : [],
        status: (row.status as LiveCourse['status']) ?? 'DRAFT',
      }
    })
  }

  /**
   * Declare un cours recurrent.
   *
   * Ecriture directe par PostgREST : la politique « son professeur le gere »
   * garantit qu'un professeur n'ecrit que ses cours. Pas besoin du serveur ici —
   * aucun argent ne bouge, et RLS exprime exactement la regle.
   */
  async createLiveCourse(input: LiveCourseInput): Promise<LiveCourse> {
    const { data: session } = await this.db.auth.getSession()
    const userId = session.session?.user.id
    if (!userId) throw new ApiError('Connectez-vous.', 401)

    const teacherId = await this.ownRowId('teachers', 'user_id', userId)
    if (!teacherId) throw new ApiError('Profil enseignant introuvable.', 403)

    const { data, error } = await this.db
      .from('live_courses')
      .insert({
        teacher_id: teacherId,
        subject_id: input.subjectId,
        level_id: input.levelId,
        title: input.title ?? null,
        description: input.description ?? null,
        price: input.price,
        slot_ids: input.slotIds,
        status: input.publish ? 'PUBLISHED' : 'DRAFT',
      })
      .select('id')
      .single()

    if (error || !data) this.fail(error ?? new Error('insertion refusée'))

    const miens = await this.myLiveCourses(teacherId)
    const cree = miens.find((c) => c.id === data!.id)
    if (!cree) throw new ApiError('Cours créé mais introuvable.', 500)
    return cree
  }

  /** S'inscrit a une seance. Passe par le serveur : place et prix. */
  async enrolInSession(
    sessionId: string,
    options: { childId?: string; method?: WalletMethod; payerPhone?: string } = {},
  ): Promise<EnrolmentResult> {
    const corps = await this.callApi('/live/enrol', {
      method: 'POST',
      body: { sessionId, ...options },
    })
    return {
      id: String(corps.id ?? ''),
      purchaseId: (corps.purchaseId as string) ?? undefined,
      status: (corps.status as EnrolmentResult['status']) ?? 'PENDING',
      amount: Number(corps.amount ?? 0),
      holdsMinutes:
        typeof corps.holdsMinutes === 'number' ? corps.holdsMinutes : undefined,
      alreadyEnrolled: Boolean(corps.alreadyEnrolled),
      payment: (corps.payment as EnrolmentResult['payment']) ?? 'none',
      redirectUrl: (corps.redirectUrl as string) ?? undefined,
      paymentError: (corps.paymentError as string) ?? undefined,
      sandbox: corps.sandbox === true,
    }
  }

  // --- Mises en avant -----------------------------------------------------

  /**
   * Les mises en avant actives.
   *
   * Publiques par la politique de 0007 (« promotion : visible quand elle est
   * active »). `views` n'est pas demande : le compteur appartient a
   * l'etablissement qui a paye, et le lire ici permettrait a un concurrent de
   * mesurer son audience.
   */
  async promotions(query: { city?: string } = {}): Promise<Promotion[]> {
    const rows = await this.rows(() =>
      this.db
        .from('promotions')
        .select(
          `id, institution_id, title, message,
           institutions ( name, city )`,
        )
        .eq('status', 'ACTIVE')
        .order('created_at', { ascending: false }),
    )

    return rows
      .map((row) => {
        const ecole = nested(row, 'institutions')
        return {
          id: text(row, 'id'),
          institutionId: text(row, 'institution_id'),
          institutionName: ecole
            ? (maybeText(ecole, 'name') ?? 'Établissement')
            : 'Établissement',
          city: ecole ? maybeText(ecole, 'city') : undefined,
          title: text(row, 'title'),
          message: maybeText(row, 'message'),
        }
      })
      .filter((promo) => !query.city || promo.city === query.city)
  }

  // --- Cours a domicile ---------------------------------------------------

  /**
   * Les offres de cours a domicile d'un enseignant.
   *
   * `active` est filtre ici en plus de la politique serveur : la politique
   * laisse l'enseignant voir les siennes, meme retirees, et la fiche publique
   * ne doit pas annoncer une offre qu'il a fermee — y compris quand c'est lui
   * qui regarde sa propre fiche.
   */
  async tutoringOffers(teacherId: string): Promise<TutoringOffer[]> {
    const rows = await this.rows(() =>
      this.db
        .from('tutoring_services')
        .select(
          `id, teacher_id, mode, hourly_rate, city, districts,
           availability_note, description, level_ids,
           subjects ( id, name, code )`,
        )
        .eq('teacher_id', teacherId)
        .eq('active', true),
    )

    const niveaux = await this.levels()
    return rows.map((row) => {
      const ids = Array.isArray(row.level_ids)
        ? (row.level_ids as unknown[]).map((v) => String(v))
        : []
      const matiere = nested(row, 'subjects')
      return {
        id: text(row, 'id'),
        teacherId: text(row, 'teacher_id'),
        subject: matiere
          ? toRefItem(matiere)
          : { id: '', name: 'Matière non précisée' },
        levels: niveaux.filter((l) => ids.includes(l.id)),
        mode:
          row.mode === 'AT_TEACHER' || row.mode === 'ONLINE'
            ? row.mode
            : ('AT_STUDENT' as const),
        hourlyRate:
          typeof row.hourly_rate === 'number' ? row.hourly_rate : undefined,
        city: maybeText(row, 'city'),
        districts: Array.isArray(row.districts)
          ? (row.districts as unknown[]).map((v) => String(v))
          : [],
        availabilityNote: maybeText(row, 'availability_note'),
        description: maybeText(row, 'description'),
      }
    })
  }

  // --- Cours video --------------------------------------------------------

  /**
   * La vitrine des cours en vente.
   *
   * `video_courses` est lisible publiquement quand `status = 'PUBLISHED'`
   * (migration 0007) : c'est une vitrine, et elle doit se lire sans compte.
   */
  async videoCourses(query: { subjectId?: string } = {}): Promise<VideoCourse[]> {
    const rows = await this.rows(() => {
      let request = this.db
        .from('video_courses')
        .select(
          `id, teacher_id, title, description, level_ids, price,
           subjects ( id, name, code ),
           teachers ( id, profiles ( first_name, last_name ) )`,
        )
        .eq('status', 'PUBLISHED')
      if (query.subjectId) request = request.eq('subject_id', query.subjectId)
      return request
    })
    if (rows.length === 0) return []

    // Le sommaire se compte en une requete pour toute la liste, pas une par
    // cours : une vitrine de vingt cours ferait vingt-et-un allers-retours.
    const chapitres = await this.rows(() =>
      this.db
        .from('course_chapters')
        .select('id, course_id')
        .in(
          'course_id',
          rows.map((r) => text(r, 'id')),
        ),
    )
    const elements =
      chapitres.length === 0
        ? []
        : await this.rows(() =>
            this.db
              .from('course_item_titles')
              .select('chapter_id, kind, duration_seconds')
              .in(
                'chapter_id',
                chapitres.map((c) => text(c, 'id')),
              ),
          )

    const coursDuChapitre = new Map<string, string>()
    for (const c of chapitres) {
      coursDuChapitre.set(text(c, 'id'), text(c, 'course_id'))
    }

    const compte = new Map<string, { chapitres: number; videos: number; duree: number }>()
    const pour = (courseId: string) => {
      const actuel = compte.get(courseId) ?? {
        chapitres: 0,
        videos: 0,
        duree: 0,
      }
      compte.set(courseId, actuel)
      return actuel
    }
    for (const c of chapitres) pour(text(c, 'course_id')).chapitres += 1
    for (const e of elements) {
      const courseId = coursDuChapitre.get(text(e, 'chapter_id'))
      if (courseId == null || e.kind !== 'VIDEO') continue
      const agrege = pour(courseId)
      agrege.videos += 1
      agrege.duree += typeof e.duration_seconds === 'number'
        ? e.duration_seconds
        : 0
    }

    const niveaux = await this.levels()
    return rows.map((row) => {
      const id = text(row, 'id')
      const agrege = compte.get(id) ?? { chapitres: 0, videos: 0, duree: 0 }
      const identite = nested(nested(row, 'teachers') ?? {}, 'profiles')
      const ids = text(row, 'level_ids')
        .split(',')
        .map((v) => v.trim())
        .filter((v) => v !== '')
      const prix = typeof row.price === 'number' ? row.price : 0

      return {
        id,
        title: text(row, 'title'),
        description: maybeText(row, 'description'),
        teacherId: text(row, 'teacher_id'),
        teacherName: identite
          ? `${maybeText(identite, 'first_name') ?? ''} ${
              maybeText(identite, 'last_name') ?? ''
            }`.trim()
          : '',
        subject: nested(row, 'subjects')
          ? toRefItem(nested(row, 'subjects') as Row)
          : undefined,
        levels: niveaux.filter((l) => ids.includes(l.id)),
        price: prix,
        // La commission est celle des constantes partagees : 20 %, calculee
        // sur le prix affiche et non en plus.
        net: Math.round(prix * 0.8),
        chapterCount: agrege.chapitres,
        videoCount: agrege.videos,
        totalSeconds: agrege.duree,
      }
    })
  }

  async videoCourse(id: string): Promise<VideoCourse | null> {
    const rows = await this.videoCourses()
    return rows.find((course) => course.id === id) ?? null
  }

  /**
   * Le sommaire d'un cours.
   *
   * **Passe par `course_item_titles` et jamais par `course_items`.** La table
   * porte `local_path` et `remote_url` ; la vue n'expose que le titre, le
   * genre et la duree. Lire la table marcherait pour un acheteur et rendrait
   * zero ligne a tous les autres — c'est-a-dire a ceux qu'on cherche a
   * convaincre.
   */
  async courseProgramme(courseId: string): Promise<CourseChapterPreview[]> {
    const chapitres = await this.rows(() =>
      this.db
        .from('course_chapters')
        .select('id, title, description, position')
        .eq('course_id', courseId)
        .order('position', { ascending: true }),
    )
    if (chapitres.length === 0) return []

    const elements = await this.rows(() =>
      this.db
        .from('course_item_titles')
        .select('id, chapter_id, kind, title, duration_seconds, position')
        .in(
          'chapter_id',
          chapitres.map((c) => text(c, 'id')),
        )
        .order('position', { ascending: true }),
    )

    const parChapitre = new Map<string, CourseItemPreview[]>()
    for (const e of elements) {
      const liste = parChapitre.get(text(e, 'chapter_id')) ?? []
      liste.push({
        id: text(e, 'id'),
        kind:
          e.kind === 'DOCUMENT' || e.kind === 'LINK'
            ? e.kind
            : ('VIDEO' as const),
        title: text(e, 'title'),
        durationSeconds:
          typeof e.duration_seconds === 'number' ? e.duration_seconds : undefined,
      })
      parChapitre.set(text(e, 'chapter_id'), liste)
    }

    return chapitres.map((c) => ({
      id: text(c, 'id'),
      title: text(c, 'title'),
      description: maybeText(c, 'description'),
      position: typeof c.position === 'number' ? c.position : 0,
      items: parChapitre.get(text(c, 'id')) ?? [],
    }))
  }

  // --- Enseignants --------------------------------------------------------

  private readonly teacherColumns = `
    id, user_id, headline, bio, city, years_experience, availability,
    identity_status, diploma_status,
    profiles ( id, first_name, last_name, photo_path ),
    teacher_subjects ( subjects ( id, name, code ) ),
    teacher_levels ( levels ( id, name, code, category ) ),
    teacher_certifications ( id, score, issued_at,
                             subjects ( id, name, code ),
                             levels ( id, name, code, category ) ),
    teacher_experiences ( id, institution_name, position, city,
                          start_date, end_date, verification_status )
  `

  async teacher(id: string): Promise<TeacherProfile | null> {
    const { data, error } = await this.db
      .from('teachers')
      .select(this.teacherColumns)
      .eq('id', id)
      .maybeSingle()
    if (error) this.fail(error)
    if (!data) return null

    const row = data as Row
    const [profile] = await this.withPublicIdentities(
      [row],
      [toTeacherProfile(row)],
    )
    return profile
  }

  /**
   * Remplit le nom et la photo depuis la vue publique quand la jointure sur
   * `profiles` n'a rien rendu.
   *
   * La politique « profil : lecture de soi » (migration 0002) ferme `profiles`
   * a tout le monde sauf son proprietaire. La fiche d'un enseignant est
   * pourtant publique depuis 0009, et cette migration a cree
   * `public_teacher_identities` — une vue `security_definer` qui n'expose que
   * le prenom, le nom, la photo et la ville — precisement pour ce cas. Rien ne
   * l'utilisait : les listes publiques se seraient affichees avec des cartes
   * sans nom, et le reflexe aurait ete d'ouvrir `profiles`, ce qui aurait
   * publie les telephones.
   *
   * Une requete separee plutot qu'une jointure sur la vue : PostgREST ne
   * devine pas toujours la relation d'une vue, et un `select` imbrique qui
   * echoue ferait tomber toute la liste. Un aller-retour de plus pour trente
   * fiches est moins cher qu'une liste vide.
   *
   * Un echec ici n'est pas fatal : on rend les fiches telles quelles. Sans
   * nom, elles restent utiles — matiere, ville, verification — alors qu'une
   * erreur ne rendrait rien du tout.
   */
  private async withPublicIdentities(
    rows: Row[],
    profiles: TeacherProfile[],
  ): Promise<TeacherProfile[]> {
    const manquants = profiles
      .map((profile, i) => ({ profile, userId: maybeText(rows[i], 'user_id') }))
      .filter((e) => e.profile.fullName === '' && e.userId != null)
    if (manquants.length === 0) return profiles

    const { data, error } = await this.db
      .from('public_teacher_identities')
      .select('id, first_name, last_name, photo_path, city')
      .in(
        'id',
        manquants.map((e) => e.userId as string),
      )
    if (error || !data) return profiles

    const parUtilisateur = new Map<string, Row>()
    for (const identite of data as Row[]) {
      const id = maybeText(identite, 'id')
      if (id != null) parUtilisateur.set(id, identite)
    }

    for (const { profile, userId } of manquants) {
      const identite = parUtilisateur.get(userId as string)
      if (!identite) continue
      profile.firstName = maybeText(identite, 'first_name') ?? ''
      profile.lastName = maybeText(identite, 'last_name') ?? ''
      profile.fullName = `${profile.firstName} ${profile.lastName}`.trim()
      profile.photoUrl = maybeText(identite, 'photo_path') ?? profile.photoUrl
      profile.city = profile.city ?? maybeText(identite, 'city')
    }
    return profiles
  }

  /**
   * Recherche d'enseignants, classee par pertinence.
   *
   * Le classement se fait ici, sur les lignes rendues, avec exactement la
   * meme fonction que le backend simule (`matching.ts`) : deux facons de
   * calculer le meme score finiraient par donner deux classements, et
   * personne ne saurait lequel croire.
   */
  async searchTeachers(query: TeacherSearchQuery): Promise<RankedCandidate[]> {
    // La matiere vit dans une table liee : `!inner` transforme la jointure
    // en filtre, donc en restriction cote serveur plutot qu'en tri d'un
    // tableau deja telecharge.
    const columns = query.subjectId
      ? this.teacherColumns.replace(
          'teacher_subjects ( subjects',
          'teacher_subjects!inner ( subjects',
        )
      : this.teacherColumns

    const rows = await this.rows(() => {
      let request = this.db.from('teachers').select(columns)
      if (query.subjectId) {
        request = request.eq('teacher_subjects.subject_id', query.subjectId)
      }
      if (query.city) request = request.eq('city', query.city)
      if (query.minExperience) {
        request = request.gte('years_experience', query.minExperience)
      }
      return request
    })

    // Le reste se filtre sur les lignes rendues : ces criteres portent sur
    // des relations deja chargees, et une seconde requete par critere
    // couterait plus que le tri lui-meme.
    const nommes = await this.withPublicIdentities(
      rows,
      rows.map(toTeacherProfile),
    )

    const shortlisted = nommes.filter((profile) => {
      if (query.certifiedOnly && profile.certifications.length === 0) {
        return false
      }
      if (
        query.minScore &&
        !profile.certifications.some((c) => c.score >= query.minScore!)
      ) {
        return false
      }
      /*
       * Le palier : filtre dur.
       *
       * Un professeur d'universite n'est pas une reponse moins bonne pour un
       * eleve de 9eme, c'est une mauvaise reponse. `scoreMatch` le ponderait
       * seulement, donc il restait dans la liste, plus bas.
       */
      if (
        query.stage &&
        !profile.levels.some((level) => level.cycle === query.stage)
      ) {
        return false
      }

      /*
       * La classe, en tolerant une declaration plus large.
       *
       * Un enseignant qui a coche « College » couvre la 9eme : exiger
       * l'identifiant exact l'ecartait alors qu'il enseigne exactement cela.
       */
      if (query.levelId) {
        const demande = profile.levels.find((l) => l.id === query.levelId)
        const cycle = demande?.cycle
        const couvre = profile.levels.some(
          (l) => l.id === query.levelId || (cycle && l.cycle === cycle),
        )
        if (!couvre) return false
      }
      return true
    })

    return shortlisted
      .map((profile) => ({
        profile,
        match: scoreMatch(requirementOf(query), profile),
      }))
      .sort((a, b) => b.match.value - a.match.value)
  }

  // --- Tests --------------------------------------------------------------

  /**
   * Les tests de competence.
   *
   * Sans `teacherId`, c'est le catalogue : la table `tests` est lisible par
   * tout le monde (politique « tests lisibles » de 0002), et les
   * certifications ne sont pas demandees — il n'y a personne dont ce serait le
   * resultat.
   */
  async tests(teacherId?: string): Promise<TestSummary[]> {
    const [rows, certifications] = await Promise.all([
      this.rows(() =>
        this.db
          .from('tests')
          .select(
            `id, title, question_count, duration_minutes, passing_score, rules,
             subjects ( id, name, code ),
             levels ( id, name, code, category )`,
          )
          .eq('active', true),
      ),
      this.rows(() =>
        this.db
          .from('teacher_certifications')
          .select(
            `id, score, issued_at, subject_id, level_id,
             subjects ( id, name, code ),
             levels ( id, name, code, category )`,
          )
          .eq('teacher_id', teacherId),
      ),
    ])

    // Une certification se rattache a un couple matiere/niveau, pas au test
    // qui l'a produite : c'est le couple qui reste vrai quand le test change
    // de version.
    const byPair = new Map(
      certifications.map((c) => [
        `${String(c.subject_id)}:${String(c.level_id)}`,
        toCertification(c),
      ]),
    )

    return rows.map((row) => {
      const subject = (row.subjects as Row | null)?.id
      const level = (row.levels as Row | null)?.id
      return toTestSummary(row, byPair.get(`${String(subject)}:${String(level)}`))
    })
  }

  /**
   * Les questions d'un test.
   *
   * Servies par la vue publique, qui ne contient pas `correct_key` : la
   * bonne reponse ne doit jamais atteindre le navigateur avant la
   * correction, sinon le test se passe en lisant la reponse dans l'onglet
   * reseau.
   */
  async testQuestions(testId: string): Promise<TestQuestion[]> {
    const rows = await this.rows(() =>
      this.db
        .from('test_questions_public')
        .select('id, statement, options, domain, position')
        .eq('test_id', testId)
        .order('position'),
    )
    return rows.map(toTestQuestion)
  }

  /**
   * Correction d'un test.
   *
   * Non implementee ici, et c'est deliberé : corriger dans le navigateur
   * suppose de lui avoir envoye les bonnes reponses, ce qui vide le test de
   * son sens. Il faut une fonction Postgres (`security definer`) ou une
   * fonction Edge qui lise `correct_key` cote serveur, ecrive la session et
   * rende le resultat.
   *
   * Tant qu'elle n'existe pas, le refus est explicite : rendre un score
   * calcule ici laisserait croire a une certification qui n'en est pas une.
   */
  async submitTest(
    _testId: string,
    _answers: Record<string, string>,
  ): Promise<TestResult> {
    throw new ApiError(
      'La correction des tests arrive avec la prochaine mise à jour du '
        + 'serveur. Vos réponses n’ont pas été enregistrées.',
      501,
    )
  }
}

/**
 * La recherche, traduite en exigence de classement.
 *
 * Exactement la forme qu'attend `scoreMatch`, et la meme que celle du
 * backend simule : deux facons de construire l'exigence donneraient deux
 * classements pour la meme recherche, et personne ne saurait lequel croire.
 */
const requirementOf = (query: TeacherSearchQuery) => ({
  subject: query.subjectId ? { id: query.subjectId, name: '' } : undefined,
  levels: query.levelId ? [{ id: query.levelId, name: '' }] : [],
  city: query.city,
  minExperience: query.minExperience ?? 0,
  requiresCertification: query.certifiedOnly ?? false,
})

/**
 * Construit le client si la configuration est presente.
 *
 * Les deux variables vont ensemble : une seule des deux est une
 * configuration a moitie faite, et se rabattre silencieusement sur les
 * donnees de demonstration ferait croire a un serveur branche.
 */
export function createSupabaseApi(
  url: string | undefined,
  anonKey: string | undefined,
): SupabaseApi | null {
  if (!url?.trim() || !anonKey?.trim()) return null
  return new SupabaseApi(
    createClient(url.trim(), anonKey.trim(), {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        // Le jeton revient dans l'URL apres un lien de connexion ; le
        // retirer de la barre d'adresse evite qu'il finisse dans un
        // historique ou un lien partage.
        detectSessionInUrl: true,
      },
    }),
  )
}
