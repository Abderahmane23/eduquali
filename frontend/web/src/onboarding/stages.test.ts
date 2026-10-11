import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

import { filterOptions, type Option } from './spec'

/**
 * Les cinq paliers d'études, et le filtre des classes.
 *
 * --- Le défaut que ces tests figent --------------------------------------
 *
 * « Vous enseignez à quel niveau ? » n'avait **aucun effet** sur « Quelles
 * classes ? ». Un professeur de primaire se voyait proposer « Master 2 ». Deux
 * causes se cumulaient, et chacune suffisait :
 *
 *   1. le résolveur du site posait `group` au singulier, que `filterOptions` ne
 *      lit pas — il ne regarde que `groups`, et traite une option sans `groups`
 *      comme toujours acceptable. Le filtre ne retirait donc jamais rien ;
 *   2. il y mettait `category`, qui range collège et lycée dans le même
 *      « SECONDARY », alors que le filtre compare à un cycle (« COLLEGE »).
 *      Même lu, il n'aurait rien apparié.
 *
 * L'application mobile posait `groups: l.cycles` depuis le début : les deux
 * clients avaient divergé sur la question que l'usager voit en premier.
 */
const code = (chemin: string) =>
  readFileSync(chemin, 'utf-8')
    .replace(/\r\n/g, '\n')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^[ \t]*\/\/.*$/gm, '')

const catalogue = JSON.parse(
  readFileSync('../../shared/seed/catalog.json', 'utf-8'),
)

describe('les cinq paliers du référentiel', () => {
  it('sont exactement primaire, collège, lycée, université, diplômé', () => {
    expect(catalogue.stages.map((s: { id: string }) => s.id)).toEqual([
      'PRIMAIRE',
      'COLLEGE',
      'LYCEE',
      'SUPERIEUR',
      'DIPLOME',
    ])
    /*
     * Les libellés nomment la PERSONNE, pas le cycle.
     *
     * Ces paliers ne servent qu'à deux questions : « Où en êtes-vous dans vos
     * études ? » et « Où en est votre enfant ? ». On y répond « collégien », pas
     * « collège ». Les rangées `levels` de regroupement gardent le nom du cycle,
     * et c'est là qu'« un professeur enseigne au collège » se dit.
     *
     * « Universitaire » porte en plus le nom du compte qui s'inscrit pour
     * lui-même : les deux doivent se répondre.
     */
    expect(catalogue.stages.map((s: { name: string }) => s.name)).toEqual([
      'Écolier',
      'Collégien',
      'Lycéen',
      'Universitaire',
      'Diplômé',
    ])
  })

  it('chaque palier correspond à un cycle de niveau, et réciproquement', () => {
    // C'est l'invariant qui permet à `optionsFilter` d'apparier sans table de
    // correspondance : l'identifiant d'un palier EST la valeur de `cycle`. S'ils
    // divergent, le filtre redevient silencieusement inopérant.
    const paliers = new Set(catalogue.stages.map((s: { id: string }) => s.id))
    const cycles = new Set(
      catalogue.levels.map((l: { cycle: string }) => l.cycle),
    )
    expect([...cycles].sort()).toEqual([...paliers].sort())
  })

  it('les paliers sans classe sont le primaire et le diplômé', () => {
    // Le référentiel ne détaille pas les six années du primaire, et un diplômé
    // n'est dans aucune classe. Poser la question obligerait à inventer.
    const sansClasse = catalogue.stages
      .filter((s: { hasClasses: boolean }) => !s.hasClasses)
      .map((s: { id: string }) => s.id)
    expect(sansClasse).toEqual(['PRIMAIRE', 'DIPLOME'])
  })

  it('« diplômé » existe comme niveau, pas seulement comme palier', () => {
    // Un palier sans niveau ne pourrait pas être enregistré : `children.level_id`
    // et `profiles` pointent sur `levels`.
    const diplome = catalogue.levels.find(
      (l: { id: string }) => l.id === 'lvl_diplome',
    )
    expect(diplome).toBeDefined()
    expect(diplome.cycle).toBe('DIPLOME')
    expect(diplome.grouping).toBe(true)
  })
})

