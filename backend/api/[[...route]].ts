import { Hono, type Context } from 'hono'
import { cors } from 'hono/cors'
import { handle } from 'hono/vercel'
import { z } from 'zod'
import { parseOrigins, resolveOrigin } from './_lib/cors'
import { asService, asUser, bearer, isConfigured } from './_lib/db'
import { isAuditable, writeEvent, type AuditRow } from './_lib/audit'
import {
  deciderLot,
  deciderRetrait,
  RETRAITS_OUVERTS,
} from './_lib/operations'
import {
  Djomy,
  DjomyError,
  canTransition,
  purchaseStatusFor,
  toDjomyPhone,
} from './_lib/djomy'
import { Gemini, GeminiError, MODELS, coutUsd } from './_lib/gemini'
import { LiveKit, sessionFromRoom, type LiveKitEvent } from './_lib/livekit'
import { R2 } from './_lib/r2'
import { CloudflareStream } from './_lib/stream'
import {
  closingEntries,
  leaderboardFor,
  shopProgress,
  testForWeek,
  weekWindow,
} from './_lib/points'
import {
  occurrencesFor,
  slotById,
  SESSION_MINUTES,
  SLOTS,
} from './_lib/scheduling'
import {
  planWrite,
  type SyncPushItem,
  type SyncPushResult,
} from './_lib/sync'
import { hit, identify, ruleFor } from './_lib/ratelimit'
import {
  canSetEnrolmentStatus,
  completionRate,
  currentSchoolYear,
  pairKey,
  scoreMatch,
  scoreTest,
  trustScore,
  type Candidate,
  type EnrolmentActor,
  type EnrolmentStatus,
  type Requirement,
} from './_lib/domain'

export const config = { runtime: 'nodejs' }

/**
 * API REST versionnee (§47).
 *
 * Un seul service pour les deux clients : l'application Flutter et le site
 * web consomment exactement les memes routes. Les regles metier
 * (compatibilite, correction, confiance) sont evaluees ici et nulle part
 * ailleurs.
 */
const app = new Hono<{ Variables: { userId?: string } }>().basePath('/api/v1')

/** Jeton de l'appelant, transmis a Supabase pour que RLS s'applique. */
const tokenOf = (c: { req: { header: (k: string) => string | undefined } }) =>
  bearer(c.req.header('Authorization'))

/*
 * CORS — liste explicite, jamais `*`.
 *
 * Le site web est servi par la meme origine et n'a besoin de rien. CORS
 * n'existe ici que pour l'application mobile (pas d'en-tete Origin sur un
 * client natif) et les outils de test. `ALLOWED_ORIGINS` accepte une liste
 * separee par des virgules ; hors production, localhost est ajoute d'office.
 */
const corsPolicy = {
  allowed: parseOrigins(process.env.ALLOWED_ORIGINS),
  isProduction: process.env.NODE_ENV === 'production',
}

app.use(
  '*',
  cors({
    // La regle vit dans `_lib/cors.ts`, pure et eprouvee cas par cas : une
    // politique d'acces qu'on ne peut pas tester est une politique qu'on relit
    // en esperant.
    origin: (origin) => resolveOrigin(origin, corsPolicy),
    allowHeaders: ['Authorization', 'Content-Type'],
    credentials: true,
    maxAge: 600,
  }),
)

/*
 * Limitation de debit (§5). Placee avant tout le reste : une requete refusee
 * ne doit pas atteindre la base.
 *
 * Le compteur vit dans la memoire de l'instance — voir _lib/ratelimit.ts.
 */
app.use('*', async (c, next) => {
  const path = c.req.path.replace('/api/v1', '') || '/'
  if (path === '/health') return next()

  const verdict = hit(
    identify(tokenOf(c), c.req.raw.headers),
    ruleFor(c.req.method, path),
  )

  c.header('X-RateLimit-Limit', String(verdict.limit))
  c.header('X-RateLimit-Remaining', String(verdict.remaining))
  c.header('X-RateLimit-Reset', String(verdict.resetAt))

  if (!verdict.allowed) {
    c.header('Retry-After', String(verdict.retryAfter))
    return c.json(
      { error: `Trop de requetes. Reessayez dans ${verdict.retryAfter} seconde(s).` },
      429,
    )
  }
  return next()
})

/*
 * Qui appelle.
 *
 * --- Pourquoi ce bloc a manque ------------------------------------------
 *
 * `c.get('userId')` etait lu par sept routes — le jeton d'entree dans une
 * salle, l'achat d'un cours, l'inscription a une seance — et **n'etait pose
 * nulle part**. Toutes repondaient donc « Connectez-vous. » a un appelant
 * parfaitement authentifie. Le defaut ne se voyait pas : les tests du depot
 * lisent le source, et un deploiement sans Supabase configure echoue de la meme
 * facon pour une autre raison.
 *
 * --- Pourquoi une verification reelle et non la lecture du jeton ---------
 *
 * Le `sub` d'un JWT se lit sans cle, en trois lignes. Ce serait suffisant si
 * `userId` ne servait qu'a choisir un affichage — mais il sert a decider, et les
 * routes qui s'en servent passent ensuite par `asService()`, qui contourne RLS.
 * Un identifiant recopie d'un jeton non verifie donnerait a quiconque la salle,
 * les achats et les inscriptions de n'importe qui.
 *
 * On paie donc un aller-retour vers Supabase par requete authentifiee. Il est
 * entre deux serveurs, pas entre le telephone et nous : ce n'est pas la latence
 * que l'usager ressent.
 *
 * Un jeton absent ou invalide ne fait pas echouer la requete : les listes
 * publiques doivent rester lisibles sans compte, et c'est chaque route qui
 * exige un compte quand elle en a besoin.
 */
app.use('*', async (c, next) => {
  const path = c.req.path.replace('/api/v1', '') || '/'

  // Un webhook porte un `Authorization` qui n'est pas un jeton Supabase : celui
  // de LiveKit est signe avec le secret du projet video. Le soumettre a Supabase
  // ferait un appel perdu par evenement — seize par classe qui commence — pour
  // un refus garanti.
  if (path.includes('/webhook')) return next()

  const jeton = tokenOf(c)
  if (!jeton) return next()

  try {
    const { data } = await asUser(jeton).auth.getUser(jeton)
    if (data.user?.id) c.set('userId', data.user.id)
  } catch (cause) {
    // Un jeton expire est le cas courant, pas une anomalie : le client se
    // reconnectera. L'echec reste dans les journaux, l'appelant recoit le refus
    // de la route qu'il visait.
    console.warn('[auth] jeton non verifiable', cause)
  }
  return next()
})

/*
 * Audit (§5). Le journal observe ce qui s'est passe et ne peut pas empecher
 * une requete d'aboutir : l'ecriture part sans etre attendue.
 */
app.use('*', async (c, next) => {
  const startedAt = Date.now()
  // Le corps est lu ici parce qu'il n'est plus lisible apres le handler.
  const payload =
    c.req.method === 'POST' || c.req.method === 'PATCH'
      ? await c.req.raw.clone().json().catch(() => undefined)
      : undefined

  await next()

  const path = c.req.path.replace('/api/v1', '') || '/'
  if (!isAuditable(c.req.method, path)) return

  void writeEvent(
    async (row: AuditRow) => {
      const { error } = await asService().from('audit_events').insert(row)
      if (error) throw error
    },
    {
      method: c.req.method,
      path,
      status: c.res.status,
      userId: c.get('userId'),
      ip: c.req.header('x-forwarded-for')?.split(',')[0]?.trim(),
      userAgent: c.req.header('user-agent'),
      durationMs: Date.now() - startedAt,
      payload,
    },
  )
})

app.onError((error, c) => {
  // Le detail technique reste dans les journaux ; l'utilisateur recoit une
  // phrase utile, jamais une trace.
  // L'etat de configuration du serveur est une information interne : il
  // reste dans les journaux, l'utilisateur recoit une phrase utile.
  console.error('[api]', c.req.method, c.req.path, error)
  return c.json(
    {
      error:
        'Le serveur n’a pas pu traiter la demande. Reessayez dans un instant.',
    },
    500,
  )
})

app.get('/health', (c) =>
  c.json({
    status: 'ok',
    database: isConfigured ? 'configured' : 'missing',
    // Quelle caisse ce deploiement utilise. Lire « sandbox » sur la production,
    // ou l'inverse, est le defaut le plus couteux de cette integration : il ne
    // se voit nulle part ailleurs, et on ne le decouvre qu'en cherchant
    // l'argent.
    payments: djomy
      ? { configured: true, environment: djomy.environment }
      : { configured: false },
    // Ce qu'un deploiement sait faire, en une lecture. Decouvrir qu'une salle
    // ne s'ouvre pas au moment du premier cours coute une classe entiere.
    live: livekit ? { configured: true } : { configured: false },
    video: video
      ? { configured: true, provider: 'cloudflare-stream', signedUrls: true }
      : { configured: false },
    // L'enregistrement demande les trois a la fois : la salle, le depot, l'hote
    // video. Un seul manquant et la rediffusion n'existe pas — autant le lire
    // ici que le decouvrir une semaine plus tard, quand un eleve la reclame.
    recording: {
      // Les trois a la fois : la salle, le depot R2, l'hote video. Un seul
      // manquant et la rediffusion n'existe pas.
      configured: Boolean(livekit && recordings && video),
      storage: recordings ? 'configured' : 'missing',
    },
    // Les points de controle marchent sans Gemini ; seul le resume manque. Le
    // lire ici evite de chercher pourquoi la phrase n'arrive pas pendant un
    // cours.
    aiSummary: gemini ? 'configured' : 'missing',
  }),
)

// --- Referentiel (§8, §9) --------------------------------------------------

app.get('/subjects', async (c) => {
  const { data, error } = await asUser(tokenOf(c))
    .from('subjects')
    .select('id, name, code')
    .eq('active', true)
    .order('sort_order')
  if (error) throw error
  return c.json(data)
})

app.get('/levels', async (c) => {
  // `cycle` et non seulement `category` : PRIMAIRE / COLLEGE / LYCEE /
  // SUPERIEUR / DIPLOME sont les cinq paliers que les formulaires proposent, et
  // `category` n'en distingue que trois — elle met college et lycee dans le meme
  // « SECONDARY ». Sans le cycle, un enseignant de primaire se voit proposer
  // « Master 2 ».
  const { data, error } = await asUser(tokenOf(c))
    .from('levels')
    .select('id, name, code, category, cycle')
    .eq('active', true)
    .order('sort_order')
  if (error) throw error
  return c.json(data)
})

app.get('/levels/cities', async (c) => {
  const { data, error } = await asUser(tokenOf(c))
    .from('jobs')
    .select('city')
    .eq('status', 'PUBLISHED')
  if (error) throw error
  return c.json([...new Set((data ?? []).map((r) => r.city as string))].sort())
})

// --- Offres (§17) ----------------------------------------------------------

const JOB_FIELDS = `
  id, title, city, contract_type, description, salary_min, salary_max,
  salary_published, min_experience, requires_certification, level_ids,
  published_at, visibility, status,
  subject:subjects (id, name),
  institution:institutions (id, name, type, city, verification_status)
`

app.get('/jobs', async (c) => {
  const db = asUser(tokenOf(c))
  const { subjectId, city, contractType, query } = c.req.query()

  let request = db
    .from('jobs')
    .select(JOB_FIELDS)
    .eq('status', 'PUBLISHED')
    .eq('visibility', 'PUBLIC')
    .order('published_at', { ascending: false })

  if (subjectId) request = request.eq('subject_id', subjectId)
  if (city) request = request.eq('city', city)
  if (contractType) request = request.eq('contract_type', contractType)
  if (query) request = request.ilike('title', `%${query}%`)

  const { data, error } = await request
  if (error) throw error

  const levels = await levelLookup(db)
  return c.json((data ?? []).map((row) => shapeJob(row, levels)))
})

app.get('/jobs/:id', async (c) => {
  const db = asUser(tokenOf(c))
  const { data, error } = await db
    .from('jobs')
    .select(JOB_FIELDS)
    .eq('id', c.req.param('id'))
    .maybeSingle()
  if (error) throw error
  if (!data) return c.json({ error: 'Offre introuvable.' }, 404)

  const levels = await levelLookup(db)
  return c.json(shapeJob(data, levels))
})

// --- Enseignants (§21, §22) ------------------------------------------------

app.get('/teachers/:id', async (c) => {
  const profile = await loadTeacher(c.req.param('id'))
  if (!profile) return c.json({ error: 'Profil introuvable.' }, 404)
  return c.json(profile)
})

/**
 * Recherche classee (§21, §22).
 *
 * Le classement est calcule ici, avec le detail de chaque critere : un
 * etablissement doit pouvoir comprendre pourquoi un candidat passe devant un
 * autre.
 */
/*
 * --- Pourquoi un filtre par palier, et pas seulement par classe ----------
 *
 * Le filtre existait deja sur `levelId`, et il comparait des identifiants
 * exacts. Deux consequences, toutes deux visibles pour une famille :
 *
 *   * un professeur qui a declare « College » (le niveau de regroupement) sans
 *     cocher la 9eme etait **ecarte** pour un eleve de 9eme, alors qu'il
 *     enseigne exactement cela ;
 *   * a l'inverse, quand la famille ne donnait pas de classe precise — le
 *     primaire et « diplome » n'en ont pas —, aucun filtre ne s'appliquait et la
 *     liste proposait des professeurs d'universite a un eleve du primaire.
 *
 * `stage` compare le cycle (PRIMAIRE, COLLEGE, LYCEE, SUPERIEUR, DIPLOME), qui
 * est la granularite de la question posee a l'inscription. `levelId` reste
 * accepte pour affiner, mais ne rejette plus un enseignant dont la declaration
 * est plus large que la demande.
 */
app.get('/teachers', async (c) => {
  const {
    subjectId,
    levelId,
    stage,
    mode,
    city,
    certifiedOnly,
    minExperience,
    minScore,
  } = c.req.query()

  const db = asService()

  /*
   * Les candidats d'abord, les fiches ensuite.
   *
   * Cette route prenait tous les identifiants de la table, puis chargeait
   * chaque fiche dans une boucle `await` — six requetes par professeur, en
   * serie. Verifie le 17/10 sur le site en ligne : la requete ne revenait
   * jamais, 60 s sans statut. L'annuaire est l'onglet principal d'une
   * famille, d'un eleve, d'une ecole et d'un visiteur sans compte, et il
   * ne s'affichait pas.
   *
   * On reduit donc l'ensemble en SQL avant de charger quoi que ce soit, en
   * commencant par le filtre le plus selectif. Ces requetes ne lisent
   * qu'une colonne d'identifiants : elles coutent un aller-retour chacune,
   * quel que soit le nombre de professeurs.
   */
  /*
   * Le croisement se fait sur place, et non dans une fermeture.
   *
   * Ecrit d'abord avec une fonction `croiser` qui reaffectait `candidats` :
   * TypeScript ne suit pas l'effet d'une fermeture sur une variable locale,
   * croyait la variable encore `null` au point de jonction, et reduisait
   * `candidats !== null` a `never`. Le compilateur avait raison de s'en
   * plaindre — la lecture aussi est plus simple ainsi.
   */
  let candidats: string[] | null = null

  if (subjectId) {
    const { data: enseignants, error: souci } = await db
      .from('teacher_subjects')
      .select('teacher_id')
      .eq('subject_id', subjectId)
    if (souci) throw souci
    candidats = (enseignants ?? []).map((r) => String(r.teacher_id))
  }

  /*
   * Le mode d'enseignement demande : « a domicile » par defaut cote famille.
   *
   * Une famille d'eleve cherche quelqu'un qui vient a la maison. Lui
   * proposer d'abord des cours a distance ou « chez l'enseignant » lui fait
   * parcourir une liste dont la moitie ne lui convient pas, et c'est la
   * premiere liste qu'elle voit du produit.
   *
   * Le filtre passe par `tutoring_services` plutot que par la fiche : c'est
   * la que l'enseignant declare ou il se deplace, et une fiche ne le dit
   * pas.
   */
  if (mode) {
    const { data: offres, error: souci } = await db
      .from('tutoring_services')
      .select('teacher_id')
      .eq('mode', mode)
      .eq('active', true)
    if (souci) throw souci
    const duMode = (offres ?? []).map((o) => String(o.teacher_id))
    if (candidats === null) {
      candidats = duMode
    } else {
      const garde = new Set(duMode)
      candidats = candidats.filter((id) => garde.has(id))
    }
  }

  let request = db.from('teachers').select('id')
  if (city) request = request.eq('city', city)
  if (minExperience) {
    request = request.gte('years_experience', Number(minExperience))
  }
  if (candidats !== null) {
    // Aucun candidat ne survit aux filtres : inutile d'interroger la base.
    if (candidats.length === 0) return c.json([])
    request = request.in('id', candidats.slice(0, PAQUET_IDS))
  }

  /*
   * Un plafond, et il est assume.
   *
   * Les filtres qui demandent la fiche assemblee — le palier, la classe, le
   * score de certification — s'appliquent apres ce plafond : une liste tres
   * filtree peut donc etre plus courte qu'elle ne devrait. C'est le prix
   * d'une reponse, et une reponse incomplete vaut mieux qu'une requete qui
   * ne revient pas. Les filtres selectifs sont deja passes en SQL plus
   * haut, ce qui limite le cas aux recherches tres fines.
   */
  const PLAFOND = 120
  const demande = Number(c.req.query('limit') ?? 0)
  request = request.limit(
    demande > 0 ? Math.min(demande, PLAFOND) : PLAFOND,
  )

  const { data: rows, error } = await request
  if (error) throw error

  const need: Requirement = {
    subjectId: subjectId || null,
    levelIds: levelId ? [levelId] : [],
    city: city || null,
    minExperience: Number(minExperience ?? 0),
    requiresCertification: certifiedOnly === 'true',
  }

  // Toutes les fiches en six requetes, au lieu de six par professeur.
  const fiches = await chargerProfesseurs(
    (rows ?? []).map((row) => String(row.id)),
  )

  const results = []
  for (const row of rows ?? []) {
    const profile = fiches.get(String(row.id))
    if (!profile) continue

    if (subjectId && !profile.subjects.some((s) => s.id === subjectId)) continue

    // Le palier : un professeur qui n'enseigne a aucune classe de ce palier
    // n'est pas une reponse, c'est du bruit.
    if (stage && !profile.levels.some((l) => l.cycle === stage)) continue

    /*
     * La classe, en tolerant une declaration plus large.
     *
     * Un enseignant qui a coche « College » couvre la 9eme : exiger
     * l'identifiant exact l'ecartait. On accepte donc l'egalite OU le meme
     * cycle, ce qui est la relation que l'enseignant a voulu exprimer.
     */
    if (levelId) {
      const demande = profile.levels.find((l) => l.id === levelId)
      const cycleDemande = demande?.cycle
      const couvre = profile.levels.some(
        (l) => l.id === levelId || (cycleDemande && l.cycle === cycleDemande),
      )
      if (!couvre) continue
    }
    if (certifiedOnly === 'true' && profile.certifications.length === 0) continue
    if (
      minScore &&
      !profile.certifications.some((cert) => cert.score >= Number(minScore))
    ) {
      continue
    }

    results.push({ profile, match: scoreMatch(need, toCandidate(profile)) })
  }

  // Visibilite+ (§35) departage deux candidats de meme score, sans jamais
  // faire passer un profil moins pertinent devant un plus pertinent.
  results.sort((a, b) => {
    if (b.match.value !== a.match.value) return b.match.value - a.match.value
    return Number(b.profile.boosted) - Number(a.profile.boosted)
  })

  return c.json(results)
})

// --- Candidatures (§18) ----------------------------------------------------

app.get('/applications', async (c) => {
  const db = asUser(tokenOf(c))
  const { data, error } = await db
    .from('applications')
    .select(
      `id, status, applied_at, match_score, job:jobs (${JOB_FIELDS})`,
    )
    .order('applied_at', { ascending: false })
  if (error) throw error

  const levels = await levelLookup(db)
  return c.json(
    (data ?? []).map((row) => ({
      id: row.id,
      status: row.status,
      appliedAt: row.applied_at,
      matchScore: row.match_score,
      job: shapeJob(row.job, levels),
    })),
  )
})

const applySchema = z.object({
  jobId: z.string().min(1),
  note: z.string().max(2000).optional(),
})

// --- Visioconference et hebergement video -----------------------------------
//
// Deux fournisseurs, deux modules, et la meme regle que pour Djomy : rien
// d'autre dans le depot ne connait leur existence.
//
// `null` sans configuration, et c'est un mode de fonctionnement a part entiere :
// la grille s'affiche, on reserve une place, mais aucune salle ne s'ouvre. Les
// ecrans le disent au lieu de montrer un lecteur vide.

const livekitConfig = {
  url: (process.env.LIVEKIT_URL ?? '').trim(),
  apiKey: (process.env.LIVEKIT_API_KEY ?? '').trim(),
  apiSecret: (process.env.LIVEKIT_API_SECRET ?? '').trim(),
}
const livekit = LiveKit.isConfigured(livekitConfig)
  ? new LiveKit(livekitConfig)
  : null

/*
 * Cloudflare Stream : l'hebergement video.
 *
 * Remplace Bunny depuis le 03/10. La raison n'est pas le prix mais le reseau :
 * R2 et Stream sont chez le meme fournisseur, donc faire passer un
 * enregistrement de l'un a l'autre ne traverse pas Internet et ne coute pas
 * d'egress. Un fournisseur de moins, aussi : une facture, un jeton et une console
 * en moins.
 */
const streamConfig = {
  accountId: (process.env.CF_ACCOUNT_ID ?? '').trim(),
  apiToken: (process.env.CF_STREAM_API_TOKEN ?? '').trim(),
  customerCode: (process.env.CF_STREAM_CUSTOMER_CODE ?? '').trim(),
}
const video = CloudflareStream.isConfigured(streamConfig)
  ? new CloudflareStream(streamConfig)
  : null

/*
 * Le depot des enregistrements.
 *
 * Maillon intermediaire oblige : l'egress LiveKit ecrit vers du stockage
 * compatible S3, Cloudflare Stream
 * va chercher une video a une URL. Sans depot configure, **une seance a lieu
 * mais ne laisse pas de rediffusion** — ce qui est un mode acceptable, pas une
 * panne, et c'est pour cela que l'absence ne bloque pas l'ouverture d'une salle.
 */
/*
 * L'assistant Gemini.
 *
 * ⚠ OFFRE PAYANTE OBLIGATOIRE : en offre gratuite, Google se sert des donnees
 * envoyees pour ameliorer ses produits. Voir `shared/ai/models.json` et
 * `scripts/check-gemini.mjs`.
 *
 * `null` sans cle, et c'est un mode a part entiere : les points de controle
 * fonctionnent, le professeur voit ses decomptes, il n'a simplement pas la
 * phrase de synthese.
 */
const geminiConfig = { apiKey: (process.env.GEMINI_API_KEY ?? '').trim() }
const gemini = Gemini.isConfigured(geminiConfig) ? new Gemini(geminiConfig) : null

const recordingsConfig = {
  endpoint: (process.env.R2_ENDPOINT ?? '').trim(),
  bucket: (process.env.R2_RECORDINGS_BUCKET ?? '').trim(),
  accessKey: (process.env.R2_ACCESS_KEY_ID ?? '').trim(),
  secret: (process.env.R2_SECRET_ACCESS_KEY ?? '').trim(),
  // `auto` chez R2, toujours. La variable existe pour un service compatible S3
  // qui exigerait une vraie region.
  region: (process.env.R2_REGION ?? 'auto').trim(),
}
const recordings = R2.isConfigured(recordingsConfig)
  ? new R2(recordingsConfig)
  : null

/*
 * Plus d'avertissement « les URL ne sont pas signees ».
 *
 * Chez Bunny, la signature dependait d'une option de zone qu'on pouvait oublier
 * d'activer, et le serveur journalisait une mise en garde a chaque demarrage.
 * Stream pose `requireSignedURLs` **a l'ingestion de chaque video** : il n'y a
 * plus de reglage a oublier, donc plus rien a avertir.
 */

/**
 * Le jeton d'entree dans une salle.
 *
 * Tout le controle d'acces est ici, parce que LiveKit n'a pas de notion de
 * compte : il fait confiance au jeton que nous signons. Quatre verifications, et
 * aucune n'est superflue :
 *
 *  1. le compte existe et porte une fiche (famille ou professeur) ;
 *  2. l'eleve est **inscrit et paye** — une place retenue sans paiement
 *     n'ouvre pas la salle ;
 *  3. on est dans la fenetre de la seance : un jeton emis trois jours avant
 *     serait une porte ouverte trois jours ;
 *  4. le role decide des droits : le professeur publie, l'eleve ecoute jusqu'a
 *     ce qu'on lui donne la parole.
 */
app.post('/live/sessions/:id/token', async (c) => {
  if (!livekit) {
    return c.json({ error: 'La visioconference n’est pas configuree.' }, 503)
  }

  const sessionId = c.req.param('id')
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const service = asService()
  const { data: seance } = await service
    .from('live_sessions')
    .select(
      'id, starts_at, duration_minutes, status, recording_status, live_courses ( teacher_id )',
    )
    .eq('id', sessionId)
    .maybeSingle()

  if (!seance) return c.json({ error: 'Seance introuvable.' }, 404)
  if (seance.status === 'CANCELLED') {
    return c.json({ error: 'Cette seance est annulee.' }, 409)
  }

  // La fenetre : quinze minutes avant le debut, et jusqu'a trente minutes apres
  // la fin. Avant, il n'y a rien a rejoindre ; apres, la salle est fermee et un
  // jeton valable n'aurait plus d'objet.
  const debut = new Date(String(seance.starts_at)).getTime()
  const duree = Number(seance.duration_minutes ?? 90) * 60_000
  const ouverture = debut - 15 * 60_000
  const fermeture = debut + duree + 30 * 60_000
  const maintenant = Date.now()

  if (maintenant < ouverture) {
    return c.json(
      {
        error: 'La salle ouvre quinze minutes avant le debut.',
        opensAt: new Date(ouverture).toISOString(),
      },
      409,
    )
  }
  if (maintenant > fermeture) {
    return c.json({ error: 'Cette seance est terminee.' }, 409)
  }

  const lie = seance.live_courses as unknown
  const cours = (Array.isArray(lie) ? lie[0] : lie) as Record<string, unknown> | null

  // Le professeur du cours ?
  const { data: prof } = await service
    .from('teachers')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()
  const estLeProfesseur =
    prof != null && cours != null && prof.id === cours.teacher_id

  /*
   * La place utilisee pour entrer.
   *
   * Un compte famille peut avoir **deux places sur la meme seance** — deux
   * enfants, deux tablettes, deux paiements. L'identite LiveKit etant la place
   * et non le compte, il faut savoir laquelle : entrer avec la place du grand
   * frere deconnecterait le grand frere.
   *
   * Une seule place : on la prend, le client n'a rien a demander. Plusieurs : on
   * rend la liste et l'ecran demande « qui suit le cours ? ». Choisir a sa place
   * serait choisir mal une fois sur deux.
   */
  let place: { id: string; childName: string | null } | null = null

  if (!estLeProfesseur) {
    const { data: parent } = await service
      .from('parents')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle()
    if (!parent) {
      return c.json({ error: 'Ce compte ne suit pas cette seance.' }, 403)
    }

    const { data: inscriptions } = await service
      .from('session_enrolments')
      .select('id, child_id, children ( first_name )')
      .eq('session_id', sessionId)
      .eq('parent_id', parent.id as string)
      .eq('status', 'CONFIRMED')

    const places = (inscriptions ?? []).map((ligne) => {
      const enfant = ligne.children as unknown
      const fiche = (Array.isArray(enfant) ? enfant[0] : enfant) as Record<
        string,
        unknown
      > | null
      return {
        id: String(ligne.id),
        childName: (fiche?.first_name as string) ?? null,
      }
    })

    if (places.length === 0) {
      // Une place retenue sans paiement expire au bout de vingt minutes. Ouvrir
      // la salle sur une reservation non payee reviendrait a donner le cours.
      return c.json({ error: 'Votre place n’est pas encore payee.' }, 403)
    }

    const demande = await c.req.json().catch(() => ({}))
    const voulue =
      typeof (demande as Record<string, unknown>).enrolmentId === 'string'
        ? String((demande as Record<string, unknown>).enrolmentId)
        : null

    if (voulue) {
      place = places.find((p) => p.id === voulue) ?? null
      if (!place) {
        return c.json({ error: 'Cette place n’est pas la votre.' }, 403)
      }
    } else if (places.length === 1) {
      place = places[0]
    } else {
      return c.json(
        {
          error: 'Plusieurs places sur cette seance : indiquez qui entre.',
          choices: places.map((p) => ({ enrolmentId: p.id, childName: p.childName })),
        },
        409,
      )
    }
  }

  const { data: profil } = await service
    .from('profiles')
    .select('first_name, last_name')
    .eq('id', userId)
    .maybeSingle()

  const nom = [profil?.first_name, profil?.last_name]
    .filter((p) => typeof p === 'string' && p !== '')
    .join(' ')

  const jeton = await livekit.joinToken({
    sessionId,
    // La place, ou l'enseignant. Jamais le compte : voir `LiveKit.identityFor`.
    identity: estLeProfesseur
      ? LiveKit.identityFor({ role: 'teacher', teacherId: String(prof!.id) })
      : LiveKit.identityFor({ role: 'student', enrolmentId: place!.id }),
    // Le prenom de l'enfant quand il est connu : dans une classe de quinze, lire
    // « Fatoumata » plutot que le nom du compte du parent est ce qui permet au
    // professeur d'appeler quelqu'un.
    name: (!estLeProfesseur ? place!.childName : null) || nom || 'Participant',
    role: estLeProfesseur ? 'teacher' : 'student',
    // Jusqu'a la fermeture de la fenetre, pas plus : un jeton qui traine est une
    // porte ouverte.
    ttlSeconds: Math.max(Math.ceil((fermeture - maintenant) / 1000), 300),
  })

  return c.json({
    token: jeton.token,
    url: jeton.url,
    room: jeton.room,
    role: estLeProfesseur ? 'teacher' : 'student',
    enrolmentId: place?.id ?? null,
    // **Dire qu'on enregistre.** Quinze eleves mineurs filmes pendant 90
    // minutes : qu'ils le sachent n'est pas une option d'affichage. L'ecran le
    // montre a tout le monde, professeur compris.
    recording: seance.recording_status ?? null,
  })
})

/*
 * --- La vie d'une seance, du cote serveur --------------------------------
 *
 *   ouverture ──▶ LIVE, opened_at, egress demarre
 *       │
 *       │  pendant : les webhooks LiveKit ecrivent la presence
 *       ▼
 *   fermeture ──▶ DONE, closed_at, egress arrete, salle videe
 *       │
 *       ▼
 *   egress_ended ──▶ URL signee de R2 ──▶ Stream ingere le fichier
 *       │
 *       ▼
 *   rediffusion lisible par les inscrits
 *
 * Deux principes tiennent cette chaine :
 *
 *   * **le professeur declare, le serveur constate.** L'ouverture est un geste
 *     du professeur ; la presence, la fin de l'egress et le depart d'un eleve
 *     sont constates par LiveKit. Rien de ce qui compte n'est declare par un
 *     client.
 *   * **chaque etape est rejouable.** Un webhook arrive deux fois, un
 *     professeur clique deux fois sur « ouvrir », une connexion tombe au milieu
 *     d'un transfert : aucune de ces situations ne doit produire deux
 *     enregistrements ni deux lignes de presence.
 */

/** La cle de l'objet d'une seance dans le depot. */
const recordingKey = (sessionId: string) => `seances/${sessionId}.mp4`

/**
 * La seance et son professeur, pour les routes qui exigent d'etre le professeur.
 *
 * Rend `null` plutot que de lever : les appelants repondent tous par un code
 * HTTP different selon ce qui manque, et une exception les en empecherait.
 */
async function sessionForTeacher(
  sessionId: string,
  userId: string,
): Promise<
  | { ok: true; session: Record<string, unknown>; teacherId: string }
  | { ok: false; status: 403 | 404; error: string }
> {
  const service = asService()
  const { data: seance } = await service
    .from('live_sessions')
    .select(
      'id, starts_at, duration_minutes, status, opened_at, closed_at, egress_id, recording_video_id, recording_status, live_courses ( id, teacher_id, title, subject_id )',
    )
    .eq('id', sessionId)
    .maybeSingle()

  if (!seance) return { ok: false, status: 404, error: 'Seance introuvable.' }

  const cours = one(seance.live_courses as never) as
    | Record<string, unknown>
    | undefined

  const { data: prof } = await service
    .from('teachers')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()

  if (!prof || !cours || prof.id !== cours.teacher_id) {
    return { ok: false, status: 403, error: 'Cette seance n’est pas la votre.' }
  }
  return { ok: true, session: seance, teacherId: String(prof.id) }
}

/**
 * Le professeur ouvre la salle.
 *
 * **Idempotent, et c'est le point.** Un professeur dont le navigateur plante
 * rouvre la page et reclique : la seance est deja `LIVE` et l'egress tourne
 * toujours — il tourne sur le serveur LiveKit, pas dans son navigateur. Demarrer
 * un second egress ecrirait sur la meme cle et perdrait la premiere moitie du
 * cours. La reponse est donc la meme qu'au premier appel, sans rien recommencer.
 */
