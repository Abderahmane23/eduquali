import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

import { roleReel } from './Signup'
import {
  AUDIENCE_BY_ROLE,
  RENDERED_STEP_TYPES,
  canContinue,
  flatSteps,
  stepApplies,
  visibleSteps,
  type FlowSpec,
  type Role,
  type Step,
} from './spec'

/**
 * Les deux pannes silencieuses de l'inscription web.
 *
 * Ni l'une ni l'autre ne levait d'erreur : elles faisaient disparaitre des
 * ecrans, ce qui ne se voit qu'en parcourant l'inscription jusqu'au bout. Un
 * test est le seul endroit ou elles se voient tout de suite.
 */

/** Lit un parcours dans `public/data/`, comme le navigateur le recevrait. */
function lireParcours(fichier: string): FlowSpec {
  return JSON.parse(
    readFileSync(`public/data/${fichier}.json`, 'utf-8'),
  ) as FlowSpec
}

const etape = (showIf: Step['showIf']): Step =>
  ({ id: 'x', type: 'statement', showIf }) as Step

describe('showIf et les reponses multiples', () => {
  it('une liste correspond des qu un de ses elements correspond', () => {
    // `['HOME','FULL_TIME']` devenait `"HOME,FULL_TIME"`, qui n'egale jamais
    // `"HOME"`. L'ecran disparaissait sans un mot.
    const condition = etape({ field: 'service_types', equals: ['HOME'] })

    expect(stepApplies(condition, { service_types: ['HOME'] })).toBe(true)
    expect(
      stepApplies(condition, { service_types: ['HOME', 'FULL_TIME'] }),
    ).toBe(true)
    expect(stepApplies(condition, { service_types: ['FULL_TIME'] })).toBe(false)
  })

  it('une reponse unique continue de fonctionner', () => {
    const condition = etape({ field: 'role', equals: ['TEACHER'] })
    expect(stepApplies(condition, { role: 'TEACHER' })).toBe(true)
    expect(stepApplies(condition, { role: 'PARENT' })).toBe(false)
  })

  it('une reponse absente ne fait pas apparaitre l ecran', () => {
    const condition = etape({ field: 'service_types', equals: ['HOME'] })
    expect(stepApplies(condition, {})).toBe(false)
  })

  it('une etape sans condition apparait toujours', () => {
    expect(stepApplies(etape(undefined), {})).toBe(true)
  })

  it('les deux ecrans de disponibilite du professeur reviennent', () => {
    // C'est le defaut tel qu'il se manifestait : depuis le retrait de « Vous
    // donnez des cours a domicile ? » le 26/09, `service_types` est une
    // reponse multiple, et aucune des deux disponibilites ne s'affichait plus.
    const parcours = lireParcours('teacher_onboarding')
    const ids = (reponses: Record<string, unknown>) =>
      visibleSteps(parcours, reponses).map((s) => s.id)

    const lesDeux = ids({ service_types: ['HOME', 'FULL_TIME'] })
    expect(lesDeux).toContain('home_availability')
    expect(lesDeux).toContain('availability')

    // Un professeur qui ne donne que des cours a domicile ne voit que la
    // disponibilite correspondante : la condition filtre encore.
    const domicileSeul = ids({ service_types: ['HOME'] })
    expect(domicileSeul).toContain('home_availability')
    expect(domicileSeul).not.toContain('availability')
  })
})