describe('le filtre des classes par palier', () => {
  /** Les options de niveaux telles que le résolveur les produit désormais. */
  const niveaux: Option[] = catalogue.levels.map(
    (l: { id: string; name: string; cycle: string }) => ({
      value: l.id,
      label: l.name,
      groups: l.cycle ? [l.cycle] : [],
    }),
  )

  it('un palier collège ne propose aucune classe de lycée ni d’université', () => {
    const vus = filterOptions(niveaux, { field: 'stage' }, {
      stage: 'COLLEGE',
    }).map((o) => o.value)

    expect(vus).toContain('lvl_7')
    expect(vus).toContain('lvl_10')
    expect(vus).not.toContain('lvl_terminale')
    // Le symptôme exact qui était signalé.
    expect(vus).not.toContain('lvl_m2')
  })

  it('un palier université ne propose que L1 à M2', () => {
    const vus = filterOptions(niveaux, { field: 'stage' }, {
      stage: 'SUPERIEUR',
    }).map((o) => o.value)
    expect(vus).toEqual(['lvl_l1', 'lvl_l2', 'lvl_l3', 'lvl_m1', 'lvl_m2'])
  })

  it('plusieurs paliers cumulent leurs classes', () => {
    // Le cas du professeur : il enseigne au collège ET au lycée.
    const vus = filterOptions(niveaux, { field: 'cycles' }, {
      cycles: ['COLLEGE', 'LYCEE'],
    }).map((o) => o.value)
    expect(vus).toContain('lvl_8')
    expect(vus).toContain('lvl_12')
    expect(vus).not.toContain('lvl_l1')
  })

  it('l’ancienne forme — `group` au singulier — ne filtrerait rien', () => {
    // Le test qui aurait dit non. Une option sans `groups` passe toujours : avec
    // `group`, les seize classes restaient proposées quel que soit le palier.
    const ancienneForme = catalogue.levels.map(
      (l: { id: string; name: string; category: string }) => ({
        value: l.id,
        label: l.name,
        group: l.category,
      }),
    ) as unknown as Option[]

    const vus = filterOptions(ancienneForme, { field: 'stage' }, {
      stage: 'COLLEGE',
    })
    expect(vus).toHaveLength(catalogue.levels.length)
  })
})

describe('le résolveur du site', () => {
  const flow = code('src/onboarding/OnboardingFlow.tsx')

  it('pose `groups` et le cycle, jamais `group` seul', () => {
    const cas = flow.slice(
      flow.indexOf("case 'levels':"),
      flow.indexOf("case 'stages'"),
    )
    expect(cas).toContain('groups:')
    expect(cas).toContain('l.cycle')
    expect(cas).not.toMatch(/\bgroup:\s/)
  })

  it('sait résoudre les paliers', () => {
    expect(flow).toContain("case 'stages'")
    expect(flow).toContain('loadStages()')
  })

  it('ne recopie aucun palier en dur', () => {
    // Le parcours enseignant en listait quatre à la main, et « diplômé » n'y
    // était pas. Une source, cinq paliers, trois parcours.
    for (const dur of ['PRIMAIRE', 'LYCEE', 'SUPERIEUR']) {
      expect(flow).not.toContain(`value: '${dur}'`)
    }
  })
})

