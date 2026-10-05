import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import {
  canSetEnrolmentStatus,
  completionRate,
  currentSchoolYear,
  pairKey,
  scoreMatch,
  scoreTest,
  trustScore,
  type Candidate,
  type Requirement,
} from './domain.ts'

/**
 * Un fichier de test par regle critique (§7 du code_skill).
 *
 * Ce module decide qui est certifie, qui passe devant qui et ce qu'un
 * etablissement lit comme « profil de confiance ». Ce sont les trois seules
 * regles que personne ne doit pouvoir changer par accident.
 *
 * Aucune infrastructure : ce sont des fonctions pures.
 *   node --test --experimental-strip-types api/_lib/domain.test.ts
 */

// --- Correction d'un test (§12) -------------------------------------------

const question = (id: string, correct: string, domain = 'Algebre') => ({
  id,
  correct_key: correct,
  domain,
})

describe('scoreTest — la note qui delivre une certification', () => {
  it('compte une question sans reponse comme fausse, jamais comme absente', () => {
    const out = scoreTest(
      [question('q1', 'A'), question('q2', 'B'), question('q3', 'C')],
      { q1: 'A', q2: null, q3: '' },
      70,
    )
    // 1 bonne sur 3 questions posees — et non 1 sur 1 repondue.
    assert.equal(out.correctCount, 1)
    assert.equal(out.answeredCount, 1)
    assert.equal(out.totalQuestions, 3)
    assert.equal(out.score, 33)
  })

  it('valide a partir du seuil, pas au-dessus', () => {
    const questions = Array.from({ length: 10 }, (_, i) =>
      question(`q${i}`, 'A'),
    )
    const answers = Object.fromEntries(
      questions.map((q, i) => [q.id, i < 7 ? 'A' : 'B']),
    )
    const out = scoreTest(questions, answers, 70)
    assert.equal(out.score, 70)
    assert.equal(out.passed, true, 'un score egal au seuil doit valider')
  })

  it('refuse juste en dessous du seuil', () => {
    const questions = Array.from({ length: 10 }, (_, i) =>
      question(`q${i}`, 'A'),
    )
    const answers = Object.fromEntries(
      questions.map((q, i) => [q.id, i < 6 ? 'A' : 'B']),
    )
    assert.equal(scoreTest(questions, answers, 70).passed, false)
  })

  it('ignore une reponse envoyee pour une question qui n’est pas du test', () => {
    // Un client peut poster n'importe quoi : seule la liste serveur compte.
    const out = scoreTest([question('q1', 'A')], { q1: 'A', qX: 'A' }, 50)
    assert.equal(out.totalQuestions, 1)
    assert.equal(out.score, 100)
  })

  it('ne renvoie pas NaN sur un test vide', () => {
    const out = scoreTest([], {}, 70)
    assert.equal(out.score, 0)
    assert.equal(out.passed, false)
    assert.deepEqual(out.domainScores, [])
  })

  it('detaille par domaine, dans un ordre stable', () => {
    const out = scoreTest(
      [
        question('q1', 'A', 'Analyse'),
        question('q2', 'B', 'Analyse'),
        question('q3', 'C', 'Algebre'),
      ],
      { q1: 'A', q2: 'X', q3: 'C' },
      50,
    )
    assert.deepEqual(out.domainScores, [
      { domain: 'Algebre', correct: 1, total: 1, percentage: 100 },
      { domain: 'Analyse', correct: 1, total: 2, percentage: 50 },
    ])
  })
})

// --- Compatibilite (§22, §61) ---------------------------------------------

const SUBJECT = 'sub_math'
const L1 = 'lvl_l1'
const L2 = 'lvl_l2'

const candidate = (over: Partial<Candidate> = {}): Candidate => ({
  subjectIds: [SUBJECT],
  levelPairs: [pairKey(SUBJECT, L1), pairKey(SUBJECT, L2)],
  certifications: { [pairKey(SUBJECT, L1)]: 90 },
  yearsExperience: 5,
  city: 'Conakry',
  availability: 'AVAILABLE',
  ...over,
})

const need = (over: Partial<Requirement> = {}): Requirement => ({
  subjectId: SUBJECT,
  levelIds: [L1],
  city: 'Conakry',
  minExperience: 3,
  requiresCertification: false,
  ...over,
})

