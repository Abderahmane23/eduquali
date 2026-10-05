import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import {
  CLASSEMENT_MINIMUM,
  PARTICIPATION_POINTS,
  awardForRank,
  closingEntries,
  ladder,
  shopProgress,
  leaderboardFor,
  testForWeek,
  weekWindow,
} from './points.ts'

/**
 * Le barème et le classement d'un concours.
 *
 * Trois règles qu'on croit évidentes et qu'on implémente de travers : les ex
 * aequo, le dernier rang récompensé, et le seuil en dessous duquel un
 * « classement national » est une affirmation fausse sur le pays.
 */

const copie = (
  userId: string,
  score: number | null,
  dureeSecondes = 600,
  rendue = true,
) => ({
  userId,
  score,
  startedAt: '2026-10-03T10:00:00.000Z',
  submittedAt: rendue
    ? new Date(Date.parse('2026-10-03T10:00:00.000Z') + dureeSecondes * 1000)
        .toISOString()
    : null,
})

describe('le barème', () => {
  it('donne l’enjeu annoncé au premier, et décroît ensuite', () => {
    assert.equal(awardForRank(100, 1), 100)
    assert.equal(awardForRank(100, 2), 60)
    assert.equal(awardForRank(100, 3), 40)
    assert.equal(awardForRank(100, 4), 10)
    assert.equal(awardForRank(100, 10), 10)
  })

  it('récompense encore celui qui finit 200e', () => {
    // Il a quand même passé une heure sur les questions. Le renvoyer les mains
    // vides est le meilleur moyen qu'il ne revienne pas la semaine suivante.
    assert.equal(awardForRank(100, 200), PARTICIPATION_POINTS)
  })

  it('ne descend jamais sous la participation', () => {
    // Un petit enjeu ne doit pas produire un gain de zéro pour le troisième :
    // « vous avez gagné 0 point » est pire que ne rien annoncer.
    for (const rang of [1, 2, 3, 7, 40]) {
      assert.ok(
        awardForRank(3, rang) >= PARTICIPATION_POINTS,
        `rang ${rang} sur un enjeu de 3`,
      )
    }
  })

  it('refuse les entrées absurdes au lieu de calculer', () => {
    assert.equal(awardForRank(-10, 1), 0)
    assert.equal(awardForRank(100, 0), 0)
    assert.equal(awardForRank(Number.NaN, 1), 0)
  })
})

describe('le classement', () => {
  it('ordonne par score décroissant', () => {
    const classes = ladder([copie('a', 40), copie('b', 90), copie('c', 70)])
    assert.deepEqual(
      classes.map((c) => c.userId),
      ['b', 'c', 'a'],
    )
    assert.deepEqual(
      classes.map((c) => c.rank),
      [1, 2, 3],
    )
  })

  it('départage à score égal par la durée, pas par l’heure d’envoi', () => {
    // Départager sur l'heure favoriserait celui qui s'y met le lundi matin, ce
    // qui ne mesure aucune compétence.
    const classes = ladder([copie('lent', 80, 1800), copie('rapide', 80, 600)])
    assert.deepEqual(
      classes.map((c) => c.userId),
      ['rapide', 'lent'],
    )
  })

  it('partage le rang entre deux copies indiscernables', () => {
    /*
     * Même score, même durée : inventer un ordre serait arbitraire, et l'un des
     * deux le verrait. Classement sportif — deux deuxièmes, puis un quatrième,
     * jamais un troisième.
     */
    const classes = ladder([
      copie('tete', 95, 500),
      copie('ex1', 80, 700),
      copie('ex2', 80, 700),
      copie('suivant', 70, 900),
    ])
    assert.deepEqual(
      classes.map((c) => c.rank),
      [1, 2, 2, 4],
    )
  })

  it('un ex aequo reçoit exactement la même chose que son co-classé', () => {
    // Le contrôle qui justifie d'avoir écrit tout ceci en fonctions pures.
    const copies = [copie('tete', 95, 500), copie('ex1', 80, 700), copie('ex2', 80, 700)]
    const ecritures = closingEntries('ct-1', 'Concours', 100, copies)
    const gains = new Map(ecritures.map((e) => [e.owner_id, e.delta]))
    assert.equal(gains.get('ex1'), gains.get('ex2'))
    assert.equal(gains.get('ex1'), 60)
  })

  it('écarte les copies non rendues, qui ne sont pas des zéros', () => {
    // Une participation ouverte n'est pas un score de zéro : l'élève est
    // peut-être encore en train de répondre. La compter le classerait dernier
    // avant même d'avoir fini.
    const classes = ladder([
      copie('fini', 50),
      copie('encours', null, 600, false),
      { ...copie('rendu-sans-note', null), submittedAt: '2026-10-03T10:10:00.000Z' },
    ])
    assert.deepEqual(
      classes.map((c) => c.userId),
      ['fini'],
    )
  })
})