app.post('/live/sessions/:id/open', async (c) => {
  if (!livekit) {
    return c.json({ error: 'La visioconference n’est pas configuree.' }, 503)
  }
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const acces = await sessionForTeacher(c.req.param('id'), userId)
  if (!acces.ok) return c.json({ error: acces.error }, acces.status)

  const seance = acces.session
  const sessionId = String(seance.id)
  if (seance.status === 'CANCELLED') {
    return c.json({ error: 'Cette seance est annulee.' }, 409)
  }

  // Meme fenetre que pour le jeton d'entree : ouvrir trois jours avant n'aurait
  // pas de sens, et la valeur unique evite qu'un professeur puisse ouvrir une
  // salle que ses eleves ne peuvent pas rejoindre.
  const debut = new Date(String(seance.starts_at)).getTime()
  const duree = Number(seance.duration_minutes ?? 90) * 60_000
  const maintenant = Date.now()
  if (maintenant < debut - 15 * 60_000) {
    return c.json(
      {
        error: 'La salle ouvre quinze minutes avant le debut.',
        opensAt: new Date(debut - 15 * 60_000).toISOString(),
      },
      409,
    )
  }
  if (maintenant > debut + duree + 30 * 60_000) {
    return c.json({ error: 'Cette seance est terminee.' }, 409)
  }

  const service = asService()
  const dejaOuverte = seance.opened_at != null
  let egressId = (seance.egress_id as string | null) ?? null
  let etatEnregistrement =
    (seance.recording_status as string | null) ?? null

  if (!egressId && recordings && video) {
    // L'enregistrement est un confort, pas la seance. Si l'egress refuse de
    // demarrer, le cours a lieu quand meme : l'erreur est journalisee et la
    // salle s'ouvre. L'inverse — refuser d'ouvrir parce qu'on ne peut pas
    // enregistrer — annulerait un cours paye pour une rediffusion.
    try {
      egressId = await livekit.startRecording({
        sessionId,
        s3: recordings.egressTarget,
        filename: recordingKey(sessionId),
      })
      etatEnregistrement = 'RECORDING'
    } catch (cause) {
      console.error('[live] egress non demarre', sessionId, cause)
      etatEnregistrement = 'FAILED'
    }
  }

  await service
    .from('live_sessions')
    .update({
      status: 'LIVE',
      opened_at: dejaOuverte ? seance.opened_at : new Date().toISOString(),
      room_name: LiveKit.roomFor(sessionId),
      egress_id: egressId,
      recording_status: etatEnregistrement,
      updated_at: new Date().toISOString(),
    })
    .eq('id', sessionId)

  return c.json({
    status: 'LIVE',
    alreadyOpen: dejaOuverte,
    recording: etatEnregistrement,
  })
})

/**
 * Le professeur ferme la salle.
 *
 * Trois gestes dans cet ordre, et l'ordre compte : **arreter l'egress avant de
 * vider la salle**. Supprimer la salle d'abord ferait finir l'egress sur une
 * salle vide, et selon le moment le fichier pourrait se terminer sur quelques
 * secondes de noir.
 */
app.post('/live/sessions/:id/close', async (c) => {
  if (!livekit) {
    return c.json({ error: 'La visioconference n’est pas configuree.' }, 503)
  }
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const acces = await sessionForTeacher(c.req.param('id'), userId)
  if (!acces.ok) return c.json({ error: acces.error }, acces.status)

  const seance = acces.session
  const sessionId = String(seance.id)
  const egressId = (seance.egress_id as string | null) ?? null
  let etat = (seance.recording_status as string | null) ?? null

  if (egressId && etat === 'RECORDING') {
    try {
      await livekit.stopRecording(egressId)
      // `TRANSFERRING` et non `READY` : le fichier existe, mais il n'est pas
      // encore chez Stream. C'est le webhook `egress_ended` qui declenchera
      // copie, et ce peut etre une minute plus tard.
      etat = 'TRANSFERRING'
    } catch (cause) {
      console.error('[live] egress non arrete', sessionId, cause)
    }
  }

  try {
    await livekit.closeRoom(sessionId)
  } catch (cause) {
    // Une salle deja vide n'existe plus chez LiveKit : l'erreur est normale et
    // ne doit pas empecher la seance d'etre marquee terminee.
    console.warn('[live] salle deja fermee', sessionId, cause)
  }

  await closeDanglingAttendance(sessionId)

  await asService()
    .from('live_sessions')
    .update({
      status: 'DONE',
      closed_at: new Date().toISOString(),
      recording_status: etat,
      updated_at: new Date().toISOString(),
    })
    .eq('id', sessionId)

  return c.json({ status: 'DONE', recording: etat })
})

/**
 * Ferme les lignes de presence restees ouvertes sur une seance.
 *
 * Appelee a la fermeture et sur `room_finished`. Une ligne ouverte pour toujours
 * ne compte jamais ses minutes, et le temps de cours du parent resterait a zero
 * pour un cours entierement suivi.
 */
async function closeDanglingAttendance(sessionId: string): Promise<number> {
  const service = asService()
  const { data: ouvertes } = await service
    .from('session_attendance')
    .select('id, joined_at')
    .eq('session_id', sessionId)
    .is('left_at', null)

  const fin = new Date()
  for (const ligne of ouvertes ?? []) {
    await service
      .from('session_attendance')
      .update({
        left_at: fin.toISOString(),
        minutes: minutesBetween(String(ligne.joined_at), fin),
      })
      .eq('id', ligne.id as string)
  }
  return (ouvertes ?? []).length
}

/** Minutes entieres entre deux instants, jamais negatives. */
function minutesBetween(depuis: string, jusqu: Date): number {
  const debut = new Date(depuis).getTime()
  if (!Number.isFinite(debut)) return 0
  return Math.max(0, Math.floor((jusqu.getTime() - debut) / 60_000))
}

/**
 * Les webhooks LiveKit — la source de verite de la presence.
 *
 * Signature verifiee avant toute lecture du corps, et **reponse 200 meme sur un
 * evenement qu'on ignore** : un webhook non acquitte est reessaye, et une file
 * de reessais sur des evenements qui ne nous interessent pas finirait par
 * retarder ceux qui comptent.
 */
app.post('/live/webhooks/livekit', async (c) => {
  if (!livekit) return c.json({ error: 'Non configure.' }, 503)

  const rawBody = await c.req.text()
  let evenement: LiveKitEvent
  try {
    evenement = await livekit.verifyWebhook(
      c.req.header('Authorization'),
      rawBody,
    )
  } catch {
    // Aucun detail : un message precis aiderait a fabriquer une signature
    // valable.
    return c.json({ error: 'Signature invalide.' }, 401)
  }

  const sessionId = sessionFromRoom(evenement.room?.name)
  const service = asService()

  switch (evenement.event) {
    case 'participant_joined': {
      if (!sessionId) break
      const identite = evenement.participant?.identity ?? ''
      const qui = LiveKit.parseIdentity(identite)
      if (!qui) break

      const userId = await accountBehind(qui)
      if (!userId) break

      // Une reconnexion est un nouveau `participant_joined`. On ferme la ligne
      // precedente avant d'ouvrir, sinon l'index unique refuse l'insertion et la
      // presence du reste du cours est perdue.
      const cle = qui.role === 'student' ? qui.enrolmentId : null
      const fermeture = service
        .from('session_attendance')
        .update({ left_at: new Date().toISOString() })
        .eq('session_id', sessionId)
        .is('left_at', null)
      await (cle
        ? fermeture.eq('enrolment_id', cle)
        : fermeture.eq('user_id', userId).is('enrolment_id', null))

      await service.from('session_attendance').insert({
        session_id: sessionId,
        user_id: userId,
        enrolment_id: cle,
        joined_at: new Date().toISOString(),
      })
      break
    }

    case 'participant_left': {
      if (!sessionId) break
      const qui = LiveKit.parseIdentity(evenement.participant?.identity ?? '')
      if (!qui) break

      const requete = service
        .from('session_attendance')
        .select('id, joined_at')
        .eq('session_id', sessionId)
        .is('left_at', null)

      const { data: lignes } = await (qui.role === 'student'
        ? requete.eq('enrolment_id', qui.enrolmentId)
        : requete.is('enrolment_id', null))

      const fin = new Date()
      for (const ligne of lignes ?? []) {
        await service
          .from('session_attendance')
          .update({
            left_at: fin.toISOString(),
            minutes: minutesBetween(String(ligne.joined_at), fin),
          })
          .eq('id', ligne.id as string)
      }
      break
    }

    case 'room_finished': {
      if (!sessionId) break
      await closeDanglingAttendance(sessionId)
      // Si le professeur a ferme son onglet sans cliquer sur « terminer », la
      // salle finit quand meme : la seance doit basculer en `DONE`, sinon elle
      // reste `LIVE` dans la grille de tout le monde.
      const { data: seance } = await service
        .from('live_sessions')
        .select('status, closed_at')
        .eq('id', sessionId)
        .maybeSingle()
      if (seance && seance.status !== 'CANCELLED' && seance.closed_at == null) {
        await service
          .from('live_sessions')
          .update({
            status: 'DONE',
            closed_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .eq('id', sessionId)
      }
      break
    }

    case 'egress_ended': {
      await handleEgressEnded(evenement)
      break
    }

    default:
      break
  }

  return c.json({ received: true })
})

/**
 * Le compte derriere une identite LiveKit.
 *
 * Une place mene a son parent, un professeur a son compte. C'est la colonne
 * `user_id` de la presence : savoir *qui s'est connecte*, en plus de *quelle
 * place* a ete utilisee.
 */
async function accountBehind(
  qui:
    | { role: 'student'; enrolmentId: string }
    | { role: 'teacher'; teacherId: string },
): Promise<string | null> {
  const service = asService()
  if (qui.role === 'teacher') {
    const { data } = await service
      .from('teachers')
      .select('user_id')
      .eq('id', qui.teacherId)
      .maybeSingle()
    return (data?.user_id as string | null) ?? null
  }
  const { data } = await service
    .from('session_enrolments')
    .select('parents ( user_id )')
    .eq('id', qui.enrolmentId)
    .maybeSingle()
  const parent = one(data?.parents as never) as Record<string, unknown> | undefined
  return (parent?.user_id as string | null) ?? null
}

/**
 * L'egress a fini : faire passer le fichier de R2 a Cloudflare Stream.
 *
 * **Pourquoi une URL signee de deux heures.** Stream telecharge le fichier depuis
 * ses serveurs ; il lui faut donc une adresse accessible depuis l'extérieur. Un
 * depot public rendrait chaque enregistrement telechargeable par qui devine un
 * nom de fichier — et un nom de fichier derive d'un identifiant de seance se
 * devine. Deux heures suffisent largement pour 90 minutes de video, et passe ce
 * delai le lien ne vaut plus rien.
 */
async function handleEgressEnded(evenement: LiveKitEvent): Promise<void> {
  const info = evenement.egressInfo ?? {}
  const egressId = info.egress_id ?? info.egressId
  if (!egressId) return

  const service = asService()
  const { data: seance } = await service
    .from('live_sessions')
    .select('id, recording_status, recording_video_id, live_courses ( title )')
    .eq('egress_id', egressId)
    .maybeSingle()
  if (!seance) return

  const sessionId = String(seance.id)

  // Rejouabilite : LiveKit reessaie un webhook non acquitte, et une deuxieme
  // copie creerait une deuxieme video facturee chez Stream.
  if (seance.recording_video_id) return

  if (!recordings || !video) {
    await service
      .from('live_sessions')
      .update({ recording_status: 'FAILED' })
      .eq('id', sessionId)
    return
  }

  if (info.status === 'EGRESS_FAILED' || info.status === 'EGRESS_ABORTED') {
    console.error('[live] egress en echec', sessionId, info.status)
    await service
      .from('live_sessions')
      .update({ recording_status: 'FAILED' })
      .eq('id', sessionId)
    return
  }

  try {
    const cours = one(seance.live_courses as never) as
      | Record<string, unknown>
      | undefined
    const titre = `${(cours?.title as string) ?? 'Cours en direct'} — ${new Date().toLocaleDateString('fr-FR')}`

    /*
     * Une seule demande au lieu de deux.
     *
     * Bunny demandait de creer la video puis de lui dire ou aller la chercher :
     * entre les deux appels, une video vide existait, et un echec du second
     * laissait une coquille a nettoyer. Stream prend l'URL d'emblee.
     *
     * L'URL pre-signee vaut deux heures — le temps de l'ingestion — puis ne vaut
     * plus rien. Le depot R2 reste prive : un dossier public rendrait chaque
     * seance de 90 minutes telechargeable par qui devine un nom de fichier.
     */
    const source = await recordings.presign({
      method: 'GET',
      key: recordingKey(sessionId),
      expiresInSeconds: 2 * 3600,
    })
    const videoId = await video.ingestFromUrl({ url: source, name: titre })

    await service
      .from('live_sessions')
      .update({
        recording_video_id: videoId,
        // Toujours `TRANSFERRING` : Stream a accepte la demande, il n'a pas fini
        // de transcoder en HLS multi-debits. C'est
        // `/live/sessions/:id/replay` qui constatera la disponibilite, au moment
        // ou quelqu'un la demande.
        recording_status: 'TRANSFERRING',
        updated_at: new Date().toISOString(),
      })
      .eq('id', sessionId)
  } catch (cause) {
    console.error('[live] transfert vers Stream echoue', sessionId, cause)
    await service
      .from('live_sessions')
      .update({ recording_status: 'FAILED' })
      .eq('id', sessionId)
  }
}

/*
 * --- Les points de controle d'une seance ----------------------------------
 *
 *   le professeur ouvre le module N ──▶ 3 boutons chez les eleves, 10 s
 *                                              │
 *                                              ▼
 *                  le professeur ferme ──▶ decompte ──▶ resume par Gemini
 *                                              │
 *                                              ▼
 *                        « 4 eleves sur 15 n'ont pas suivi : reprendre »
 *
 * C'est ce qui distingue ce format d'une video. Dans une classe de quinze
 * adolescents, personne ne dit « je n'ai pas compris » — trois boutons et dix
 * secondes, si.
 *
 * Deux regles tiennent la chose :
 *
 *   * **anonyme pour la classe, nominatif pour le seul professeur.** Un eleve
 *     qui sait que sa reponse s'affiche devant quatorze camarades repond
 *     « oui », et le point de controle ne sert plus a rien ;
 *   * **le resume est une aide, pas une note.** Il n'entre dans aucun score, et
 *     Gemini ne recoit **aucune donnee personnelle** : une matiere, un numero de
 *     module, trois nombres.
 */

/** Le module en cours et son titre, tels que le professeur les declare. */
const checkpointSchema = z.object({
  moduleIndex: z.number().int().min(0).max(3),
  // Jamais un nom de personne : ce champ part dans l'invite envoyee a Google.
  topic: z.string().max(120).optional(),
})

const answerSchema = z.object({
  answer: z.enum(['YES', 'NO', 'PARTLY']),
})

/**
 * Le professeur ouvre le point de controle d'un module.
 *
 * **Rejouable.** Un professeur qui clique deux fois, ou dont le navigateur a
 * plante, retrouve le meme point de controle : la contrainte
 * `unique (session_id, module_index)` l'impose, et en ouvrir un second
 * scinderait les reponses en deux decomptes dont aucun ne serait vrai.
 */
app.post('/live/sessions/:id/checkpoints', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const parsed = checkpointSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) {
    return c.json({ error: 'Module non precise (0 a 3).' }, 400)
  }

  const acces = await sessionForTeacher(c.req.param('id'), userId)
  if (!acces.ok) return c.json({ error: acces.error }, acces.status)

  const sessionId = String(acces.session.id)
  const service = asService()

  // Deja ouvert ? On le rend tel quel. Le professeur voit le meme panneau, et
  // les reponses deja donnees ne sont pas perdues.
  const { data: existant } = await service
    .from('session_checkpoints')
    .select('id, module_index, opened_at, closed_at')
    .eq('session_id', sessionId)
    .eq('module_index', parsed.data.moduleIndex)
    .maybeSingle()

  if (existant) {
    return c.json({
      id: existant.id,
      moduleIndex: existant.module_index,
      openedAt: existant.opened_at,
      closedAt: existant.closed_at,
      reopened: true,
    })
  }

  const { data: cree, error } = await service
    .from('session_checkpoints')
    .insert({
      session_id: sessionId,
      module_index: parsed.data.moduleIndex,
    })
    .select('id, module_index, opened_at')
    .single()

  if (error || !cree) {
    return c.json({ error: 'Le point de controle n’a pas pu s’ouvrir.' }, 500)
  }

  return c.json({
    id: cree.id,
    moduleIndex: cree.module_index,
    openedAt: cree.opened_at,
    closedAt: null,
    reopened: false,
  })
})

/**
 * Un eleve repond.
 *
 * Trois verifications, et la troisieme est celle qu'on oublie : la place est la
 * sienne, elle est **payee**, et le vote est **encore ouvert**. Repondre a un
 * module ferme depuis une heure rendrait faux le resume deja lu par le
 * professeur.
 */
app.post('/live/checkpoints/:id/answer', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const parsed = answerSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) {
    return c.json({ error: 'Reponse attendue : YES, NO ou PARTLY.' }, 400)
  }

  const checkpointId = c.req.param('id')
  const service = asService()

  const { data: point } = await service
    .from('session_checkpoints')
    .select('id, session_id, closed_at')
    .eq('id', checkpointId)
    .maybeSingle()

  if (!point) return c.json({ error: 'Point de controle introuvable.' }, 404)
  if (point.closed_at != null) {
    return c.json({ error: 'Ce module est termine.' }, 409)
  }

  const { data: parent } = await service
    .from('parents')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()
  if (!parent) {
    return c.json({ error: 'Ce compte ne suit pas cette seance.' }, 403)
  }

  const { data: places } = await service
    .from('session_enrolments')
    .select('id')
    .eq('session_id', point.session_id as string)
    .eq('parent_id', parent.id as string)
    .eq('status', 'CONFIRMED')

  const liste = places ?? []
  if (liste.length === 0) {
    return c.json({ error: 'Votre place n’est pas encore payee.' }, 403)
  }

  // Deux enfants sur la meme seance : chacun repond pour sa place. Le client
  // indique laquelle, comme pour le jeton d'entree.
  const demande = (await c.req.json().catch(() => ({}))) as Record<string, unknown>
  const voulue = typeof demande.enrolmentId === 'string' ? demande.enrolmentId : null
  const place = voulue
    ? liste.find((p) => p.id === voulue)
    : liste.length === 1
      ? liste[0]
      : null

  if (!place) {
    return c.json(
      {
        error: 'Plusieurs places sur cette seance : indiquez qui repond.',
        choices: liste.map((p) => ({ enrolmentId: p.id })),
      },
      409,
    )
  }

  // `upsert` sur la cle primaire : une reponse se donne une fois, mais un
  // double envoi (bouton tapote deux fois sur un reseau lent) ne doit pas
  // echouer sous les yeux de l'eleve.
  const { error } = await service.from('checkpoint_answers').upsert(
    {
      checkpoint_id: checkpointId,
      enrolment_id: place.id as string,
      answer: parsed.data.answer,
    },
    { onConflict: 'checkpoint_id,enrolment_id' },
  )

  if (error) {
    return c.json({ error: 'La reponse n’a pas pu etre enregistree.' }, 500)
  }
  return c.json({ recorded: true, answer: parsed.data.answer })
})

/**
 * Le professeur ferme le vote, et recoit le resume.
 *
 * La fermeture et le resume sont **un seul geste** : un resume demande
 * separement serait demande trop tard — la pause dure cinq minutes.
 *
 * Si Gemini n'est pas configure ou refuse, le decompte est rendu quand meme. Le
 * professeur a besoin des chiffres ; la phrase est un supplement, et perdre les
 * deux pour un incident chez Google serait absurde.
 */
app.post('/live/checkpoints/:id/close', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const checkpointId = c.req.param('id')
  const service = asService()

  const { data: point } = await service
    .from('session_checkpoints')
    .select(
      'id, session_id, module_index, closed_at, summary, live_sessions ( live_course_id, live_courses ( teacher_id, title, subjects ( name ), levels ( name ) ) )',
    )
    .eq('id', checkpointId)
    .maybeSingle()

  if (!point) return c.json({ error: 'Point de controle introuvable.' }, 404)

  const acces = await sessionForTeacher(String(point.session_id), userId)
  if (!acces.ok) return c.json({ error: acces.error }, acces.status)

  const { data: reponses } = await service
    .from('checkpoint_answers')
    .select('answer')
    .eq('checkpoint_id', checkpointId)

  const decompte = { yes: 0, partly: 0, no: 0 }
  for (const ligne of reponses ?? []) {
    if (ligne.answer === 'YES') decompte.yes += 1
    else if (ligne.answer === 'PARTLY') decompte.partly += 1
    else if (ligne.answer === 'NO') decompte.no += 1
  }

  // Deja ferme : on rend l'etat enregistre sans rappeler Gemini. Un second appel
  // paierait une deuxieme fois pour la meme phrase.
  if (point.closed_at != null) {
    return c.json({
      closedAt: point.closed_at,
      counts: decompte,
      summary: point.summary,
      alreadyClosed: true,
    })
  }

  const ferme = new Date().toISOString()
  let resume: string | null = null

  if (gemini && decompte.yes + decompte.partly + decompte.no > 0) {
    const seance = one(point.live_sessions as never) as
      | Record<string, unknown>
      | undefined
    const cours = one(seance?.live_courses as never) as
      | Record<string, unknown>
      | undefined
    const matiere = one(cours?.subjects as never) as
      | Record<string, unknown>
      | undefined
    const niveau = one(cours?.levels as never) as
      | Record<string, unknown>
      | undefined

    try {
      resume = await gemini.summariseCheckpoint({
        subject: (matiere?.name as string) ?? 'Cours',
        level: (niveau?.name as string) ?? '',
        moduleIndex: Number(point.module_index ?? 0),
        yes: decompte.yes,
        partly: decompte.partly,
        no: decompte.no,
      })
    } catch (cause) {
      // Journalise, jamais remonte tel quel : un message de Google au milieu
      // d'un cours n'aide personne.
      console.error('[checkpoint] resume indisponible', checkpointId, cause)
    }
  }

  await service
    .from('session_checkpoints')
    .update({ closed_at: ferme, summary: resume })
    .eq('id', checkpointId)

  return c.json({
    closedAt: ferme,
    counts: decompte,
    summary: resume,
    alreadyClosed: false,
  })
})

/**
 * L'etat des points de controle d'une seance.
 *
 * **Deux reponses tres differentes selon qui demande**, et c'est le coeur de la
 * regle d'anonymat :
 *
 *   * le **professeur** recoit les decomptes et les resumes — c'est son panneau
 *     « ce qui bloque » ;
 *   * un **eleve** recoit seulement : y a-t-il un vote ouvert, et ai-je deja
 *     repondu. Jamais le decompte, jamais la reponse d'un autre. Lui montrer
 *     « 11 sur 15 ont compris » lui dirait aussi qu'il est dans les quatre.
 */
app.get('/live/sessions/:id/checkpoints', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const sessionId = c.req.param('id')
  const service = asService()

  const { data: points } = await service
    .from('session_checkpoints')
    .select('id, module_index, opened_at, closed_at, summary')
    .eq('session_id', sessionId)
    .order('module_index', { ascending: true })

  const liste = points ?? []

  const { data: prof } = await service
    .from('teachers')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()

  const { data: seance } = await service
    .from('live_sessions')
    .select('live_courses ( teacher_id )')
    .eq('id', sessionId)
    .maybeSingle()
  const cours = one(seance?.live_courses as never) as
    | Record<string, unknown>
    | undefined
  const estLeProfesseur =
    prof != null && cours != null && prof.id === cours.teacher_id

  if (estLeProfesseur) {
    const decomptes = new Map<string, { yes: number; partly: number; no: number }>()
    if (liste.length > 0) {
      const { data: reponses } = await service
        .from('checkpoint_answers')
        .select('checkpoint_id, answer')
        .in(
          'checkpoint_id',
          liste.map((p) => p.id as string),
        )
      for (const ligne of reponses ?? []) {
        const cle = String(ligne.checkpoint_id)
        const total = decomptes.get(cle) ?? { yes: 0, partly: 0, no: 0 }
        if (ligne.answer === 'YES') total.yes += 1
        else if (ligne.answer === 'PARTLY') total.partly += 1
        else if (ligne.answer === 'NO') total.no += 1
        decomptes.set(cle, total)
      }
    }

    return c.json({
      role: 'teacher',
      checkpoints: liste.map((point) => ({
        id: point.id,
        moduleIndex: point.module_index,
        openedAt: point.opened_at,
        closedAt: point.closed_at,
        summary: point.summary,
        counts: decomptes.get(String(point.id)) ?? { yes: 0, partly: 0, no: 0 },
      })),
    })
  }

  // Cote eleve : ses places, pour savoir ce qu'il a deja repondu.
  const { data: parent } = await service
    .from('parents')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()
  if (!parent) return c.json({ role: 'student', checkpoints: [] })

  const { data: places } = await service
    .from('session_enrolments')
    .select('id')
    .eq('session_id', sessionId)
    .eq('parent_id', parent.id as string)
    .eq('status', 'CONFIRMED')

  const ids = (places ?? []).map((p) => p.id as string)
  const miennes = new Map<string, string>()
  if (ids.length > 0 && liste.length > 0) {
    const { data: reponses } = await service
      .from('checkpoint_answers')
      .select('checkpoint_id, answer, enrolment_id')
      .in(
        'checkpoint_id',
        liste.map((p) => p.id as string),
      )
      .in('enrolment_id', ids)
    for (const ligne of reponses ?? []) {
      miennes.set(String(ligne.checkpoint_id), String(ligne.answer))
    }
  }

  return c.json({
    role: 'student',
    enrolmentIds: ids,
    checkpoints: liste.map((point) => ({
      id: point.id,
      moduleIndex: point.module_index,
      openedAt: point.opened_at,
      closedAt: point.closed_at,
      // Ni decompte ni resume : voir l'en-tete de cette route.
      myAnswer: miennes.get(String(point.id)) ?? null,
    })),
  })
})

/**
 * Les seances d'une famille : celles a venir, et celles deja suivies.
 *
 * --- Pourquoi cette route existe ------------------------------------------
 *
 * Sans elle, la grille publique ne montre que les seances **a venir**. Une
 * famille qui a paye le cours de mardi n'a aucun endroit ou le retrouver
 * mercredi — ni pour voir la rediffusion, ni pour verifier ce qu'elle a paye. Un
 * cours achete qu'on ne retrouve pas est un remboursement demande.
 *
 * Les inscriptions `PENDING` y figurent aussi, et c'est voulu : une place retenue
 * dont le paiement n'est pas passe doit se voir, sinon la personne croit avoir
 * paye et se presente a 18 h devant une porte fermee.
 */
app.get('/live/my-sessions', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const service = asService()
  const { data: parent } = await service
    .from('parents')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()

  // Un compte enseignant n'a pas de fiche famille : liste vide, pas une erreur.
  // Ses cours a lui se lisent par `/live/courses`.
  if (!parent) return c.json([])

  const { data, error } = await service
    .from('session_enrolments')
    .select(
      'id, status, holds_until, children ( first_name ), live_sessions ( id, slot_id, starts_at, duration_minutes, status, seats_taken, recording_status, recording_video_id, live_courses ( id, title, price, seats, teacher_id, subjects ( id, name, code ), levels ( id, name, code, category ) ) )',
    )
    .eq('parent_id', parent.id as string)
    .order('created_at', { ascending: false })
    .limit(60)

  if (error) return c.json({ error: 'Lecture impossible.' }, 500)

  const lignes = (data ?? []).flatMap((inscription) => {
    const seance = one(inscription.live_sessions as never) as
      | Record<string, unknown>
      | undefined
    if (!seance) return []
    const cours = one(seance.live_courses as never) as
      | Record<string, unknown>
      | undefined
    const enfant = one(inscription.children as never) as
      | Record<string, unknown>
      | undefined
    const matiere = one(cours?.subjects as never) as
      | Record<string, unknown>
      | undefined
    const niveau = one(cours?.levels as never) as
      | Record<string, unknown>
      | undefined

    return [
      {
        enrolmentId: String(inscription.id),
        enrolmentStatus: String(inscription.status),
        holdsUntil: (inscription.holds_until as string | null) ?? null,
        childName: (enfant?.first_name as string | null) ?? null,
        sessionId: String(seance.id),
        slotId: String(seance.slot_id ?? ''),
        startsAt: String(seance.starts_at),
        durationMinutes: Number(seance.duration_minutes ?? 90),
        // Rempli plus bas, une fois toutes les places connues : « 52 » pour
        // « 52 minutes sur 60 ». Zero avant la seance.
        minutesAttended: 0,
        status: String(seance.status),
        // L'etat de l'enregistrement, pour que l'ecran sache s'il doit proposer
        // une rediffusion ou expliquer qu'il n'y en aura pas. **Pas
        // l'identifiant de la video** : il n'est pas lisible sans signature, et
        // le donner inviterait a le faire fuir.
        replay: seance.recording_video_id
          ? ((seance.recording_status as string | null) ?? 'TRANSFERRING')
          : null,
        courseId: cours ? String(cours.id) : '',
        title: (cours?.title as string | null) ?? null,
        price: Number(cours?.price ?? 0),
        subject: matiere
          ? { id: String(matiere.id), name: String(matiere.name) }
          : null,
        level: niveau
          ? { id: String(niveau.id), name: String(niveau.name) }
          : null,
      },
    ]
  })

  /*
   * Les minutes suivies, par place.
   *
   * --- Pourquoi une seconde requete et non une jointure --------------
   *
   * `attendance_detail` porte une ligne **par entree en salle**, pas par
   * place : un enfant qui perd le reseau et revient en a deux, et il faut
   * les additionner. Une jointure rendrait la place en double et le reste de
   * la fiche avec elle.
   *
   * Une requete pour toutes les places a la fois, et non une par seance :
   * quinze seances feraient quinze allers-retours sur une connexion lente.
   */
  const places = lignes.map((l) => l.enrolmentId)
  const minutesParPlace = new Map<string, number>()
  if (places.length > 0) {
    const { data: presences } = await service
      .from('attendance_detail')
      .select('enrolment_id, minutes')
      .in('enrolment_id', places)

    for (const ligne of presences ?? []) {
      const place = String(ligne.enrolment_id)
      minutesParPlace.set(
        place,
        (minutesParPlace.get(place) ?? 0) + Number(ligne.minutes ?? 0),
      )
    }
  }

  for (const ligne of lignes) {
    /*
     * Zero quand la seance n'a pas encore eu lieu, et c'est juste : il n'y a
     * rien a montrer avant. L'ecran s'en sert pour n'afficher la preuve que
     * sur les seances passees.
     *
     * Jamais plus que la duree : une ligne de presence qui reste ouverte
     * apres la fin du cours donnerait « 94 minutes sur 90 », ce qui se lit
     * comme une erreur de compte et ruine la confiance dans le chiffre.
     */
    ligne.minutesAttended = Math.min(
      minutesParPlace.get(ligne.enrolmentId) ?? 0,
      ligne.durationMinutes,
    )
  }

  // La plus proche d'abord parmi celles a venir, puis les passees de la plus
  // recente a la plus ancienne : c'est l'ordre dans lequel on les cherche.
  const maintenant = Date.now()
  lignes.sort((a, b) => {
    const da = new Date(a.startsAt).getTime()
    const db = new Date(b.startsAt).getTime()
    const aVenirA = da >= maintenant
    const aVenirB = db >= maintenant
    if (aVenirA !== aVenirB) return aVenirA ? -1 : 1
    return aVenirA ? da - db : db - da
  })

  return c.json(lignes)
})

/**
 * Qui suit un cours en ce moment.
 *
 * --- Pourquoi par le serveur et non en lecture directe -------------------
 *
 * La vue `attendance_detail` est en `security_invoker` : un client pourrait la
 * lire directement sans rien voir de plus que ce que la politique lui ouvre. Le
 * passage par ici n'est donc pas une question de securite mais de **nombre
 * d'implementations** : le bandeau du site, celui de l'application Flutter et
 * tout ecran a venir lisent la meme reponse, construite une fois. Un cumul de
 * minutes recalcule dans chaque client finirait par donner deux chiffres
 * differents pour la meme semaine, et c'est le chiffre qu'un parent regarde.
 *
 * **Ce que cette route ne rend jamais : rien qui touche a l'image.** Un parent
 * voit que son enfant suit un cours et depuis combien de temps. C'est une
 * presence, pas une surveillance video, et la distinction se tient ici autant
 * que dans le dessin de l'ecran.
 */
app.get('/live/presence', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  // Sous le jeton de l'appelant : c'est la politique de `session_attendance`
  // qui decide ce qu'il voit, et elle ne lui ouvre que les siens.
  const { data, error } = await asUser(tokenOf(c))
    .from('attendance_detail')
    .select(
      'id, session_id, child_name, subject_name, course_title, minutes_so_far, starts_at',
    )
    .is('left_at', null)
    .order('joined_at', { ascending: true })

  if (error) return c.json({ error: 'Lecture impossible.' }, 500)

  return c.json(
    (data ?? []).map((ligne) => ({
      id: String(ligne.id),
      sessionId: String(ligne.session_id),
      childName: (ligne.child_name as string | null) ?? undefined,
      subjectName: (ligne.subject_name as string | null) ?? undefined,
      courseTitle: (ligne.course_title as string | null) ?? undefined,
      minutes: Number(ligne.minutes_so_far ?? 0),
      startsAt: String(ligne.starts_at),
    })),
  )
})

/**
 * Le temps de cours cumule.
 *
 * Par defaut depuis lundi : c'est la semaine telle qu'une famille la compte, et
 * « cette semaine » doit dire la meme chose un vendredi qu'un dimanche. Le
 * dimanche appartient a la semaine qui finit, pas a celle qui commence — d'ou le
 * decalage sur `getUTCDay() === 0`.
 */