describe('scoreMatch — le classement des candidats', () => {
  it('reste borne entre 0 et 100', () => {
    const perfect = scoreMatch(need(), candidate())
    const empty = scoreMatch(
      need(),
      candidate({
        subjectIds: [],
        levelPairs: [],
        certifications: {},
        yearsExperience: 0,
        city: 'Kankan',
        availability: 'UNAVAILABLE',
      }),
    )
    for (const score of [perfect, empty]) {
      assert.ok(score.value >= 0 && score.value <= 100, `hors bornes : ${score.value}`)
    }
    assert.ok(perfect.value > empty.value)
  })

  it('expose un motif pour chaque critere — jamais de boite noire', () => {
    const { factors } = scoreMatch(need(), candidate())
    assert.deepEqual(
      factors.map((f) => f.key),
      ['subject', 'level', 'competency', 'experience', 'location', 'availability'],
    )
    for (const f of factors) {
      assert.ok(f.detail.length > 0, `${f.key} sans explication`)
      assert.ok(f.points <= f.max, `${f.key} depasse son maximum`)
    }
  })

  it('annule la competence quand la certification est exigee et absente', () => {
    const withCert = scoreMatch(
      need({ requiresCertification: true }),
      candidate(),
    )
    const without = scoreMatch(
      need({ requiresCertification: true }),
      candidate({ certifications: {} }),
    )
    const points = (s: typeof withCert) =>
      s.factors.find((f) => f.key === 'competency')!.points

    assert.ok(points(withCert) > 0)
    assert.equal(points(without), 0, 'exigence non satisfaite = 0 point')
  })

  it('accorde un credit partiel quand la certification n’est pas exigee', () => {
    const s = scoreMatch(need(), candidate({ certifications: {} }))
    assert.ok(s.factors.find((f) => f.key === 'competency')!.points > 0)
  })

  it('compte les niveaux couverts au prorata', () => {
    const s = scoreMatch(
      need({ levelIds: [L1, L2, 'lvl_l3'] }),
      candidate(),
    )
    const level = s.factors.find((f) => f.key === 'level')!
    // 2 niveaux sur 3 : 20 points de bareme -> 13.
    assert.equal(level.max, 20)
    assert.equal(level.points, 13)
  })

  it('ne rend pas une autre ville eliminatoire', () => {
    const ailleurs = scoreMatch(need(), candidate({ city: 'Kankan' }))
    const location = ailleurs.factors.find((f) => f.key === 'location')!
    assert.ok(location.points > 0, 'habiter ailleurs ne doit pas exclure')
    assert.ok(location.points < location.max)
  })

  it('ne donne aucun point de disponibilite a un candidat indisponible', () => {
    const s = scoreMatch(need(), candidate({ availability: 'UNAVAILABLE' }))
    assert.equal(s.factors.find((f) => f.key === 'availability')!.points, 0)
  })

  it('donne tous les points quand le besoin n’impose rien', () => {
    const s = scoreMatch(
      { subjectId: null, levelIds: [], city: null, minExperience: 0, requiresCertification: false },
      candidate(),
    )
    assert.equal(s.factors.find((f) => f.key === 'subject')!.points, 30)
    assert.equal(s.factors.find((f) => f.key === 'level')!.points, 20)
    assert.equal(s.factors.find((f) => f.key === 'location')!.points, 10)
  })

  it('plafonne l’experience : 20 ans ne valent pas plus que l’exigence', () => {
    const juste = scoreMatch(need({ minExperience: 5 }), candidate({ yearsExperience: 5 }))
    const beaucoup = scoreMatch(need({ minExperience: 5 }), candidate({ yearsExperience: 20 }))
    const pts = (s: typeof juste) => s.factors.find((f) => f.key === 'experience')!.points
    assert.equal(pts(juste), pts(beaucoup))
  })
})

// --- Indicateur de confiance (§62) ----------------------------------------

