/**
 * Regles metier — source unique.
 *
 * Le calcul du score de compatibilite, la correction des tests et
 * l'indicateur de confiance vivaient jusqu'ici en double, dans le client
 * Flutter et dans le client web. Deux copies finissent toujours par diverger,
 * et un meme candidat se serait retrouve classe differemment selon le
 * support. Ces regles sont desormais evaluees ici, une seule fois ; les
 * clients affichent ce que le serveur renvoie.
 */

// --- Compatibilite (§22, §61) ---------------------------------------------

const MATCH_WEIGHTS = {
  subject: 0.3,
  level: 0.2,
  competency: 0.2,
  experience: 0.15,
  location: 0.1,
  availability: 0.05,
} as const

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

export interface Requirement {
  subjectId?: string | null
  levelIds: string[]
  city?: string | null
  minExperience: number
  requiresCertification: boolean
}

export interface Candidate {
  subjectIds: string[]
  /** Couples « matiere:niveau » declares. */
  levelPairs: string[]
  /** Scores obtenus, indexes par « matiere:niveau ». */
  certifications: Record<string, number>
  yearsExperience: number
  city?: string | null
  availability: string
}

export const pairKey = (subjectId: string, levelId: string) =>
  `${subjectId}:${levelId}`

const factor = (
  key: string,
  label: string,
  weight: number,
  ratio: number,
  detail: string,
): MatchFactor => ({
  key,
  label,
  points: Math.round(weight * ratio * 100),
  max: Math.round(weight * 100),
  detail,
})

export function scoreMatch(
  need: Requirement,
  candidate: Candidate,
): MatchScore {
  const factors: MatchFactor[] = []
  const w = MATCH_WEIGHTS

  // Matiere
  if (!need.subjectId) {
    factors.push(factor('subject', 'Matiere', w.subject, 1, 'Aucune matiere imposee'))
  } else {
    const match = candidate.subjectIds.includes(need.subjectId)
    factors.push(
      factor(
        'subject',
        'Matiere',
        w.subject,
        match ? 1 : 0,
        match
          ? 'Matiere enseignee par le candidat'
          : 'Matiere non declaree par le candidat',
      ),
    )
  }

  // Niveau
  if (need.levelIds.length === 0 || !need.subjectId) {
    factors.push(factor('level', 'Niveau', w.level, 1, 'Aucun niveau impose'))
  } else {
    const covered = need.levelIds.filter((id) =>
      candidate.levelPairs.includes(pairKey(need.subjectId!, id)),
    ).length
    const ratio = covered / need.levelIds.length
    factors.push(
      factor(
        'level',
        'Niveau',
        w.level,
        ratio,
        ratio === 1
          ? 'Tous les niveaux demandes sont couverts'
          : `${covered} niveau(x) couvert(s) sur ${need.levelIds.length}`,
      ),
    )
  }

  // Competence evaluee
  const scores =
    need.subjectId && need.levelIds.length > 0
      ? need.levelIds
          .map((id) => candidate.certifications[pairKey(need.subjectId!, id)])
          .filter((s): s is number => typeof s === 'number')
      : Object.values(candidate.certifications)

  if (scores.length === 0) {
    factors.push(
      factor(
        'competency',
        'Competence evaluee',
        w.competency,
        // Une exigence de certification non satisfaite annule le critere.
        need.requiresCertification ? 0 : 0.25,
        'Competence non evaluee pour ce niveau',
      ),
    )
  } else {
    const best = Math.max(...scores)
    factors.push(
      factor(
        'competency',
        'Competence evaluee',
        w.competency,
        best / 100,
        `Competence verifiee — ${best} %`,
      ),
    )
  }

  // Experience
  if (need.minExperience <= 0) {
    const ratio = Math.min(1, candidate.yearsExperience / 5)
    factors.push(
      factor(
        'experience',
        'Experience',
        w.experience,
        ratio,
        `${candidate.yearsExperience} an(s) d’experience`,
      ),
    )
  } else {
    const ratio = Math.min(1, candidate.yearsExperience / need.minExperience)
    factors.push(
      factor(
        'experience',
        'Experience',
        w.experience,
        ratio,
        ratio >= 1
          ? `${candidate.yearsExperience} ans — exigence satisfaite`
          : `${candidate.yearsExperience} ans sur ${need.minExperience} demandes`,
      ),
    )
  }

  // Localisation — une ville differente n'est pas eliminatoire.
  if (!need.city) {
    factors.push(
      factor('location', 'Localisation', w.location, 1, 'Aucune ville imposee'),
    )
  } else {
    const same = candidate.city?.toLowerCase() === need.city.toLowerCase()
    factors.push(
      factor(
        'location',
        'Localisation',
        w.location,
        same ? 1 : 0.3,
        same ? `Reside a ${need.city}` : `Reside a ${candidate.city ?? '—'}`,
      ),
    )
  }

  // Disponibilite
  const availabilityRatio =
    candidate.availability === 'AVAILABLE'
      ? 1
      : candidate.availability === 'AVAILABLE_SOON'
        ? 0.6
        : 0
  factors.push(
    factor(
      'availability',
      'Disponibilite',
      w.availability,
      availabilityRatio,
      {
        AVAILABLE: 'Disponible',
        AVAILABLE_SOON: 'Bientot disponible',
        UNAVAILABLE: 'Indisponible',
      }[candidate.availability] ?? candidate.availability,
    ),
  )

  const value = factors.reduce((sum, f) => sum + f.points, 0)
  return { value: Math.max(0, Math.min(100, value)), factors }
}