app.get('/live/study-minutes', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const demande = c.req.query('since')
  const depuis = demande && !Number.isNaN(Date.parse(demande))
    ? new Date(demande)
    : startOfWeek(new Date())

  const { data, error } = await asUser(tokenOf(c))
    .from('attendance_detail')
    .select('session_id, child_name, subject_name, minutes, minutes_so_far')
    .gte('joined_at', depuis.toISOString())

  if (error) return c.json({ error: 'Lecture impossible.' }, 500)

  const lignes = data ?? []
  const parEnfant = new Map<string, number>()
  const parMatiere = new Map<string, number>()
  const seances = new Set<string>()
  let total = 0

  for (const ligne of lignes) {
    // `minutes_so_far` couvre la seance en cours ; `minutes` les terminees. La
    // vue rend la seconde dans la premiere quand la ligne est fermee, donc une
    // seule lecture suffit.
    const duree = Number(ligne.minutes_so_far ?? ligne.minutes ?? 0)
    if (!Number.isFinite(duree) || duree <= 0) continue
    total += duree
    seances.add(String(ligne.session_id))

    const enfant = (ligne.child_name as string | null) ?? 'Mon compte'
    parEnfant.set(enfant, (parEnfant.get(enfant) ?? 0) + duree)

    const matiere = (ligne.subject_name as string | null) ?? 'Autre'
    parMatiere.set(matiere, (parMatiere.get(matiere) ?? 0) + duree)
  }

  const classe = (table: Map<string, number>, cle: 'childName' | 'subjectName') =>
    [...table.entries()]
      .sort((a, b) => b[1] - a[1])
      .map(([nom, minutes]) => ({ [cle]: nom, minutes }))

  return c.json({
    since: depuis.toISOString(),
    totalMinutes: total,
    sessions: seances.size,
    perChild: classe(parEnfant, 'childName'),
    perSubject: classe(parMatiere, 'subjectName'),
  })
})

/** Lundi 00 h 00 de la semaine d'une date. */
function startOfWeek(reference: Date): Date {
  const jour = reference.getUTCDay()
  // Dimanche vaut 0 : il ferme la semaine, il ne l'ouvre pas.
  const recul = jour === 0 ? 6 : jour - 1
  const lundi = new Date(
    Date.UTC(
      reference.getUTCFullYear(),
      reference.getUTCMonth(),
      reference.getUTCDate() - recul,
    ),
  )
  return lundi
}

/**
 * La rediffusion d'une seance.
 *
 * --- Qui y a droit --------------------------------------------------------
 *
 * Les memes que dans la salle : le professeur du cours, et les inscrits payes.
 * Un eleve qui a paye la seance du mardi a droit a la rediffusion du mardi —
 * c'est le meme cours, et c'est la reponse a « j'ai eu une coupure de courant »,
 * qui est la premiere raison de rater un cours ici.
 *
 * --- Pourquoi l'etat se verifie a la lecture ------------------------------
 *
 * Stream transcode en quelques minutes et ne nous previent pas. Interroger a la
 * demande, plutot que d'attendre un balayage nocturne, fait que l'eleve qui
 * revient une heure apres le cours trouve sa rediffusion — et nous evite une
 * tache planifiee qui interroge Stream pour des seances que personne ne regarde.
 */
app.get('/live/sessions/:id/replay', async (c) => {
  if (!video) {
    return c.json({ error: 'L’hebergement video n’est pas configure.' }, 503)
  }
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const sessionId = c.req.param('id')
  const service = asService()
  const { data: seance } = await service
    .from('live_sessions')
    .select(
      'id, starts_at, status, opened_at, recording_video_id, recording_status, live_courses ( id, teacher_id, title )',
    )
    .eq('id', sessionId)
    .maybeSingle()

  if (!seance) return c.json({ error: 'Seance introuvable.' }, 404)

  const cours = one(seance.live_courses as never) as
    | Record<string, unknown>
    | undefined

  const { data: prof } = await service
    .from('teachers')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()
  let autorise = prof != null && cours != null && prof.id === cours.teacher_id

  if (!autorise) {
    const { data: parent } = await service
      .from('parents')
      .select('id')
      .eq('user_id', userId)
      .maybeSingle()
    if (parent) {
      const { data: places } = await service
        .from('session_enrolments')
        .select('id')
        .eq('session_id', sessionId)
        .eq('parent_id', parent.id as string)
        .eq('status', 'CONFIRMED')
        .limit(1)
      autorise = (places ?? []).length > 0
    }
  }

  if (!autorise) {
    return c.json({ error: 'Cette seance n’est pas accessible.' }, 403)
  }

  const videoId = seance.recording_video_id as string | null
  let etat = (seance.recording_status as string | null) ?? null

  if (!videoId) {
    return c.json({ status: etat ?? 'NONE', available: false })
  }

  if (etat !== 'READY') {
    /*
     * Trois etats, pas six codes numeriques.
     *
     * Bunny rendait un entier (4 = « finished », 5 et 6 des echecs) que ce
     * fichier devait traduire. `_lib/stream.ts` rend directement le vocabulaire
     * du schema : la traduction vit dans le module du fournisseur, qui est le
     * seul endroit cense connaitre ses conventions.
     */
    const constate = await video.videoState(videoId).catch(() => null)
    if (constate) etat = constate
    if (etat !== seance.recording_status) {
      await service
        .from('live_sessions')
        .update({ recording_status: etat })
        .eq('id', sessionId)
    }
  }

  if (etat !== 'READY') {
    return c.json({ status: etat, available: false })
  }

  /*
   * --- Les quatre modules, sans decouper la video ------------------------
   *
   * Le plan (strategy_implementation.md §B7) prevoyait de produire quatre
   * segments et autant de `course_items`. On rend des **reperes temporels** a la
   * place, et c'est mieux pour trois raisons :
   *
   *   * aucun re-encodage : decouper 90 minutes en quatre demanderait de
   *     retraiter la video, donc du temps machine et une occasion d'echouer ;
   *   * aucun stockage en plus : quatre segments, c'est deux fois la video chez
   *     Stream, facture ;
   *   * un seul lien a signer. Quatre videos, c'est quatre URL signees a tenir
   *     a jour, et quatre chances d'en laisser fuir une.
   *
   * Ce que l'eleve voulait — « atterrir sur le module que j'ai manque » — est
   * obtenu avec `?t=`, que le lecteur de Stream comme `video_player` savent
   * faire. Le decoupage physique resolvait un probleme qu'on n'avait pas.
   *
   * --- D'ou viennent les bornes ------------------------------------------
   *
   * `live_sessions.opened_at` est l'instant ou la salle s'ouvre, donc l'instant
   * ou l'egress commence : c'est le zero de l'enregistrement. Chaque point de
   * controle est ouvert par le professeur **a la fin** de son module, donc son
   * `opened_at` marque la fin du module et le debut du suivant.
   *
   * Sans point de controle, pas de repere : on ne coupe pas au hasard a 0, 22,
   * 45 et 67 minutes. Mieux vaut une rediffusion sans chapitres qu'une
   * rediffusion dont les chapitres mentent.
   */
  const chapitres: Array<{
    index: number
    label: string
    startSeconds: number
  }> = []

  const ouverture = seance.opened_at
    ? new Date(String(seance.opened_at)).getTime()
    : null

  if (ouverture != null) {
    const { data: points } = await service
      .from('session_checkpoints')
      .select('module_index, opened_at')
      .eq('session_id', sessionId)
      .order('module_index', { ascending: true })

    let debut = 0
    for (const point of points ?? []) {
      chapitres.push({
        index: Number(point.module_index ?? 0),
        label: `Module ${Number(point.module_index ?? 0) + 1}`,
        startSeconds: debut,
      })
      const fin = Math.max(
        0,
        Math.round(
          (new Date(String(point.opened_at)).getTime() - ouverture) / 1000,
        ),
      )
      // Cinq secondes avant la bascule : l'egress demarre une seconde ou deux
      // apres l'ouverture de la salle, et un eleve qui atterrit apres la
      // premiere phrase du module croit avoir manque quelque chose.
      debut = Math.max(0, fin - 5)
    }

    // Le dernier module n'a pas de point de controle apres lui : il va de la
    // derniere bascule a la fin de l'enregistrement.
    if (chapitres.length > 0 && chapitres.length < 4) {
      chapitres.push({
        index: chapitres.length,
        label: `Module ${chapitres.length + 1}`,
        startSeconds: debut,
      })
    }
  }

  /*
   * Quatre heures : de quoi regarder 90 minutes en s'interrompant, sans qu'un
   * lien copie reste valable une semaine.
   *
   * Un seul appel rend les deux adresses — chez Bunny il en fallait deux, donc
   * deux jetons avec deux expirations differentes pour la meme video.
   */
  const lecture = await video.playbackUrls(videoId, { ttlSeconds: 4 * 3600 })

  return c.json({
    status: 'READY',
    available: true,
    // `embed` pour le site (Chrome et Firefox ne lisent pas HLS sans
    // bibliotheque), `hls` pour l'application Flutter, ou `video_player` le lit
    // nativement par ExoPlayer.
    embed: lecture.iframe,
    hls: lecture.hls,
    signed: lecture.signed,
    expiresAt: lecture.expiresAt,
    title: (cours?.title as string) ?? null,
    startsAt: seance.starts_at,
    // Vide quand la seance n'a pas eu de point de controle : l'ecran affiche
    // alors la video sans chapitres, ce qui est honnete.
    chapters: chapitres,
  })
})

/**
 * Une URL de lecture signee pour une video de cours.
 *
 * **Verification de l'achat d'abord, signature ensuite.** C'est le seul ordre
 * acceptable : une URL signee emise sans controle vaut un cours offert, et elle
 * circule.
 */
app.get('/videos/:itemId/url', async (c) => {
  if (!video) {
    return c.json({ error: 'L’hebergement video n’est pas configure.' }, 503)
  }

  const itemId = c.req.param('itemId')

  // La lecture passe par le jeton de l'appelant : c'est RLS qui decide s'il a
  // le droit de voir cet element, et `course_items` est fermee a qui n'a pas
  // achete (migration 0010). On ne contourne pas cette regle avec la cle de
  // service — ce serait la defaire.
  const { data: element, error } = await asUser(tokenOf(c))
    .from('course_items')
    .select('id, title, provider_video_id, provider_status')
    .eq('id', itemId)
    .maybeSingle()

  if (error || !element) {
    // Indistinguable d'un element inexistant, volontairement : dire « vous
    // n'avez pas achete » confirmerait l'existence du contenu.
    return c.json({ error: 'Video indisponible.' }, 404)
  }

  const videoId = element.provider_video_id as string | undefined
  if (!videoId) {
    return c.json({ error: 'Cette video n’est pas encore deposee.' }, 409)
  }
  // Ouvrir un lecteur sur une video encore en transcodage
  // donne un cadre noir.
  if (element.provider_status && element.provider_status !== 'READY') {
    return c.json(
      { error: 'Cette video est en preparation.', status: element.provider_status },
      409,
    )
  }

  const lecture = await video.playbackUrls(videoId)
  // `url` conserve pour les appelants existants : le lecteur du telephone lit
  // HLS nativement, et c'est ce que cette route servait deja.
  return c.json({ ...lecture, url: lecture.hls })
})

// --- Cours en direct : generation des seances -------------------------------
//
// Un cours recurrent ne porte que ses creneaux ; ce sont ses occurrences qu'on
// achete. Le generateur les cree a l'avance, et il est **rejouable** : la
// contrainte `unique (live_course_id, starts_at)` fait que relancer ne cree
// aucun doublon. C'est ce qui permet de le declencher par cron sans tenir de
// curseur.

/** Combien de semaines d'avance. Quatre : un mois d'agenda visible. */
const WEEKS_AHEAD = 4

/**
 * Cree les seances manquantes de tous les cours publies.
 *
 * Rend le nombre cree. Ne supprime rien : une seance annulee garde son etat
 * `CANCELLED` et ne doit pas reapparaitre au prochain passage — ce que
 * garantit la contrainte d'unicite, pas une logique de suppression.
 */
async function generateSessions(
  /**
   * Un seul cours, ou tous les cours publies quand c'est nul.
   *
   * Le cron passe a 2 h du matin ; un professeur qui vient de publier son
   * cours ne va pas attendre jusque-la pour voir ses seances apparaitre — il
   * croirait que la publication a echoue.
   */
  coursId?: string,
): Promise<{ created: number; courses: number }> {
  const service = asService()

  let requete = service
    .from('live_courses')
    .select('id, slot_ids')
    .eq('status', 'PUBLISHED')
  if (coursId) requete = requete.eq('id', coursId)
  const { data: cours } = await requete

  if (!cours || cours.length === 0) return { created: 0, courses: 0 }

  const lignes: Record<string, unknown>[] = []
  const maintenant = new Date()

  for (const c of cours) {
    const creneaux = Array.isArray(c.slot_ids)
      ? (c.slot_ids as unknown[]).map(String)
      : []
    for (const occurrence of occurrencesFor(creneaux, {
      from: maintenant,
      weeks: WEEKS_AHEAD,
    })) {
      lignes.push({
        live_course_id: c.id,
        slot_id: occurrence.slotId,
        starts_at: occurrence.startsAt.toISOString(),
        duration_minutes: occurrence.durationMinutes,
        status: 'PLANNED',
      })
    }
  }

  if (lignes.length === 0) return { created: 0, courses: cours.length }

  // `ignoreDuplicates` plutot qu'un `upsert` qui ecrase : une seance existante
  // peut avoir ete annulee, renommee, ou porter une salle. La regenerer
  // effacerait ces changements.
  const { error, count } = await service
    .from('live_sessions')
    .upsert(lignes, {
      onConflict: 'live_course_id,starts_at',
      ignoreDuplicates: true,
      count: 'exact',
    })

  if (error) {
    console.error('[seances] generation impossible', error.message)
    return { created: 0, courses: cours.length }
  }
  return { created: count ?? 0, courses: cours.length }
}

/**
 * Declenchement manuel, reserve a la cle de service.
 *
 * Le cron fait le travail en temps normal ; ce point d'entree sert a verifier
 * apres un deploiement, et a rattraper si une execution a ete manquee. Il
 * n'est pas ouvert a un compte : un client qui pourrait le declencher pourrait
 * le declencher mille fois.
 */
app.post('/live/sessions/generate', async (c) => {
  const cle = c.req.header('X-Service-Key')
  if (!cle || cle !== process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return c.json({ error: 'Non autorise.' }, 401)
  }
  const bilan = await generateSessions()
  const liberees = await releaseExpiredSeats()
  return c.json({ ...bilan, seatsReleased: liberees })
})

// --- Publier un cours en direct --------------------------------------------

const coursSchema = z.object({
  subjectId: z.string().min(1).max(64),
  levelId: z.string().min(1).max(64),
  title: z.string().trim().min(3).max(120).optional(),
  description: z.string().trim().max(2000).optional(),

  // Les bornes viennent de la contrainte SQL (migration 0014). Les repeter ici
  // sert a rendre un message lisible plutot qu'une erreur de base : une faute
  // de frappe a sept chiffres doit se voir a l'ecran.
  price: z.number().int().min(1000).max(1000000),

  // Quinze au maximum, et c'est la valeur du produit : au-dela, un professeur
  // ne peut plus repondre a chacun pendant les pauses.
  seats: z.number().int().min(1).max(15).default(15),

  // Les identifiants de creneaux choisis. La liste fermee vit dans
  // `shared/scheduling/slots.json` ; un creneau inconnu est refuse ici plutot
  // que de produire des seances a une heure qui n'existe pas.
  slotIds: z.array(z.string().min(1).max(32)).min(1).max(6),

  /** Faux pour garder le cours en brouillon. */
  publish: z.boolean().default(true),
})

/**
 * Cree un cours en direct, et ses premieres seances.
 *
 * --- Le trou que ceci comble -------------------------------------------
 *
 * Il n'existait **aucun parcours de creation**, ni sur le telephone ni sur le
 * site. Les cours en direct ne pouvaient donc venir que d'un semis manuel, et
 * la consequence se lisait en chaine :
 *
 *   pas de cours -> pas de seance -> pas de place payee -> pas de presence,
 *   pas de groupe de discussion, rien dans « En direct »
 *
 * Trois fonctions terminees et invisibles, pour un formulaire manquant.
 *
 * --- Pourquoi les seances sont generees tout de suite -------------------
 *
 * Le cron de 2 h du matin les aurait creees de toute facon. Mais un professeur
 * qui publie son cours et ne voit rien apparaitre croit que la publication a
 * echoue — et republie. On genere donc pour ce seul cours, immediatement.
 */
app.post('/live/courses', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const corps = coursSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) {
    return c.json(
      {
        error: 'Demande incomplete.',
        detail: corps.error.issues.map(
          (i) => `${i.path.join('.')}: ${i.message}`,
        ),
      },
      400,
    )
  }
  const entree = corps.data

  // Les creneaux, verifies contre la liste fermee. Un identifiant invente
  // produirait des seances a une heure qui n'existe pas, et le generateur les
  // ignorerait en silence — le professeur verrait un cours sans seance.
  const inconnus = entree.slotIds.filter((id) => !slotById(id))
  if (inconnus.length > 0) {
    return c.json({ error: `Créneau inconnu : ${inconnus.join(', ')}.` }, 400)
  }

  const service = asService()

  // La matiere et la classe doivent exister : la base les refuserait par cle
  // etrangere, mais avec un message que personne ne peut lire.
  const [{ data: matiere }, { data: niveau }] = await Promise.all([
    service
      .from('subjects')
      .select('id, name')
      .eq('id', entree.subjectId)
      .maybeSingle(),
    service
      .from('levels')
      .select('id, name')
      .eq('id', entree.levelId)
      .maybeSingle(),
  ])
  if (!matiere) return c.json({ error: 'Matière inconnue.' }, 400)
  if (!niveau) return c.json({ error: 'Classe inconnue.' }, 400)

  const { data: cours, error } = await service
    .from('live_courses')
    .insert({
      teacher_id: teacherId,
      subject_id: entree.subjectId,
      level_id: entree.levelId,
      title: entree.title ?? `${matiere.name} — ${niveau.name}`,
      description: entree.description ?? null,
      price: entree.price,
      seats: entree.seats,
      slot_ids: entree.slotIds,
      status: entree.publish ? 'PUBLISHED' : 'DRAFT',
    })
    .select('id, title, status, price, seats, slot_ids')
    .maybeSingle()

  if (error || !cours) {
    console.error('[cours] creation impossible', error)
    return c.json({ error: 'Création impossible.' }, 500)
  }

  // Les seances, maintenant — pas dans six heures.
  const bilan = entree.publish
    ? await generateSessions(cours.id as string)
    : { created: 0, courses: 0 }

  return c.json({
    id: cours.id,
    title: cours.title,
    status: cours.status,
    price: cours.price,
    seats: cours.seats,
    slotIds: cours.slot_ids,
    sessionsCreated: bilan.created,
  })
})

/**
 * Les cours du professeur, avec le compte de leurs seances a venir.
 *
 * Sans cet ecran, il ne peut pas savoir ce qui existe deja — et republierait
 * le meme cours.
 */
app.get('/live/courses/mine', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const service = asService()
  const { data: cours, error } = await service
    .from('live_courses')
    .select(
      'id, title, status, price, seats, slot_ids, created_at, ' +
        'subjects ( name ), levels ( name )',
    )
    .eq('teacher_id', teacherId)
    .order('created_at', { ascending: false })

  if (error) {
    console.error('[cours] lecture impossible', error)
    return c.json({ error: 'Lecture impossible.' }, 500)
  }

  // Le typage de supabase-js ne traverse pas une jointure imbriquee : il rend
  // `GenericStringError`. Le meme contournement qu ailleurs dans ce fichier.
  const lignes = (cours ?? []) as unknown as Record<string, unknown>[]
  const ids = lignes.map((x) => x.id as string)
  const aVenir = new Map<string, number>()
  if (ids.length > 0) {
    const { data: seances } = await service
      .from('live_sessions')
      .select('live_course_id')
      .in('live_course_id', ids)
      .gte('starts_at', new Date().toISOString())
      .neq('status', 'CANCELLED')
    for (const seance of seances ?? []) {
      const k = seance.live_course_id as string
      aVenir.set(k, (aVenir.get(k) ?? 0) + 1)
    }
  }

  const nomDe = (v: unknown): string | null => {
    const ligne = Array.isArray(v) ? v[0] : v
    return (ligne as { name?: string } | null)?.name ?? null
  }

  return c.json({
    courses: lignes.map((x) => ({
      id: x.id,
      title: x.title,
      status: x.status,
      price: x.price,
      seats: x.seats,
      slotIds: x.slot_ids,
      subjectName: nomDe(x.subjects),
      levelName: nomDe(x.levels),
      upcomingSessions: aVenir.get(x.id as string) ?? 0,
    })),
  })
})

/** Les creneaux proposables, pour que l'ecran n'en invente aucun. */
app.get('/live/slots', (c) =>
  c.json({
    sessionMinutes: SESSION_MINUTES,
    slots: SLOTS.map((s) => ({
      id: s.id,
      label: s.label,
      days: s.days,
      start: s.start,
      end: s.end,
    })),
  }),
)

// --- S'inscrire a une seance ------------------------------------------------

const enrolSchema = z.object({
  sessionId: z.string().min(1),
  /** L'eleve concerne. Absent : c'est l'etudiant majeur lui-meme. */
  childId: z.string().min(1).optional(),
  method: z.enum(['OM', 'MOMO']).optional(),
  payerPhone: z.string().min(8).max(20).optional(),
})

/** Combien de temps une place reste retenue sans paiement. */
const SEAT_HOLD_MINUTES = 20

/**
 * Inscrit a une seance et lance le paiement.
 *
 * L'ordre compte et il n'est pas interchangeable :
 *
 *  1. **prendre la place** — avant tout, parce que c'est la ressource rare.
 *     Lancer le paiement d'abord ferait payer quelqu'un pour une salle pleine ;
 *  2. creer l'inscription, qui retient la place 20 minutes ;
 *  3. lancer le paiement.
 *
 * Si l'une des deux dernieres etapes echoue, la place est rendue tout de suite.
 * Si personne ne paie, le cron la rend a l'expiration.
 */
app.post('/live/enrol', async (c) => {
  const parsed = enrolSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) return c.json({ error: 'Seance non precisee.' }, 400)

  const db = asUser(tokenOf(c))
  const { data: parent } = await db.from('parents').select('id').maybeSingle()
  if (!parent) {
    return c.json({ error: 'Ce compte n’a pas de fiche famille.' }, 403)
  }
  const parentId = parent.id as string

  const service = asService()

  // La seance, son cours, son prix. Le prix est relu ici : un montant envoye
  // par le client serait un montant choisi par le client.
  const { data: seance } = await service
    .from('live_sessions')
    .select(
      'id, starts_at, status, live_courses ( id, price, title, teacher_id, seats )',
    )
    .eq('id', parsed.data.sessionId)
    .maybeSingle()

  if (!seance) return c.json({ error: 'Seance introuvable.' }, 404)
  if (seance.status !== 'PLANNED') {
    return c.json({ error: 'Cette seance n’accepte plus d’inscription.' }, 409)
  }
  if (new Date(String(seance.starts_at)).getTime() <= Date.now()) {
    return c.json({ error: 'Cette seance a deja commence.' }, 409)
  }

  // PostgREST rend l'objet lie tantot seul, tantot dans un tableau selon la
  // cardinalite qu'il deduit. On accepte les deux plutot que de parier.
  const lie = seance.live_courses as unknown
  const cours = (Array.isArray(lie) ? lie[0] : lie) as
    | Record<string, unknown>
    | null
  const prix = Number(cours?.price ?? 0)
  if (!cours || prix <= 0) {
    return c.json({ error: 'Ce cours n’a pas de prix.' }, 409)
  }

  // Deja inscrit ? On rend l'inscription existante. Les deux index partiels la
  // refuseraient, et un 409 ferait croire a une panne alors que la place est
  // acquise.
  let dejaQuery = service
    .from('session_enrolments')
    .select('id, status')
    .eq('session_id', seance.id as string)
    .eq('parent_id', parentId)
    .limit(1)
  dejaQuery = parsed.data.childId
    ? dejaQuery.eq('child_id', parsed.data.childId)
    : dejaQuery.is('child_id', null)

  const { data: dejas } = await dejaQuery
  if (dejas && dejas.length > 0) {
    return c.json({
      id: dejas[0].id,
      status: dejas[0].status,
      alreadyEnrolled: true,
    })
  }

  // 1. La place, de maniere atomique.
  const { data: prise } = await service.rpc('claim_session_seat', {
    session: seance.id as string,
  })
  if (prise !== true) {
    return c.json({ error: 'Cette seance est complete.' }, 409)
  }

  const rendreLaPlace = () =>
    service.rpc('release_session_seat', { session: seance.id as string })

  // 2. L'inscription, qui retient la place.
  const { data: inscription, error: echecInscription } = await service
    .from('session_enrolments')
    .insert({
      id: crypto.randomUUID(),
      session_id: seance.id as string,
      parent_id: parentId,
      child_id: parsed.data.childId ?? null,
      status: 'PENDING',
      holds_until: new Date(
        Date.now() + SEAT_HOLD_MINUTES * 60_000,
      ).toISOString(),
    })
    .select('id, status')
    .single()

  if (echecInscription || !inscription) {
    await rendreLaPlace()
    return c.json({ error: 'L’inscription n’a pas abouti.' }, 500)
  }

  // 3. Le paiement — exactement le meme chemin que pour un cours video, avec le
  // prix relu en base et la commission calculee ici.
  const commission = Math.round(prix * COURSE_COMMISSION)
  const { data: achat, error: echecAchat } = await service
    .from('course_purchases')
    .insert({
      id: crypto.randomUUID(),
      // Un achat porte soit un cours video, soit une inscription — jamais les
      // deux (contrainte `course_purchases_target_check`, migration 0015).
      course_id: null,
      enrolment_id: inscription.id as string,
      parent_id: parentId,
      amount: prix,
      commission,
      status: 'PENDING',
    })
    .select('id')
    .single()

  if (echecAchat || !achat) {
    // Sans ligne de paiement, personne ne pourra jamais payer cette place :
    // on la rend tout de suite plutot que de la laisser bloquee 20 minutes.
    await service
      .from('session_enrolments')
      .update({ status: 'CANCELLED' })
      .eq('id', inscription.id as string)
    await rendreLaPlace()
    return c.json({ error: 'Le paiement n’a pas pu etre prepare.' }, 500)
  }

  const lancement = await startPayment(c, {
    purchaseId: achat.id as string,
    amount: prix,
    method: parsed.data.method,
    payerPhone: parsed.data.payerPhone,
    courseTitle: String(cours.title ?? 'Cours en direct'),
  })

  return c.json(
    {
      id: inscription.id,
      purchaseId: achat.id,
      status: 'PENDING',
      amount: prix,
      holdsMinutes: SEAT_HOLD_MINUTES,
      alreadyEnrolled: false,
      ...lancement,
    },
    201,
  )
})

/**
 * Libere les places retenues sans paiement.
 *
 * Appelee par le cron. Sans elle, une inscription abandonnee garderait sa place
 * pour toujours et la seance afficherait complet en etant vide.
 */
async function releaseExpiredSeats(): Promise<number> {
  const service = asService()
  const { data: expirees } = await service
    .from('session_enrolments')
    .select('id, session_id')
    .eq('status', 'PENDING')
    .lt('holds_until', new Date().toISOString())
    .limit(200)

  if (!expirees || expirees.length === 0) return 0

  for (const e of expirees) {
    await service
      .from('session_enrolments')
      .update({ status: 'CANCELLED', updated_at: new Date().toISOString() })
      .eq('id', e.id as string)
    await service.rpc('release_session_seat', { session: e.session_id })
  }
  return expirees.length
}

/** Les seances a venir d'un cours, pour le professeur comme pour l'eleve. */
app.get('/live/courses/:id/sessions', async (c) => {
  const rows = await asUser(tokenOf(c))
    .from('live_sessions')
    .select('id, slot_id, starts_at, duration_minutes, status')
    .eq('live_course_id', c.req.param('id'))
    .gte('starts_at', new Date().toISOString())
    .order('starts_at', { ascending: true })
    .limit(60)

  if (rows.error) return c.json({ error: 'Lecture impossible.' }, 500)
  return c.json(rows.data ?? [])
})

// --- Achat d'un cours video ------------------------------------------------
//
// **Le client n'envoie que l'identifiant du cours.** Il n'envoie pas le prix :
// un montant qui vient du navigateur est un montant choisi par le navigateur.
// Le prix se relit dans `video_courses`, la commission se calcule ici, et la
// ligne est ecrite avec la cle de service — la politique d'insertion a ete
// retiree du client par la migration 0012.
//
// L'achat est enregistre `PENDING`. Il n'y a pas encore d'encaissement : aucun
// fournisseur de paiement n'est branche, et `has_bought_course()` n'ouvre les
// videos qu'a l'etat `PAID`. Ce point d'entree cree donc une demande, pas un
// acces — ce qui est la verite de ce qui se passe, et ce qui evite de donner
// le cours a qui appuie sur le bouton.
//
// Quand l'API de l'operateur sera branchee, c'est ici que partira la demande
// de paiement, et un second point d'entree recevra sa confirmation
// (`provider_ref`, `paid_at`, puis `status = 'PAID'`).

/**
 * L'encaisseur, quand il est configure.
 *
 * `null` sans configuration, et c'est un mode de fonctionnement a part
 * entiere : la demande d'achat s'enregistre `PENDING` et personne n'est
 * debite. C'est l'etat du produit tant que le compte marchand n'existe pas, et
 * l'ecran le dit — « rien n'est debite maintenant ».
 */
const djomyConfig = {
  // `DJOMY_ENVIRONMENT` vient de `[vars]` dans `wrangler.toml`, pas d'un
  // secret : ce n'est pas une donnee sensible, et la voir versionnee par
  // environnement de deploiement est precisement ce qui evite de se tromper.
  environment: process.env.DJOMY_ENVIRONMENT as
    | 'sandbox'
    | 'production'
    | undefined,
  baseUrl: (process.env.DJOMY_BASE_URL ?? '').replace(/\/$/, ''),
  clientId: process.env.DJOMY_CLIENT_ID ?? '',
  clientSecret: process.env.DJOMY_CLIENT_SECRET ?? '',
  // La documentation dit « la cle secrete du marchand (clientSecret) ». On
  // accepte une cle distincte au cas ou l'espace developpeur en delivre une.
  webhookSecret:
    process.env.DJOMY_WEBHOOK_SECRET ?? process.env.DJOMY_CLIENT_SECRET ?? '',
  countryCode: process.env.DJOMY_COUNTRY ?? 'GN',
}

const djomy = Djomy.isConfigured(djomyConfig) ? new Djomy(djomyConfig) : null

/**
 * Des cles sans environnement declare : on refuse d'encaisser.
 *
 * C'est le cas qui merite un refus plutot qu'un defaut. Choisir « production »
 * facturerait de vrais clients depuis un poste de developpement ; choisir
 * « sandbox » laisserait une mise en ligne encaisser dans le vide pendant des
 * semaines, et le defaut ne se verrait qu'au premier client qui reclame son
 * cours. Les deux se decouvrent trop tard.
 */
if (!djomy && djomyConfig.clientId !== '') {
  console.error(
    '[djomy] cles presentes mais configuration incomplete — encaissement ' +
      'desactive. Verifier DJOMY_ENVIRONMENT (sandbox|production), ' +
      'DJOMY_BASE_URL, DJOMY_CLIENT_ID, DJOMY_CLIENT_SECRET.',
  )
} else if (djomy) {
  console.log(`[djomy] encaissement actif en ${djomy.environment}`)
}

const purchaseSchema = z.object({
  courseId: z.string().min(1),
  /**
   * Le portefeuille choisi. Absent, aucun paiement n'est demande : la ligne
   * reste une intention, ce qui sert tant que l'encaissement n'existe pas.
   */
  method: z.enum(['OM', 'MOMO']).optional(),
  /**
   * Le numero qui paie. Par defaut celui du compte — mais on paie souvent avec
   * le portefeuille d'un proche, et imposer celui du compte ferait echouer la
   * moitie des paiements.
   */
  payerPhone: z.string().min(8).max(20).optional(),
})

/** La part retenue par la plateforme, identique aux deux clients. */
const COURSE_COMMISSION = 0.2

app.post('/purchases', async (c) => {
  const parsed = purchaseSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) {
    return c.json({ error: 'Cours non precise.' }, 400)
  }

  // La fiche de l'acheteur, lue sous SON jeton : c'est RLS qui garantit qu'on
  // ne peut pas acheter au nom de quelqu'un d'autre, et non un parametre.
  const db = asUser(tokenOf(c))
  const { data: parent } = await db.from('parents').select('id').maybeSingle()
  if (!parent) {
    return c.json(
      { error: 'Ce compte n’a pas de fiche famille. Connectez-vous.' },
      403,
    )
  }

  const service = asService()
  const { data: course } = await service
    .from('video_courses')
    .select('id, title, price, status, teacher_id')
    .eq('id', parsed.data.courseId)
    .maybeSingle()
  if (!course) return c.json({ error: 'Cours introuvable.' }, 404)
  if (course.status !== 'PUBLISHED') {
    return c.json({ error: 'Ce cours n’est plus en vente.' }, 409)
  }

  const parentId = parent.id as string

  // Deja achete ? On rend la ligne existante au lieu d'en creer une seconde :
  // la contrainte d'unicite la refuserait, et un 409 ferait croire a une panne
  // alors que l'acces est deja acquis — ou la demande deja enregistree.
  const { data: existing } = await service
    .from('course_purchases')
    .select('id, status, amount, provider_ref')
    .eq('course_id', course.id)
    .eq('parent_id', parentId)
    .maybeSingle()

  if (existing) {
    // Une demande en attente **sans reference d'operateur** est une tentative
    // qui n'a pas abouti : l'appel a Djomy a echoue, ou aucun n'a ete fait. La
    // contrainte d'unicite empeche d'en creer une seconde, donc sans cette
    // reprise le cours devenait inachetable pour toujours.
    const aRelancer =
      existing.status === 'PENDING' && existing.provider_ref == null

    if (!aRelancer) {
      return c.json({
        id: existing.id,
        status: existing.status,
        amount: existing.amount,
        alreadyRequested: true,
      })
    }

    const relance = await startPayment(c, {
      purchaseId: existing.id as string,
      amount: Number(existing.amount ?? 0),
      method: parsed.data.method,
      payerPhone: parsed.data.payerPhone,
      courseTitle: String(course.title ?? ''),
    })
    return c.json({
      id: existing.id,
      status: 'PENDING',
      amount: existing.amount,
      alreadyRequested: true,
      ...relance,
    })
  }

  const price = Number(course.price ?? 0)
  if (price <= 0) {
    return c.json({ error: 'Ce cours n’a pas de prix.' }, 409)
  }

  // Le prix et la commission sont figes maintenant : changer le tarif plus
  // tard ne doit pas reecrire ce qui a ete demande.
  const commission = Math.round(price * COURSE_COMMISSION)

  const { data: created, error } = await service
    .from('course_purchases')
    .insert({
      id: crypto.randomUUID(),
      course_id: course.id,
      parent_id: parentId,
      amount: price,
      commission,
      status: 'PENDING',
    })
    .select('id, status, amount')
    .single()

  if (error || !created) {
    return c.json({ error: 'La demande n’a pas pu être enregistrée.' }, 500)
  }

  // La ligne existe avant l'appel a l'operateur, et dans cet ordre : si Djomy
  // repond apres un delai ou pas du tout, la demande est deja tracee et le
  // webhook saura la retrouver par `merchantPaymentReference`. L'inverse —
  // appeler d'abord — perdrait un paiement reussi dont nous n'aurions aucune
  // trace.
  const lancement = await startPayment(c, {
    purchaseId: created.id as string,
    amount: price,
    method: parsed.data.method,
    payerPhone: parsed.data.payerPhone,
    courseTitle: String(course.title ?? ''),
  })

  // Aucun appel au journal ici : l'intergiciel d'audit enregistre toute
  // mutation (`isAuditable`), celle-ci comprise, avec l'appelant et la charge
  // utile. Un second enregistrement ferait deux lignes pour un achat.

  return c.json(
    {
      id: created.id,
      status: created.status,
      amount: created.amount,
      alreadyRequested: false,
      ...lancement,
    },
    201,
  )
})