describe('trustScore — ce qu’un etablissement lit comme « profil sur »', () => {
  const base = {
    identityVerified: false,
    diplomaVerified: false,
    certificationScores: [] as number[],
    verifiedExperienceCount: 0,
    yearsExperience: 0,
    reviewAverage: null,
    completedRecruitments: 0,
  }

  it('part de zero quand rien n’est verifie', () => {
    assert.equal(trustScore(base).value, 0)
  })

  it('ne depasse jamais 100', () => {
    const max = trustScore({
      identityVerified: true,
      diplomaVerified: true,
      certificationScores: [100],
      verifiedExperienceCount: 4,
      yearsExperience: 30,
      reviewAverage: 100,
      completedRecruitments: 12,
    })
    assert.equal(max.value, 100)
  })

  it('vaut plus pour une experience verifiee que declaree', () => {
    const declaree = trustScore({ ...base, yearsExperience: 10 })
    const verifiee = trustScore({
      ...base,
      yearsExperience: 10,
      verifiedExperienceCount: 1,
    })
    assert.ok(
      verifiee.value > declaree.value,
      'une preuve doit peser plus qu’une declaration',
    )
  })

  it('somme exactement ses dimensions', () => {
    const t = trustScore({ ...base, identityVerified: true, yearsExperience: 2 })
    assert.equal(
      t.value,
      t.dimensions.reduce((s, d) => s + d.earned, 0),
    )
  })

  it('plafonne l’identite et le diplome a leur bareme', () => {
    const t = trustScore({ ...base, identityVerified: true, diplomaVerified: true })
    assert.equal(t.value, 45)
  })
})

// --- Completion du profil (§16) -------------------------------------------

describe('completionRate', () => {
  it('atteint 100 quand tout est fait', () => {
    const done = {
      personal_info: true, photo: true, identity: true, diploma: true,
      subjects: true, levels: true, experience: true, availability: true,
      certification: true,
    }
    assert.equal(completionRate(done), 100)
  })

  it('vaut 0 sur un profil vide', () => {
    assert.equal(completionRate({}), 0)
  })

  it('ignore une cle inconnue au lieu de la compter', () => {
    assert.equal(completionRate({ inexistant: true }), 0)
  })
})

// --- Demandes d'inscription (§55-bis) -------------------------------------

describe('currentSchoolYear — la rentree tombe en octobre', () => {
  it('compte septembre dans l’annee qui commence', () => {
    assert.equal(currentSchoolYear(new Date('2026-09-15T08:00:00Z')), '2026-2027')
  })

  it('compte juillet dans l’annee qui s’acheve', () => {
    assert.equal(currentSchoolYear(new Date('2027-07-04T08:00:00Z')), '2026-2027')
  })

  it('ne bascule pas au 1er janvier, en plein milieu d’annee', () => {
    const decembre = currentSchoolYear(new Date('2026-12-31T23:00:00Z'))
    const janvier = currentSchoolYear(new Date('2027-01-01T01:00:00Z'))
    assert.equal(decembre, janvier)
  })

  it('bascule bien a la rentree', () => {
    assert.notEqual(
      currentSchoolYear(new Date('2026-08-31T12:00:00Z')),
      currentSchoolYear(new Date('2026-09-01T12:00:00Z')),
    )
  })
})

describe('canSetEnrolmentStatus — qui decide quoi', () => {
  it('laisse l’etablissement accepter ou refuser', () => {
    assert.ok(canSetEnrolmentStatus('institution', 'SENT', 'ACCEPTED'))
    assert.ok(canSetEnrolmentStatus('institution', 'SENT', 'REJECTED'))
    assert.ok(canSetEnrolmentStatus('institution', 'SENT', 'VIEWED'))
  })

  it('interdit a un parent d’accepter lui-meme', () => {
    assert.equal(canSetEnrolmentStatus('parent', 'SENT', 'ACCEPTED'), false)
    assert.equal(canSetEnrolmentStatus('parent', 'VIEWED', 'REJECTED'), false)
  })

  it('laisse le parent annuler, et seulement annuler', () => {
    assert.ok(canSetEnrolmentStatus('parent', 'SENT', 'CANCELLED'))
    assert.equal(canSetEnrolmentStatus('parent', 'SENT', 'VIEWED'), false)
  })

  it('interdit a l’etablissement d’annuler a la place du parent', () => {
    assert.equal(
      canSetEnrolmentStatus('institution', 'SENT', 'CANCELLED'),
      false,
    )
  })

  it('refuse de revenir sur une decision rendue', () => {
    for (const final of ['ACCEPTED', 'REJECTED', 'CANCELLED'] as const) {
      assert.equal(
        canSetEnrolmentStatus('institution', final, 'ACCEPTED'),
        false,
        `${final} doit etre definitif`,
      )
    }
  })

  it('refuse une transition vers le statut deja porte', () => {
    assert.equal(canSetEnrolmentStatus('institution', 'VIEWED', 'VIEWED'), false)
  })
})