// --- Correction d'un test (§12) -------------------------------------------

export interface DomainScore {
  domain: string
  correct: number
  total: number
  percentage: number
}

export interface TestOutcome {
  score: number
  correctCount: number
  totalQuestions: number
  answeredCount: number
  passed: boolean
  passingScore: number
  domainScores: DomainScore[]
}

export function scoreTest(
  questions: { id: string; correct_key: string; domain: string }[],
  answers: Record<string, string | null>,
  passingScore: number,
): TestOutcome {
  const byDomain = new Map<string, { correct: number; total: number }>()
  let correctCount = 0
  let answeredCount = 0

  for (const question of questions) {
    const given = answers[question.id]
    const answered = given != null && given !== ''
    const correct = answered && given === question.correct_key

    if (answered) answeredCount++
    if (correct) correctCount++

    const bucket = byDomain.get(question.domain) ?? { correct: 0, total: 0 }
    bucket.total++
    if (correct) bucket.correct++
    byDomain.set(question.domain, bucket)
  }

  const total = questions.length
  // Une question sans reponse compte comme incorrecte.
  const score = total === 0 ? 0 : Math.round((correctCount / total) * 100)

  return {
    score,
    correctCount,
    totalQuestions: total,
    answeredCount,
    passed: score >= passingScore,
    passingScore,
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

// --- Indicateur de confiance (§62) ----------------------------------------

const TRUST_WEIGHTS = {
  identity: 25,
  diploma: 20,
  competency: 20,
  experience: 15,
  reputation: 10,
  history: 10,
} as const

export interface TrustInput {
  identityVerified: boolean
  diplomaVerified: boolean
  certificationScores: number[]
  verifiedExperienceCount: number
  yearsExperience: number
  reviewAverage?: number | null
  completedRecruitments: number
}

export interface TrustDimension {
  key: string
  label: string
  earned: number
  max: number
  detail: string
}

export function trustScore(input: TrustInput): {
  value: number
  dimensions: TrustDimension[]
} {
  const w = TRUST_WEIGHTS
  const best =
    input.certificationScores.length === 0
      ? 0
      : Math.max(...input.certificationScores)

  // Une experience verifiee vaut davantage qu'une simple declaration.
  const experienceRatio =
    input.verifiedExperienceCount > 0
      ? Math.min(1, input.yearsExperience / 5)
      : Math.min(0.5, input.yearsExperience / 10)

  const dimensions: TrustDimension[] = [
    {
      key: 'identity',
      label: 'Identite',
      earned: input.identityVerified ? w.identity : 0,
      max: w.identity,
      detail: input.identityVerified ? 'Identite verifiee' : 'Non verifiee',
    },
    {
      key: 'diploma',
      label: 'Diplome',
      earned: input.diplomaVerified ? w.diploma : 0,
      max: w.diploma,
      detail: input.diplomaVerified ? 'Diplome verifie' : 'Non verifie',
    },
    {
      key: 'competency',
      label: 'Competence',
      earned: Math.round((w.competency * best) / 100),
      max: w.competency,
      detail:
        best === 0
          ? 'Aucune competence evaluee'
          : `${input.certificationScores.length} certification(s), meilleur score ${best} %`,
    },
    {
      key: 'experience',
      label: 'Experience',
      earned: Math.round(w.experience * experienceRatio),
      max: w.experience,
      detail: `${input.yearsExperience} an(s)`,
    },
    {
      key: 'reputation',
      label: 'Reputation',
      earned:
        input.reviewAverage == null
          ? 0
          : Math.round((w.reputation * input.reviewAverage) / 100),
      max: w.reputation,
      detail: input.reviewAverage == null ? 'Aucune evaluation' : `${Math.round(input.reviewAverage)} %`,
    },
    {
      key: 'history',
      label: 'Historique',
      earned: Math.round(
        w.history * Math.min(1, input.completedRecruitments / 3),
      ),
      max: w.history,
      detail: `${input.completedRecruitments} recrutement(s) via la plateforme`,
    },
  ]

  return {
    value: Math.min(100, dimensions.reduce((s, d) => s + d.earned, 0)),
    dimensions,
  }
}

// --- Completion du profil (§16) -------------------------------------------

const COMPLETION_WEIGHTS: Record<string, number> = {
  personal_info: 10,
  photo: 10,
  identity: 15,
  diploma: 15,
  subjects: 10,
  levels: 10,
  experience: 10,
  availability: 5,
  certification: 15,
}

export function completionRate(done: Record<string, boolean>): number {
  return Math.min(
    100,
    Object.entries(COMPLETION_WEIGHTS).reduce(
      (sum, [key, weight]) => sum + (done[key] ? weight : 0),
      0,
    ),
  )
}

// --- Demandes d'inscription (§55-bis) -------------------------------------

/**
 * Annee scolaire courante.
 *
 * La rentree guineenne tombe en octobre : une demande deposee en juillet
 * porte encore sur l'annee commencee l'annee civile precedente. Sans cette
 * regle, l'unicite « un eleve, un etablissement, une annee » basculerait au
 * 1er janvier, en plein milieu de l'annee scolaire.
 */
export function currentSchoolYear(now: Date = new Date()): string {
  const year = now.getFullYear()
  const start = now.getMonth() >= 8 ? year : year - 1
  return `${start}-${start + 1}`
}

export type EnrolmentStatus =
  | 'SENT'
  | 'VIEWED'
  | 'ACCEPTED'
  | 'REJECTED'
  | 'CANCELLED'

export type EnrolmentActor = 'parent' | 'institution'

/**
 * Qui a le droit de faire quoi.
 *
 * RLS empeche d'ecrire sur la ligne d'un autre ; cette table dit ce qui est
 * permis a l'interieur de ses propres lignes — sans elle, un parent pourrait
 * accepter lui-meme la demande d'inscription de son enfant.
 */
const ENROLMENT_TRANSITIONS: Record<EnrolmentActor, EnrolmentStatus[]> = {
  institution: ['VIEWED', 'ACCEPTED', 'REJECTED'],
  parent: ['CANCELLED'],
}

/** Statuts definitifs : plus aucune suite n'est possible. */
const ENROLMENT_FINAL: EnrolmentStatus[] = ['ACCEPTED', 'REJECTED', 'CANCELLED']

export function canSetEnrolmentStatus(
  actor: EnrolmentActor,
  current: EnrolmentStatus,
  next: EnrolmentStatus,
): boolean {
  if (ENROLMENT_FINAL.includes(current)) return false
  if (current === next) return false
  return ENROLMENT_TRANSITIONS[actor].includes(next)
}
