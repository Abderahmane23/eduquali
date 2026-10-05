import type {
  Application,
  ApplicationStatus,
  Availability,
  Certification,
  ContractType,
  Institution,
  InstitutionType,
  JobOffer,
  RefItem,
  Session,
  TeacherProfile,
  TestQuestion,
  TestSummary,
  TrustBadges,
  VerificationStatus,
} from './types'

/**
 * Traduction des lignes Postgres vers les types du domaine.
 *
 * Postgres parle `snake_case`, l'application `camelCase`. C'est la seule
 * frontiere ou les deux se rencontrent, et c'est aussi l'endroit ou une
 * erreur ne se voit pas : une colonne mal nommee ne leve rien, elle rend
 * `undefined`, et l'ecran affiche un blanc la ou il devrait y avoir un nom.
 *
 * D'ou deux regles ici. Les fonctions sont **pures** — aucune ne touche au
 * reseau — donc elles se testent sans serveur ni cle. Et chaque colonne lue
 * est nommee une seule fois, dans ce fichier : le jour ou le schema bouge,
 * c'est ici qu'on corrige, pas dans quinze requetes.
 */

/** Ce que rend PostgREST : des colonnes, sans garantie de type. */
export type Row = Record<string, unknown>

export const text = (row: Row, key: string): string => {
  const value = row[key]
  return typeof value === 'string' ? value : ''
}

/**
 * Exporte parce que `supabase.ts` lit lui aussi des lignes brutes : la vue des
 * identites publiques se relit avec le meme vocabulaire que les mappeurs, et
 * deux facons de lire une colonne finiraient par differer sur les cas vides.
 */
export const maybeText = (row: Row, key: string): string | undefined => {
  const value = row[key]
  return typeof value === 'string' && value !== '' ? value : undefined
}

const number = (row: Row, key: string, fallback = 0): number => {
  const value = row[key]
  return typeof value === 'number' ? value : fallback
}

const maybeNumber = (row: Row, key: string): number | undefined => {
  const value = row[key]
  return typeof value === 'number' ? value : undefined
}

const flag = (row: Row, key: string): boolean => row[key] === true

/** Une relation imbriquee rendue par `select('…, autre(*)')`. */
export const nested = (row: Row, key: string): Row | null => {
  const value = row[key]
  // PostgREST rend un objet pour une relation « vers un », un tableau pour
  // une relation « vers plusieurs ». On accepte les deux : la forme depend
  // de la facon dont la cle etrangere est declaree, et s'en remettre a
  // l'une des deux casse le jour ou l'autre arrive.
  if (Array.isArray(value)) return (value[0] as Row) ?? null
  return typeof value === 'object' && value !== null ? (value as Row) : null
}

const nestedList = (row: Row, key: string): Row[] => {
  const value = row[key]
  if (Array.isArray(value)) return value as Row[]
  return typeof value === 'object' && value !== null ? [value as Row] : []
}

/**
 * Une valeur de colonne contrainte, ramenee dans son ensemble autorise.
 *
 * Le schema pose des `check (… in (…))`, mais une base peut etre corrigee a
 * la main et une migration peut ajouter une valeur avant le client. Une
 * chaine inconnue ne doit pas traverser l'application deguisee en type sur :
 * elle retombe sur le defaut, qui est toujours le cas le moins engageant.
 */
const oneOf = <T extends string>(
  value: unknown,
  allowed: readonly T[],
  fallback: T,
): T => (allowed.includes(value as T) ? (value as T) : fallback)

const VERIFICATION: readonly VerificationStatus[] = [
  'NONE',
  'PENDING',
  'IN_REVIEW',
  'VERIFIED',
  'REJECTED',
  'NEEDS_FIX',
]

const AVAILABILITY: readonly Availability[] = [
  'AVAILABLE',
  'AVAILABLE_SOON',
  'UNAVAILABLE',
]

const CONTRACTS: readonly ContractType[] = [
  'PERMANENT',
  'FIXED_TERM',
  'HOURLY',
  'INTERNSHIP',
]

const INSTITUTION_TYPES: readonly InstitutionType[] = [
  'SCHOOL',
  'HIGH_SCHOOL',
  'UNIVERSITY',
  'INSTITUTE',
  'TRAINING_CENTER',
  'OTHER',
]

const APPLICATION_STATUS: readonly ApplicationStatus[] = [
  'SENT',
  'VIEWED',
  'SHORTLISTED',
  'INTERVIEW',
  'OFFER_RECEIVED',
  'ACCEPTED',
  'REJECTED',
  'HIRED',
]

const ROLES: readonly Session['role'][] = [
  'TEACHER',
  'INSTITUTION',
  'PARENT',
  'ADMIN',
]

