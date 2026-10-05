import type { MatchFactor, MatchScore, RefItem, TeacherProfile } from './types'

/**
 * Moteur de compatibilite (§61), transpose depuis l'application mobile.
 *
 * Les ponderations sont identiques a celles du mobile : un meme candidat sur
 * un meme besoin doit obtenir le meme score des deux cotes, sinon le
 * classement devient incomprehensible pour l'établissement.
 *
 * Chaque critère conserve sa contribution : le score doit rester explicable
 * et ne pas devenir une boite noire (§22).
 */

const WEIGHTS = {
  subject: 0.3,
  level: 0.2,
  competency: 0.2,
  experience: 0.15,
  location: 0.1,
  availability: 0.05,
} as const

export interface MatchRequirement {
  subject?: RefItem
  levels: RefItem[]
  city?: string
  minExperience: number
  requiresCertification: boolean
}

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
  need: MatchRequirement,
  candidate: TeacherProfile,
): MatchScore {
  const factors: MatchFactor[] = []

  // Matière
  if (!need.subject?.id) {
    factors.push(
      factor('subject', 'Matière', WEIGHTS.subject, 1, 'Aucune matière imposee'),
    )
  } else {
    const match = candidate.subjects.some((s) => s.id === need.subject!.id)
    factors.push(
      factor(
        'subject',
        'Matière',
        WEIGHTS.subject,
        match ? 1 : 0,
        match
          ? 'Matière enseignee par le candidat'
          : 'Matière non declaree par le candidat',
      ),
    )
  }

  // Niveau
  if (need.levels.length === 0) {
    factors.push(
      factor('level', 'Niveau', WEIGHTS.level, 1, 'Aucun niveau impose'),
    )
  } else {
    const covered = need.levels.filter((needed) =>
      candidate.levels.some((l) => l.id === needed.id),
    ).length
    const ratio = covered / need.levels.length
    factors.push(
      factor(
        'level',
        'Niveau',
        WEIGHTS.level,
        ratio,
        ratio === 1
          ? 'Tous les niveaux demandes sont couverts'
          : `${covered} niveau(x) couvert(s) sur ${need.levels.length}`,
      ),
    )
  }

  // Compétence evaluee
  const relevant = candidate.certifications.filter(
    (cert) =>
      (!need.subject?.id || cert.subject.id === need.subject.id) &&
      (need.levels.length === 0 ||
        need.levels.some((l) => l.id === cert.level.id)),
  )
  if (relevant.length === 0) {
    factors.push(
      factor(
        'competency',
        'Compétence evaluee',
        WEIGHTS.competency,
        // Une exigence de certification non satisfaite annule le critère.
        need.requiresCertification ? 0 : 0.25,
        'Compétence non evaluee pour ce niveau',
      ),
    )
  } else {
    const best = Math.max(...relevant.map((c) => c.score))
    factors.push(
      factor(
        'competency',
        'Compétence evaluee',
        WEIGHTS.competency,
        best / 100,
        `Compétence vérifiée — ${best} %`,
      ),
    )
  }

  // Expérience
  if (need.minExperience <= 0) {
    const ratio = Math.min(1, candidate.yearsExperience / 5)
    factors.push(
      factor(
        'experience',
        'Expérience',
        WEIGHTS.experience,
        ratio,
        `${candidate.yearsExperience} an(s) d’experience`,
      ),
    )
  } else {
    const ratio = Math.min(1, candidate.yearsExperience / need.minExperience)
    factors.push(
      factor(
        'experience',
        'Expérience',
        WEIGHTS.experience,
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
      factor('location', 'Localisation', WEIGHTS.location, 1, 'Aucune ville imposee'),
    )
  } else {
    const same = candidate.city?.toLowerCase() === need.city.toLowerCase()
    factors.push(
      factor(
        'location',
        'Localisation',
        WEIGHTS.location,
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
      WEIGHTS.availability,
      availabilityRatio,
      candidate.availability === 'AVAILABLE'
        ? 'Disponible'
        : candidate.availability === 'AVAILABLE_SOON'
          ? 'Bientôt disponible'
          : 'Indisponible',
    ),
  )

  const value = factors.reduce((sum, f) => sum + f.points, 0)
  return { value: Math.max(0, Math.min(100, value)), factors }
}