/**
 * Demande le paiement a Djomy et enregistre ce qu'il rend.
 *
 * Rend ce que le client doit savoir : si une confirmation est attendue sur le
 * telephone du payeur, ou s'il faut le rediriger. Un echec n'est pas fatal — la
 * demande reste enregistree, le message explique, et un nouvel appel reprendra
 * la meme ligne.
 */
async function startPayment(
  c: Context,
  input: {
    purchaseId: string
    amount: number
    method?: 'OM' | 'MOMO'
    payerPhone?: string
    courseTitle: string
  },
): Promise<{
  payment: 'none' | 'awaiting_confirmation' | 'redirect'
  redirectUrl?: string
  paymentError?: string
  sandbox?: boolean
}> {
  if (!djomy || !input.method) return { payment: 'none' }
  // Porte jusqu'a l'ecran : un paiement de test doit se voir. Sans cela, une
  // demonstration en bac a sable passe pour un encaissement reel, et personne
  // ne s'en apercoit avant de chercher l'argent.
  const sandbox = djomy.isSandbox

  // Le numero du compte sert de defaut. Il est lu sous la cle de service :
  // `profiles` est ferme a tout le monde sauf son proprietaire, et nous
  // agissons ici pour lui.
  let payerPhone = input.payerPhone
  if (!payerPhone) {
    const { data: profile } = await asService()
      .from('profiles')
      .select('phone')
      .eq('id', c.get('userId') ?? '')
      .maybeSingle()
    payerPhone = (profile?.phone as string | undefined) ?? undefined
  }
  if (!payerPhone) {
    return {
      payment: 'none',
      paymentError: 'Aucun numéro de téléphone pour le paiement.',
      sandbox,
    }
  }

  try {
    const paiement = await djomy.chargeWallet({
      method: input.method,
      payerPhone,
      amount: input.amount,
      // Notre identifiant d'achat : c'est lui qui revient dans le webhook et
      // qui permet de retrouver la ligne sans dependre de `provider_ref`.
      reference: input.purchaseId,
      description: `Cours : ${input.courseTitle}`.slice(0, 255),
      metadata: { purchase_id: input.purchaseId },
    })

    await asService()
      .from('course_purchases')
      .update({
        provider: 'DJOMY',
        provider_ref: paiement.transactionId,
        provider_method: input.method,
        payer_identifier: toDjomyPhone(payerPhone),
      })
      .eq('id', input.purchaseId)

    return paiement.redirectUrl
      ? { payment: 'redirect', redirectUrl: paiement.redirectUrl, sandbox }
      : { payment: 'awaiting_confirmation', sandbox }
  } catch (cause) {
    const message =
      cause instanceof DjomyError
        ? cause.message
        : 'Le paiement n’a pas pu être lancé.'
    console.error('[djomy] initiation', message)
    // La demande reste `PENDING` sans reference : le prochain appel la
    // reprendra au lieu de buter sur la contrainte d'unicite.
    return { payment: 'none', paymentError: message, sandbox }
  }
}

/**
 * Ou en est une demande d'achat.
 *
 * La page de retour interroge ce point d'entree plutot que de croire les
 * parametres d'URL que Djomy y ajoute : `?status=SUCCESS` se tape a la main.
 * Le webhook est la seule source de verite, et ceci la relit.
 */
app.get('/purchases/:id', async (c) => {
  const db = asUser(tokenOf(c))
  const { data: parent } = await db.from('parents').select('id').maybeSingle()
  if (!parent) return c.json({ error: 'Compte sans fiche famille.' }, 403)

  const { data: purchase } = await asService()
    .from('course_purchases')
    .select('id, course_id, status, amount, provider_method, paid_at')
    .eq('id', c.req.param('id'))
    // Filtre sur le proprietaire : sans lui, un identifiant devine donnerait
    // l'etat de l'achat de quelqu'un d'autre.
    .eq('parent_id', parent.id as string)
    .maybeSingle()

  if (!purchase) return c.json({ error: 'Demande introuvable.' }, 404)

  // Filet quand le webhook n'est pas arrive : on demande a Djomy. Le resultat
  // n'est pas ecrit ici — seul le webhook, signe, modifie l'achat. On le rend
  // comme information, en le nommant pour ce qu'il est.
  let providerStatus: string | undefined
  if (djomy && purchase.status === 'PENDING') {
    const { data: withRef } = await asService()
      .from('course_purchases')
      .select('provider_ref')
      .eq('id', purchase.id as string)
      .maybeSingle()
    const reference = withRef?.provider_ref as string | undefined
    if (reference) {
      providerStatus = await djomy
        .paymentStatus(reference)
        .catch(() => undefined)
    }
  }

  return c.json({
    id: purchase.id,
    courseId: purchase.course_id,
    status: purchase.status,
    amount: purchase.amount,
    method: purchase.provider_method,
    paidAt: purchase.paid_at,
    providerStatus,
  })
})

/**
 * Webhook Djomy : changement de statut d'un paiement.
 *
 * Public et non authentifie — c'est Djomy qui appelle, pas un compte. Ce qui
 * tient la porte est la signature HMAC du corps, verifiee **avant** toute
 * analyse : re-serialiser le JSON changerait les octets et la signature ne
 * correspondrait plus.
 *
 * Trois regles portent la correction de ce point d'entree :
 *
 *  1. **Signature d'abord.** Sans elle, n'importe qui crédite n'importe quel
 *     achat en envoyant `payment.success`.
 *  2. **Deduplication par `eventId`.** Djomy reessaie ce qui n'a pas repondu
 *     200 ; un reessai ne doit pas rejouer un encaissement.
 *  3. **Pas de retour en arriere.** Les evenements arrivent dans un ordre
 *     quelconque : un `payment.pending` reçu apres un `payment.success` ne doit
 *     pas retirer un cours deja paye.
 */
app.post('/payments/djomy/webhook', async (c) => {
  if (!djomy) return c.json({ error: 'Encaissement non configuré.' }, 503)

  const rawBody = await c.req.text()
  const signature = c.req.header('X-Webhook-Signature')

  if (!(await djomy.verifyWebhook(rawBody, signature))) {
    // 401 et aucun detail : un message precis aiderait a fabriquer une
    // signature valide.
    return c.json({ error: 'Signature invalide.' }, 401)
  }

  let enveloppe: Record<string, unknown>
  try {
    enveloppe = JSON.parse(rawBody) as Record<string, unknown>
  } catch {
    return c.json({ error: 'Corps illisible.' }, 400)
  }

  const eventType = String(enveloppe.eventType ?? '')
  const eventId = String(enveloppe.eventId ?? '')
  if (!eventId) return c.json({ error: 'eventId manquant.' }, 400)

  // V1 pose les donnees directement dans `data` ; V2 les met sous
  // `data.payment`. Les deux formes coexistent selon la configuration du
  // marchand, et on ne choisit pas la sienne.
  const data = (enveloppe.data ?? {}) as Record<string, unknown>
  const paiement = (data.payment ?? data) as Record<string, unknown>

  const service = asService()

  // La deduplication passe par l'insertion : la contrainte de cle primaire
  // tranche, sans lecture prealable et donc sans course entre deux reessais
  // simultanes.
  const { error: dejaVu } = await service.from('payment_events').insert({
    event_id: eventId,
    event_type: eventType,
    transaction_id: (paiement.transactionId as string) ?? null,
    merchant_ref: (paiement.merchantPaymentReference as string) ?? null,
    status: (paiement.status as string) ?? null,
    paid_amount:
      typeof paiement.paidAmount === 'number' ? paiement.paidAmount : null,
    payload: enveloppe,
  })
  if (dejaVu) {
    // Deja traite. On repond 200 : un 4xx ferait reessayer Djomy
    // indefiniment pour un evenement dont nous avons fini.
    return c.json({ received: true, duplicate: true })
  }

  const nouveau = purchaseStatusFor(eventType)
  // Un `payout.*`, ou un type ajoute plus tard : journalise, sans toucher a
  // l'achat.
  if (!nouveau) return c.json({ received: true, ignored: eventType })

  const reference = paiement.merchantPaymentReference as string | undefined
  const transactionId = paiement.transactionId as string | undefined

  // Par notre reference d'abord — c'est l'identifiant de l'achat, et il ne
  // depend pas d'une ecriture qui a pu echouer a l'initiation.
  let requete = service
    .from('course_purchases')
    .select('id, status, amount')
    .limit(1)
  requete = reference
    ? requete.eq('id', reference)
    : requete.eq('provider_ref', transactionId ?? '')

  const { data: achats } = await requete
  const achat = achats?.[0]
  if (!achat) {
    // L'evenement est garde : il concerne peut-etre un paiement initie
    // ailleurs, et le perdre rendrait un rapprochement impossible.
    return c.json({ received: true, unmatched: true })
  }

  if (!canTransition(String(achat.status), nouveau)) {
    return c.json({ received: true, unchanged: String(achat.status) })
  }

  const miseAJour: Record<string, unknown> = {
    status: nouveau,
    updated_at: new Date().toISOString(),
  }
  if (transactionId) miseAJour.provider_ref = transactionId
  if (typeof paiement.fees === 'number') miseAJour.provider_fees = paiement.fees
  if (typeof paiement.receivedAmount === 'number') {
    miseAJour.provider_received = paiement.receivedAmount
  }
  if (typeof paiement.paymentMethod === 'string') {
    miseAJour.provider_method = paiement.paymentMethod
  }
  if (typeof paiement.payerIdentifier === 'string') {
    miseAJour.payer_identifier = paiement.payerIdentifier
  }
  if (nouveau === 'PAID') miseAJour.paid_at = new Date().toISOString()

  const { error: echec } = await service
    .from('course_purchases')
    .update(miseAJour)
    .eq('id', achat.id as string)

  if (echec) {
    // 500 : Djomy reessaiera, et la deduplication a deja enregistre
    // l'evenement — donc le reessai sera ignore. On retire la ligne de journal
    // pour que la reprise puisse reellement rejouer.
    await service.from('payment_events').delete().eq('event_id', eventId)
    return c.json({ error: 'Mise a jour impossible.' }, 500)
  }

  // Une inscription a une seance se confirme au paiement. Sans cela la place
  // reste « retenue » et le cron la rendrait au bout de vingt minutes — alors
  // qu'elle est payee.
  const { data: porte } = await service
    .from('course_purchases')
    .select('enrolment_id')
    .eq('id', achat.id as string)
    .maybeSingle()

  const enrolmentId = porte?.enrolment_id as string | undefined
  if (enrolmentId) {
    if (nouveau === 'PAID') {
      await service
        .from('session_enrolments')
        .update({
          status: 'CONFIRMED',
          // La place n'expire plus : elle est payee.
          holds_until: null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', enrolmentId)

      // Le groupe du cours s'ouvre a la premiere place payee, et la famille y
      // entre du meme coup — son appartenance se deduit de cette place.
      //
      // Appele a chaque paiement : `assurerGroupe` ne fait rien si le groupe
      // existe, ce qui evite d'avoir a savoir qui est le premier.
      const { data: cours } = await service
        .from('session_enrolments')
        .select(
          'live_sessions!inner ( live_course_id, ' +
            'live_courses!inner ( title, subjects ( name ) ) )',
        )
        .eq('id', enrolmentId)
        .maybeSingle()

      // Le typage de supabase-js ne traverse pas un `!inner` imbrique : il
      // rend `GenericStringError`. Le meme contournement qu'ailleurs dans ce
      // fichier.
      const ligne = cours as unknown as Record<string, unknown> | null
      const brut = ligne?.live_sessions
      const seance = (Array.isArray(brut) ? brut[0] : brut) as Record<
        string,
        unknown
      > | null
      const fiche = (Array.isArray(seance?.live_courses)
        ? seance?.live_courses[0]
        : seance?.live_courses) as Record<string, unknown> | null
      const matiere = fiche?.subjects as { name?: string } | null

      if (seance?.live_course_id) {
        await assurerGroupe(
          'COURSE',
          seance.live_course_id as string,
          (fiche?.title as string) ?? matiere?.name ?? 'Cours en direct',
        )
      }
    } else if (nouveau === 'FAILED' || nouveau === 'CANCELLED') {
      const { data: avant } = await service
        .from('session_enrolments')
        .select('session_id, status')
        .eq('id', enrolmentId)
        .maybeSingle()

      await service
        .from('session_enrolments')
        .update({ status: 'CANCELLED', updated_at: new Date().toISOString() })
        .eq('id', enrolmentId)

      // On ne rend la place que si elle etait encore tenue : un double
      // evenement ne doit pas offrir une place de plus que la salle n'en a.
      if (avant && avant.status !== 'CANCELLED') {
        await service.rpc('release_session_seat', {
          session: avant.session_id,
        })
      }
    }
  }

  // Le compteur de ventes ne bouge qu'au paiement confirme, et seulement pour
  // un cours video : une seance en direct compte ses places, pas ses ventes.
  if (nouveau === 'PAID' && !enrolmentId) {
    const { data: cours } = await service
      .from('video_courses')
      .select('purchase_count')
      .eq('id', (await courseOf(achat.id as string)) ?? '')
      .maybeSingle()
    if (cours) {
      await service
        .from('video_courses')
        .update({ purchase_count: Number(cours.purchase_count ?? 0) + 1 })
        .eq('id', (await courseOf(achat.id as string)) ?? '')
    }
  }

  return c.json({ received: true, status: nouveau })
})

/** Le cours d'un achat. */
async function courseOf(purchaseId: string): Promise<string | undefined> {
  const { data } = await asService()
    .from('course_purchases')
    .select('course_id')
    .eq('id', purchaseId)
    .maybeSingle()
  return (data?.course_id as string | undefined) ?? undefined
}

app.post('/applications', async (c) => {
  const parsed = applySchema.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) {
    return c.json({ error: 'Offre non precisee.' }, 400)
  }

  const db = asUser(tokenOf(c))
  const { data: teacher } = await db.from('teachers').select('id').maybeSingle()
  if (!teacher) return c.json({ error: 'Profil enseignant introuvable.' }, 403)

  const service = asService()
  const { data: job } = await service
    .from('jobs')
    .select('id, subject_id, level_ids, city, min_experience, requires_certification')
    .eq('id', parsed.data.jobId)
    .maybeSingle()
  if (!job) return c.json({ error: 'Offre introuvable.' }, 404)

  const profile = await loadTeacher(teacher.id as string)
  // Le score est fige a la candidature : le profil evoluera, la decision de
  // l'etablissement doit rester lisible telle qu'elle a ete prise.
  const match = profile
    ? scoreMatch(
        {
          subjectId: job.subject_id as string,
          levelIds: (job.level_ids as string[]) ?? [],
          city: job.city as string,
          minExperience: (job.min_experience as number) ?? 0,
          requiresCertification: Boolean(job.requires_certification),
        },
        toCandidate(profile),
      )
    : null

  const { data, error } = await db
    .from('applications')
    .insert({
      job_id: job.id,
      teacher_id: teacher.id,
      cover_note: parsed.data.note,
      match_score: match?.value,
      match_factors: match?.factors,
    })
    .select('id, status, applied_at, match_score')
    .single()

  if (error) {
    const duplicate = error.code === '23505'
    return c.json(
      {
        error: duplicate
          ? 'Vous avez deja postule a cette offre.'
          : 'La candidature n’a pas pu etre enregistree.',
      },
      duplicate ? 409 : 500,
    )
  }

  return c.json(data, 201)
})

// --- Etablissements (surface eleve) ----------------------------------------

app.get('/institutions', async (c) => {
  const { city, type } = c.req.query()
  let request = asUser(tokenOf(c))
    .from('institutions')
    .select('id, name, type, city, address, description, verification_status')
    .order('name')

  if (city) request = request.eq('city', city)
  if (type) request = request.eq('type', type)

  const { data, error } = await request
  if (error) throw error

  const list = (data ?? []).map((row) => ({
    id: row.id,
    name: row.name,
    type: row.type,
    city: row.city,
    address: row.address ?? undefined,
    description: row.description ?? undefined,
    verified: row.verification_status === 'VERIFIED',
  }))

  // Un etablissement verifie passe devant : c'est la seule hierarchie que
  // l'eleve peut verifier lui-meme.
  return c.json(
    list.sort(
      (a, b) =>
        Number(b.verified) - Number(a.verified) || a.name.localeCompare(b.name),
    ),
  )
})

// --- Demandes d'inscription (l'eleve postule a un etablissement) -----------

const ENROLMENT_FIELDS = `
  id, status, school_year, message, level_id, created_at, responded_at,
  child:children (id, first_name, level_id),
  institution:institutions (id, name, type, city, verification_status)
`

/*
 * Les enfants du compte parent connecte.
 *
 * --- Pourquoi cette route existe ---------------------------------------
 *
 * `POST /live/enrol` accepte un `childId`, et le site ne l'envoyait jamais :
 * faute de savoir qui etaient les enfants, toute place prise depuis le web
 * partait avec `child_id = null`. Pour un parent de deux enfants, les deux
 * reservations d'une meme seance se confondaient, et la preuve de presence
 * disait « Vous etiez la » au lieu de nommer l'enfant.
 *
 * L'application lit ses enfants dans sa base locale, synchronisee par
 * `/sync/pull` ; le web n'a pas de base locale. Cette route lui donne la
 * meme liste.
 *
 * --- Pourquoi `asUser` et non `asService` ------------------------------
 *
 * La politique « enfants : geres par le parent » fait tout le travail :
 * `parent_id = my_parent_id()`. Un autre compte lit une liste vide, et aucun
 * filtre ecrit a la main ne peut l'oublier. Un role sans fiche parent — un
 * enseignant, un etudiant majeur — recoit `[]` : c'est une absence
 * d'enfants, pas une erreur.
 */
/**
 * Les noms d'ecoles deja saisis, pour l'autocompletion du parcours.
 *
 * Publique : ce sont des noms d'etablissements, pas des donnees de
 * personnes, et le parcours d'inscription s'ouvre avant tout compte. La vue
 * `ecoles_connues` n'expose que le nom — ni enfant, ni parent, ni
 * professeur — et elle rassemble les trois endroits ou un nom existe deja :
 * les comptes d'etablissement, ce que les familles ont tape, et les
 * experiences declarees par les professeurs.
 */
app.get('/schools/names', async (c) => {
  const { data, error } = await asService()
    .from('ecoles_connues')
    .select('nom')
    .order('nom')
    .limit(500)

  if (error) throw error

  return c.json(
    (data ?? [])
      .map((ligne) => String(ligne.nom ?? '').trim())
      .filter((nom) => nom !== '')
      .map((nom) => ({ value: nom, label: nom })),
  )
})

app.get('/children', async (c) => {
  const { data, error } = await asUser(tokenOf(c))
    .from('children')
    .select('id, first_name, school_name, levels ( id, name )')
    .order('first_name')
  if (error) throw error

  return c.json(
    (data ?? []).map((ligne) => {
      // PostgREST rend l'objet lie tantot seul, tantot dans un tableau selon
      // la cardinalite qu'il deduit. On accepte les deux plutot que de parier.
      const lie = ligne.levels as unknown
      const niveau = (Array.isArray(lie) ? lie[0] : lie) as
        | { id?: string; name?: string }
        | null
      return {
        id: ligne.id as string,
        firstName: ligne.first_name as string,
        levelId: niveau?.id ?? undefined,
        levelName: niveau?.name ?? undefined,
        schoolName: (ligne.school_name as string | null) ?? undefined,
      }
    }),
  )
})

app.get('/enrolments', async (c) => {
  const { data, error } = await asUser(tokenOf(c))
    .from('enrolment_requests')
    .select(ENROLMENT_FIELDS)
    .order('created_at', { ascending: false })
  if (error) throw error

  return c.json((data ?? []).map(shapeEnrolment))
})

const enrolmentSchema = z.object({
  childId: z.string().min(1),
  institutionId: z.string().min(1),
  levelId: z.string().min(1).optional(),
  message: z.string().max(2000).optional(),
})

app.post('/enrolments', async (c) => {
  const parsed = enrolmentSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) {
    return c.json({ error: 'Etablissement non precise.' }, 400)
  }

  const db = asUser(tokenOf(c))
  const { data: parent } = await db.from('parents').select('id').maybeSingle()
  if (!parent) return c.json({ error: 'Profil parent introuvable.' }, 403)

  const { data, error } = await db
    .from('enrolment_requests')
    .insert({
      parent_id: parent.id,
      child_id: parsed.data.childId,
      institution_id: parsed.data.institutionId,
      level_id: parsed.data.levelId,
      message: parsed.data.message,
      school_year: currentSchoolYear(),
    })
    .select(ENROLMENT_FIELDS)
    .single()

  if (error) {
    const duplicate = error.code === '23505'
    return c.json(
      {
        error: duplicate
          ? 'Une demande est deja en cours dans cet etablissement.'
          : 'La demande n’a pas pu etre enregistree.',
      },
      duplicate ? 409 : 500,
    )
  }

  return c.json(shapeEnrolment(data), 201)
})

const decisionSchema = z.object({
  status: z.enum(['VIEWED', 'ACCEPTED', 'REJECTED', 'CANCELLED']),
})

app.patch('/enrolments/:id', async (c) => {
  const parsed = decisionSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) return c.json({ error: 'Statut inconnu.' }, 400)

  const db = asUser(tokenOf(c))
  const [{ data: parent }, { data: institution }] = await Promise.all([
    db.from('parents').select('id').maybeSingle(),
    db.from('institutions').select('id').maybeSingle(),
  ])

  const actor: EnrolmentActor | null = institution
    ? 'institution'
    : parent
      ? 'parent'
      : null
  if (!actor) return c.json({ error: 'Profil introuvable.' }, 403)

  // Le statut courant est relu cote serveur : le client ne le fournit pas,
  // donc il ne peut pas mentir sur le point de depart de la transition.
  const { data: existing } = await db
    .from('enrolment_requests')
    .select('status')
    .eq('id', c.req.param('id'))
    .maybeSingle()
  if (!existing) return c.json({ error: 'Demande introuvable.' }, 404)

  if (
    !canSetEnrolmentStatus(
      actor,
      existing.status as EnrolmentStatus,
      parsed.data.status,
    )
  ) {
    return c.json({ error: 'Cette suite n’est pas possible.' }, 409)
  }

  const { data, error } = await db
    .from('enrolment_requests')
    .update({
      status: parsed.data.status,
      status_changed_at: new Date().toISOString(),
      responded_at:
        parsed.data.status === 'VIEWED' ? null : new Date().toISOString(),
    })
    .eq('id', c.req.param('id'))
    .select(ENROLMENT_FIELDS)
    .maybeSingle()

  if (error) throw error
  if (!data) return c.json({ error: 'Demande introuvable.' }, 404)
  return c.json(shapeEnrolment(data))
})

// --- Tests (§10 a §13) -----------------------------------------------------

app.get('/tests', async (c) => {
  const db = asUser(tokenOf(c))
  const { data: teacher } = await db.from('teachers').select('id').maybeSingle()

  const { data: subjects } = teacher
    ? await db
        .from('teacher_subjects')
        .select('subject_id')
        .eq('teacher_id', teacher.id)
    : { data: [] }

  const subjectIds = (subjects ?? []).map((s) => s.subject_id as string)

  let request = db
    .from('tests')
    .select(
      'id, title, question_count, duration_minutes, passing_score, rules, subject:subjects (id, name), level:levels (id, name)',
    )
    .eq('active', true)

  // Un enseignant ne passe que les tests de ses matieres (§10.1).
  if (subjectIds.length > 0) request = request.in('subject_id', subjectIds)

  const { data, error } = await request
  if (error) throw error

  const { data: certs } = teacher
    ? await db
        .from('teacher_certifications')
        .select('subject_id, level_id, score, issued_at')
        .eq('teacher_id', teacher.id)
    : { data: [] }

  return c.json(
    (data ?? []).map((test) => {
      const subject = one(test.subject)
      const level = one(test.level)
      const cert = (certs ?? []).find(
        (x) => x.subject_id === subject?.id && x.level_id === level?.id,
      )
      return {
        id: test.id,
        title: test.title,
        subject,
        level,
        questionCount: test.question_count,
        durationMinutes: test.duration_minutes,
        passingScore: test.passing_score,
        rules: test.rules,
        certification: cert
          ? { score: cert.score, issuedAt: cert.issued_at }
          : undefined,
      }
    }),
  )
})

/** Questions sans la bonne reponse — elle ne quitte jamais le serveur. */
app.get('/tests/:id/questions', async (c) => {
  const { data, error } = await asUser(tokenOf(c))
    .from('test_questions_public')
    .select('id, statement, options, domain, position')
    .eq('test_id', c.req.param('id'))
    .order('position')
  if (error) throw error
  return c.json(data)
})

const submitSchema = z.object({
  answers: z.record(z.string(), z.string().nullable()),
})

/**
 * Correction (§12).
 *
 * Le calcul est refait ici a partir des reponses stockees : le serveur reste
 * la source officielle du resultat, meme lorsque le test s'est deroule hors
 * ligne (§11).
 */
app.post('/tests/:id/submit', async (c) => {
  const parsed = submitSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) return c.json({ error: 'Reponses illisibles.' }, 400)

  const testId = c.req.param('id')
  const db = asUser(tokenOf(c))
  const { data: teacher } = await db.from('teachers').select('id').maybeSingle()
  if (!teacher) return c.json({ error: 'Profil enseignant introuvable.' }, 403)

  const service = asService()
  const { data: test } = await service
    .from('tests')
    .select('id, subject_id, level_id, passing_score')
    .eq('id', testId)
    .maybeSingle()
  if (!test) return c.json({ error: 'Test introuvable.' }, 404)

  const { data: questions } = await service
    .from('test_questions')
    .select('id, correct_key, domain')
    .eq('test_id', testId)

  const outcome = scoreTest(
    (questions ?? []) as { id: string; correct_key: string; domain: string }[],
    parsed.data.answers,
    test.passing_score as number,
  )

  await service.from('test_sessions').insert({
    teacher_id: teacher.id,
    test_id: testId,
    status: 'SUBMITTED',
    expires_at: new Date().toISOString(),
    submitted_at: new Date().toISOString(),
    score: outcome.score,
    passed: outcome.passed,
    correct_count: outcome.correctCount,
    domain_scores: outcome.domainScores,
  })

  // La certification n'est delivree qu'au-dessus du seuil, et porte toujours
  // la matiere et le niveau evalues (§13).
  if (outcome.passed) {
    await service.from('teacher_certifications').upsert(
      {
        teacher_id: teacher.id,
        subject_id: test.subject_id,
        level_id: test.level_id,
        score: outcome.score,
        issued_at: new Date().toISOString(),
      },
      { onConflict: 'teacher_id,subject_id,level_id' },
    )
  }

  return c.json(outcome)
})

// --- Synchronisation (§44) -------------------------------------------------

/**
 * `/sync/push` — ce que le telephone a ecrit hors ligne.
 *
 * --- Le trou que cette route comble --------------------------------------
 *
 * L'application mobile poussait ici depuis le premier jour. La route n'existait
 * pas : tout ce qu'une personne saisissait restait sur son telephone,
 * definitivement. Un professeur qui cree un cours, un parent qui ajoute un
 * enfant — rien ne remontait, et une reinstallation de l'APK effacait le tout.
 *
 * --- Deux barrieres, aucune ne remplace l'autre --------------------------
 *
 *   * **RLS**, parce que l'ecriture passe par `asUser(jeton)` : Postgres refuse
 *     une ligne qui n'appartient pas a l'appelant ;
 *   * **la liste de colonnes** de `_lib/sync.ts`, parce que RLS ne regarde que
 *     la ligne. Un professeur possede sa ligne `teachers` : RLS le laisserait
 *     ecrire `identity_status = 'VERIFIED'` sur lui-meme, ou prolonger son
 *     propre `boosted_until`, qui se paie.
 *
 * --- Pourquoi chaque element est traite seul ----------------------------
 *
 * Pas de transaction englobante. Une file de synchronisation accumule des
 * operations independantes : si la trente-deuxieme est refusee, les trente-et-une
 * precedentes doivent rester. Tout annuler renverrait le telephone a son etat
 * initial a chaque element fautif, et il reessaierait indefiniment.
 *
 * Le client sait traiter un resultat par element — c'est la forme qu'il attend
 * (`clientRef`, `status`, `message`).
 */
const compteSchema = z.object({
  role: z.enum(['TEACHER', 'INSTITUTION', 'PARENT', 'STUDENT']),
  phone: z.string().min(8).max(20),
  firstName: z.string().max(120).optional(),
  lastName: z.string().max(120).optional(),
  city: z.string().max(120).optional(),
  region: z.string().max(60).optional(),
  district: z.string().max(120).optional(),
  institutionName: z.string().max(200).optional(),
  institutionType: z.string().max(40).optional(),
  pendingPlan: z.enum(['FREE', 'PRO', 'MASTER']).optional(),

  /*
   * L'identifiant que le telephone a deja donne a la fiche de role.
   *
   * Le meme principe que pour `users.id` : « un compte doit porter le meme
   * identifiant sur le telephone et sur le site, sinon *le meme compte* n'est
   * qu'une facon de parler ». Ici l'enjeu est concret — les enfants d'une
   * famille sont pousses avec `parent_id`, et un identifiant different de
   * chaque cote ferait echouer la cle etrangere.
   *
   * Le serveur l'accepte donc a la creation. Il ne permet rien de plus : la
   * ligne est de toute facon liee a `auth.uid()`, et un identifiant deja pris
   * fait echouer l'insertion.
   */
  roleId: z.string().min(1).max(64).optional(),
})

/**
 * Provisionne le profil et la fiche de role d'un compte qui vient de naitre.
 *
 * --- Le defaut que cette route corrige ---------------------------------
 *
 * L'application mobile creait le compte d'authentification chez Supabase
 * (`/auth/v1/signup`) puis ecrivait tout le reste dans son SQLite. Pour le
 * serveur, elle mettait l'entite `user` dans sa file de synchronisation — que
 * `REFUSED` renvoie avec « un profil se modifie par la route de compte, qui
 * verifie le role ».
 *
 * **Cette route n'existait pas.** Un compte cree depuis le telephone avait
 * donc une identite chez Supabase et **aucune ligne `profiles`**. Les
 * consequences se lisaient partout sans jamais nommer la cause :
 *
 *   * le site ne voyait pas la personne ;
 *   * toute politique RLS appuyee sur `profiles` la rejetait ;
 *   * sa fiche `teachers` ou `parents` n'existait pas cote serveur, donc ni
 *     ses matieres, ni ses eleves, ni ses contrats ne pouvaient remonter.
 *
 * C'est le maillon manquant de « la synchro ne marche pas » : il n'y avait
 * rien a synchroniser puisque le compte n'existait pas.
 *
 * --- Pourquoi le serveur et pas le client ------------------------------
 *
 * `profiles` porte le **role**, et le role decide de tout le reste. Ouvrir son
 * ecriture a un client laisserait n'importe qui se declarer `ADMIN`. La route
 * lit donc l'identite dans le jeton — jamais dans le corps — et ecrit sous la
 * cle de service.
 *
 * --- Rejouable ---------------------------------------------------------
 *
 * Le telephone appelle apres chaque ouverture de session tant qu'il n'a pas eu
 * de reponse : une inscription interrompue par le reseau se reprend. Les
 * ecritures sont donc des `upsert`, et une deuxieme passe ne duplique rien.
 */
