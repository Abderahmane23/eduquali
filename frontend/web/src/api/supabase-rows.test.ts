import { describe, expect, it } from 'vitest'
import {
  toApplication,
  toBadges,
  toCompletionRate,
  toInstitution,
  toJobOffer,
  toRefItem,
  toSession,
  toTeacherProfile,
  toTestQuestion,
} from './supabase-rows'
import type { RefItem } from './types'

/**
 * La traduction des lignes Postgres vers le domaine.
 *
 * C'est la frontiere ou une erreur ne se voit pas : une colonne mal nommee
 * ne leve rien, elle rend `undefined`, et l'ecran affiche un blanc la ou il
 * devrait y avoir un nom. Un test de bout en bout ne l'attrape pas non plus
 * — il montre une page vide, ce qui ressemble a une base vide.
 *
 * Les noms de colonnes verifies ici viennent de `backend/supabase/
 * migrations/0001_schema.sql`. Les changer d'un cote doit casser ce fichier.
 */
describe('Referentiel', () => {
  it('lit une matiere', () => {
    expect(toRefItem({ id: 'sub_math', name: 'Mathématiques', code: 'MATH' }))
      .toEqual({
        id: 'sub_math',
        name: 'Mathématiques',
        code: 'MATH',
        category: undefined,
      })
  })

  it('survit a une ligne vide', () => {
    // PostgREST rend `null` pour une relation absente ; le mappeur recoit
    // alors un objet vide. Rendre un nom vide vaut mieux que planter au
    // milieu d'une liste d'offres.
    expect(toRefItem({})).toEqual({
      id: '',
      name: '',
      code: undefined,
      category: undefined,
    })
  })
})

describe('Etablissement', () => {
  it('n’est verifie que lorsqu’il l’est vraiment', () => {
    // `verification_status` porte tout le cycle. « En cours » n'est pas
    // « verifie », et l'afficher comme tel serait une preuve inventee.
    const encours = toInstitution({ verification_status: 'PENDING' })
    expect(encours.verified).toBe(false)
    expect(toInstitution({ verification_status: 'VERIFIED' }).verified).toBe(
      true,
    )
  })

  it('ramene un type inconnu sur AUTRE', () => {
    // Une base corrigee a la main ou une migration en avance sur le client
    // ne doit pas faire traverser une chaine inconnue deguisee en type sur.
    expect(toInstitution({ type: 'COLLEGE_TECHNIQUE' }).type).toBe('OTHER')
    expect(toInstitution({ type: 'UNIVERSITY' }).type).toBe('UNIVERSITY')
  })
})

describe('Fiche enseignant', () => {
  const ligne = {
    id: 't1',
    headline: 'Professeur de mathématiques',
    city: 'Conakry',
    years_experience: 7,
    availability: 'AVAILABLE',
    identity_status: 'VERIFIED',
    diploma_status: 'PENDING',
    profiles: {
      id: 'u1',
      first_name: 'Mariama',
      last_name: 'Diallo',
      photo_path: 'photos/u1.jpg',
    },
    teacher_subjects: [{ subjects: { id: 'sub_math', name: 'Mathématiques' } }],
    teacher_levels: [
      { levels: { id: 'lvl_12', name: 'Terminale', category: 'SECONDARY' } },
    ],
    teacher_certifications: [
      {
        id: 'c1',
        score: 82,
        issued_at: '2026-03-01T00:00:00Z',
        subjects: { id: 'sub_math', name: 'Mathématiques' },
        levels: { id: 'lvl_12', name: 'Terminale' },
      },
    ],
    teacher_experiences: [
      {
        id: 'e1',
        institution_name: 'Lycée Donka',
        position: 'Professeur',
        start_date: '2019-09-01',
        end_date: null,
        verification_status: 'VERIFIED',
      },
    ],
  }

  it('assemble le nom depuis le profil joint', () => {
    const profil = toTeacherProfile(ligne)
    expect(profil.fullName).toBe('Mariama Diallo')
    expect(profil.photoUrl).toBe('photos/u1.jpg')
  })

  it('aplatit les relations imbriquees', () => {
    const profil = toTeacherProfile(ligne)
    expect(profil.subjects.map((s) => s.id)).toEqual(['sub_math'])
    expect(profil.levels.map((l) => l.id)).toEqual(['lvl_12'])
    expect(profil.certifications).toHaveLength(1)
    expect(profil.certifications[0].subject.name).toBe('Mathématiques')
  })

  it('tire l’annee d’une date de debut', () => {
    const profil = toTeacherProfile(ligne)
    expect(profil.experiences[0].startYear).toBe(2019)
    // Un poste en cours n'a pas de fin : `null`, et non l'annee courante,
    // qui ferait croire a un depart.
    expect(profil.experiences[0].endYear).toBeNull()
  })

  it('accepte aussi une ligne deja aplatie par une vue', () => {
    // `public_teacher_identities` rend le prenom au premier niveau ; les
    // deux formes doivent passer, sinon un des deux chemins rend un nom vide.
    const plat = toTeacherProfile({
      id: 't2',
      first_name: 'Ibrahima',
      last_name: 'Barry',
      headline: 'Physique',
    })
    expect(plat.fullName).toBe('Ibrahima Barry')
  })

  it('n’invente pas de score de confiance sans certification', () => {
    expect(toTeacherProfile({ id: 't3' }).trustScore).toBe(0)
    expect(toTeacherProfile(ligne).trustScore).toBe(82)
  })
})