// --- Referentiel ----------------------------------------------------------

export const toRefItem = (row: Row): RefItem => ({
  id: text(row, 'id'),
  name: text(row, 'name'),
  code: maybeText(row, 'code'),
  category: maybeText(row, 'category'),
  cycle: maybeText(row, 'cycle'),
})

// --- Etablissement --------------------------------------------------------

export const toInstitution = (row: Row): Institution => ({
  id: text(row, 'id'),
  name: text(row, 'name'),
  type: oneOf(row.type, INSTITUTION_TYPES, 'OTHER'),
  city: text(row, 'city'),
  address: maybeText(row, 'address'),
  description: maybeText(row, 'description'),
  // `verification_status` porte tout le cycle ; le domaine n'a besoin que du
  // fait accompli, et « en cours de verification » n'est pas « verifie ».
  verified: row.verification_status === 'VERIFIED',
})

// --- Enseignant -----------------------------------------------------------

export const toCertification = (row: Row): Certification => ({
  id: text(row, 'id'),
  subject: toRefItem(nested(row, 'subjects') ?? {}),
  level: toRefItem(nested(row, 'levels') ?? {}),
  score: number(row, 'score'),
  issuedAt: text(row, 'issued_at'),
})

/**
 * Les badges de confiance (§14).
 *
 * Calcules a partir de ce qui est reellement prouve, jamais stockes : un
 * badge en base se desynchronise de la preuve qu'il resume, et c'est
 * toujours dans le sens qui avantage la fiche.
 */
export const toBadges = (
  teacher: Row,
  counts: { certifications: number; experiences: number; subjects: number },
): TrustBadges => ({
  identity: teacher.identity_status === 'VERIFIED',
  diploma: teacher.diploma_status === 'VERIFIED',
  competency: counts.certifications > 0,
  experience: counts.experiences > 0,
  profile: counts.subjects > 0 && text(teacher, 'headline') !== '',
})

/**
 * Taux de completion du profil, en cinq parts egales.
 *
 * Le meme decoupage que les badges : ce qu'on demande de completer est
 * exactement ce qui se voit ensuite sur la fiche.
 */
export const toCompletionRate = (badges: TrustBadges): number =>
  Math.round(
    (Object.values(badges).filter(Boolean).length / Object.keys(badges).length) *
      100,
  )

export function toTeacherProfile(row: Row): TeacherProfile {
  // La fiche vient soit de `teachers` joint a `profiles`, soit de la vue
  // publique qui a deja aplati les deux. On accepte les deux formes.
  const profile = nested(row, 'profiles') ?? row
  const firstName = text(profile, 'first_name')
  const lastName = text(profile, 'last_name')

  const certifications = nestedList(row, 'teacher_certifications').map(
    toCertification,
  )
  const experiences = nestedList(row, 'teacher_experiences').map((e) => ({
    id: text(e, 'id'),
    institutionName: text(e, 'institution_name'),
    position: text(e, 'position'),
    city: maybeText(e, 'city'),
    startYear: yearOf(text(e, 'start_date')),
    endYear: e.end_date ? yearOf(text(e, 'end_date')) : null,
    verified: e.verification_status === 'VERIFIED',
  }))
  const subjects = nestedList(row, 'teacher_subjects')
    .map((s) => nested(s, 'subjects'))
    .filter((s): s is Row => s !== null)
    .map(toRefItem)
  const levels = nestedList(row, 'teacher_levels')
    .map((l) => nested(l, 'levels'))
    .filter((l): l is Row => l !== null)
    .map(toRefItem)

  const badges = toBadges(row, {
    certifications: certifications.length,
    experiences: experiences.length,
    subjects: subjects.length,
  })

  return {
    id: text(row, 'id'),
    firstName,
    lastName,
    fullName: `${firstName} ${lastName}`.trim(),
    headline: text(row, 'headline'),
    bio: maybeText(row, 'bio'),
    city: maybeText(row, 'city'),
    photoUrl: maybeText(profile, 'photo_path'),
    yearsExperience: number(row, 'years_experience'),
    availability: oneOf(row.availability, AVAILABILITY, 'AVAILABLE'),
    identityStatus: oneOf(row.identity_status, VERIFICATION, 'NONE'),
    diplomaStatus: oneOf(row.diploma_status, VERIFICATION, 'NONE'),
    subjects,
    levels,
    certifications,
    experiences,
    badges,
    // Le score de confiance est calcule cote client tant qu'aucune vue
    // serveur ne le rend : le meilleur des certifications, sinon zero.
    trustScore: certifications.reduce((best, c) => Math.max(best, c.score), 0),
    completionRate: toCompletionRate(badges),
  }
}