app.post('/account', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const corps = compteSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) {
    return c.json({ error: 'Demande illisible.', detail: corps.error.issues }, 400)
  }
  const entree = corps.data
  const service = asService()

  // Le role ne se change pas par cette route : un compte deja provisionne
  // garde le sien. Sans cette garde, un appel rejoue avec un autre role
  // suffirait a se promouvoir.
  const { data: existant } = await service
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .maybeSingle()

  const role = (existant?.role as string | undefined) ?? entree.role

  const { error: erreurProfil } = await service.from('profiles').upsert(
    {
      id: userId,
      role,
      phone: entree.phone,
      first_name: entree.firstName ?? null,
      last_name: entree.lastName ?? null,
      city: entree.city ?? null,
      pending_plan: entree.pendingPlan ?? null,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'id' },
  )
  if (erreurProfil) {
    console.error('[account] profil non ecrit', erreurProfil)
    return c.json({ error: 'Création du profil impossible.' }, 500)
  }

  // La fiche du role : c'est elle que les ecrans manipulent ensuite, et son
  // absence est ce qui rendait tout le reste invisible.
  let roleId: string | null = null
  if (role === 'TEACHER') {
    const { data } = await service
      .from('teachers')
      .upsert(
        {
          ...(entree.roleId ? { id: entree.roleId } : {}),
          user_id: userId,
          city: entree.city ?? null,
          region: entree.region ?? null,
          district: entree.district ?? null,
        },
        { onConflict: 'user_id' },
      )
      .select('id')
      .maybeSingle()
    roleId = (data?.id as string | undefined) ?? null
  } else if (role === 'PARENT' || role === 'STUDENT') {
    // Un etudiant majeur partage l'espace de la famille : meme fiche, role
    // distinct. Sans cette ligne son compte s'ouvrait sans `parentId`.
    const { data } = await service
      .from('parents')
      .upsert(
        {
          ...(entree.roleId ? { id: entree.roleId } : {}),
          user_id: userId,
          city: entree.city ?? null,
          region: entree.region ?? null,
          district: entree.district ?? null,
        },
        { onConflict: 'user_id' },
      )
      .select('id')
      .maybeSingle()
    roleId = (data?.id as string | undefined) ?? null
  } else if (role === 'INSTITUTION') {
    const { data: deja } = await service
      .from('institutions')
      .select('id')
      .eq('owner_id', userId)
      .maybeSingle()
    if (deja?.id) {
      roleId = deja.id as string
    } else {
      const { data } = await service
        .from('institutions')
        .insert({
          ...(entree.roleId ? { id: entree.roleId } : {}),
          owner_id: userId,
          // Le nom de l'etablissement, jamais celui du responsable : le site
          // a longtemps envoye `manager_name` ici, et un lycee se retrouvait
          // nomme d'apres son directeur.
          name: entree.institutionName ?? 'Établissement',
          type: entree.institutionType ?? 'SCHOOL',
          city: entree.city ?? '',
          region: entree.region ?? null,
          district: entree.district ?? null,
          manager_name:
            [entree.firstName, entree.lastName].filter(Boolean).join(' ') ||
            null,
        })
        .select('id')
        .maybeSingle()
      roleId = (data?.id as string | undefined) ?? null
    }
  }

  return c.json({ userId, role, roleId })
})

const competencesSchema = z.object({
  // Une matiere, et les niveaux ou elle est enseignee. `teacher_levels` est
  // clee par (professeur, matiere, niveau) : les niveaux se declarent donc
  // **par matiere**, et c'est cette forme-la que le client doit envoyer.
  subjects: z
    .array(
      z.object({
        subjectId: z.string().min(1).max(64),
        levelIds: z.array(z.string().min(1).max(64)).max(40).default([]),
      }),
    )
    .max(40),
})

/**
 * Remplace les matieres et niveaux declares d'un professeur, d'un bloc.
 *
 * --- Pourquoi une route et non la synchronisation generique -----------
 *
 * `planWrite` ecrit **une ligne** a partir d'une charge utile dont les cles
 * sont des noms de colonnes. Or ces deux tables sont des ensembles : le geste
 * du professeur est « voila mes matieres », ce qui veut dire en ajouter,
 * mais aussi **retirer celles qu'il a decochees**. Une synchronisation ligne
 * par ligne ne sait pas exprimer ce retrait sans envoyer un differentiel
 * complet.
 *
 * Le client poussait donc `{subjectIds: [...]}` sous l'entite
 * `teacher_subjects`, dont les colonnes autorisees sont `teacher_id` et
 * `subject_id`. Aucune cle ne correspondait, la charge etait videe, et l'envoi
 * refuse avec « Aucune colonne reconnue ». Les competences d'un professeur
 * restaient sur son telephone — et comme `offersInSubjects` rend une liste
 * vide sans matiere declaree, son onglet d'offres restait vide cote serveur.
 *
 * --- Le remplacement est atomique -------------------------------------
 *
 * Supprimer puis reinserer en deux appels laisserait, entre les deux, un
 * professeur sans aucune matiere : visible par les autres, et introuvable dans
 * toute recherche. La fonction `remplacer_competences` fait les deux dans une
 * seule instruction.
 */
app.post('/teacher/competences', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const corps = competencesSchema.safeParse(
    await c.req.json().catch(() => ({})),
  )
  if (!corps.success) return c.json({ error: 'Demande illisible.' }, 400)

  const { error } = await asService().rpc('remplacer_competences', {
    prof: teacherId,
    declaration: corps.data.subjects.map((m) => ({
      subject_id: m.subjectId,
      level_ids: m.levelIds,
    })),
  })

  if (error) {
    console.error('[competences] remplacement impossible', error)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }

  return c.json({
    subjects: corps.data.subjects.length,
    levels: corps.data.subjects.reduce((n, m) => n + m.levelIds.length, 0),
  })
})

app.post('/sync/push', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const corps = (await c.req.json().catch(() => ({}))) as Record<string, unknown>
  const brut = Array.isArray(corps.operations) ? corps.operations : []

  if (brut.length === 0) {
    // Une file vide n'est pas une erreur : le moteur pousse de maniere
    // opportuniste, parfois sans rien a dire.
    return c.json({ results: [] })
  }

  /*
   * Plafond par appel.
   *
   * Un telephone reste hors ligne une semaine, revient avec deux mille
   * operations, et un seul appel depasserait le temps processeur du Worker. Le
   * client garde les suivantes en file et rappelle : c'est exactement ce que son
   * moteur fait deja apres un envoi partiel.
   */
  const LOT = 100
  const lot = brut.slice(0, LOT)

  // Sous le jeton de l'appelant : c'est RLS qui decide a quelles lignes il
  // touche. `asService()` ici annulerait la premiere des deux barrieres.
  const db = asUser(tokenOf(c))
  const results: SyncPushResult[] = []

  for (const element of lot) {
    const item = element as Record<string, unknown>
    const push: SyncPushItem = {
      clientRef: Number(item.clientRef ?? 0),
      entity: String(item.entity ?? ''),
      entityId: String(item.entityId ?? ''),
      operation: String(item.operation ?? ''),
      payload:
        item.payload && typeof item.payload === 'object'
          ? (item.payload as Record<string, unknown>)
          : {},
    }

    const plan = planWrite(push)

    if (plan.kind === 'refuse') {
      results.push({
        clientRef: push.clientRef,
        entity: push.entity,
        entityId: push.entityId,
        status: plan.status,
        message: plan.message,
      })
      continue
    }

    try {
      if (plan.kind === 'delete') {
        const { error } = await db.from(plan.table).delete().eq('id', plan.id)
        if (error) throw error
      } else {
        const { error } = await db
          .from(plan.table)
          .upsert(plan.row, { onConflict: 'id' })
        if (error) throw error

        if (plan.ignored.length > 0) {
          // Journalise sans echouer : une version plus recente de l'application
          // peut envoyer un champ que ce serveur ne connait pas encore, et
          // refuser tout l'element pour cela bloquerait la file.
          console.warn(
            '[sync] colonnes ignorees',
            push.entity,
            plan.ignored.join(', '),
          )
        }
      }

      results.push({
        clientRef: push.clientRef,
        entity: push.entity,
        entityId: push.entityId,
        status: 'applied',
      })
    } catch (cause) {
      /*
       * Un refus de RLS est un **conflit**, pas un echec.
       *
       * La distinction decide du comportement du telephone : `failed` se remet
       * en file et se reessaie, `conflict` s'arrete. Reessayer une ecriture que
       * RLS refusera toujours — une ligne qui n'est pas la sienne — occuperait la
       * file indefiniment, et la personne verrait un compteur d'erreurs qui ne
       * descend jamais.
       *
       * Postgres rend `42501` (insufficient_privilege) quand une politique
       * refuse ; PostgREST le relaie en `PGRST116` sur une ligne invisible.
       */
      const erreur = cause as { code?: string; message?: string }
      const refusePolitique =
        erreur.code === '42501' ||
        erreur.code === 'PGRST116' ||
        /row-level security|permission denied/i.test(erreur.message ?? '')

      results.push({
        clientRef: push.clientRef,
        entity: push.entity,
        entityId: push.entityId,
        status: refusePolitique ? 'conflict' : 'failed',
        message: refusePolitique
          ? 'Cette donnee n’appartient pas a ce compte.'
          : // Le detail technique reste dans les journaux : il nommerait des
            // colonnes et des contraintes.
            'Le serveur n’a pas pu enregistrer cette modification.',
      })
      if (!refusePolitique) {
        console.error('[sync] echec', push.entity, push.entityId, cause)
      }
    }
  }

  return c.json({
    results,
    // Ce qui reste a envoyer, pour que le client rappelle sans deviner.
    remaining: Math.max(0, brut.length - lot.length),
  })
})

app.get('/sync/pull', async (c) => {
  const cursor = Number(c.req.query('cursor') ?? 0)
  const { data, error } = await asUser(tokenOf(c))
    .from('sync_events')
    .select('id, entity, entity_id, operation, payload, created_at')
    .gt('id', Number.isFinite(cursor) ? cursor : 0)
    .order('id')
    .limit(200)
  if (error) throw error

  const changes = data ?? []
  return c.json({
    changes,
    cursor: changes.length > 0 ? String(changes[changes.length - 1].id) : String(cursor),
  })
})

// --- Helpers ---------------------------------------------------------------

function shapeEnrolment(row: any) {
  const institution = one<any>(row.institution)
  const child = one<any>(row.child)
  return {
    id: row.id,
    child: child
      ? { id: child.id, firstName: child.first_name, levelId: child.level_id }
      : null,
    status: row.status,
    schoolYear: row.school_year,
    message: row.message ?? undefined,
    levelId: row.level_id ?? undefined,
    createdAt: row.created_at,
    respondedAt: row.responded_at ?? undefined,
    institution: institution
      ? {
          id: institution.id,
          name: institution.name,
          type: institution.type,
          city: institution.city,
          verified: institution.verification_status === 'VERIFIED',
        }
      : null,
  }
}

/** Supabase renvoie une relation comme objet ou tableau selon le contexte. */
function one<T>(value: T | T[] | null | undefined): T | undefined {
  if (Array.isArray(value)) return value[0]
  return value ?? undefined
}

async function levelLookup(
  db: ReturnType<typeof asUser>,
): Promise<Map<string, { id: string; name: string }>> {
  const { data } = await db.from('levels').select('id, name')
  return new Map((data ?? []).map((l) => [l.id as string, { id: l.id as string, name: l.name as string }]))
}

function shapeJob(row: any, levels: Map<string, { id: string; name: string }>) {
  const institution = one<any>(row.institution)
  return {
    id: row.id,
    title: row.title,
    subject: one<any>(row.subject),
    levels: ((row.level_ids as string[]) ?? [])
      .map((id) => levels.get(id))
      .filter(Boolean),
    city: row.city,
    contractType: row.contract_type,
    description: row.description,
    salaryMin: row.salary_min,
    salaryMax: row.salary_max,
    salaryPublished: row.salary_published,
    minExperience: row.min_experience,
    requiresCertification: row.requires_certification,
    publishedAt: row.published_at,
    applicationCount: 0,
    institution: institution
      ? {
          id: institution.id,
          name: institution.name,
          type: institution.type,
          city: institution.city,
          verified: institution.verification_status === 'VERIFIED',
        }
      : null,
  }
}

/** Profil complet, assemble avec la cle de service pour le calcul du score. */
/*
 * Les champs d'une fiche, ecrits une fois.
 *
 * La meme liste servait au chargement d'une fiche seule ; la dupliquer pour
 * le chargement par lot ferait deux fiches legerement differentes selon
 * qu'on arrive par l'annuaire ou par le lien direct.
 */
const CHAMPS_PROFESSEUR =
  'id, headline, bio, city, years_experience, availability, identity_status, '
  + 'diploma_status, boosted_until, user_id'

/*
 * La taille d'un paquet d'identifiants.
 *
 * PostgREST met le filtre `in` dans l'adresse. Une adresse trop longue est
 * refusee par la passerelle, et le refus ressemble a une liste vide : on
 * decoupe donc, plutot que de decouvrir la limite un jour ou l'annuaire
 * aura grossi.
 */
const PAQUET_IDS = 200

async function parPaquets<T>(
  ids: string[],
  lire: (lot: string[]) => Promise<T[]>,
): Promise<T[]> {
  const tout: T[] = []
  for (let i = 0; i < ids.length; i += PAQUET_IDS) {
    for (const ligne of await lire(ids.slice(i, i + PAQUET_IDS))) {
      tout.push(ligne)
    }
  }
  return tout
}

/** Regroupe des lignes par la colonne qui porte le professeur. */
function parProfesseur<T extends Record<string, unknown>>(
  lignes: T[],
  colonne = 'teacher_id',
): Map<string, T[]> {
  const paquets = new Map<string, T[]>()
  for (const ligne of lignes) {
    const cle = String(ligne[colonne])
    const liste = paquets.get(cle)
    if (liste) liste.push(ligne)
    else paquets.set(cle, [ligne])
  }
  return paquets
}

/**
 * Assemble une fiche a partir de lignes deja lues.
 *
 * Pure : aucune requete. C'est ce qui permet au chargement par lot et au
 * chargement d'une fiche seule de produire exactement la meme forme.
 */
function assemblerProfesseur(
  teacher: Record<string, any>,
  profile: Record<string, any> | null,
  subjects: any[],
  levels: any[],
  certs: any[],
  experiences: any[],
) {
  const certifications = certs.map((row) => ({
    id: row.id,
    subject: one<any>(row.subject),
    level: one<any>(row.level),
    score: row.score,
    issuedAt: row.issued_at,
  }))

  const verifiedExperience = experiences.filter(
    (e) => e.verification_status === 'VERIFIED',
  ).length

  const identityVerified = teacher.identity_status === 'VERIFIED'
  const diplomaVerified = teacher.diploma_status === 'VERIFIED'

  const badges = {
    identity: identityVerified,
    diploma: diplomaVerified,
    competency: certifications.length > 0,
    experience: verifiedExperience > 0,
    profile: false,
  }
  badges.profile = badges.identity && badges.diploma && badges.competency

  const trust = trustScore({
    identityVerified,
    diplomaVerified,
    certificationScores: certifications.map((c) => c.score as number),
    verifiedExperienceCount: verifiedExperience,
    yearsExperience: teacher.years_experience as number,
    reviewAverage: null,
    completedRecruitments: 0,
  })

  const subjectItems = subjects.map((r) => one<any>(r.subject)).filter(Boolean)

  return {
    id: teacher.id as string,
    firstName: profile?.first_name ?? '',
    lastName: profile?.last_name ?? '',
    fullName: `${profile?.first_name ?? ''} ${profile?.last_name ?? ''}`.trim(),
    headline: teacher.headline ?? '',
    bio: teacher.bio,
    city: teacher.city,
    photoUrl: profile?.photo_path ?? undefined,
    yearsExperience: teacher.years_experience as number,
    availability: teacher.availability as string,
    identityStatus: teacher.identity_status as string,
    diplomaStatus: teacher.diploma_status as string,
    subjects: subjectItems,
    levels: levels.map((r) => one<any>(r.level)).filter(Boolean),
    levelPairs: levels.map(
      (r) => pairKey(r.subject_id as string, (one<any>(r.level))?.id),
    ),
    certifications,
    experiences: experiences.map((e) => ({
      id: e.id,
      institutionName: e.institution_name,
      position: e.position,
      city: e.city,
      startYear: new Date(e.start_date as string).getFullYear(),
      endYear: e.end_date ? new Date(e.end_date as string).getFullYear() : null,
      verified: e.verification_status === 'VERIFIED',
    })),
    badges,
    trustScore: trust.value,
    trustDimensions: trust.dimensions,
    boosted:
      teacher.boosted_until != null &&
      new Date(teacher.boosted_until as string) > new Date(),
    completionRate: completionRate({
      personal_info: Boolean(profile?.first_name),
      photo: Boolean(profile?.photo_path),
      identity: identityVerified,
      diploma: diplomaVerified,
      subjects: subjectItems.length > 0,
      levels: levels.length > 0,
      experience: experiences.length > 0,
      availability: true,
      certification: certifications.length > 0,
    }),
  }
}

/**
 * Charge plusieurs fiches en six requetes, quel que soit leur nombre.
 *
 * --- Le defaut que cette fonction corrige -------------------------------
 *
 * `GET /teachers` appelait `loadTeacher` dans une boucle `await`. Chaque
 * fiche coute six requetes en trois vagues, si bien que la liste entiere
 * valait 3N allers-retours en serie. Verifie le 17/10 sur le site en
 * ligne : la requete ne revenait jamais — 60 s sans statut, deux fois de
 * suite, quand les autres routes repondaient en moins de trois secondes.
 *
 * Le defaut ne se voyait pas en developpement, ou la base tient quelques
 * professeurs de demonstration et ou chaque aller-retour coute une
 * milliseconde. Il apparait avec les vraies donnees, c'est-a-dire chez la
 * personne a qui on montre le produit.
 */
async function chargerProfesseurs(ids: string[]) {
  const fiches = new Map<string, ReturnType<typeof assemblerProfesseur>>()
  if (ids.length === 0) return fiches

  const db = asService()

  const professeurs = await parPaquets(ids, async (lot) => {
    const { data, error } = await db
      .from('teachers')
      .select(CHAMPS_PROFESSEUR)
      .in('id', lot)
    if (error) throw error
    return (data ?? []) as Record<string, any>[]
  })
  if (professeurs.length === 0) return fiches

  const presents = professeurs.map((t) => String(t.id))

  /*
   * Les cinq lectures restantes partent ensemble.
   *
   * Elles ne dependent pas l'une de l'autre : les enchainer ajouterait
   * quatre allers-retours a une route qu'on vient precisement de corriger
   * pour cela.
   */
  const comptes = professeurs
    .map((t) => String(t.user_id))
    .filter((v) => v && v !== 'null')

  const [profils, matieres, paliers, certifications, experiences] =
    await Promise.all([
      parPaquets(comptes, async (lot) => {
        const { data, error } = await db
          .from('profiles')
          .select('id, first_name, last_name, photo_path')
          .in('id', lot)
        if (error) throw error
        return (data ?? []) as Record<string, any>[]
      }),
      parPaquets(presents, async (lot) => {
        const { data, error } = await db
          .from('teacher_subjects')
          .select('teacher_id, subject:subjects (id, name)')
          .in('teacher_id', lot)
        if (error) throw error
        return (data ?? []) as Record<string, any>[]
      }),
      parPaquets(presents, async (lot) => {
        const { data, error } = await db
          .from('teacher_levels')
          // `cycle` en plus du nom : c'est lui qui dit si un enseignant
          // couvre le palier de l'eleve. Sans lui, la recherche comparait
          // des identifiants exacts et proposait un professeur
          // d'universite a une famille de 9eme.
          .select('teacher_id, subject_id, level:levels (id, name, cycle)')
          .in('teacher_id', lot)
        if (error) throw error
        return (data ?? []) as Record<string, any>[]
      }),
      parPaquets(presents, async (lot) => {
        const { data, error } = await db
          .from('teacher_certifications')
          .select(
            'teacher_id, id, score, issued_at, subject:subjects (id, name), '
            + 'level:levels (id, name)',
          )
          .in('teacher_id', lot)
        if (error) throw error
        return (data ?? []) as Record<string, any>[]
      }),
      parPaquets(presents, async (lot) => {
        const { data, error } = await db
          .from('teacher_experiences')
          .select(
            'teacher_id, id, institution_name, position, city, start_date, '
            + 'end_date, verification_status',
          )
          .in('teacher_id', lot)
        if (error) throw error
        return (data ?? []) as Record<string, any>[]
      }),
    ])

  const parCompte = new Map(profils.map((p) => [String(p.id), p]))
  const matieresDe = parProfesseur(matieres)
  const paliersDe = parProfesseur(paliers)
  const certsDe = parProfesseur(certifications)
  const experiencesDe = parProfesseur(experiences)

  for (const teacher of professeurs) {
    const id = String(teacher.id)
    fiches.set(
      id,
      assemblerProfesseur(
        teacher,
        parCompte.get(String(teacher.user_id)) ?? null,
        matieresDe.get(id) ?? [],
        paliersDe.get(id) ?? [],
        certsDe.get(id) ?? [],
        experiencesDe.get(id) ?? [],
      ),
    )
  }

  return fiches
}

/** Une seule fiche : le meme chargement, pour un identifiant. */
async function loadTeacher(teacherId: string) {
  const fiches = await chargerProfesseurs([teacherId])
  return fiches.get(teacherId) ?? null
}
function toCandidate(profile: Awaited<ReturnType<typeof loadTeacher>>): Candidate {
  return {
    subjectIds: profile!.subjects.map((s: any) => s.id),
    levelPairs: profile!.levelPairs,
    certifications: Object.fromEntries(
      profile!.certifications.map((c: any) => [
        pairKey(c.subject?.id, c.level?.id),
        c.score,
      ]),
    ),
    yearsExperience: profile!.yearsExperience,
    city: profile!.city,
    availability: profile!.availability,
  }
}

// --- Points de fidelite et concours (D1, D4) --------------------------------
//
// Le solde se calcule cote serveur et jamais dans le client : la vue
// `point_balances` somme le journal, et le client ne fait que l'afficher. Un
// solde calcule dans l'application divergerait du jour ou une ecriture arrive
// pendant que le telephone est hors ligne.

app.get('/points/balance', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  // Sous le jeton de l'appelant : RLS garantit qu'il ne lit que sa ligne.
  const { data, error } = await asUser(tokenOf(c))
    .from('point_balances')
    .select('balance, entries, last_entry_at')
    .maybeSingle()

  if (error) return c.json({ error: 'Lecture impossible.' }, 500)

  // Aucune ligne = aucun point encore gagne. Un zero, pas une erreur : c'est
  // l'etat de tout compte neuf, et le refuser afficherait un message d'echec a
  // chaque nouvelle inscription.
  return c.json({
    balance: data?.balance ?? 0,
    entries: data?.entries ?? 0,
    lastEntryAt: data?.last_entry_at ?? null,
  })
})

app.get('/points/ledger', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const { data, error } = await asUser(tokenOf(c))
    .from('point_ledger')
    .select('id, delta, reason, reference, created_at')
    .order('created_at', { ascending: false })
    .limit(50)

  if (error) return c.json({ error: 'Lecture impossible.' }, 500)
  return c.json({ entries: data ?? [] })
})

/** Les concours ouverts et ceux qui arrivent. Visible sans compte. */
app.get('/contests', async (c) => {
  const { data, error } = await asService()
    .from('contests')
    .select('id, test_id, title, opens_at, closes_at, points_prize')
    .gte('closes_at', new Date(Date.now() - 7 * 24 * 3600_000).toISOString())
    .order('opens_at', { ascending: true })
    .limit(20)

  if (error) return c.json({ error: 'Lecture impossible.' }, 500)

  const maintenant = Date.now()
  return c.json({
    contests: (data ?? []).map((concours) => ({
      ...concours,
      state:
        Date.parse(concours.opens_at) > maintenant
          ? 'UPCOMING'
          : Date.parse(concours.closes_at) > maintenant
            ? 'OPEN'
            : 'CLOSED',
    })),
  })
})

/**
 * Entrer dans un concours.
 *
 * La fenetre de temps n'est pas verifiee ici mais par la politique RLS
 * (`participation : s'inscrire pendant la fenetre`). Le controle vit donc a un
 * seul endroit, et une route oubliee demain ne pourra pas le contourner.
 */
app.post('/contests/:id/enter', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const { data, error } = await asUser(tokenOf(c))
    .from('contest_entries')
    .insert({ contest_id: c.req.param('id'), user_id: userId })
    .select('id, started_at')
    .maybeSingle()

  if (error) {
    // Deja inscrit : ce n'est pas une erreur, c'est l'etat attendu quand on
    // revient sur l'ecran. Renvoyer un echec ferait croire a une panne.
    //
    // `23505` est la violation d'unicite de Postgres — ici la contrainte
    // `unique (contest_id, user_id)`.
    if (error.code === '23505') {
      const { data: existante } = await asUser(tokenOf(c))
        .from('contest_entries')
        .select('id, started_at')
        .eq('contest_id', c.req.param('id'))
        // RLS filtrerait deja sur le compte, mais l'ecrire ici dit ce que la
        // requete veut : une requete juste seulement grace a une politique
        // devient fausse le jour ou la politique bouge.
        .eq('user_id', userId)
        .maybeSingle()
      if (existante) return c.json({ entry: existante, resumed: true })
    }
    return c.json(
      { error: 'Ce concours n’accepte pas de participation en ce moment.' },
      409,
    )
  }

  return c.json({ entry: data, resumed: false })
})

const submitContestSchema = z.object({
  answers: z.record(z.string(), z.string().nullable()),
})

/**
 * Rendre sa copie.
 *
 * Corrigee avec la cle de service, parce qu'elle seule voit
 * `test_questions.correct_key` — c'est la meme raison qui ferme la table aux
 * clients. Le score n'est pas davantage accepte depuis le corps de la requete :
 * il est calcule ici, avec `scoreTest`, deja utilise par le test de competence.
 */
app.post('/contests/:id/submit', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const corps = submitContestSchema.safeParse(await c.req.json().catch(() => null))
  if (!corps.success) return c.json({ error: 'Reponses illisibles.' }, 400)

  const contestId = c.req.param('id')
  const service = asService()

  const { data: concours } = await service
    .from('contests')
    .select('id, test_id, title, closes_at')
    .eq('id', contestId)
    .maybeSingle()
  if (!concours) return c.json({ error: 'Concours inconnu.' }, 404)

  // La fermeture se verifie au moment de rendre, pas a l'ouverture : une copie
  // commencee a temps mais rendue le lendemain ne doit pas compter.
  if (Date.parse(concours.closes_at) < Date.now()) {
    return c.json({ error: 'Ce concours est termine.' }, 409)
  }

  const { data: participation } = await service
    .from('contest_entries')
    .select('id, submitted_at')
    .eq('contest_id', contestId)
    .eq('user_id', userId)
    .maybeSingle()
  if (!participation) {
    return c.json({ error: 'Entrez d’abord dans le concours.' }, 409)
  }
  // Une copie se rend une fois : sans cela on recommencerait jusqu'a obtenir un
  // bon score, et le classement ne voudrait plus rien dire.
  if (participation.submitted_at) {
    return c.json({ error: 'Votre copie est deja rendue.' }, 409)
  }

  const { data: questions } = await service
    .from('test_questions')
    .select('id, correct_key, domain')
    .eq('test_id', concours.test_id)

  const { data: test } = await service
    .from('tests')
    .select('passing_score')
    .eq('id', concours.test_id)
    .maybeSingle()

  const bilan = scoreTest(
    questions ?? [],
    corps.data.answers,
    test?.passing_score ?? 0,
  )

  const { error } = await service
    .from('contest_entries')
    .update({
      score: bilan.score,
      correct_count: bilan.correctCount,
      submitted_at: new Date().toISOString(),
    })
    .eq('id', participation.id)

  if (error) return c.json({ error: 'Enregistrement impossible.' }, 500)

  // Pas de points ici : ils sont attribues a la fermeture, quand le classement
  // est connu. Crediter maintenant demanderait de deviner le rang final.
  return c.json({
    score: bilan.score,
    correctCount: bilan.correctCount,
    totalQuestions: bilan.totalQuestions,
  })
})

/**
 * Le classement d'un concours.
 *
 * Calcule a la lecture, jamais stocke : un rang ecrit en base se desynchronise
 * des scores au premier incident, et donnerait des chiffres saisis la ou l'on
 * attend des chiffres calcules.
 *
 * Lu avec la cle de service parce qu'un classement porte sur les copies des
 * autres, que RLS cache a juste titre. **Aucun identifiant de compte ne sort**
 * d'ici : seulement un rang, un prenom et un score.
 *
 * --- Pourquoi il faut un compte -----------------------------------------
 *
 * La liste des concours est publique ; ce classement ne l'est pas. Il rend des
 * prenoms d'eleves et leurs notes. Ouvert sans compte, n'importe qui avec
 * l'adresse lirait « Fatoumata, 14/20 » — une donnee d'enfant, sortie pour la
 * seule commodite de ne pas demander a se connecter.
 *
 * Le controle d'`auth-context.test.ts` a signale cette route alors qu'elle
 * laissait passer les visiteurs, et il avait raison.
 */
app.get('/contests/:id/leaderboard', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const contestId = c.req.param('id')
  const service = asService()

  const { data: participations, error } = await service
    .from('contest_entries')
    .select('user_id, score, started_at, submitted_at')
    .eq('contest_id', contestId)

  if (error) return c.json({ error: 'Lecture impossible.' }, 500)

  const vue = leaderboardFor(
    (participations ?? []).map((p) => ({
      userId: p.user_id as string,
      score: p.score as number | null,
      startedAt: p.started_at as string,
      submittedAt: p.submitted_at as string | null,
    })),
    { me: userId },
  )

  // Les prenoms des seuls classes affiches : un podium sans nom ne motive
  // personne, et un nom complet n'est pas necessaire pour s'y reconnaitre.
  const ids = vue.podium.map((p) => p.userId)
  const prenoms = new Map<string, string>()
  if (ids.length > 0) {
    const { data: profils } = await service
      .from('profiles')
      .select('id, first_name')
      .in('id', ids)
    for (const profil of profils ?? []) {
      prenoms.set(profil.id as string, (profil.first_name as string) ?? '')
    }
  }

  return c.json({
    published: vue.published,
    participants: vue.participants,
    missing: vue.missing,
    // Le rang personnel avant le podium, ici comme a l'ecran : c'est ce que
    // l'eleve vient chercher.
    me: vue.me
      ? { rank: vue.me.rank, score: vue.me.score }
      : null,
    podium: vue.podium.map((place) => ({
      rank: place.rank,
      score: place.score,
      firstName: prenoms.get(place.userId) ?? 'Participant',
    })),
  })
})

/**
 * Fermer un concours et crediter les points.
 *
 * Reserve a la cle de service, comme la generation des seances : un client qui
 * pourrait la declencher pourrait la declencher mille fois.
 *
 * **Rejouable.** Les ecritures portent `reference = 'contest:<id>'`, et la
 * fonction commence par regarder si elles existent deja. Fermer deux fois le
 * meme concours ne double donc pas les gains — ce qui compte, parce qu'un cron
 * qui echoue a mi-chemin sera relance.
 */
app.post('/contests/:id/close', async (c) => {
  const cle = c.req.header('X-Service-Key')
  if (!cle || cle !== process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return c.json({ error: 'Non autorise.' }, 401)
  }

  const contestId = c.req.param('id')
  const reference = `contest:${contestId}`
  const service = asService()

  const { data: concours } = await service
    .from('contests')
    .select('id, title, points_prize, closes_at')
    .eq('id', contestId)
    .maybeSingle()
  if (!concours) return c.json({ error: 'Concours inconnu.' }, 404)

  const { data: deja } = await service
    .from('point_ledger')
    .select('id')
    .eq('reference', reference)
    .limit(1)
  if ((deja ?? []).length > 0) {
    return c.json({ awarded: 0, alreadyClosed: true })
  }

  const { data: participations } = await service
    .from('contest_entries')
    .select('user_id, score, started_at, submitted_at')
    .eq('contest_id', contestId)

  const ecritures = closingEntries(
    contestId,
    concours.title as string,
    (concours.points_prize as number) ?? 0,
    (participations ?? []).map((p) => ({
      userId: p.user_id as string,
      score: p.score as number | null,
      startedAt: p.started_at as string,
      submittedAt: p.submitted_at as string | null,
    })),
  )

  if (ecritures.length === 0) return c.json({ awarded: 0, alreadyClosed: false })

  const { error } = await service.from('point_ledger').insert(ecritures)
  if (error) return c.json({ error: 'Attribution impossible.' }, 500)

  return c.json({ awarded: ecritures.length, alreadyClosed: false })
})

// --- Le professeur et sa classe ---------------------------------------------

/** L'identifiant professeur de l'appelant, ou null. */
async function teacherIdOf(userId: string): Promise<string | null> {
  const { data } = await asService()
    .from('teachers')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()
  return (data?.id as string) ?? null
}

/**
 * Les seances du professeur : celle en cours, et les suivantes.
 *
 * Sert le gros bouton de l'accueil. Il n'existait aucune route pour cela — le
 * cote famille avait `/live/my-sessions`, le professeur rien — et un professeur
 * ne pouvait donc atteindre sa propre salle qu'en passant par la grille
 * publique de tous les cours.
 */
app.get('/live/teacher/sessions', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ sessions: [] })

  const service = asService()
  const { data, error } = await service
    .from('live_sessions')
    .select(
      'id, starts_at, duration_minutes, status, seats_taken, ' +
        'live_courses!inner ( id, title, teacher_id, seats, subjects ( name ) )',
    )
    .eq('live_courses.teacher_id', teacherId)
    .neq('status', 'CANCELLED')
    // Les seances d'hier n'interessent plus personne ; celle d'il y a deux
    // heures peut encore attendre une rediffusion ou un retardataire.
    .gte('starts_at', new Date(Date.now() - 4 * 3600_000).toISOString())
    .order('starts_at', { ascending: true })
    .limit(10)

  if (error) return c.json({ error: 'Lecture impossible.' }, 500)

  // Les jointures `!inner` imbriquees depassent l'inference de supabase-js, qui
  // rend alors un type d'erreur. Le fichier fait deja ce transtypage pour les
  // relations ; on l'applique a la ligne entiere.
  const seances = (data ?? []) as unknown as Record<string, unknown>[]

  return c.json({
    sessions: seances.map((seance) => {
      const lie = seance.live_courses as unknown
      const cours = (Array.isArray(lie) ? lie[0] : lie) as Record<
        string,
        unknown
      > | null
      const matiere = cours?.subjects as { name?: string } | null
      return {
        id: seance.id,
        startsAt: seance.starts_at,
        durationMinutes: seance.duration_minutes,
        status: seance.status,
        seatsTaken: seance.seats_taken,
        seats: cours?.seats ?? 0,
        title: cours?.title ?? null,
        subject: matiere?.name ?? null,
      }
    }),
  })
})

/**
 * Qui est attendu, et qui est la.
 *
 * Deux listes en une : les places vendues (`session_enrolments`) et la presence
 * constatee (`attendance_detail`). Le professeur a besoin des deux ensemble —
 * « douze inscrits, sept presents » est la seule phrase qui lui dit s'il doit
 * attendre ou commencer.
 *
 * Lu avec la cle de service : les places appartiennent aux familles, et RLS les
 * cache au professeur a juste titre. Ce qui sort d'ici est donc restreint a la
 * main — un prenom d'enfant et un etat de presence, jamais un telephone ni un
 * identifiant de compte.
 */