describe('ce qu’un écran peut afficher', () => {
  const beaucoup = Array.from({ length: CLASSEMENT_MINIMUM }, (_, i) =>
    copie(`u${i}`, 100 - i, 600 + i),
  )

  it('garde le podium fermé en dessous du seuil', () => {
    const vue = leaderboardFor([copie('a', 90), copie('b', 80)])
    assert.equal(vue.published, false)
    assert.deepEqual(vue.podium, [])
    assert.equal(vue.participants, 2)
    assert.equal(vue.missing, CLASSEMENT_MINIMUM - 2)
  })

  it('rend quand même son rang à celui qui regarde', () => {
    // C'est ce qu'il vient chercher, et son rang est honnête quel que soit le
    // nombre de participants — contrairement à un « podium national » à deux.
    const vue = leaderboardFor([copie('a', 90), copie('b', 80)], { me: 'b' })
    assert.equal(vue.published, false)
    assert.equal(vue.me?.rank, 2)
  })

  it('ouvre le podium au seuil atteint', () => {
    const vue = leaderboardFor(beaucoup, { me: 'u3', top: 3 })
    assert.equal(vue.published, true)
    assert.equal(vue.podium.length, 3)
    assert.equal(vue.missing, 0)
    assert.equal(vue.me?.userId, 'u3')
  })

  it('ne rend pas « moi » quand je n’ai pas participé', () => {
    const vue = leaderboardFor(beaucoup, { me: 'inconnu' })
    assert.equal(vue.me, null)
  })
})

describe('la distance au lot suivant', () => {
  const lots = [
    { id: 'a5', pointsPrice: 4500, stock: 3 },
    { id: 'watch', pointsPrice: 39000, stock: 1 },
    { id: 'iphone15', pointsPrice: 30000, stock: 1 },
    { id: 'iphone17', pointsPrice: 48000, stock: 1 },
  ]

  it('vise le moins cher de ceux qu’on ne peut pas encore s’offrir', () => {
    /*
     * Et non le moins cher du catalogue.
     *
     * Une fois le petit lot atteint, viser toujours le même afficherait
     * « encore 0 point » indéfiniment — l'écran cesserait de dire quoi que ce
     * soit au moment précis où il devrait montrer la marche suivante.
     */
    const debut = shopProgress(0, lots)
    assert.equal(debut.nextId, 'a5')
    assert.equal(debut.missing, 4500)

    const apres = shopProgress(5000, lots)
    assert.deepEqual(apres.affordable, ['a5'])
    assert.equal(apres.nextId, 'iphone15')
    assert.equal(apres.missing, 25000)
  })

  it('ignore les lots épuisés', () => {
    // Viser ce qu'on ne pourra pas recevoir est la meilleure façon de faire
    // abandonner.
    const epuise = [
      { id: 'a5', pointsPrice: 4500, stock: 0 },
      { id: 'watch', pointsPrice: 39000, stock: 1 },
    ]
    const vue = shopProgress(0, epuise)
    assert.equal(vue.nextId, 'watch')
    assert.deepEqual(vue.affordable, [])
  })

  it('ne promet rien quand tout est atteint', () => {
    const vue = shopProgress(100000, lots)
    assert.equal(vue.nextId, null)
    assert.equal(vue.missing, 0)
    assert.equal(vue.affordable.length, 4)
  })

  it('un catalogue vide ne casse pas l’écran', () => {
    const vue = shopProgress(500, [])
    assert.equal(vue.nextId, null)
    assert.deepEqual(vue.affordable, [])
  })
})