/** « 2019-09-01 » → 2019. Zero quand la date manque. */
const yearOf = (iso: string): number => {
  const year = Number.parseInt(iso.slice(0, 4), 10)
  return Number.isFinite(year) ? year : 0
}

// --- Offres et candidatures ----------------------------------------------

export function toJobOffer(row: Row, levelsById: Map<string, RefItem>): JobOffer {
  const levelIds = Array.isArray(row.level_ids)
    ? (row.level_ids as unknown[]).map(String)
    : []

  return {
    id: text(row, 'id'),
    title: text(row, 'title'),
    institution: toInstitution(nested(row, 'institutions') ?? {}),
    subject: toRefItem(nested(row, 'subjects') ?? {}),
    // Les niveaux d'une offre sont un tableau d'identifiants, pas une
    // relation : on les rapproche du referentiel deja charge plutot que de
    // faire une requete par offre.
    levels: levelIds
      .map((id) => levelsById.get(id))
      .filter((l): l is RefItem => l !== undefined),
    city: text(row, 'city'),
    contractType: oneOf(row.contract_type, CONTRACTS, 'PERMANENT'),
    description: maybeText(row, 'description'),
    salaryMin: maybeNumber(row, 'salary_min'),
    salaryMax: maybeNumber(row, 'salary_max'),
    salaryPublished: flag(row, 'salary_published'),
    minExperience: number(row, 'min_experience'),
    requiresCertification: flag(row, 'requires_certification'),
    publishedAt: maybeText(row, 'published_at') ?? text(row, 'created_at'),
    // PostgREST rend un agregat `count` sous forme de tableau d'objets.
    applicationCount: countOf(row, 'applications'),
  }
}

const countOf = (row: Row, key: string): number => {
  const value = row[key]
  if (Array.isArray(value)) {
    const first = value[0] as Row | undefined
    return first ? number(first, 'count') : 0
  }
  return typeof value === 'number' ? value : 0
}

export const toApplication = (
  row: Row,
  levelsById: Map<string, RefItem>,
): Application => ({
  id: text(row, 'id'),
  job: toJobOffer(nested(row, 'jobs') ?? {}, levelsById),
  status: oneOf(row.status, APPLICATION_STATUS, 'SENT'),
  appliedAt: text(row, 'applied_at'),
  matchScore: maybeNumber(row, 'match_score'),
})

// --- Tests ----------------------------------------------------------------

export const toTestSummary = (
  row: Row,
  certification?: Certification,
): TestSummary => ({
  id: text(row, 'id'),
  title: text(row, 'title'),
  subject: toRefItem(nested(row, 'subjects') ?? {}),
  level: toRefItem(nested(row, 'levels') ?? {}),
  questionCount: number(row, 'question_count'),
  durationMinutes: number(row, 'duration_minutes'),
  passingScore: number(row, 'passing_score', 70),
  rules: maybeText(row, 'rules'),
  certification,
})

export const toTestQuestion = (row: Row): TestQuestion => ({
  id: text(row, 'id'),
  statement: text(row, 'statement'),
  // `options` est du JSONB : il arrive deja decode, mais rien ne garantit sa
  // forme. Une question sans reponse proposee est inutilisable — mieux vaut
  // une liste vide qu'un plantage au milieu d'un test chronometre.
  options: Array.isArray(row.options)
    ? (row.options as Row[]).map((o) => ({
        key: text(o, 'key'),
        text: text(o, 'text'),
      }))
    : [],
  domain: text(row, 'domain'),
  // `correct_key` n'est jamais servi avant la correction : la vue publique
  // ne le contient pas. S'il arrive, c'est qu'on lit la mauvaise source.
  correctKey: maybeText(row, 'correct_key'),
  explanation: maybeText(row, 'explanation'),
})

// --- Session --------------------------------------------------------------

export const toSession = (
  profile: Row,
  ids: { teacherId?: string; institutionId?: string; parentId?: string },
): Session => {
  const firstName = text(profile, 'first_name')
  const lastName = text(profile, 'last_name')
  const displayName = `${firstName} ${lastName}`.trim()

  return {
    userId: text(profile, 'id'),
    role: oneOf(profile.role, ROLES, 'TEACHER'),
    teacherId: ids.teacherId,
    institutionId: ids.institutionId,
    parentId: ids.parentId,
    city: maybeText(profile, 'city'),
    // Sans nom saisi, le telephone identifie quand meme le compte : un
    // en-tete vide laisse croire qu'on est connecte a autre chose.
    displayName: displayName !== '' ? displayName : text(profile, 'phone'),
  }
}