app.get('/live/sessions/:id/roster', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const sessionId = c.req.param('id')
  const service = asService()

  // La seance est-elle bien la sienne ? Sans ce controle, un professeur lirait
  // la classe d'un autre.
  const { data: seance } = await service
    .from('live_sessions')
    .select('id, starts_at, live_courses!inner ( teacher_id )')
    .eq('id', sessionId)
    .maybeSingle()

  const lie = seance?.live_courses as unknown
  const cours = (Array.isArray(lie) ? lie[0] : lie) as Record<
    string,
    unknown
  > | null
  if (!seance || cours?.teacher_id !== teacherId) {
    return c.json({ error: 'Seance introuvable.' }, 404)
  }

  const { data: places } = await service
    .from('session_enrolments')
    .select('id, status, parent_id, children ( first_name )')
    .eq('session_id', sessionId)
    .eq('status', 'CONFIRMED')

  const { data: presents } = await service
    .from('attendance_detail')
    .select('enrolment_id, minutes_so_far, left_at')
    .eq('session_id', sessionId)
    .is('left_at', null)

  const enSalle = new Map<string, number>()
  for (const ligne of presents ?? []) {
    if (ligne.enrolment_id) {
      enSalle.set(
        ligne.enrolment_id as string,
        (ligne.minutes_so_far as number) ?? 0,
      )
    }
  }

  return c.json({
    expected: (places ?? []).length,
    present: enSalle.size,
    roster: (places ?? []).map((place) => {
      const enfant = place.children as { first_name?: string } | null
      return {
        enrolmentId: place.id,
        // Le prenom de l'eleve, et rien d'autre : le professeur n'a pas besoin
        // du compte de la famille pour faire son cours.
        name: enfant?.first_name ?? 'Élève',
        present: enSalle.has(place.id as string),
        minutes: enSalle.get(place.id as string) ?? 0,
      }
    }),
  })
})

/**
 * Prevenir que le cours commence.
 *
 * Une place, ou toutes. Ecrit des lignes dans `notifications`, que le
 * destinataire lit avec sa propre politique — c'est la seule table que le
 * serveur ecrit pour quelqu'un d'autre, et elle n'a volontairement aucune
 * politique d'insertion pour les clients.
 *
 * **Pas de SMS.** Chaque message coute, et un professeur qui previent quinze
 * familles deux fois par seance y passerait son benefice. La notification entre
 * dans l'application ; le jour ou le SMS existera, il sera une decision avec un
 * budget, pas un effet de bord d'un bouton.
 */
const notifySchema = z.object({
  enrolmentIds: z.array(z.string().min(1)).max(60).optional(),
  all: z.boolean().optional(),
})

app.post('/live/sessions/:id/notify', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const corps = notifySchema.safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) return c.json({ error: 'Demande illisible.' }, 400)

  const sessionId = c.req.param('id')
  const service = asService()

  const { data: seance } = await service
    .from('live_sessions')
    .select(
      'id, starts_at, live_courses!inner ( teacher_id, title, subjects ( name ) )',
    )
    .eq('id', sessionId)
    .maybeSingle()

  const lie = seance?.live_courses as unknown
  const cours = (Array.isArray(lie) ? lie[0] : lie) as Record<
    string,
    unknown
  > | null
  if (!seance || cours?.teacher_id !== teacherId) {
    return c.json({ error: 'Seance introuvable.' }, 404)
  }

  let requete = service
    .from('session_enrolments')
    .select('id, parents!inner ( user_id )')
    .eq('session_id', sessionId)
    .eq('status', 'CONFIRMED')

  if (!corps.data.all) {
    const choisies = corps.data.enrolmentIds ?? []
    if (choisies.length === 0) {
      return c.json({ error: 'Personne a prevenir.' }, 400)
    }
    requete = requete.in('id', choisies)
  }

  const { data: places, error } = await requete
  if (error) return c.json({ error: 'Lecture impossible.' }, 500)

  const matiere = cours?.subjects as { name?: string } | null
  const titre = (cours?.title as string) ?? matiere?.name ?? 'Cours en direct'

  // Un compte peut avoir deux places sur la meme seance — deux enfants. Une
  // seule notification : deux lignes identiques dans la liste se lisent comme
  // un bogue.
  const comptes = new Set<string>()
  for (const place of places ?? []) {
    const parent = place.parents as unknown
    const ligne = (Array.isArray(parent) ? parent[0] : parent) as Record<
      string,
      unknown
    > | null
    if (ligne?.user_id) comptes.add(ligne.user_id as string)
  }

  if (comptes.size === 0) return c.json({ notified: 0 })

  const maintenant = new Date().toISOString()
  const { error: erreurEcriture } = await service.from('notifications').insert(
    [...comptes].map((compte) => ({
      id: crypto.randomUUID(),
      user_id: compte,
      kind: 'LIVE_STARTING',
      title: `${titre} commence`,
      body: 'Le professeur vous attend dans la salle.',
      // Le chemin exact de l'application mobile : la notification n'existe que
      // pour ouvrir la salle, et go_router ne resout rien d'autre. Une
      // notification dont le lien ne mene nulle part est pire qu'absente — on
      // la touche, rien ne se passe, et le cours commence sans l'eleve.
      route: `/direct/${sessionId}/salle`,
      created_at: maintenant,
      updated_at: maintenant,
    })),
  )

  if (erreurEcriture) {
    console.error('[live] notification impossible', erreurEcriture)
    return c.json({ error: 'Envoi impossible.' }, 500)
  }

  return c.json({ notified: comptes.size })
})

/**
 * Le repertoire du professeur — **derive, jamais stocke**.
 *
 * --- Pourquoi pas une table de contacts ---------------------------------
 *
 * Un professeur connait deja des familles : celles inscrites a ses seances,
 * celles sous contrat, celles qui lui ont ecrit une demande. Ces liens existent
 * en base. Une table `contacts` en ferait une copie, et une copie diverge : le
 * contrat se termine, la ligne reste.
 *
 * Surtout, **l'acces suit la relation**. Une liste stockee est une copie
 * permanente des coordonnees d'enfants dans l'application ; derivee, elle
 * disparait d'elle-meme quand la relation s'arrete. Pour un produit qui
 * manipule des mineurs, c'est la difference qui compte.
 *
 * --- Pourquoi pas le carnet d'adresses du telephone ---------------------
 *
 * `READ_CONTACTS` est une permission lourde, la plupart des entrees ne sont pas
 * des comptes, et cela ajouterait un greffon a un APK qui pese deja 77,9 Mo —
 * pour un resultat moins bon que ce que la base sait deja.
 *
 * Ce que ceci ne couvre pas : inviter quelqu'un sans relation prealable. C'est
 * une **invitation par numero**, pas un contact, et cela ne stocke toujours
 * rien.
 */
app.get('/live/teacher/contacts', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ contacts: [] })

  const service = asService()

  // Les familles passees par mes seances.
  const { data: parMesSeances } = await service
    .from('session_enrolments')
    .select(
      'parent_id, parents!inner ( user_id, profiles!inner ( first_name, last_name ) ), ' +
        'live_sessions!inner ( live_courses!inner ( teacher_id ) )',
    )
    .eq('live_sessions.live_courses.teacher_id', teacherId)
    .eq('status', 'CONFIRMED')
    .limit(200)

  // Celles sous contrat avec moi.
  const { data: parContrat } = await service
    .from('work_contracts')
    .select('parent_id, parents ( user_id, profiles ( first_name, last_name ) )')
    .eq('teacher_id', teacherId)
    .in('status', ['PENDING', 'ACTIVE'])
    .limit(200)

  const repertoire = new Map<
    string,
    { parentId: string; name: string; sources: Set<string> }
  >()

  const ajouter = (ligne: Record<string, unknown>, source: string) => {
    const parent = ligne.parents as unknown
    const p = (Array.isArray(parent) ? parent[0] : parent) as Record<
      string,
      unknown
    > | null
    if (!p) return
    const profil = p.profiles as unknown
    const pr = (Array.isArray(profil) ? profil[0] : profil) as Record<
      string,
      unknown
    > | null
    const parentId = ligne.parent_id as string
    if (!parentId) return

    const nom = [pr?.first_name, pr?.last_name]
      .filter(Boolean)
      .join(' ')
      .trim()
    const existant = repertoire.get(parentId)
    if (existant) {
      existant.sources.add(source)
      return
    }
    repertoire.set(parentId, {
      parentId,
      name: nom.length > 0 ? nom : 'Famille',
      sources: new Set([source]),
    })
  }

  const desSeances = (parMesSeances ?? []) as unknown as Record<
    string,
    unknown
  >[]
  const desContrats = (parContrat ?? []) as unknown as Record<
    string,
    unknown
  >[]
  for (const ligne of desSeances) ajouter(ligne, 'SESSION')
  for (const ligne of desContrats) ajouter(ligne, 'CONTRACT')

  return c.json({
    contacts: [...repertoire.values()]
      .map((contact) => ({
        parentId: contact.parentId,
        name: contact.name,
        // D'ou je le connais : « a suivi vos seances » se lit mieux qu'une
        // liste de noms sans contexte.
        sources: [...contact.sources],
      }))
      .sort((a, b) => a.name.localeCompare(b.name, 'fr')),
  })
})

/**
 * Ouvre le groupe d'une relation, si personne ne l'a encore fait.
 *
 * --- Pourquoi le serveur, et pas le client ------------------------------
 *
 * `chat_groups` n'a **aucune politique d'ecriture** : un client qui pourrait
 * creer un groupe choisirait ses propres membres, puisque l'appartenance se
 * deduit de `kind` et `source_id`. La creation passe donc par la cle de
 * service, au moment ou la relation nait.
 *
 * --- Pourquoi c'est sans danger de l'appeler deux fois ------------------
 *
 * `unique (kind, source_id)` : le deuxieme appel se heurte a la contrainte et
 * ne fait rien. On peut donc l'appeler a chaque paiement confirme sans se
 * demander si c'est le premier — ce qui evite d'avoir a le savoir.
 */
async function assurerGroupe(
  kind: 'COURSE' | 'CONTRACT',
  sourceId: string,
  name: string,
): Promise<void> {
  const { error } = await asService()
    .from('chat_groups')
    .insert({ kind, source_id: sourceId, name })

  // `23505` : il existait deja. C'est le cas courant, pas une anomalie.
  if (error && error.code !== '23505') {
    console.error('[chat] groupe non ouvert', kind, sourceId, error)
  }
}

// --- Les promotions d'etablissement (10/10) ---------------------------------

/**
 * Les promotions a montrer a cette personne, et rien de plus.
 *
 * --- Pourquoi une route, alors que RLS les ouvre deja -------------------
 *
 * La politique `promotion : visible quand elle est active` laisse n'importe
 * quel compte lire les promotions actives. Le client pourrait donc les lire en
 * direct. Deux raisons de passer ici quand meme :
 *
 *   * **la formule decide.** Une promotion ne s'affiche qu'aux comptes `FREE`
 *     — c'est ce qui donne une raison de passer a une formule payante. Lire la
 *     formule dans le client la rendrait contournable ;
 *   * **le choix de ce qu'on montre** est une regle produit (la moins vue
 *     d'abord, pour etaler la diffusion). Dans le client, chaque ecran la
 *     recopierait.
 */
app.get('/promotions/feed', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const service = asService()

  const { data: profil } = await service
    .from('profiles')
    .select('plan, role')
    .eq('id', userId)
    .maybeSingle()

  const formule = (profil?.plan as string | undefined) ?? 'FREE'
  if (formule !== 'FREE') {
    // Payer, c'est ne plus voir de publicite. Le dire franchement plutot que
    // de rendre une liste vide : l'ecran n'a pas a deviner pourquoi.
    return c.json({ promotions: [], reason: 'PAID_PLAN' })
  }

  const { data, error } = await service
    .from('promotions')
    .select(
      'id, title, message, media_paths, views, ' +
        'institutions!inner ( name, city, type )',
    )
    .eq('status', 'ACTIVE')
    // La moins vue d'abord : une promotion achetee ne doit pas rester derriere
    // une autre indefiniment. C'est l'etalement le plus simple qui soit juste.
    .order('views', { ascending: true })
    .limit(3)

  if (error) {
    console.error('[promotions] lecture impossible', error)
    return c.json({ error: 'Lecture impossible.' }, 500)
  }

  return c.json({
    // Le typage de supabase-js ne traverse pas un `!inner` : il rend
    // `GenericStringError`. Le meme contournement qu'ailleurs dans ce fichier.
    promotions: ((data ?? []) as unknown as Record<string, unknown>[]).map((p) => {
      const lie = p.institutions as unknown
      const etablissement = (Array.isArray(lie) ? lie[0] : lie) as Record<
        string,
        unknown
      > | null
      return {
        id: p.id,
        title: p.title,
        message: p.message,
        // Le premier media seulement : une carte de tableau de bord n'affiche
        // qu'une image, et envoyer la liste entiere ferait telecharger le
        // reste pour rien sur une connexion lente.
        image: ((p.media_paths as string) ?? '').split(',')[0] || null,
        institutionName: (etablissement?.name as string) ?? 'Établissement',
        institutionCity: (etablissement?.city as string) ?? null,
        institutionType: (etablissement?.type as string) ?? null,
      }
    }),
  })
})

/**
 * Compte un affichage.
 *
 * Une vue par personne et par jour : c'est `enregistrer_affichage` qui tient
 * l'unicite, et le compteur n'avance que si la vue etait nouvelle. Le
 * spectateur n'a aucun droit d'ecriture sur `promotions` — la politique le
 * reserve a l'etablissement — donc la fonction le fait pour lui, sous son
 * propre jeton pour que `auth.uid()` soit bien le sien.
 */
app.post('/promotions/:id/view', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const { data, error } = await asUser(tokenOf(c)).rpc(
    'enregistrer_affichage',
    { promo: c.req.param('id') },
  )

  if (error) {
    console.error('[promotions] affichage non compte', error)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }

  // `counted: false` n'est pas une erreur : la personne l'avait deja vue
  // aujourd'hui, ou la promotion n'est plus active.
  return c.json({ counted: data === true })
})

// --- Les groupes de discussion (04/10) --------------------------------------
//
// Un groupe par relation : un cours en direct, un contrat. L'appartenance est
// derivee par `est_membre_groupe()` cote Postgres et jamais stockee — l'acces
// suit la relation, donc il expire avec elle. Voir la migration 0027.
//
// Les trois routes lisent et ecrivent **sous le jeton du lecteur**, jamais sous
// la cle de service : c'est RLS qui decide qui voit quoi, et passer par la cle
// reviendrait a recopier la regle d'appartenance dans du TypeScript — une
// seconde definition qui finirait par s'ecarter de celle de la base.

/**
 * Les groupes de la personne, avec leur dernier message.
 *
 * `chat_groups` ne rend que les siens : la politique de select appelle
 * `est_membre_groupe`. On n'a donc rien a filtrer ici, et c'est voulu.
 */
app.get('/chat/groups', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const db = asUser(tokenOf(c))

  const { data: groupes, error } = await db
    .from('chat_groups')
    .select('id, kind, source_id, name, updated_at')
    .order('updated_at', { ascending: false })

  if (error) {
    console.error('[chat] lecture des groupes impossible', error)
    return c.json({ error: 'Lecture impossible.' }, 500)
  }

  // Le dernier message de chacun, en une requete plutot qu'une par groupe :
  // quinze groupes feraient quinze allers-retours sur une connexion lente.
  const ids = (groupes ?? []).map((g) => g.id as string)
  const derniers = new Map<string, { body: string; at: string }>()
  if (ids.length > 0) {
    const { data: messages } = await db
      .from('chat_messages')
      .select('group_id, body, created_at')
      .in('group_id', ids)
      .order('created_at', { ascending: false })
      .limit(200)
    for (const message of messages ?? []) {
      const groupe = message.group_id as string
      if (derniers.has(groupe)) continue
      derniers.set(groupe, {
        body: message.body as string,
        at: message.created_at as string,
      })
    }
  }

  return c.json({
    groups: (groupes ?? []).map((g) => ({
      id: g.id,
      kind: g.kind,
      sourceId: g.source_id,
      name: g.name,
      lastBody: derniers.get(g.id as string)?.body ?? null,
      lastAt: derniers.get(g.id as string)?.at ?? null,
    })),
  })
})

/**
 * Les messages d'un groupe, du plus ancien au plus recent.
 *
 * Pagine par le haut (`before`) : une discussion se lit par le bas, et on
 * remonte. Cinquante a la fois — assez pour remplir un ecran deux fois, pas
 * assez pour faire attendre sur un reseau lent.
 */
app.get('/chat/groups/:id/messages', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const db = asUser(tokenOf(c))
  const groupId = c.req.param('id')
  const avant = c.req.query('before')

  let requete = db
    .from('chat_messages')
    .select('id, group_id, author_id, body, created_at')
    .eq('group_id', groupId)
    .order('created_at', { ascending: false })
    .limit(50)

  if (avant) requete = requete.lt('created_at', avant)

  const { data: messages, error } = await requete
  if (error) {
    console.error('[chat] lecture des messages impossible', error)
    return c.json({ error: 'Lecture impossible.' }, 500)
  }

  // Un groupe dont on n'est pas membre rend zero message, pas une erreur :
  // c'est RLS qui filtre, et il n'a pas a dire si le groupe existe.
  const auteurs = [
    ...new Set((messages ?? []).map((m) => m.author_id as string)),
  ]
  const noms = new Map<string, { name: string; role: string }>()
  if (auteurs.length > 0) {
    // Sous la cle de service, et pour une seule raison : `profiles` est ferme
    // a tout le monde sauf son proprietaire, or afficher « Fatoumata » plutot
    // qu'un identifiant est le minimum d'une discussion. Seuls le prenom et le
    // role sortent — ni telephone, ni adresse.
    const { data: profils } = await asService()
      .from('profiles')
      .select('id, first_name, role')
      .in('id', auteurs)
    for (const profil of profils ?? []) {
      noms.set(profil.id as string, {
        name: (profil.first_name as string) ?? 'Quelqu’un',
        role: (profil.role as string) ?? 'PARENT',
      })
    }
  }

  return c.json({
    messages: (messages ?? [])
      .map((m) => ({
        id: m.id,
        groupId: m.group_id,
        authorId: m.author_id,
        authorName: noms.get(m.author_id as string)?.name ?? 'Quelqu’un',
        authorRole: noms.get(m.author_id as string)?.role ?? 'PARENT',
        body: m.body,
        sentAt: m.created_at,
      }))
      // Rendus dans l'ordre de lecture, apres avoir ete pris dans l'ordre
      // inverse : c'est la seule facon de prendre les cinquante *derniers*.
      .reverse(),
  })
})

const chatEnvoiSchema = z.object({ body: z.string().min(1).max(2000) })

/**
 * Ecrire dans un groupe.
 *
 * L'auteur vient du jeton, jamais du corps : `author_id = auth.uid()` est dans
 * la politique d'insertion, donc ecrire au nom d'un autre est refuse par la
 * base et non par une verification qu'on pourrait oublier ici.
 */
app.post('/chat/groups/:id/messages', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const corps = chatEnvoiSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) return c.json({ error: 'Message vide ou trop long.' }, 400)

  const db = asUser(tokenOf(c))
  const groupId = c.req.param('id')

  const { data: ligne, error } = await db
    .from('chat_messages')
    .insert({
      group_id: groupId,
      author_id: userId,
      body: corps.data.body.trim(),
    })
    .select('id, created_at')
    .maybeSingle()

  if (error) {
    // `42501` : la politique a refuse. Le compte n'est pas membre — place
    // annulee, contrat termine. Le dire franchement vaut mieux qu'une erreur
    // technique, parce que c'est une situation normale.
    if (error.code === '42501') {
      return c.json({ error: 'Vous ne faites plus partie de ce groupe.' }, 403)
    }
    console.error('[chat] envoi impossible', error)
    return c.json({ error: 'Envoi impossible.' }, 500)
  }

  // Remonter le groupe dans la liste. Sous la cle de service : `chat_groups`
  // n'a aucune politique d'ecriture, a dessein — un client qui pourrait la
  // modifier pourrait se renommer un groupe. Ici le serveur ne touche qu'une
  // date, et seulement apres que la base a accepte le message.
  await asService()
    .from('chat_groups')
    .update({ updated_at: new Date().toISOString() })
    .eq('id', groupId)

  return c.json({ id: ligne?.id, sentAt: ligne?.created_at })
})

// --- La boutique (D2) -------------------------------------------------------

/**
 * Le catalogue, et ou l'on en est.
 *
 * Le solde et la distance au lot suivant partent avec le catalogue, en une
 * seule reponse : trois appels pour peindre un ecran, sur une connexion
 * guineenne, ce sont trois occasions d'afficher la page a moitie.
 */
app.get('/shop/items', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const db = asUser(tokenOf(c))

  const { data: lots, error } = await db
    .from('shop_items')
    .select(
      'id, name, summary, image, points_price, value_gnf, stock, kind, draws_at',
    )
    .eq('active', true)
    .order('position', { ascending: true })

  if (error) return c.json({ error: 'Lecture impossible.' }, 500)

  // RLS limite la vue des soldes a sa propre ligne : pas de ligne = zero point.
  const { data: solde } = await db
    .from('point_balances')
    .select('balance')
    .maybeSingle()
  const balance = (solde?.balance as number) ?? 0

  const progression = shopProgress(
    balance,
    (lots ?? []).map((lot) => ({
      id: lot.id as string,
      pointsPrice: lot.points_price as number,
      stock: lot.stock as number,
    })),
  )

  // Les lots mis de cote, dans le meme appel : un second aller-retour pour
  // savoir quels coeurs allumer ferait apparaitre la liste puis les coeurs,
  // ce qui se lit comme un defaut d'affichage.
  const { data: favoris } = await db.from('shop_favorites').select('item_id')
  const misDeCote = new Set((favoris ?? []).map((f) => f.item_id as string))

  // Combien de mises par tirage, pour que l'ecran puisse dire « vous avez trois
  // chances » plutot que de laisser compter.
  const { data: mises } = await db
    .from('redemptions')
    .select('item_id')
    .eq('kind', 'RAFFLE')
    .eq('status', 'PENDING')
  const chances = new Map<string, number>()
  for (const mise of mises ?? []) {
    const cle = mise.item_id as string
    chances.set(cle, (chances.get(cle) ?? 0) + 1)
  }

  return c.json({
    balance,
    nextId: progression.nextId,
    missing: progression.missing,
    items: (lots ?? []).map((lot) => ({
      ...lot,
      affordable: progression.affordable.includes(lot.id as string),
      favorite: misDeCote.has(lot.id as string),
      entries: chances.get(lot.id as string) ?? 0,
    })),
  })
})

/**
 * Les lots mis de cote, avec leur fiche.
 *
 * Sert l'accueil, qui les affiche sans ouvrir la boutique : la jointure se fait
 * ici plutot que de demander a l'ecran de croiser deux listes.
 */
app.get('/shop/favorites', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const { data, error } = await asUser(tokenOf(c))
    .from('shop_favorites')
    .select(
      'item_id, created_at, shop_items ( id, name, summary, image, points_price, value_gnf, stock )',
    )
    .order('created_at', { ascending: false })
    .limit(20)

  if (error) return c.json({ error: 'Lecture impossible.' }, 500)

  return c.json({
    items: (data ?? [])
      .map((ligne) => ligne.shop_items)
      .filter((lot) => lot != null),
  })
})

/**
 * Mettre un lot de cote, ou l'en retirer.
 *
 * `PUT` et `DELETE` plutot qu'une bascule : les deux sont **idempotents**. Un
 * telephone qui reessaie apres une coupure ne doit pas eteindre le coeur qu'il
 * venait d'allumer, ce qu'une bascule ferait exactement une fois sur deux.
 */
app.put('/shop/items/:id/favorite', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const { error } = await asUser(tokenOf(c))
    .from('shop_favorites')
    .upsert(
      { user_id: userId, item_id: c.req.param('id') },
      { onConflict: 'user_id,item_id' },
    )

  if (error) return c.json({ error: 'Enregistrement impossible.' }, 500)
  return c.json({ favorite: true })
})

app.delete('/shop/items/:id/favorite', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const { error } = await asUser(tokenOf(c))
    .from('shop_favorites')
    .delete()
    .eq('user_id', userId)
    .eq('item_id', c.req.param('id'))

  if (error) return c.json({ error: 'Suppression impossible.' }, 500)
  return c.json({ favorite: false })
})

/**
 * Echanger ses points contre un lot.
 *
 * Tout le travail est dans `redeem_shop_item`, cote base : verifier le solde,
 * debiter le journal et decrementer le stock doivent tenir dans une seule
 * instruction. Fait ici en trois requetes, deux demandes simultanees — un
 * telephone qui reessaie apres une coupure — passeraient toutes deux la
 * verification et debiteraient deux fois.
 *
 * La fonction est appelee **sous le jeton de l'appelant** : elle lit `auth.uid()`
 * pour savoir qui echange. Avec la cle de service, `auth.uid()` serait nul et
 * l'echange serait refuse — ce qui est la bonne facon d'echouer.
 */
app.post('/shop/items/:id/redeem', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const { data, error } = await asUser(tokenOf(c)).rpc('redeem_shop_item', {
    item: c.req.param('id'),
  })

  if (error) {
    console.error('[boutique] echange impossible', error)
    return c.json({ error: 'Echange impossible pour le moment.' }, 500)
  }

  const resultat = Array.isArray(data) ? data[0] : data
  if (resultat?.redemption_id) {
    return c.json({ redemptionId: resultat.redemption_id })
  }

  /*
   * Un refus est une reponse, pas une panne.
   *
   * Les motifs sont traduits ici et non dans la base : la base dit ce qui s'est
   * passe, l'API dit ce que la personne doit lire. « NOT_ENOUGH_POINTS » affiche
   * tel quel serait du jargon sur un ecran d'enfant.
   */
  const motifs: Record<string, string> = {
    NOT_ENOUGH_POINTS: 'Il vous manque des points pour ce lot.',
    OUT_OF_STOCK: 'Ce lot vient d’etre pris. Il revient bientot.',
    UNKNOWN_ITEM: 'Ce lot n’existe plus.',
    DRAW_CLOSED: 'Le tirage de ce lot est deja passe.',
    NOT_SIGNED_IN: 'Connectez-vous.',
  }
  const motif = String(resultat?.reason ?? 'UNKNOWN_ITEM')
  return c.json({ error: motifs[motif] ?? 'Echange refuse.', reason: motif }, 409)
})

/** Ses propres demandes, en cours ou traitees. */
app.get('/shop/redemptions', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const { data, error } = await asUser(tokenOf(c))
    .from('redemptions')
    .select('id, item_id, points_spent, status, requested_at, note')
    .order('requested_at', { ascending: false })
    .limit(20)

  if (error) return c.json({ error: 'Lecture impossible.' }, 500)
  return c.json({ redemptions: data ?? [] })
})

/**
 * Les tests proposes en concours, dans l'ordre de rotation.
 *
 * Les tests de niveau universitaire (`_l1`, `_l2`) sont ecartes : un concours
 * hebdomadaire s'adresse aux eleves, et proposer un test de L2 a un collegien
 * donnerait une page de zeros et plus personne la semaine suivante.
 */
const TESTS_DE_CONCOURS = [
  'test_math_lycee',
  'test_fran_lycee',
  'test_angl_lycee',
]

/** Ce que gagne le premier d'un concours hebdomadaire. */
const ENJEU_HEBDOMADAIRE = 100

/**
 * Le cycle des concours : fermer ceux qui sont echus, ouvrir celui de la semaine.
 *
 * --- Pourquoi un seul point d'entree pour les deux ----------------------
 *
 * Les deux gestes vont ensemble : un concours qui se termine doit distribuer ses
 * points, et la semaine suivante doit en proposer un autre. Separes, on
 * deploierait un cron qui ouvre sans jamais fermer — des concours qui
 * s'accumulent et ne recompensent personne, ce qui est exactement l'etat du
 * 03/10 avant ce code.
 *
 * --- Rejouable, et c'est la propriete qui compte -----------------------
 *
 * Le cron tourne chaque nuit. La fenetre de la semaine est **derivee de la
 * date** (`weekWindow`), donc mardi et mercredi calculent le meme `opens_at` :
 * il suffit de regarder s'il existe deja. Et la fermeture reconnait les
 * concours deja payes a leur `reference` dans le journal. Une execution manquee
 * se rattrape au passage suivant, sans etat a reparer.
 */
async function cycleContests(now: Date = new Date()): Promise<{
  closed: number
  awarded: number
  opened: string | null
}> {
  const service = asService()
  const maintenant = now.toISOString()
  let closed = 0
  let awarded = 0

  // --- Fermer ce qui est echu ---------------------------------------------
  const { data: echus } = await service
    .from('contests')
    .select('id, title, points_prize')
    .lt('closes_at', maintenant)
    // Une quinzaine suffit : au-dela, c'est un rattrapage et le passage suivant
    // prendra la suite. Tout traiter d'un coup depasserait le temps processeur
    // du Worker un lendemain de panne.
    .order('closes_at', { ascending: false })
    .limit(15)

  for (const concours of echus ?? []) {
    const reference = `contest:${concours.id}`

    const { data: deja } = await service
      .from('point_ledger')
      .select('id')
      .eq('reference', reference)
      .limit(1)
    if ((deja ?? []).length > 0) continue

    const { data: participations } = await service
      .from('contest_entries')
      .select('user_id, score, started_at, submitted_at')
      .eq('contest_id', concours.id)

    const ecritures = closingEntries(
      concours.id as string,
      concours.title as string,
      (concours.points_prize as number) ?? 0,
      (participations ?? []).map((p) => ({
        userId: p.user_id as string,
        score: p.score as number | null,
        startedAt: p.started_at as string,
        submittedAt: p.submitted_at as string | null,
      })),
    )

    // Un concours sans copie rendue n'est pas une erreur : personne n'a joue.
    // Il reste « non paye », et le passage suivant le reverra sans rien faire.
    if (ecritures.length === 0) continue

    const { error } = await service.from('point_ledger').insert(ecritures)
    if (error) {
      console.error(`[concours] attribution impossible ${concours.id}`, error)
      continue
    }
    closed += 1
    awarded += ecritures.length
  }

  // --- Ouvrir celui de la semaine ----------------------------------------
  const fenetre = weekWindow(now)
  const { data: dejaOuvert } = await service
    .from('contests')
    .select('id')
    .eq('opens_at', fenetre.opensAt)
    .limit(1)

  if ((dejaOuvert ?? []).length > 0) {
    return { closed, awarded, opened: null }
  }

  const testId = testForWeek(fenetre.opensAt, TESTS_DE_CONCOURS)
  if (!testId) return { closed, awarded, opened: null }

  // Le test doit exister : sur une base dont le referentiel n'est pas seme,
  // inserer echouerait sur la cle etrangere et le cron se plaindrait chaque
  // nuit sans que personne ne sache pourquoi.
  const { data: test } = await service
    .from('tests')
    .select('id')
    .eq('id', testId)
    .maybeSingle()
  if (!test) {
    console.warn(`[concours] test ${testId} absent : aucun concours ouvert`)
    return { closed, awarded, opened: null }
  }

  const semaine = fenetre.opensAt.slice(0, 10)
  const { data: ouvert, error: erreurOuverture } = await service
    .from('contests')
    .insert({
      test_id: testId,
      title: `Concours de la semaine du ${semaine}`,
      opens_at: fenetre.opensAt,
      closes_at: fenetre.closesAt,
      points_prize: ENJEU_HEBDOMADAIRE,
    })
    .select('id')
    .maybeSingle()

  if (erreurOuverture) {
    console.error('[concours] ouverture impossible', erreurOuverture)
    return { closed, awarded, opened: null }
  }

  return { closed, awarded, opened: (ouvert?.id as string) ?? null }
}

/**
 * Declenchement du cycle, reserve a la cle de service.
 *
 * Le cron l'appelle chaque nuit ; ce point d'entree sert aussi a verifier apres
 * un deploiement, et a rattraper une execution manquee. Comme la generation des
 * seances, il n'est pas ouvert a un compte : un client qui pourrait le
 * declencher pourrait le declencher mille fois.
 */
app.post('/contests/cycle', async (c) => {
  const cle = c.req.header('X-Service-Key')
  if (!cle || cle !== process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return c.json({ error: 'Non autorise.' }, 401)
  }
  return c.json(await cycleContests())
})

/* ===========================================================================
 * Le dossier du professeur : ses pieces
 * ===========================================================================
 *
 * --- Le defaut que ceci corrige ------------------------------------------
 *
 * Les quatre pastilles du profil — identite, diplome, competence, experience
 * — ne pouvaient passer au vert que depuis le telephone. Sur le site, la
 * fiche etait en lecture seule : un professeur qui n'a pas l'application
 * restait non verifie a vie, et des professeurs verifies sont precisement ce
 * que ce produit vend.
 *
 * --- Pourquoi le fichier ne traverse pas le Worker ----------------------
 *
 * Le serveur signe une adresse, le navigateur y envoie les octets. Un
 * diplome scanne pese 3 a 5 Mo ; le faire passer par un Worker reviendrait a
 * payer du temps de calcul pour recopier un fichier d'un tuyau dans un
 * autre, avec une limite de taille de requete au bout.
 *
 * C'est le serveur qui choisit la cle, jamais le client : une adresse signee
 * autorise n'importe quel contenu sous *cette* cle, donc laisser le client la
 * nommer lui permettrait d'ecraser la piece de quelqu'un d'autre.
 */

const documentsConfig = {
  endpoint: (process.env.R2_ENDPOINT ?? '').trim(),
  // Un depot a part quand il existe. A defaut celui des enregistrements, qui
  // est prive et signe de la meme facon : mieux vaut un prefixe dans un
  // depot ferme que pas de depot du tout.
  bucket: (
    process.env.R2_DOCUMENTS_BUCKET
    ?? process.env.R2_RECORDINGS_BUCKET
    ?? ''
  ).trim(),
  accessKey: (process.env.R2_ACCESS_KEY_ID ?? '').trim(),
  secret: (process.env.R2_SECRET_ACCESS_KEY ?? '').trim(),
  region: (process.env.R2_REGION ?? 'auto').trim(),
}
const documents = R2.isConfigured(documentsConfig)
  ? new R2(documentsConfig)
  : null