describe('Badges de confiance', () => {
  it('suivent la preuve, pas une colonne', () => {
    const badges = toBadges(
      { identity_status: 'VERIFIED', diploma_status: 'NONE', headline: 'Maths' },
      { certifications: 1, experiences: 0, subjects: 2 },
    )
    expect(badges).toEqual({
      identity: true,
      diploma: false,
      competency: true,
      experience: false,
      profile: true,
    })
  })

  it('donnent un taux de completion proportionnel', () => {
    const aucun = toBadges({}, { certifications: 0, experiences: 0, subjects: 0 })
    expect(toCompletionRate(aucun)).toBe(0)
    const tous = toBadges(
      { identity_status: 'VERIFIED', diploma_status: 'VERIFIED', headline: 'x' },
      { certifications: 1, experiences: 1, subjects: 1 },
    )
    expect(toCompletionRate(tous)).toBe(100)
  })
})

describe('Offre d’emploi', () => {
  const niveaux = new Map<string, RefItem>([
    ['lvl_11', { id: 'lvl_11', name: '11ème année' }],
    ['lvl_12', { id: 'lvl_12', name: 'Terminale' }],
  ])

  const ligne = {
    id: 'j1',
    title: 'Professeur de maths',
    city: 'Conakry',
    contract_type: 'PERMANENT',
    salary_min: 2_000_000,
    salary_published: true,
    min_experience: 3,
    requires_certification: true,
    level_ids: ['lvl_12', 'lvl_inconnu'],
    published_at: '2026-09-01T10:00:00Z',
    subjects: { id: 'sub_math', name: 'Mathématiques' },
    institutions: { id: 'i1', name: 'Lycée Donka', type: 'HIGH_SCHOOL' },
    applications: [{ count: 4 }],
  }

  it('rapproche les niveaux du referentiel deja charge', () => {
    const offre = toJobOffer(ligne, niveaux)
    // Un identifiant inconnu est ignore plutot que rendu sous forme
    // d'etiquette vide : une ligne blanche dans une liste de niveaux se lit
    // comme une donnee manquante, pas comme une erreur de referentiel.
    expect(offre.levels.map((l) => l.name)).toEqual(['Terminale'])
  })

  it('lit le compteur de candidatures rendu en agregat', () => {
    expect(toJobOffer(ligne, niveaux).applicationCount).toBe(4)
    expect(toJobOffer({ ...ligne, applications: [] }, niveaux)
      .applicationCount).toBe(0)
  })

  it('retombe sur la date de creation si rien n’a ete publie', () => {
    const brouillon = toJobOffer(
      { ...ligne, published_at: null, created_at: '2026-08-01T00:00:00Z' },
      niveaux,
    )
    expect(brouillon.publishedAt).toBe('2026-08-01T00:00:00Z')
  })

  it('ne publie pas un salaire qui ne doit pas l’etre', () => {
    const offre = toJobOffer({ ...ligne, salary_published: false }, niveaux)
    expect(offre.salaryPublished).toBe(false)
  })
})

describe('Candidature', () => {
  it('porte son offre complete', () => {
    const candidature = toApplication(
      {
        id: 'a1',
        status: 'SHORTLISTED',
        applied_at: '2026-09-10T08:00:00Z',
        match_score: 76,
        jobs: { id: 'j1', title: 'Professeur de maths' },
      },
      new Map(),
    )
    expect(candidature.status).toBe('SHORTLISTED')
    expect(candidature.job.title).toBe('Professeur de maths')
    expect(candidature.matchScore).toBe(76)
  })

  it('ramene un statut inconnu sur ENVOYEE', () => {
    const candidature = toApplication({ status: 'EN_ATTENTE' }, new Map())
    expect(candidature.status).toBe('SENT')
  })
})

describe('Question de test', () => {
  it('lit les options rendues en JSONB', () => {
    const question = toTestQuestion({
      id: 'q1',
      statement: 'Combien font 2 + 2 ?',
      domain: 'Calcul',
      options: [
        { key: 'a', text: '3' },
        { key: 'b', text: '4' },
      ],
    })
    expect(question.options).toHaveLength(2)
    expect(question.options[1].text).toBe('4')
  })

  it('ne rend pas la bonne reponse quand la source ne la porte pas', () => {
    // La vue publique ne contient pas `correct_key`. Si elle apparait, c'est
    // qu'on interroge la mauvaise table — et le test se passe alors en
    // lisant la reponse dans l'onglet reseau.
    const question = toTestQuestion({ id: 'q1', options: [] })
    expect(question.correctKey).toBeUndefined()
  })

  it('survit a des options mal formees', () => {
    // Une question chronometree ne doit pas planter au milieu d'un test.
    expect(toTestQuestion({ id: 'q1', options: 'cassé' }).options).toEqual([])
  })
})

describe('Session', () => {
  it('porte l’identifiant de la fiche du role', () => {
    const session = toSession(
      {
        id: 'u1',
        role: 'TEACHER',
        first_name: 'Mariama',
        last_name: 'Diallo',
        city: 'Conakry',
      },
      { teacherId: 't1' },
    )
    expect(session).toEqual({
      userId: 'u1',
      role: 'TEACHER',
      teacherId: 't1',
      institutionId: undefined,
      parentId: undefined,
      city: 'Conakry',
      displayName: 'Mariama Diallo',
    })
  })

  it('retombe sur le telephone quand aucun nom n’est saisi', () => {
    // Un en-tete vide laisse croire qu'on est connecte a autre chose.
    const session = toSession(
      { id: 'u2', role: 'PARENT', phone: '+224620000101' },
      { parentId: 'p1' },
    )
    expect(session.displayName).toBe('+224620000101')
  })

  it('ramene un role inconnu sur le moins engageant', () => {
    expect(toSession({ id: 'u3', role: 'SUPERVISEUR' }, {}).role).toBe('TEACHER')
  })
})