describe('les quatre profils', () => {
  const roles: Role[] = ['TEACHER', 'INSTITUTION', 'PARENT', 'STUDENT']

  it('chacun designe un parcours qui existe', () => {
    // `STUDENT` manquait : la requete partait sur
    // `/data/undefined_onboarding.json` et l'ecran affichait « Parcours
    // indisponible ». Un quatrieme profil choisissable qui ne menait nulle
    // part.
    for (const role of roles) {
      const audience = AUDIENCE_BY_ROLE[role]
      expect(audience, `aucun parcours pour ${role}`).toBeDefined()

      const parcours = lireParcours(`${audience}_onboarding`)
      expect(flatSteps(parcours).length).toBeGreaterThan(0)
    }
  })

  it('les profils proposes par intro.json sont tous couverts', () => {
    // La verite est dans le JSON partage, pas dans le code : un cinquieme
    // profil ajoute la-bas doit faire echouer ce test, pas disparaitre.
    const intro = lireParcours('intro')
    const choix = flatSteps(intro)
      .filter((s) => s.type === 'role_select')
      .flatMap((s) => s.options ?? [])
      .map((o) => o.value)

    expect(choix.length).toBeGreaterThan(0)
    for (const valeur of choix) {
      /*
       * Une carte peut ne pas etre un role.
       *
       * « Elève ou étudiant » vaut `FAMILY`, qui n'existe ni dans la base
       * ni dans les politiques RLS : c'est la question « Êtes-vous
       * parent ? », posée juste après, qui le traduit en `PARENT` ou
       * `STUDENT`. On passe donc par `roleReel`, exactement comme l'écran.
       *
       * Ce que ce contrôle garde est intact : aucune carte ne mène nulle
       * part. Si `FAMILY` cessait d'être traduit, `roleReel` le rendrait
       * tel quel et `AUDIENCE_BY_ROLE` n'en saurait rien — l'épreuve
       * tomberait, comme elle est tombée le jour où `STUDENT` était
       * proposé sans parcours.
       */
      const reel = roleReel({ role: valeur, is_parent: 'no' })
      expect(
        AUDIENCE_BY_ROLE[reel],
        `« ${valeur} » est proposé mais n’a pas de parcours`,
      ).toBeDefined()
    }

    // Les deux reponses de la question doivent mener quelque part, elles
    // aussi : une seule des deux verifiee laisserait l'autre se casser.
    for (const reponse of ['yes', 'no']) {
      const reel = roleReel({ role: 'FAMILY', is_parent: reponse })
      expect(
        AUDIENCE_BY_ROLE[reel],
        `« ${reponse} » ne mène à aucun parcours`,
      ).toBeDefined()
    }
    expect(roleReel({ role: 'FAMILY', is_parent: 'yes' })).toBe('PARENT')
    expect(roleReel({ role: 'FAMILY', is_parent: 'no' })).toBe('STUDENT')
  })
})

describe('tous les types d etape du JSON sont rendus', () => {
  const parcours = ['intro', 'teacher', 'institution', 'parent', 'student']

  it('aucun type n arrive sans rendu', () => {
    // `upload` et `day_hours` ont ete ajoutes au JSON le 24/09 sans rendu
    // cote web : l'ecran s'affichait vide, « Continuer » passait, et un
    // professeur inscrit sur le web ne deposait jamais son CV ni ne declarait
    // ses horaires. Rien ne le signalait.
    const manquants = new Set<string>()
    for (const nom of parcours) {
      const fichier = nom === 'intro' ? 'intro' : `${nom}_onboarding`
      for (const etape of flatSteps(lireParcours(fichier))) {
        if (!RENDERED_STEP_TYPES.includes(etape.type)) {
          manquants.add(`${etape.type} (${nom}/${etape.id})`)
        }
      }
    }
    expect([...manquants]).toEqual([])
  })
})

describe('le depot de documents', () => {
  const documents = flatSteps(lireParcours('teacher_onboarding')).find(
    (s) => s.type === 'upload',
  )!

  it('demande le CV et le diplome', () => {
    expect(documents).toBeDefined()
    expect((documents.uploads ?? []).map((u) => u.id)).toEqual([
      'cv_path',
      'diploma_path',
    ])
  })

  it('reste facultative : le bouton « Passer » doit exister', () => {
    // Un candidat n'a pas toujours son diplome sous la main. Demande le 02/10 :
    // laisser le bouton « Passer » sur cette page du parcours professeur.
    expect(documents.optional).toBe(true)
    expect(canContinue(documents, {})).toBe(true)
  })
})

describe('les disponibilites', () => {
  const domicile = flatSteps(lireParcours('teacher_onboarding')).find(
    (s) => s.id === 'home_availability',
  )!

  it('exigent trois jours pour les cours a domicile', () => {
    // En dessous de trois jours, presque aucune famille ne trouve un creneau
    // qui tombe avec celui du professeur.
    expect(domicile.minSelected).toBe(3)
    expect(canContinue(domicile, {})).toBe(false)
    expect(
      canContinue(domicile, {
        home_availability: { MON: ['MORNING'], TUE: ['EVENING'] },
      }),
    ).toBe(false)
    expect(
      canContinue(domicile, {
        home_availability: {
          MON: ['MORNING'],
          TUE: ['EVENING'],
          WED: ['AFTERNOON'],
        },
      }),
    ).toBe(true)
  })

  it('un jour sans creneau ne compte pas', () => {
    // Il ne dit pas quand on est libre : le compter laisserait passer un
    // professeur que personne ne peut joindre.
    expect(
      canContinue(domicile, {
        home_availability: { MON: [], TUE: [], WED: [], THU: [] },
      }),
    ).toBe(false)
  })
})