/** Les types de piece qu'un professeur depose lui-meme. */
const TYPES_PIECE = ['ID_FRONT', 'ID_BACK', 'SELFIE', 'DIPLOMA', 'CV'] as const

const pieceSchema = z.object({
  type: z.enum(TYPES_PIECE),
  // Pour choisir l'extension, et pour refuser un exécutable. Jamais pour
  // nommer la cle : le nom d'origine peut contenir n'importe quoi.
  contentType: z.enum([
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  ]),
  sizeBytes: z
    .number()
    .int()
    .positive()
    // 12 Mo : un scan de diplome en PDF depasse rarement 5 Mo, et au-dela
    // c'est une photo non compressee qu'il vaut mieux refuser tout de suite
    // que de faire monter pendant huit minutes sur un reseau guineen.
    .max(12 * 1024 * 1024),
})

const EXTENSIONS: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'application/pdf': 'pdf',
}

/** Les pieces deja deposees, et leur etat de verification. */
app.get('/teacher/documents', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ documents: [] })

  const { data, error } = await asService()
    .from('teacher_documents')
    .select('id, type, status, size_bytes, created_at, updated_at')
    .eq('teacher_id', teacherId)
    .order('created_at', { ascending: false })

  if (error) {
    console.error('[pieces] lecture impossible', error)
    return c.json({ error: 'Lecture impossible.' }, 500)
  }

  return c.json({
    documents: (data ?? []).map((piece) => ({
      id: piece.id,
      type: piece.type,
      status: piece.status,
      sizeBytes: piece.size_bytes,
      createdAt: piece.created_at,
      updatedAt: piece.updated_at,
    })),
    // Le chemin de stockage ne sort jamais : il ne servirait a rien au client
    // (le depot est prive) et il dit ou chercher.
  })
})

/**
 * Une adresse pour deposer une piece, valable dix minutes.
 *
 * La ligne est creee avant le depot, a l'etat `PENDING_UPLOAD` : si le
 * telechargement echoue, on garde la trace d'une tentative plutot qu'un
 * fichier orphelin dont personne ne connait le proprietaire.
 */
app.post('/teacher/documents', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  if (!documents) {
    return c.json(
      {
        error:
          'Le depot de pieces n’est pas configure sur ce serveur. '
          + 'Contactez le support.',
      },
      503,
    )
  }

  const corps = pieceSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) {
    return c.json(
      {
        error:
          'Fichier refuse. Acceptes : photo JPEG, PNG, WEBP ou PDF, '
          + '12 Mo au maximum.',
      },
      400,
    )
  }
  const { type, contentType, sizeBytes } = corps.data

  const service = asService()

  // Une piece par type : la seconde remplace la premiere. Un professeur qui
  // reprend une photo floue ne doit pas laisser derriere lui une pile de
  // versions dont le verificateur ne saurait pas laquelle regarder.
  await service
    .from('teacher_documents')
    .delete()
    .eq('teacher_id', teacherId)
    .eq('type', type)
    .neq('status', 'VERIFIED')

  const cle = `pieces/${teacherId}/${type}-${Date.now()}.${
    EXTENSIONS[contentType]
  }`

  const { data: ligne, error } = await service
    .from('teacher_documents')
    .insert({
      teacher_id: teacherId,
      type,
      storage_path: cle,
      size_bytes: sizeBytes,
      status: 'PENDING_UPLOAD',
    })
    .select('id')
    .single()

  if (error || !ligne) {
    console.error('[pieces] creation impossible', error)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }

  const url = await documents.presign({
    method: 'PUT',
    key: cle,
    // Dix minutes : assez pour 5 Mo sur une connexion lente, assez court
    // pour qu'une adresse recuperee dans un journal ne serve plus a rien.
    expiresInSeconds: 600,
  })

  return c.json({ id: ligne.id, uploadUrl: url, expiresInSeconds: 600 })
})

/**
 * Le depot a abouti.
 *
 * Le navigateur le declare apres son `PUT`. On ne le croit pas sur parole
 * pour autant : l'etat devient `UPLOADED`, pas `VERIFIED`. La verification
 * est un acte humain, et c'est elle qui allume la pastille.
 */
app.post('/teacher/documents/:id/uploaded', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const { data, error } = await asService()
    .from('teacher_documents')
    .update({ status: 'UPLOADED', updated_at: new Date().toISOString() })
    .eq('id', c.req.param('id'))
    // La piece est-elle bien la sienne ? Sans ce filtre, un identifiant devine
    // ferait avancer le dossier d'un autre.
    .eq('teacher_id', teacherId)
    .eq('status', 'PENDING_UPLOAD')
    .select('id, type, status')
    .maybeSingle()

  if (error) {
    console.error('[pieces] mise a jour impossible', error)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }
  if (!data) return c.json({ error: 'Piece introuvable.' }, 404)

  return c.json({ id: data.id, type: data.type, status: data.status })
})

/* ===========================================================================
 * Les revenus et les retraits
 * ===========================================================================
 *
 * --- Pourquoi un calcul et non un solde stocke --------------------------
 *
 * Trois sources alimentent ce que gagne un professeur, et aucune n'a la meme
 * forme : les places vendues sur ses seances, les achats de ses cours video,
 * les echeances reglees de ses contrats. Un solde stocke devrait etre mis a
 * jour par chacun de ces trois chemins, et le jour ou l'un oublie, c'est le
 * solde qu'on croit plutot que les mouvements.
 *
 * `revenus_enseignant()` (migration 0031) additionne les trois en une
 * requete, sous `security definer` : les places appartiennent aux familles,
 * et leurs politiques cachent au professeur ce qu'il a lui-meme encaisse.
 */

/**
 * Le plancher d'un retrait.
 *
 * Chaque virement Orange Money coute une commission a peu pres fixe : sous
 * ce montant, elle mange la somme. Le professeur attend donc d'avoir de quoi
 * que le virement vaille la peine, et l'ecran le lui dit avant qu'il demande.
 */
const RETRAIT_MINIMUM = 50_000

app.get('/teacher/revenue', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const service = asService()

  const { data, error } = await service.rpc('revenus_enseignant', {
    prof: teacherId,
  })
  if (error) {
    console.error('[revenus] calcul impossible', error)
    return c.json({ error: 'Lecture impossible.' }, 500)
  }

  // `returns table` rend un tableau d'une ligne.
  const ligne = (Array.isArray(data) ? data[0] : data) as Record<
    string,
    number
  > | null

  const direct = Number(ligne?.direct_gnf ?? 0)
  const videos = Number(ligne?.videos_gnf ?? 0)
  const contrats = Number(ligne?.contrats_gnf ?? 0)
  const retire = Number(ligne?.retire_gnf ?? 0)
  const enCours = Number(ligne?.en_cours_gnf ?? 0)

  const { data: retraits } = await service
    .from('payout_requests')
    .select('id, amount, method, status, decision_note, requested_at, settled_at')
    .eq('teacher_id', teacherId)
    .order('requested_at', { ascending: false })
    .limit(20)

  const gagne = direct + videos + contrats

  return c.json({
    // Ce qui a ete gagne, par origine : « 1 200 000 » sans dire d'ou il
    // vient ne permet pas de decider quoi faire de plus.
    earned: { live: direct, videos, contracts: contrats, total: gagne },
    seats: Number(ligne?.places ?? 0),
    purchases: Number(ligne?.achats ?? 0),
    paidOut: retire,
    pending: enCours,
    // Ce qu'il peut demander maintenant. Jamais negatif : un arrondi ou une
    // correction manuelle ne doit pas afficher « -15 000 a retirer ».
    available: Math.max(0, gagne - retire - enCours),
    minimum: RETRAIT_MINIMUM,
    payouts: (retraits ?? []).map((r) => ({
      id: r.id,
      amount: r.amount,
      method: r.method,
      status: r.status,
      note: r.decision_note,
      requestedAt: r.requested_at,
      settledAt: r.settled_at,
    })),
  })
})

const retraitSchema = z.object({
  amount: z.number().int().positive(),
  method: z.enum(['ORANGE', 'MTN', 'CASH']),
  /** Les quatre derniers chiffres du numero, pour qu'il reconnaisse le sien. */
  last4: z
    .string()
    .regex(/^[0-9]{4}$/)
    .optional(),
})

/**
 * Demander un retrait.
 *
 * Le montant est verifie **ici** contre ce qui est reellement disponible, et
 * c'est pourquoi `payout_requests` n'a aucune politique d'insertion : un
 * client qui pourrait inserer demanderait un million sur un solde de zero.
 *
 * Le double appui est tenu par l'index partiel de 0031, pas par ce code : une
 * seule demande peut etre en cours par professeur, et c'est la base qui le
 * refuse. Un controle en lecture puis ecriture laisserait passer deux
 * requetes parties en meme temps.
 */
app.post('/teacher/payouts', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const corps = retraitSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) return c.json({ error: 'Demande illisible.' }, 400)
  const { amount, method, last4 } = corps.data

  if (amount < RETRAIT_MINIMUM) {
    return c.json(
      {
        error:
          `Le retrait minimum est de ${RETRAIT_MINIMUM.toLocaleString('fr-FR')} `
          + 'GNF : en dessous, la commission du transfert mange la somme.',
      },
      400,
    )
  }

  const service = asService()

  const { data, error: erreurCalcul } = await service.rpc(
    'revenus_enseignant',
    { prof: teacherId },
  )
  if (erreurCalcul) {
    console.error('[retrait] calcul impossible', erreurCalcul)
    return c.json({ error: 'Calcul impossible.' }, 500)
  }
  const ligne = (Array.isArray(data) ? data[0] : data) as Record<
    string,
    number
  > | null
  const disponible = Math.max(
    0,
    Number(ligne?.direct_gnf ?? 0)
      + Number(ligne?.videos_gnf ?? 0)
      + Number(ligne?.contrats_gnf ?? 0)
      - Number(ligne?.retire_gnf ?? 0)
      - Number(ligne?.en_cours_gnf ?? 0),
  )

  if (amount > disponible) {
    return c.json(
      {
        error:
          'Montant supérieur à ce qui est disponible '
          + `(${disponible.toLocaleString('fr-FR')} GNF).`,
      },
      400,
    )
  }

  const { data: creee, error } = await service
    .from('payout_requests')
    .insert({
      teacher_id: teacherId,
      amount,
      method,
      method_last4: last4 ?? null,
    })
    .select('id, amount, method, status, requested_at')
    .single()

  if (error) {
    // 23505 : l'index partiel a refuse une seconde demande en cours. Ce n'est
    // pas une panne, c'est la reponse — et elle se lit mieux ainsi qu'en
    // « erreur serveur ».
    if (error.code === '23505') {
      return c.json(
        {
          error:
            'Vous avez déjà une demande en cours. Elle doit être réglée '
            + 'avant la suivante.',
        },
        409,
      )
    }
    console.error('[retrait] enregistrement impossible', error)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }

  return c.json({
    id: creee.id,
    amount: creee.amount,
    method: creee.method,
    status: creee.status,
    requestedAt: creee.requested_at,
  })
})

/* ===========================================================================
 * Les cours a domicile
 * ===========================================================================
 *
 * --- Pourquoi c'est la ligne la plus importante de cette serie -----------
 *
 * C'est la plus riche du modele economique : 500 000 a 900 000 GNF par mois
 * et par eleve, contre quelques milliers pour une place en direct. Les
 * tables existaient depuis `0001_schema.sql` ; aucune route ne les servait,
 * sur aucun client. Une offre a domicile ne pouvait donc ni se publier ni se
 * recevoir.
 *
 * --- Une offre, pas un tarif impose --------------------------------------
 *
 * `hourly_rate` est ce que le professeur demande, et le dossier de reference
 * le dit explicitement : on est toujours pret a negocier avec les parents.
 * Le serveur ne plafonne donc rien — il refuse seulement l'absurde, qui
 * trahit une faute de frappe plutot qu'une intention.
 */

const offreDomicileSchema = z.object({
  subjectId: z.string().min(1),
  levelIds: z.array(z.string().min(1)).min(1).max(12),
  mode: z.enum(['AT_STUDENT', 'AT_TEACHER', 'ONLINE']).default('AT_STUDENT'),
  // 1 000 a 5 000 000 GNF : en dessous c'est un zero oublie, au-dessus c'en
  // est un de trop. Entre les deux, c'est au professeur de decider.
  hourlyRate: z.number().int().min(1_000).max(5_000_000).optional(),
  city: z.string().max(80).optional(),
  districts: z.array(z.string().min(1).max(80)).max(12).default([]),
  availabilityNote: z.string().max(400).optional(),
  description: z.string().max(1500).optional(),
  active: z.boolean().default(true),
})

/**
 * Les offres a domicile, publiques.
 *
 * Publique comme la liste des professeurs et celle des offres d'emploi : on
 * regarde avant d'ouvrir un compte, et l'accueil promet deja que « le compte
 * n'est reclame qu'au moment de contacter quelqu'un ». RLS l'autorise depuis
 * 0002 — `active or teacher_id = my_teacher_id()`.
 *
 * Ce qu'elle ne montre pas, et ne doit jamais montrer : le telephone, le
 * courriel et les pieces. Ils ne circulent qu'apres mise en relation (§30).
 */
app.get('/tutoring/offers', async (c) => {
  const ville = (c.req.query('city') ?? '').trim()
  const matiere = (c.req.query('subjectId') ?? '').trim()

  let requete = asService()
    .from('tutoring_services')
    .select(
      'id, teacher_id, subject_id, level_ids, mode, hourly_rate, city, '
        + 'districts, availability_note, description, '
        + 'subjects ( id, name ), '
        + 'teachers!inner ( id, headline, city, years_experience, '
        + 'profiles!inner ( first_name, last_name, suspended ) )',
    )
    .eq('active', true)
    // Un compte suspendu ne doit pas rester au catalogue : la jointure
    // `!inner` sur `profiles` permet de filtrer dessus.
    .eq('teachers.profiles.suspended', false)
    .order('created_at', { ascending: false })
    .limit(60)

  if (ville) requete = requete.ilike('city', `%${ville}%`)
  if (matiere) requete = requete.eq('subject_id', matiere)

  const { data, error } = await requete
  if (error) {
    console.error('[domicile] catalogue illisible', error)
    return c.json({ error: 'Lecture impossible.' }, 500)
  }

  const lignes = (data ?? []) as unknown as Record<string, unknown>[]

  return c.json({
    offers: lignes.map((offre) => {
      const matiereLue = offre.subjects as { id?: string; name?: string } | null
      const prof = offre.teachers as Record<string, unknown> | null
      const compte = prof?.profiles as Record<string, unknown> | null
      const prenom = String(compte?.first_name ?? '').trim()
      const nom = String(compte?.last_name ?? '').trim()
      return {
        id: offre.id,
        teacherId: offre.teacher_id,
        // Le prenom et l'initiale, pas le nom complet : c'est ce que montre
        // deja la liste publique des professeurs.
        teacherName: nom ? `${prenom} ${nom.charAt(0)}.` : prenom,
        headline: prof?.headline ?? null,
        yearsExperience: prof?.years_experience ?? 0,
        subject: {
          id: matiereLue?.id ?? offre.subject_id,
          name: matiereLue?.name ?? '',
        },
        levelIds: offre.level_ids ?? [],
        mode: offre.mode,
        hourlyRate: offre.hourly_rate,
        city: offre.city,
        districts: offre.districts ?? [],
        availabilityNote: offre.availability_note,
        description: offre.description,
      }
    }),
  })
})

/** Mes offres a domicile. */
app.get('/tutoring/services/mine', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ services: [] })

  const { data, error } = await asService()
    .from('tutoring_services')
    .select(
      'id, subject_id, level_ids, mode, hourly_rate, city, districts, '
        + 'availability_note, description, active, created_at, '
        + 'subjects ( id, name )',
    )
    .eq('teacher_id', teacherId)
    .order('created_at', { ascending: false })

  if (error) {
    console.error('[domicile] lecture impossible', error)
    return c.json({ error: 'Lecture impossible.' }, 500)
  }

  // La relation imbriquee depasse l'inference de supabase-js, qui rend alors
  // un type d'erreur. Meme transtypage que partout ailleurs dans ce fichier.
  const offres = (data ?? []) as unknown as Record<string, unknown>[]

  return c.json({
    services: offres.map((offre) => {
      const matiere = offre.subjects as { id?: string; name?: string } | null
      return {
        id: offre.id,
        subject: { id: matiere?.id ?? offre.subject_id, name: matiere?.name ?? '' },
        levelIds: offre.level_ids ?? [],
        mode: offre.mode,
        hourlyRate: offre.hourly_rate,
        city: offre.city,
        districts: offre.districts ?? [],
        availabilityNote: offre.availability_note,
        description: offre.description,
        active: offre.active,
        createdAt: offre.created_at,
      }
    }),
  })
})

/** Publier une offre a domicile. */
app.post('/tutoring/services', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const corps = offreDomicileSchema.safeParse(
    await c.req.json().catch(() => ({})),
  )
  if (!corps.success) {
    return c.json(
      { error: 'Offre incomplete : matiere et au moins un niveau.' },
      400,
    )
  }
  const o = corps.data

  const service = asService()

  // La ville par defaut est celle du profil : la redemander alors qu'elle a
  // ete donnee a l'inscription est exactement la redondance que l'audit du
  // 04/10 reprochait au parcours.
  let ville = o.city
  if (!ville) {
    const { data: fiche } = await service
      .from('teachers')
      .select('city')
      .eq('id', teacherId)
      .maybeSingle()
    ville = (fiche?.city as string) ?? undefined
  }

  const { data, error } = await service
    .from('tutoring_services')
    .insert({
      teacher_id: teacherId,
      subject_id: o.subjectId,
      level_ids: o.levelIds,
      mode: o.mode,
      hourly_rate: o.hourlyRate ?? null,
      city: ville ?? null,
      districts: o.districts,
      availability_note: o.availabilityNote ?? null,
      description: o.description ?? null,
      active: o.active,
    })
    .select('id')
    .single()

  if (error) {
    // 23503 : la matiere n'existe pas. Le dire plutot que « erreur serveur ».
    if (error.code === '23503') {
      return c.json({ error: 'Matiere ou niveau inconnu.' }, 400)
    }
    console.error('[domicile] publication impossible', error)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }

  return c.json({ id: data.id })
})

/** Retirer ou remettre une offre. */
app.patch('/tutoring/services/:id', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const corps = z
    .object({
      active: z.boolean().optional(),
      hourlyRate: z.number().int().min(1_000).max(5_000_000).optional(),
    })
    .safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) return c.json({ error: 'Demande illisible.' }, 400)

  const modification: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  }
  if (corps.data.active !== undefined) modification.active = corps.data.active
  if (corps.data.hourlyRate !== undefined) {
    modification.hourly_rate = corps.data.hourlyRate
  }

  const { data, error } = await asService()
    .from('tutoring_services')
    .update(modification)
    .eq('id', c.req.param('id'))
    .eq('teacher_id', teacherId)
    .select('id, active, hourly_rate')
    .maybeSingle()

  if (error) {
    console.error('[domicile] mise a jour impossible', error)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }
  if (!data) return c.json({ error: 'Offre introuvable.' }, 404)

  return c.json({ id: data.id, active: data.active, hourlyRate: data.hourly_rate })
})

/**
 * Les demandes recues sur mes offres.
 *
 * Lu avec la cle de service, et restreint a la main : le professeur voit le
 * prenom de l'enfant, la matiere et la date souhaitee. Ni telephone ni
 * adresse — ils ne circulent qu'apres mise en relation (§30), et c'est la
 * seule chose qui rende acceptable qu'un inconnu publie une offre a domicile
 * pour des mineurs.
 */
app.get('/tutoring/requests', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ requests: [] })

  const service = asService()

  const { data: miennes } = await service
    .from('tutoring_services')
    .select('id')
    .eq('teacher_id', teacherId)

  const ids = (miennes ?? []).map((o) => o.id as string)
  if (ids.length === 0) return c.json({ requests: [] })

  const { data, error } = await service
    .from('tutoring_requests')
    .select(
      'id, service_id, status, message, preferred_start, created_at, '
        + 'responded_at, children ( first_name ), '
        + 'tutoring_services ( subjects ( name ) )',
    )
    .in('service_id', ids)
    .order('created_at', { ascending: false })
    .limit(50)

  if (error) {
    console.error('[domicile] demandes illisibles', error)
    return c.json({ error: 'Lecture impossible.' }, 500)
  }

  const lignes = (data ?? []) as unknown as Record<string, unknown>[]

  return c.json({
    requests: lignes.map((demande) => {
      const enfant = demande.children as { first_name?: string } | null
      const offre = demande.tutoring_services as {
        subjects?: { name?: string } | null
      } | null
      return {
        id: demande.id,
        serviceId: demande.service_id,
        status: demande.status,
        message: demande.message,
        preferredStart: demande.preferred_start,
        createdAt: demande.created_at,
        respondedAt: demande.responded_at,
        childName: enfant?.first_name ?? 'Élève',
        subject: offre?.subjects?.name ?? null,
      }
    }),
  })
})

/**
 * Accepter ou refuser une demande.
 *
 * Accepter ouvre le groupe de discussion : c'est le moment ou les deux
 * personnes ont une raison de se parler, et c'est ce passage-la qui
 * transforme une annonce en relation.
 */
app.patch('/tutoring/requests/:id', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const corps = z
    .object({ status: z.enum(['ACCEPTED', 'DECLINED']) })
    .safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) return c.json({ error: 'Demande illisible.' }, 400)

  const service = asService()
  const demandeId = c.req.param('id')

  // L'offre visee est-elle bien la mienne ? Une demande se designe par son
  // identifiant, et rien dans la table ne porte le professeur : c'est la
  // jointure qui le dit.
  const { data: demande } = await service
    .from('tutoring_requests')
    .select('id, service_id, tutoring_services!inner ( teacher_id )')
    .eq('id', demandeId)
    .eq('tutoring_services.teacher_id', teacherId)
    .maybeSingle()

  if (!demande) return c.json({ error: 'Demande introuvable.' }, 404)

  const { error } = await service
    .from('tutoring_requests')
    .update({
      status: corps.data.status,
      responded_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', demandeId)

  if (error) {
    console.error('[domicile] reponse impossible', error)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }

  return c.json({ id: demandeId, status: corps.data.status })
})

/* ===========================================================================
 * L'assistant
 * ===========================================================================
 *
 * --- Ou vit la cle, et pourquoi -----------------------------------------
 *
 * Le navigateur ne parle jamais a Google. Il parle a cette route, qui detient
 * l'unique cle et decide qui a le droit de s'en servir. Une cle prefixee
 * `VITE_` serait recopiee dans le paquet du site par Vite, donc lisible par
 * n'importe quel visiteur — `Gemini` refuse d'ailleurs une cle qui porte ce
 * prefixe plutot que de la laisser passer.
 *
 * --- Les deux garde-fous, et ce qu'ils protegent ------------------------
 *
 * Ils ne protegent pas la meme chose, et c'est pourquoi il en faut deux :
 *
 *   * **la limite par compte** (100 messages par jour) empeche une personne
 *     de monopoliser le service ou de boucler par accident ;
 *   * **le plafond mensuel en dollars** empeche la facture de partir si cent
 *     personnes decouvrent le jouet le meme jour. C'est le seul qui protege
 *     l'argent, et il est lu avant chaque appel.
 *
 * Atteint, le plafond ne rend pas une erreur de panne : il dit que le service
 * est en pause, parce que c'est ce qui se passe.
 *
 * --- Ce qui part chez Google, et ce qui n'en part pas -------------------
 *
 * L'invite ne porte **ni prenom, ni identifiant, ni ville, ni nom d'ecole**.
 * Le serveur envoie les consignes de role, l'historique borne et la question.
 * Google ne peut pas relier deux conversations a la meme personne.
 *
 * ⚠ OFFRE PAYANTE OBLIGATOIRE. En offre gratuite, Google se sert des donnees
 * envoyees pour ameliorer ses produits : inacceptable pour des devoirs
 * d'enfants. L'API ne dit pas de quelle offre releve une cle.
 */

/** 100 messages par jour et par compte (AI_ASSISTANT.md §3.5). */
const AI_MESSAGES_PAR_JOUR = 100

/** Le plafond mensuel, en dollars. Lu dans l'environnement. */
const AI_PLAFOND_USD = Number(process.env.AI_MONTHLY_BUDGET_USD ?? 25) || 25

/**
 * Les tours de parole renvoyes au modele.
 *
 * Huit, soit quatre echanges. « Et pour la question 3 ? » n'a de sens
 * qu'avec ce qui precede ; vingt tours feraient grossir l'entree, donc la
 * facture, sans ameliorer la reponse.
 */
const AI_HISTORIQUE = 8

/** Les consignes, par usage. Courtes : une longue invite est moins suivie. */
const CONSIGNES: Record<string, string> = {
  HOMEWORK: [
    'Tu es un repetiteur guineen patient. Tu aides un eleve a comprendre',
    'son devoir en francais simple.',
    '',
    'Regle absolue : tu ne donnes jamais la reponse finale directement. Tu',
    'donnes la methode, une etape a la fois, et tu poses une question pour',
    'verifier que l eleve suit. Si il insiste pour avoir la reponse, tu',
    'expliques le dernier pas et tu le laisses conclure.',
    '',
    'Tu te refere au programme guineen. Tu utilises des exemples locaux :',
    'francs guineens, Conakry, marche de Madina.',
    '',
    'Trois paragraphes au maximum. Pas de formule de politesse longue.',
  ].join('\n'),
  COURSE: [
    'Tu aides un professeur guineen a preparer son cours.',
    '',
    'Tu rends un plan utilisable tel quel : objectifs, deroule minute par',
    'minute, exercices avec leur corrige. Tu te refere au programme',
    'guineen et aux manuels en usage.',
    '',
    'Tu es concret. Pas de conseils pedagogiques generaux.',
  ].join('\n'),
  GENERAL: [
    'Tu reponds aux questions sur Eduquali et sur la scolarite en Guinee,',
    'en francais simple.',
    '',
    'Tu ne promets rien sur les prix, les abonnements ou les delais : tu',
    'renvoies vers le support. Si tu ne sais pas, tu le dis.',
    '',
    'Court : deux paragraphes au maximum.',
  ].join('\n'),
}

/** Ou en est ce compte de sa limite du jour. */
app.get('/ai/quota', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  if (!gemini) {
    return c.json({ available: false, used: 0, limit: AI_MESSAGES_PAR_JOUR })
  }

  const service = asService()
  const { data } = await service.rpc('ai_messages_du_jour', { qui: userId })
  const { data: cout } = await service.rpc('ai_cout_du_mois')

  const utilises = Number(data ?? 0)
  const depense = Number(cout ?? 0)

  return c.json({
    available: depense < AI_PLAFOND_USD,
    used: utilises,
    limit: AI_MESSAGES_PAR_JOUR,
    remaining: Math.max(0, AI_MESSAGES_PAR_JOUR - utilises),
  })
})

/** Mes conversations, la plus recente d'abord. */
app.get('/ai/conversations', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const { data, error } = await asService()
    .from('ai_conversations')
    .select('id, feature, title, updated_at')
    .eq('owner_id', userId)
    .order('updated_at', { ascending: false })
    .limit(30)

  if (error) {
    console.error('[assistant] conversations illisibles', error)
    return c.json({ error: 'Lecture impossible.' }, 500)
  }

  return c.json({
    conversations: (data ?? []).map((fil) => ({
      id: fil.id,
      feature: fil.feature,
      title: fil.title,
      updatedAt: fil.updated_at,
    })),
  })
})

/** Les messages d'une conversation. */
app.get('/ai/conversations/:id', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const service = asService()
  const { data: fil } = await service
    .from('ai_conversations')
    .select('id, feature, title')
    .eq('id', c.req.param('id'))
    .eq('owner_id', userId)
    .maybeSingle()

  if (!fil) return c.json({ error: 'Conversation introuvable.' }, 404)

  const { data } = await service
    .from('ai_messages')
    .select('id, role, body, created_at')
    .eq('conversation_id', fil.id)
    .order('created_at', { ascending: true })
    .limit(200)

  return c.json({
    id: fil.id,
    feature: fil.feature,
    title: fil.title,
    messages: (data ?? []).map((m) => ({
      id: m.id,
      role: m.role,
      body: m.body,
      createdAt: m.created_at,
    })),
  })
})

/**
 * Les formats d'image acceptes en piece jointe.
 *
 * Trois, et pas un de plus : ce sont ceux que produit l'appareil photo d'un
 * telephone, et ceux que le modele lit nativement. Un PDF demanderait
 * l'API de fichiers de Google — un televersement separe, un identifiant a
 * garder, une duree de vie a gerer — pour un cas qui n'est pas celui d'une
 * photo de cahier.
 */
const AI_IMAGES = ['image/jpeg', 'image/png', 'image/webp'] as const

/**
 * Le poids maximal d'une piece, apres encodage.
 *
 * Quatre megaoctets de base64, soit environ trois megaoctets de fichier :
 * une photo de cahier prise au telephone et compressee tient largement
 * dedans. Au-dela, c'est une photo non compressee — elle coute une seconde
 * de televersement par megaoctet sur un reseau guineen, et le modele n'en
 * lit pas davantage.
 */
const AI_PIECE_MAX = 4 * 1024 * 1024

const aiSchema = z.object({
  message: z.string().min(1).max(4000),
  feature: z.enum(['HOMEWORK', 'COURSE', 'GENERAL']).default('GENERAL'),
  /** Absent au premier message : la route ouvre alors un fil. */
  conversationId: z.string().min(1).optional(),
  /**
   * Une image, encodee en base64, sans son prefixe `data:`.
   *
   * Une seule, et seulement sur la question courante : renvoyer les images
   * de tout l'historique a chaque tour multiplierait la facture par le
   * nombre d'echanges sans rien apporter — le modele a deja decrit l'image
   * dans sa reponse, et c'est ce texte qui fait le contexte.
   */
  attachment: z
    .object({
      mimeType: z.enum(AI_IMAGES),
      data: z.string().min(1).max(AI_PIECE_MAX),
      /** Le nom du fichier, pour l'ecrire dans le fil. Jamais envoye au modele. */
      name: z.string().max(200).optional(),
    })
    .optional(),
})

app.post('/ai/chat', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  if (!gemini) {
    return c.json(
      {
        error:
          'L’assistant n’est pas configuré sur ce serveur. '
          + 'Les autres fonctions restent disponibles.',
      },
      503,
    )
  }

  const corps = aiSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) {
    return c.json({ error: 'Message vide ou trop long (4 000 signes).' }, 400)
  }
  const { message, feature, attachment } = corps.data

  const service = asService()

  // --- Garde-fou 1 : la facture ------------------------------------------
  //
  // Lu avant la limite par compte, et avant tout appel : c'est le seul qui
  // protege l'argent, et il doit s'appliquer meme au premier message d'un
  // compte neuf.
  const { data: cout } = await service.rpc('ai_cout_du_mois')
  if (Number(cout ?? 0) >= AI_PLAFOND_USD) {
    return c.json(
      {
        error:
          'L’assistant est en pause jusqu’au mois prochain. '
          + 'Rien ne vous a été débité.',
      },
      503,
    )
  }

  // --- Garde-fou 2 : la limite du jour ----------------------------------
  const { data: utilises } = await service.rpc('ai_messages_du_jour', {
    qui: userId,
  })
  if (Number(utilises ?? 0) >= AI_MESSAGES_PAR_JOUR) {
    return c.json(
      {
        error:
          `Vous avez atteint ${AI_MESSAGES_PAR_JOUR} messages aujourd’hui. `
          + 'Le compteur repart demain.',
      },
      429,
    )
  }

  // --- Le fil ------------------------------------------------------------
  let filId = corps.data.conversationId ?? null
  if (filId) {
    const { data: existant } = await service
      .from('ai_conversations')
      .select('id')
      .eq('id', filId)
      .eq('owner_id', userId)
      .maybeSingle()
    if (!existant) return c.json({ error: 'Conversation introuvable.' }, 404)
  } else {
    const { data: nouveau, error } = await service
      .from('ai_conversations')
      .insert({
        owner_id: userId,
        feature,
        // Le debut de la premiere question : c'est ce qui s'affiche dans la
        // liste, et c'est ce dont on se souvient d'un fil.
        title: message.slice(0, 80),
      })
      .select('id')
      .single()
    if (error || !nouveau) {
      console.error('[assistant] ouverture impossible', error)
      return c.json({ error: 'Enregistrement impossible.' }, 500)
    }
    filId = nouveau.id as string
  }

  // L'historique borne, du plus ancien au plus recent.
  const { data: precedents } = await service
    .from('ai_messages')
    .select('role, body')
    .eq('conversation_id', filId)
    .order('created_at', { ascending: false })
    .limit(AI_HISTORIQUE)

  const historique = [...(precedents ?? [])].reverse().map((m) => ({
    role: m.role as 'USER' | 'MODEL',
    body: m.body as string,
  }))
  // L'image accompagne **le dernier tour seulement**. Les tours precedents
  // viennent de la base, qui ne garde que leur texte.
  historique.push({
    role: 'USER',
    body: message,
    ...(attachment
      ? {
          attachment: {
            mimeType: attachment.mimeType,
            data: attachment.data,
          },
        }
      : {}),
  })

  /*
   * La question est enregistree avant l'appel : si le modele echoue, elle
   * reste dans le fil et la personne la retrouve au lieu de la retaper.
   *
   * **L'image n'est pas enregistree**, et c'est deliberé. Une photo de
   * cahier porte souvent le nom de l'enfant, parfois celui de l'ecole ; la
   * garder ferait de cette table un depot de donnees d'enfants que rien
   * dans le produit ne reclame. Le fil garde la mention qu'une piece a ete
   * jointe, et cela suffit a relire l'echange.
   */
  await service.from('ai_messages').insert({
    conversation_id: filId,
    role: 'USER',
    body: attachment
      ? `${message}

[Image jointe : ${attachment.name ?? 'photo'}]`
      : message,
  })

  const depart = Date.now()
  try {
    const reponse = await gemini.converse({
      history: historique,
      system: CONSIGNES[feature] ?? CONSIGNES.GENERAL,
    })

    const duree = Date.now() - depart
    const dollars = coutUsd({
      model: reponse.model,
      tokensIn: reponse.tokensIn,
      tokensOut: reponse.tokensOut,
    })

    // Les deux ecritures, puis la reponse. L'ordre compte : le journal
    // d'usage est ce qui alimente le plafond, et un appel paye mais non
    // journalise rend le plafond faux a la baisse.
    await service.from('ai_usage').insert({
      owner_id: userId,
      feature,
      model: reponse.model,
      tokens_in: reponse.tokensIn,
      tokens_out: reponse.tokensOut,
      cost_usd: dollars,
      duration_ms: duree,
      status: 'OK',
    })

    const { data: ecrit } = await service
      .from('ai_messages')
      .insert({ conversation_id: filId, role: 'MODEL', body: reponse.text })
      .select('id, created_at')
      .single()

    await service
      .from('ai_conversations')
      .update({ updated_at: new Date().toISOString() })
      .eq('id', filId)

    return c.json({
      conversationId: filId,
      id: ecrit?.id ?? null,
      body: reponse.text,
      createdAt: ecrit?.created_at ?? new Date().toISOString(),
    })
  } catch (cause) {
    // Un echec est journalise lui aussi, a cout nul : sans cette ligne, une
    // panne de dix minutes serait invisible dans les relevés.
    await service.from('ai_usage').insert({
      owner_id: userId,
      feature,
      model: MODELS.chat,
      duration_ms: Date.now() - depart,
      status: 'ERROR',
    })

    const status =
      cause instanceof GeminiError ? cause.status : 502
    const message =
      cause instanceof GeminiError
        ? cause.message
        : 'L’assistant n’a pas répondu. Réessayez dans un instant.'
    console.error('[assistant] appel echoue', cause)
    // 422 : refus de securite, deja formule pour l'affichage. Les autres sont
    // reecrits — le message de Google n'est pas destine a un professeur.
    return c.json(
      { conversationId: filId, error: status === 422 ? message : message },
      status === 422 ? 422 : 502,
    )
  }
})