describe('le concours de la semaine', () => {
  it('tombe toujours sur le lundi 00 h UTC', () => {
    // Mercredi 7 octobre 2026 → la semaine commence le lundi 5.
    const fenetre = weekWindow(new Date('2026-10-07T15:42:00.000Z'))
    assert.equal(fenetre.opensAt, '2026-10-05T00:00:00.000Z')
    assert.equal(fenetre.closesAt, '2026-10-12T00:00:00.000Z')
  })

  it('range le dimanche dans la semaine qui s’achève, pas la suivante', () => {
    /*
     * Le cas que `getUTCDay()` fait rater.
     *
     * Il rend 0 pour dimanche, donc un calcul naïf placerait le dimanche 11 au
     * début d'une semaine commençant le 11 — un concours de un jour, et le vrai
     * concours de la semaine jamais fermé.
     */
    const fenetre = weekWindow(new Date('2026-10-11T23:59:00.000Z'))
    assert.equal(fenetre.opensAt, '2026-10-05T00:00:00.000Z')
  })

  it('donne la même fenêtre tous les jours de la semaine', () => {
    // C'est ce qui rend le cron rejouable : il tourne chaque nuit et ne doit
    // ouvrir qu'un concours par semaine.
    const lundi = weekWindow(new Date('2026-10-05T02:00:00.000Z')).opensAt
    for (const jour of ['06', '07', '08', '09', '10', '11']) {
      assert.equal(
        weekWindow(new Date(`2026-10-${jour}T02:00:00.000Z`)).opensAt,
        lundi,
        `le ${jour} doit tomber dans la même semaine`,
      )
    }
    // Et le lundi suivant ouvre bien une nouvelle fenêtre.
    assert.notEqual(weekWindow(new Date('2026-10-12T02:00:00.000Z')).opensAt, lundi)
  })

  it('fait tourner les tests sans jamais tirer au hasard', () => {
    const tests = ['t-math', 't-fran', 't-angl']
    const semaines = [
      '2026-10-05T00:00:00.000Z',
      '2026-10-12T00:00:00.000Z',
      '2026-10-19T00:00:00.000Z',
      '2026-10-26T00:00:00.000Z',
    ].map((semaine) => testForWeek(semaine, tests))

    // Trois tests, quatre semaines : le premier revient en quatrième position.
    assert.equal(semaines[0], semaines[3])
    assert.equal(new Set(semaines.slice(0, 3)).size, 3)

    // Deux appels sur la même semaine rendent le même test : sans cela, deux
    // exécutions du cron ouvriraient deux concours différents.
    assert.equal(
      testForWeek('2026-10-05T00:00:00.000Z', tests),
      testForWeek('2026-10-05T00:00:00.000Z', tests),
    )
  })

  it('ne choisit rien quand il n’y a aucun test', () => {
    assert.equal(testForWeek('2026-10-05T00:00:00.000Z', []), null)
  })
})

describe('la fermeture d’un concours', () => {
  it('porte la raison en clair, rang compris', () => {
    // « Un solde qui monte sans raison lisible ne motive pas » : la raison est
    // destinée à l'élève, pas au journal technique.
    const ecritures = closingEntries('ct-7', 'Concours de maths', 100, [
      copie('a', 90, 500),
      copie('b', 80, 600),
    ])
    assert.equal(ecritures[0].reason, 'Concours de maths — 1re place')
    assert.equal(ecritures[1].reason, 'Concours de maths — 2e place')
  })

  it('porte une référence qui rend la fermeture rejouable', () => {
    // Fermer deux fois le même concours ne doit pas doubler les gains :
    // l'appelant reconnaît les écritures déjà passées à cette référence.
    const ecritures = closingEntries('ct-7', 'Concours', 100, [copie('a', 90)])
    assert.equal(ecritures[0].reference, 'contest:ct-7')
  })

  it('n’écrit rien pour une copie non rendue', () => {
    const ecritures = closingEntries('ct-7', 'Concours', 100, [
      copie('a', 90),
      copie('b', null, 600, false),
    ])
    assert.deepEqual(
      ecritures.map((e) => e.owner_id),
      ['a'],
    )
  })

  it('aucune écriture ne vaut zéro', () => {
    // `point_ledger` refuse `delta = 0` : une écriture nulle ferait échouer la
    // fermeture entière, et personne ne recevrait ses points.
    const ecritures = closingEntries('ct-7', 'Concours', 0, [
      copie('a', 90),
      copie('b', 80),
    ])
    for (const ecriture of ecritures) {
      assert.ok(ecriture.delta > 0, `delta de ${ecriture.owner_id}`)
    }
  })
})