describe('les parcours parent et étudiant', () => {
  const parcours = (nom: string) =>
    JSON.parse(readFileSync(`../../shared/onboarding/${nom}.json`, 'utf-8'))

  const etapes = (nom: string): Array<Record<string, unknown>> =>
    parcours(nom).sections.flatMap(
      (s: { steps: Array<Record<string, unknown>> }) => s.steps,
    )

  it('demandent l’école, le quartier et la commune dès la deuxième page', () => {
    for (const [nom, prefixe] of [
      ['student_onboarding', ''],
      ['parent_onboarding', 'child_'],
    ] as const) {
      const liste = etapes(nom)
      const seconde = liste[1] as {
        id: string
        fields: Array<{ id: string; required?: boolean }>
      }
      expect(seconde.id).toBe(`${prefixe}school`)
      const champs = seconde.fields.map((f) => f.id)
      expect(champs).toContain(`${prefixe}institution`)
      expect(champs).toContain('city')
      expect(champs).toContain('district')

      // Le quartier devient obligatoire : c'est lui qui décide si un professeur
      // peut venir à pied.
      const quartier = seconde.fields.find((f) => f.id === 'district')
      expect(quartier?.required).toBe(true)

      // L'école reste facultative, et c'est ce qui remplace « a-t-il déjà une
      // école ? » : la laisser vide dit qu'on en cherche une.
      const ecole = seconde.fields.find((f) => f.id === `${prefixe}institution`)
      expect(ecole?.required).toBe(false)
    }
  })

  it('ne redemandent plus l’établissement plus loin dans le parcours', () => {
    const ids = etapes('parent_onboarding').map((e) => e.id)
    expect(ids).not.toContain('child_status')
    expect(ids).not.toContain('current_school')
  })

  it('ne demandent plus où se passent les cours à domicile', () => {
    expect(etapes('parent_onboarding').map((e) => e.id)).not.toContain(
      'tutoring_mode',
    )
  })

  it('proposent les cinq paliers avant la classe', () => {
    for (const [nom, champ] of [
      ['student_onboarding', 'level_stage'],
      ['parent_onboarding', 'child_level_stage'],
    ] as const) {
      const liste = etapes(nom)
      const palier = liste.find((e) => e.fieldId === champ) as
        | { optionsSource: string }
        | undefined
      expect(palier?.optionsSource).toBe('stages')

      const classe = liste.find(
        (e) => (e.optionsFilter as { field?: string })?.field === champ,
      ) as { optionsSource: string; showIf: { equals: string[] } } | undefined
      expect(classe?.optionsSource).toBe('levels')

      /*
       * La classe ne se demande que pour les paliers qui en ont.
       *
       * Le primaire a rejoint la liste le 11/10. Il en etait absent pour une
       * raison concrete : le referentiel ne detaillait pas ses six annees,
       * donc la question n'avait rien a proposer. Elles existent desormais
       * (1ere a 6eme annee, la numerotation guineenne continue qui donne
       * ensuite la 7eme au college).
       *
       * « Diplome » reste dehors, et le restera : il n'est dans aucune classe.
       */
      expect(classe?.showIf.equals).toEqual([
        'PRIMAIRE',
        'COLLEGE',
        'LYCEE',
        'SUPERIEUR',
      ])
      expect(classe?.showIf.equals).not.toContain('DIPLOME')

      // Et le palier vient AVANT la classe, sinon le filtre n'a rien à lire.
      expect(liste.indexOf(palier as never)).toBeLessThan(
        liste.indexOf(classe as never),
      )
    }
  })

  /**
   * Le numero de paiement ne se demande plus a l'inscription (04/10).
   *
   * L'etape existait et portait, dans son propre libelle, « Le meme que votre
   * numero de compte, en general ». Elle reposait donc une question deja
   * repondue deux ecrans plus tot, sans preremplir — le modele d'etape n'a
   * aucune notion de prerempli — et `momo_phone` n'etait **lu nulle part**
   * dans le code.
   *
   * Elle etait aussi inutile par construction : le serveur prend deja le
   * numero du compte comme payeur par defaut et accepte un autre numero au
   * moment de payer (`chargeWallet`, `payerPhone` facultatif). La question se
   * pose donc la ou le montant est a l'ecran, pas douze ecrans avant.
   */
  it('ne redemandent pas le numéro de paiement', () => {
    for (const nom of ['student_onboarding', 'parent_onboarding']) {
      const liste = etapes(nom)
      expect(liste.find((e) => e.id === 'payment')).toBeUndefined()
      // Et le numéro du compte, lui, reste demandé une fois.
      const numeros = liste.filter((e) =>
        (e.fields as Array<{ id: string }> | undefined)?.some(
          (f) => f.id === 'phone',
        ),
      )
      expect(numeros).toHaveLength(1)
    }
  })

  /**
   * Un etablissement declare ce qu'il est.
   *
   * `SignupCompletion` lisait `institution_type` sans qu'aucune etape ne la
   * demande : tout etablissement etait donc cree `SCHOOL`, universite
   * comprise.
   */
  it('demandent le type de l’établissement', () => {
    const champs = etapes('institution_onboarding').flatMap(
      (e) => (e.fields as Array<{ id: string; options?: unknown[] }>) ?? [],
    )
    const type = champs.find((f) => f.id === 'institution_type')
    expect(type).toBeDefined()
    expect(type!.options?.length).toBeGreaterThanOrEqual(5)
  })
})