/* ===========================================================================
 * La creation d'un cours video
 * ===========================================================================
 *
 * --- Le vide que ceci remplit -------------------------------------------
 *
 * `sync.ts` refuse depuis toujours l'ecriture directe de `video_courses`,
 * `course_chapters` et `course_items`, et chacun des trois refus renvoie vers
 * « une route dediee ». Ces routes n'existaient pas. Un professeur ne pouvait
 * donc pas creer un cours video, sur aucun des deux clients — la table etait
 * remplie par le jeu de demonstration et par rien d'autre.
 *
 * --- Le prix est relu ici ------------------------------------------------
 *
 * C'est la raison du refus cote synchronisation, et elle tient : un prix
 * ecrit par un client est un prix que le client choisit, y compris zero sur
 * un cours payant, ou un million sur le cours de quelqu'un d'autre.
 *
 * --- Le chemin d'une video ----------------------------------------------
 *
 *   1. le navigateur demande une adresse de depot -> R2, cle choisie ici ;
 *   2. il y envoie le fichier directement ;
 *   3. il declare le depot fini ;
 *   4. le serveur demande a Stream d'ingerer depuis une adresse signee en
 *      lecture, et garde l'identifiant rendu.
 *
 * C'est exactement le chemin des enregistrements de seance, deja eprouve.
 * Le fichier ne traverse jamais le Worker.
 */

const PRIX_COURS_MAX = 2_000_000

const coursVideoSchema = z.object({
  title: z.string().min(3).max(140),
  description: z.string().max(4000).optional(),
  subjectId: z.string().min(1),
  levelIds: z.array(z.string().min(1)).min(1).max(12),
  // Zero est permis, et c'est un choix : un cours offert fait venir du monde
  // sur les suivants. Au-dela de deux millions, c'est un zero de trop.
  price: z.number().int().min(0).max(PRIX_COURS_MAX),
  chapters: z
    .array(
      z.object({
        title: z.string().min(1).max(140),
        description: z.string().max(1000).optional(),
      }),
    )
    .min(1)
    .max(30),
})

/** Mes cours video, publies ou non. */
app.get('/courses/mine', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ courses: [] })

  const service = asService()
  const { data, error } = await service
    .from('video_courses')
    .select(
      'id, title, description, subject_id, level_ids, price, status, '
        + 'purchase_count, created_at, subjects ( name )',
    )
    .eq('teacher_id', teacherId)
    .order('created_at', { ascending: false })

  if (error) {
    console.error('[cours] lecture impossible', error)
    return c.json({ error: 'Lecture impossible.' }, 500)
  }

  const lignes = (data ?? []) as unknown as Record<string, unknown>[]
  const ids = lignes.map((cours) => cours.id as string)

  // Le nombre de chapitres et d'elements deposes, en une requete : « cours
  // en brouillon » sans dire s'il contient deja trois videos ne permet pas
  // de savoir ce qu'il reste a faire.
  const compte = new Map<string, { chapitres: number; elements: number }>()
  if (ids.length > 0) {
    const { data: chapitres } = await service
      .from('course_chapters')
      .select('id, course_id')
      .in('course_id', ids)
    const parChapitre = new Map<string, string>()
    for (const chapitre of chapitres ?? []) {
      const cours = chapitre.course_id as string
      parChapitre.set(chapitre.id as string, cours)
      const actuel = compte.get(cours) ?? { chapitres: 0, elements: 0 }
      actuel.chapitres += 1
      compte.set(cours, actuel)
    }
    if (parChapitre.size > 0) {
      const { data: elements } = await service
        .from('course_items')
        .select('id, chapter_id')
        .in('chapter_id', [...parChapitre.keys()])
      for (const element of elements ?? []) {
        const cours = parChapitre.get(element.chapter_id as string)
        if (!cours) continue
        const actuel = compte.get(cours) ?? { chapitres: 0, elements: 0 }
        actuel.elements += 1
        compte.set(cours, actuel)
      }
    }
  }

  return c.json({
    courses: lignes.map((cours) => {
      const matiere = cours.subjects as { name?: string } | null
      const n = compte.get(cours.id as string) ?? { chapitres: 0, elements: 0 }
      return {
        id: cours.id,
        title: cours.title,
        description: cours.description,
        subject: matiere?.name ?? null,
        // `level_ids` est une chaine separee par des virgules sur cette
        // table, et non un tableau : elle precede la convention actuelle.
        levelIds: String(cours.level_ids ?? '')
          .split(',')
          .filter((v) => v !== ''),
        price: cours.price,
        status: cours.status,
        purchaseCount: cours.purchase_count,
        chapters: n.chapitres,
        items: n.elements,
        createdAt: cours.created_at,
      }
    }),
  })
})

/** Creer un cours video, en brouillon, avec ses chapitres. */
app.post('/courses', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const corps = coursVideoSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) {
    return c.json(
      {
        error:
          'Cours incomplet : un titre, une matiere, un niveau, un prix et '
          + 'au moins un chapitre.',
      },
      400,
    )
  }
  const cours = corps.data

  const service = asService()
  const coursId = crypto.randomUUID()

  const { error } = await service.from('video_courses').insert({
    id: coursId,
    teacher_id: teacherId,
    title: cours.title,
    description: cours.description ?? null,
    subject_id: cours.subjectId,
    level_ids: cours.levelIds.join(','),
    price: cours.price,
    // Brouillon : un cours sans video ne doit pas apparaitre au catalogue.
    // C'est la publication, plus tard, qui verifie qu'il a du contenu.
    status: 'DRAFT',
  })

  if (error) {
    if (error.code === '23503') {
      return c.json({ error: 'Matiere inconnue.' }, 400)
    }
    console.error('[cours] creation impossible', error)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }

  const chapitres = cours.chapters.map((chapitre, index) => ({
    id: crypto.randomUUID(),
    course_id: coursId,
    title: chapitre.title,
    description: chapitre.description ?? null,
    position: index,
  }))

  const { error: erreurChapitres } = await service
    .from('course_chapters')
    .insert(chapitres)

  if (erreurChapitres) {
    // Le cours sans ses chapitres ne sert a rien : on le retire plutot que de
    // laisser un brouillon vide que le professeur ne saura pas reparer.
    await service.from('video_courses').delete().eq('id', coursId)
    console.error('[cours] chapitres impossibles', erreurChapitres)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }

  return c.json({
    id: coursId,
    status: 'DRAFT',
    chapters: chapitres.map((chapitre) => ({
      id: chapitre.id,
      title: chapitre.title,
      position: chapitre.position,
    })),
  })
})

/** Le detail d'un de mes cours, avec ses chapitres et ses elements. */
app.get('/courses/:id/content', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const service = asService()
  const { data: cours } = await service
    .from('video_courses')
    .select('id, title, status, price')
    .eq('id', c.req.param('id'))
    .eq('teacher_id', teacherId)
    .maybeSingle()

  if (!cours) return c.json({ error: 'Cours introuvable.' }, 404)

  const { data: chapitres } = await service
    .from('course_chapters')
    .select('id, title, description, position')
    .eq('course_id', cours.id)
    .order('position', { ascending: true })

  const ids = (chapitres ?? []).map((chapitre) => chapitre.id as string)

  // `.in('x', [])` rend zero ligne sans erreur : la requete part toujours,
  // plutot qu'un ternaire dont les deux branches n'ont pas le meme type.
  const { data: elementsLus } = await service
    .from('course_items')
    .select(
      'id, chapter_id, kind, title, position, duration_seconds, '
        + 'provider_status',
    )
    .in('chapter_id', ids)
    .order('position', { ascending: true })
  const elements = (elementsLus ?? []) as unknown as Record<
    string,
    unknown
  >[]

  return c.json({
    id: cours.id,
    title: cours.title,
    status: cours.status,
    price: cours.price,
    chapters: (chapitres ?? []).map((chapitre) => ({
      id: chapitre.id,
      title: chapitre.title,
      description: chapitre.description,
      position: chapitre.position,
      items: elements
        .filter((element) => element.chapter_id === chapitre.id)
        .map((element) => ({
          id: element.id,
          kind: element.kind,
          title: element.title,
          position: element.position,
          durationSeconds: element.duration_seconds,
          status: element.provider_status,
        })),
    })),
  })
})

const elementSchema = z.object({
  chapterId: z.string().min(1),
  title: z.string().min(1).max(140),
  // 600 Mo : une heure de cours filmee au telephone. Au-dela, le depot
  // n'aboutira pas sur une connexion guineenne, et il vaut mieux le dire.
  sizeBytes: z
    .number()
    .int()
    .positive()
    .max(600 * 1024 * 1024),
  contentType: z.enum(['video/mp4', 'video/quicktime', 'video/webm']),
})

/** Une adresse pour deposer la video d'un chapitre. */
app.post('/courses/items', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  if (!documents) {
    return c.json({ error: 'Le depot video n’est pas configure.' }, 503)
  }

  const corps = elementSchema.safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) {
    return c.json(
      { error: 'Video refusee. MP4, MOV ou WEBM, 600 Mo au maximum.' },
      400,
    )
  }

  const service = asService()

  // Le chapitre appartient-il a un de mes cours ? Sans ce controle, un
  // identifiant devine ferait deposer une video dans le cours d'un autre.
  const { data: chapitre } = await service
    .from('course_chapters')
    .select('id, course_id, video_courses!inner ( teacher_id )')
    .eq('id', corps.data.chapterId)
    .eq('video_courses.teacher_id', teacherId)
    .maybeSingle()

  if (!chapitre) return c.json({ error: 'Chapitre introuvable.' }, 404)

  const { count } = await service
    .from('course_items')
    .select('id', { count: 'exact', head: true })
    .eq('chapter_id', chapitre.id)

  const elementId = crypto.randomUUID()
  const cle = `cours/${teacherId}/${elementId}.mp4`

  const { error } = await service.from('course_items').insert({
    id: elementId,
    chapter_id: chapitre.id,
    kind: 'VIDEO',
    title: corps.data.title,
    local_path: cle,
    position: count ?? 0,
    provider_status: 'PENDING_UPLOAD',
  })

  if (error) {
    console.error('[cours] element impossible', error)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }

  const url = await documents.presign({
    method: 'PUT',
    key: cle,
    // Trente minutes : une video de 300 Mo sur une connexion a 2 Mbit/s met
    // vingt minutes. Dix auraient expire au milieu du depot.
    expiresInSeconds: 1800,
  })

  return c.json({ id: elementId, uploadUrl: url, expiresInSeconds: 1800 })
})

/**
 * Le depot est fini : faire ingerer la video par Stream.
 *
 * Stream va chercher le fichier lui-meme, par une adresse signee en lecture
 * valable une heure — le temps du transcodage. On garde l'identifiant rendu ;
 * c'est lui que `/videos/:itemId/url` signera plus tard pour la lecture.
 */
app.post('/courses/items/:id/uploaded', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  if (!documents || !video) {
    return c.json({ error: 'L’hebergement video n’est pas configure.' }, 503)
  }

  const service = asService()
  const { data: lu } = await service
    .from('course_items')
    .select(
      'id, local_path, title, chapter_id, '
        + 'course_chapters!inner ( video_courses!inner ( teacher_id ) )',
    )
    .eq('id', c.req.param('id'))
    .eq('course_chapters.video_courses.teacher_id', teacherId)
    .maybeSingle()

  if (!lu) return c.json({ error: 'Element introuvable.' }, 404)
  // Deux niveaux de `!inner` depassent l'inference de supabase-js.
  const element = lu as unknown as Record<string, unknown>

  const cle = element.local_path as string | null
  if (!cle) return c.json({ error: 'Aucun fichier attendu.' }, 409)

  const lecture = await documents.presign({
    method: 'GET',
    key: cle,
    expiresInSeconds: 3600,
  })

  try {
    const videoId = await video.ingestFromUrl({
      url: lecture,
      name: String(element.title ?? 'Cours'),
    })
    await service
      .from('course_items')
      .update({
        provider_video_id: videoId,
        provider_status: 'TRANSFERRING',
        updated_at: new Date().toISOString(),
      })
      .eq('id', element.id)

    return c.json({ id: element.id, status: 'TRANSFERRING' })
  } catch (cause) {
    console.error('[cours] ingestion refusee', cause)
    await service
      .from('course_items')
      .update({ provider_status: 'FAILED' })
      .eq('id', element.id)
    return c.json(
      { error: 'Le transfert vers l’hebergeur video a echoue.' },
      502,
    )
  }
})

/**
 * Publier ou retirer un cours.
 *
 * Publier verifie qu'il y a quelque chose a voir : un cours au catalogue
 * sans une seule video prete est une promesse qu'on ne tient pas, et un
 * acheteur decouvre l'ecran vide apres avoir paye.
 */
app.patch('/courses/:id', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const teacherId = await teacherIdOf(userId)
  if (!teacherId) return c.json({ error: 'Reserve au professeur.' }, 403)

  const corps = z
    .object({
      status: z.enum(['PUBLISHED', 'HIDDEN', 'DRAFT']).optional(),
      price: z.number().int().min(0).max(PRIX_COURS_MAX).optional(),
    })
    .safeParse(await c.req.json().catch(() => ({})))
  if (!corps.success) return c.json({ error: 'Demande illisible.' }, 400)

  const service = asService()
  const coursId = c.req.param('id')

  const { data: cours } = await service
    .from('video_courses')
    .select('id')
    .eq('id', coursId)
    .eq('teacher_id', teacherId)
    .maybeSingle()
  if (!cours) return c.json({ error: 'Cours introuvable.' }, 404)

  if (corps.data.status === 'PUBLISHED') {
    const { data: chapitres } = await service
      .from('course_chapters')
      .select('id')
      .eq('course_id', coursId)
    const ids = (chapitres ?? []).map((chapitre) => chapitre.id as string)
    const { count } = ids.length
      ? await service
          .from('course_items')
          .select('id', { count: 'exact', head: true })
          .in('chapter_id', ids)
          .eq('provider_status', 'READY')
      : { count: 0 }

    if (!count) {
      return c.json(
        {
          error:
            'Aucune video prete. Deposez au moins une video et attendez la '
            + 'fin de sa preparation avant de publier.',
        },
        409,
      )
    }
  }

  const modification: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  }
  if (corps.data.status) modification.status = corps.data.status
  if (corps.data.price !== undefined) modification.price = corps.data.price

  const { data, error } = await service
    .from('video_courses')
    .update(modification)
    .eq('id', coursId)
    .select('id, status, price')
    .single()

  if (error) {
    console.error('[cours] mise a jour impossible', error)
    return c.json({ error: 'Enregistrement impossible.' }, 500)
  }

  return c.json({ id: data.id, status: data.status, price: data.price })
})

/**
 * La preuve de presence d'une seance, pour la famille.
 *
 * --- Ce que cette route sert -------------------------------------------
 *
 * « Votre enfant etait la. Vous le voyez. » C'est la promesse faite au
 * parent, et la seule chose qu'il vient chercher apres une seance. Les
 * minutes partaient deja avec `/live/my-sessions` ; ce qui manquait, ce sont
 * les trois faits que la charte demande autour d'elles : l'heure d'arrivee,
 * les points de controle auxquels l'eleve a repondu, et ce qui a ete
 * travaille.
 *
 * --- Qui peut la lire ---------------------------------------------------
 *
 * La famille qui detient la place, et le professeur du cours. Personne
 * d'autre : « les minutes de presence d'un eleve ne s'affichent qu'a son
 * parent et a son professeur ».
 *
 * Lue sous la cle de service, et restreinte **a la main** : la presence est
 * ecrite par les webhooks LiveKit, donc sous une identite qui n'est celle de
 * personne, et les politiques de `session_attendance` ne sauraient pas
 * decider ici. Le controle ci-dessous est donc le seul qui existe — c'est
 * pourquoi il est le premier du corps, avant toute lecture.
 */
app.get('/live/sessions/:id/presence', async (c) => {
  const userId = c.get('userId')
  if (!userId) return c.json({ error: 'Connectez-vous.' }, 401)

  const sessionId = c.req.param('id')
  const service = asService()

  // --- Qui demande ? -----------------------------------------------------
  const { data: parent } = await service
    .from('parents')
    .select('id')
    .eq('user_id', userId)
    .maybeSingle()
  const teacherId = await teacherIdOf(userId)

  const { data: seance } = await service
    .from('live_sessions')
    .select(
      'id, starts_at, duration_minutes, status, recording_status, '
        + 'recording_video_id, '
        + 'live_courses!inner ( id, title, teacher_id, subjects ( name ), '
        + 'levels ( name ) )',
    )
    .eq('id', sessionId)
    .maybeSingle()

  if (!seance) return c.json({ error: 'Seance introuvable.' }, 404)

  // La jointure `!inner` imbriquee depasse l'inference de supabase-js, qui
  // rend alors un type d'erreur. Meme transtypage que partout ailleurs.
  const lue = seance as unknown as Record<string, unknown>
  const lie = lue.live_courses
  const cours = (Array.isArray(lie) ? lie[0] : lie) as Record<
    string,
    unknown
  > | null

  // --- La place de cette famille sur cette seance -----------------------
  //
  // Une seule, celle qui est confirmee : une place annulee n'a pas de
  // presence a montrer, et une place en attente non plus.
  const { data: place } = parent
    ? await service
        .from('session_enrolments')
        .select('id, child_id, children ( first_name )')
        .eq('session_id', sessionId)
        .eq('parent_id', parent.id)
        .eq('status', 'CONFIRMED')
        .maybeSingle()
    : { data: null }

  const estLeProfesseur = Boolean(teacherId) && cours?.teacher_id === teacherId
  if (!place && !estLeProfesseur) {
    // Indistinguable d'une seance inexistante, volontairement : dire « vous
    // n'avez pas de place sur cette seance » confirmerait qu'elle existe et
    // qui la suit.
    return c.json({ error: 'Seance introuvable.' }, 404)
  }

  // --- La presence --------------------------------------------------------
  //
  // Une ligne par entree en salle : un enfant qui perd le reseau et revient
  // en a deux. On additionne les minutes et on garde la **premiere** entree,
  // qui est l'heure d'arrivee.
  const { data: presences } = place
    ? await service
        .from('attendance_detail')
        .select('joined_at, minutes')
        .eq('enrolment_id', place.id)
        .order('joined_at', { ascending: true })
    : { data: [] }

  const lignes = presences ?? []
  const minutes = Math.min(
    lignes.reduce((total, l) => total + Number(l.minutes ?? 0), 0),
    Number(lue.duration_minutes ?? 90),
  )
  const arrivee = lignes.length > 0 ? String(lignes[0].joined_at) : null

  // --- Les points de controle --------------------------------------------
  const { data: controles } = await service
    .from('session_checkpoints')
    .select('id')
    .eq('session_id', sessionId)

  const idsControles = (controles ?? []).map((cp) => cp.id as string)
  const { count: repondus } = place && idsControles.length > 0
    ? await service
        .from('checkpoint_answers')
        .select('checkpoint_id', { count: 'exact', head: true })
        .eq('enrolment_id', place.id)
        .in('checkpoint_id', idsControles)
    : { count: 0 }

  const enfant = place
    ? ((place.children as { first_name?: string } | null)?.first_name ?? null)
    : null
  const matiere = cours?.subjects as { name?: string } | null
  const niveau = cours?.levels as { name?: string } | null

  return c.json({
    sessionId,
    startsAt: lue.starts_at,
    durationMinutes: lue.duration_minutes,
    // Le prenom, et rien d'autre : la phrase se lit « Aissatou a suivi 52
    // minutes sur 60 », pas « l'eleve de la place 7 ».
    childName: enfant,
    minutesAttended: minutes,
    /*
     * L'heure d'arrivee, et jamais un retard calcule.
     *
     * « Ne jamais faire de reproche. Un retard se dit avec l'heure
     * d'arrivee. » Le serveur rend donc l'heure ; c'est l'ecran qui decide
     * s'il la montre, et il ne la commente pas.
     */
    joinedAt: arrivee,
    checkpointsAnswered: repondus ?? 0,
    checkpointsTotal: idsControles.length,
    // Ce qui a ete travaille : le titre du cours, qui est ce que le
    // professeur a nomme en le publiant.
    title: cours?.title ?? null,
    subject: matiere?.name ?? null,
    level: niveau?.name ?? null,
    /*
     * L'etat de l'enregistrement, pas son identifiant : il n'est pas lisible
     * sans signature, et le donner inviterait a le faire fuir.
     *
     * C'est lui qui porte la phrase de rattrapage — « les minutes manquantes
     * sont sur l'enregistrement » — et la charte en fait une regle : une
     * absence se dit avec le moyen de rattraper.
     */
    replay: lue.recording_video_id
      ? ((lue.recording_status as string | null) ?? 'TRANSFERRING')
      : null,
  })
})

/**
 * L'application elle-meme, sans adaptateur.
 *
 * Exportee pour que Cloudflare Workers la serve directement
 * (`worker.ts`) : Hono tourne nativement sur les deux plateformes, et un
 * second exemplaire du code de routage aurait diverge du premier.
 */
/* ===========================================================================
 * L'espace d'exploitation
 * ===========================================================================
 *
 * --- Ce qui n'existait pas ------------------------------------------------
 *
 * Deux files se remplissaient sans que personne puisse y repondre : les
 * demandes de retrait des professeurs, et les echanges de la boutique. On y
 * repondait dans l'editeur SQL de Supabase — a la main, sans trace, avec la
 * cle de service ouverte dans un onglet.
 *
 * Ce sont les deux operations qui font tourner l'entreprise. Payer les
 * professeurs, c'est l'offre entiere ; livrer les lots, c'est la boucle de
 * retour entiere.
 *
 * --- Qui a le droit -------------------------------------------------------
 *
 * Un compte dont `profiles.role` vaut `ADMIN`, verifie **a chaque appel** et
 * sous la cle de service. Pas de RLS ici : ces routes lisent la file de tous
 * les professeurs, ce qu'aucune politique de ligne ne doit ouvrir a un compte
 * de navigateur.
 *
 * `ADMIN` est hors de portee d'un client : le schema d'inscription n'accepte
 * que `TEACHER | INSTITUTION | PARENT | STUDENT`, et `/account` refuse de
 * changer le role d'un compte deja cree. La valeur ne se pose donc qu'avec la
 * cle de service ou dans l'editeur SQL.
 *
 * --- Ce qui est journalise ------------------------------------------------
 *
 * Tout. Le middleware d'audit couvre deja toute mutation ; `isAuditable`
 * ajoute les lectures de `/operations`, parce que lire qui attend combien
 * d'argent est une donnee personnelle.
 */

/** Le compte est-il de la maison ? Rend son identifiant, ou `null`. */
async function operateurOf(userId: string | undefined): Promise<string | null> {
  if (!userId) return null
  const { data } = await asService()
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .maybeSingle()
  return data?.role === 'ADMIN' ? userId : null
}

/**
 * La file des retraits a regler.
 *
 * Chaque ligne porte **ce que l'operateur doit savoir pour decider** : qui,
 * combien, par quel canal, depuis quand — et le revenu recalcule du
 * professeur, pour qu'il puisse voir si la somme est due sans ouvrir un
 * second ecran.
 */
app.get('/operations/payouts', async (c) => {
  const operateur = await operateurOf(c.get('userId'))
  if (!operateur) return c.json({ error: 'Reserve a l’exploitation.' }, 403)

  const service = asService()
  const { data, error } = await service
    .from('payout_requests')
    .select(
      `id, amount, method, method_last4, status, requested_at,
       teachers ( id, profiles ( first_name, last_name, phone ) )`,
    )
    .in('status', [...RETRAITS_OUVERTS])
    .order('requested_at', { ascending: true })
    .limit(100)

  if (error) throw error

  const lignes = (data ?? []) as unknown as Record<string, unknown>[]

  // Le revenu de chaque professeur, recalcule. Une file de cent lignes fait
  // cent appels au pire ; elle en fait rarement dix, et la justesse du
  // montant vaut plus ici que le nombre d'allers-retours.
  const sorties = []
  for (const ligne of lignes) {
    const lie = ligne.teachers as Record<string, unknown> | null
    const prof = (Array.isArray(lie) ? lie[0] : lie) as
      | Record<string, unknown>
      | null
    const fiche = prof?.profiles as Record<string, unknown> | null
    const personne = (Array.isArray(fiche) ? fiche[0] : fiche) as
      | Record<string, unknown>
      | null

    let disponible: number | null = null
    if (prof?.id) {
      const { data: revenu } = await service.rpc('revenus_enseignant', {
        prof: prof.id as string,
      })
      const premier = Array.isArray(revenu) ? revenu[0] : revenu
      const r = premier as Record<string, unknown> | null
      disponible = r?.disponible == null ? null : Number(r.disponible)
    }

    sorties.push({
      id: ligne.id as string,
      amount: Number(ligne.amount ?? 0),
      method: ligne.method as string,
      methodLast4: (ligne.method_last4 as string | null) ?? null,
      status: ligne.status as string,
      requestedAt: ligne.requested_at as string,
      teacherId: (prof?.id as string) ?? null,
      teacherName: [personne?.first_name, personne?.last_name]
        .filter(Boolean)
        .join(' '),
      // Le numero complet, parce que l'operateur doit envoyer l'argent
      // quelque part. C'est la seule route du produit qui le rend, et elle
      // est fermee a tout ce qui n'est pas `ADMIN`.
      teacherPhone: (personne?.phone as string | null) ?? null,
      available: disponible,
    })
  }

  return c.json({ payouts: sorties })
})

const decisionRetrait = z.object({
  decision: z.enum(['PAID', 'REJECTED']),
  note: z.string().max(500).optional(),
  /**
   * Le montant, retape par l'operateur.
   *
   * C'est la seule operation du produit qu'on ne peut pas annuler : l'argent
   * part par Orange Money et ne revient pas. Retaper la somme est la garde
   * la plus simple contre la ligne d'a cote — celle qu'aucune verification
   * de permission ne remplace.
   */
  amountConfirmed: z.number().int().positive().optional(),
})

app.post('/operations/payouts/:id/decision', async (c) => {
  const operateur = await operateurOf(c.get('userId'))
  if (!operateur) return c.json({ error: 'Reserve a l’exploitation.' }, 403)

  const parsed = decisionRetrait.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) return c.json({ error: 'Decision non precisee.' }, 400)
  const { decision, note, amountConfirmed } = parsed.data

  const service = asService()
  const { data: demande } = await service
    .from('payout_requests')
    .select('id, amount, status')
    .eq('id', c.req.param('id'))
    .maybeSingle()

  if (!demande) return c.json({ error: 'Demande introuvable.' }, 404)

  /*
   * La decision vient du module pur, et pas d'ici.
   *
   * Les trois gardes — deja tranchee, refus sans motif, montant retape qui
   * ne correspond pas — sont verifiees dans `_lib/operations.ts`, sans base
   * et sans reseau. Une garde qu'on ne peut eprouver qu'en montant une
   * infrastructure n'est jamais eprouvee, et c'est la seule operation du
   * produit qu'on ne peut pas annuler.
   */
  const verdict = deciderRetrait(
    {
      id: demande.id as string,
      amount: Number(demande.amount),
      status: demande.status as string,
    },
    { decision, note, amountConfirmed },
  )

  if (!verdict.ok) {
    if (verdict.deja) {
      return c.json({ id: demande.id, status: verdict.status, already: true })
    }
    return c.json({ error: verdict.message }, verdict.code as 400 | 409)
  }

  // Mise a jour conditionnelle : deux operateurs qui tranchent en meme temps
  // n'ecrivent qu'une fois, et le second lit `already`.
  const { data: regle, error } = await service
    .from('payout_requests')
    .update({
      status: verdict.status,
      decision_note: verdict.note,
      settled_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq('id', demande.id as string)
    .in('status', [...RETRAITS_OUVERTS])
    .select('id, status')
    .maybeSingle()

  if (error) throw error
  if (!regle) {
    return c.json({ id: demande.id, status: demande.status, already: true })
  }

  return c.json({ id: regle.id, status: regle.status })
})

/** La file des lots a remettre. */
app.get('/operations/redemptions', async (c) => {
  const operateur = await operateurOf(c.get('userId'))
  if (!operateur) return c.json({ error: 'Reserve a l’exploitation.' }, 403)

  const { data, error } = await asService()
    .from('redemptions')
    .select(
      `id, points_spent, status, requested_at,
       shop_items ( id, name ),
       profiles ( first_name, last_name, phone, city )`,
    )
    .eq('status', 'PENDING')
    .order('requested_at', { ascending: true })
    .limit(100)

  if (error) throw error

  const un = (valeur: unknown) => {
    const lie = Array.isArray(valeur) ? valeur[0] : valeur
    return (lie ?? null) as Record<string, unknown> | null
  }

  return c.json({
    redemptions: (data ?? []).map((ligne) => {
      const lot = un((ligne as Record<string, unknown>).shop_items)
      const personne = un((ligne as Record<string, unknown>).profiles)
      return {
        id: ligne.id as string,
        pointsSpent: Number(ligne.points_spent ?? 0),
        requestedAt: ligne.requested_at as string,
        itemName: (lot?.name as string) ?? 'Lot retire du catalogue',
        studentName: [personne?.first_name, personne?.last_name]
          .filter(Boolean)
          .join(' '),
        studentPhone: (personne?.phone as string | null) ?? null,
        city: (personne?.city as string | null) ?? null,
      }
    }),
  })
})

const decisionLot = z.object({
  decision: z.enum(['DELIVERED', 'REFUSED']),
  note: z.string().max(500).optional(),
})

app.post('/operations/redemptions/:id/decision', async (c) => {
  const operateur = await operateurOf(c.get('userId'))
  if (!operateur) return c.json({ error: 'Reserve a l’exploitation.' }, 403)

  const parsed = decisionLot.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) return c.json({ error: 'Decision non precisee.' }, 400)
  const { decision, note } = parsed.data

  const service = asService()
  const id = c.req.param('id')

  if (decision === 'REFUSED') {
    /*
     * Par la fonction, et pas autrement.
     *
     * Un refus touche trois choses : le statut, le stock du lot, et les
     * points de l'eleve. Trois ecritures separees laissent une fenetre ou
     * l'eleve a perdu ses points sans que le lot soit revenu en stock.
     */
    const verdict = deciderLot({ decision, note })
    if (!verdict.ok) return c.json({ error: verdict.message }, 400)

    const { data, error } = await service.rpc('refuser_lot', {
      demande: id,
      motif: note,
    })
    if (error) throw error

    const premier = Array.isArray(data) ? data[0] : data
    const resultat = premier as Record<string, unknown> | null
    const raison = (resultat?.raison as string | null) ?? null

    if (raison === 'INCONNUE') {
      return c.json({ error: 'Demande introuvable.' }, 404)
    }
    if (raison === 'DEJA_TRANCHEE') {
      return c.json({ id, status: 'REFUSED', already: true })
    }
    if (raison) return c.json({ error: 'Refus impossible.' }, 409)

    return c.json({
      id,
      status: 'REFUSED',
      pointsRendus: Number(resultat?.rendu ?? 0),
    })
  }

  // La remise, elle, ne touche qu'une ligne : la mise a jour conditionnelle
  // suffit, et elle est idempotente par construction.
  const { data: remis, error } = await service
    .from('redemptions')
    .update({
      status: 'DELIVERED',
      decided_at: new Date().toISOString(),
      note: note ?? null,
    })
    .eq('id', id)
    .eq('status', 'PENDING')
    .select('id, status')
    .maybeSingle()

  if (error) throw error
  if (!remis) {
    const { data: deja } = await service
      .from('redemptions')
      .select('id, status')
      .eq('id', id)
      .maybeSingle()
    if (!deja) return c.json({ error: 'Demande introuvable.' }, 404)
    return c.json({ id: deja.id, status: deja.status, already: true })
  }

  return c.json({ id: remis.id, status: remis.status })
})

export { app }

export const GET = handle(app)
export const POST = handle(app)
export const PATCH = handle(app)
export const DELETE = handle(app)
export default handle(app)
