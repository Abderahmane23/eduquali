import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import {
  ESSAI,
  FORMULES,
  JOURS_ESSAI,
  dansLEssai,
  debutDePeriode,
  formuleDe,
  formuleEffective,
  joursDEssaiRestants,
  verdict,
} from './formules.ts'

/**
 * Les regles d'acces, eprouvees sans base ni reseau.
 *
 * Ce module decide ce qu'un compte peut faire. Une regle d'acces qu'on ne
 * peut eprouver qu'en creant un compte et en attendant sept jours n'est
 * jamais eprouvee — et c'est precisement quand elle se trompe qu'elle coute
 * cher : soit on ferme la porte a qui a paye, soit on l'ouvre a qui n'a pas
 * paye.
 */

const LE = (iso: string) => new Date(iso)

describe('L’essai de sept jours', () => {
  const inscription = LE('2026-10-01T10:00:00Z')

  it('dure sept jours pleins', () => {
    assert.equal(dansLEssai(inscription, LE('2026-10-01T10:00:01Z')), true)
    assert.equal(dansLEssai(inscription, LE('2026-10-07T23:00:00Z')), true)
    assert.equal(dansLEssai(inscription, LE('2026-10-08T10:00:01Z')), false)
  })

  it('annonce ce qu’il en reste', () => {
    assert.equal(joursDEssaiRestants(inscription, inscription), JOURS_ESSAI)
    /*
     * Un jour entame compte pour un jour entier.
     *
     * Le 7 a 9 h, il reste vingt-cinq heures : on annonce deux jours, pas
     * un. Arrondir vers le bas dirait « il reste 1 jour » a quelqu'un qui en
     * a encore un et demi, et l'ecran qui pousse a s'abonner mentirait dans
     * le sens qui l'arrange.
     */
    assert.equal(
      joursDEssaiRestants(inscription, LE('2026-10-07T09:00:00Z')),
      2,
    )
    // Vingt-trois heures : un jour.
    assert.equal(
      joursDEssaiRestants(inscription, LE('2026-10-07T11:00:00Z')),
      1,
    )
    assert.equal(
      joursDEssaiRestants(inscription, LE('2026-10-20T00:00:00Z')),
      0,
    )
  })

  it('ouvre les directs et les cours, mais pas l’assistant', () => {
    assert.equal(ESSAI.quotas.direct.max, null)
    assert.equal(ESSAI.quotas.cours.max, null)
    // Trois questions par jour, essai compris : chaque question est facturee
    // au jeton chez le fournisseur.
    assert.equal(ESSAI.quotas.assistant.max, 3)
  })

  it('s’applique a un compte neuf, meme s’il a demande une formule payante', () => {
    // `pending_plan` est une intention, pas un paiement.
    const formule = formuleEffective({
      plan: 'FREE',
      renouvelleLe: null,
      creeLe: inscription,
      maintenant: LE('2026-10-03T10:00:00Z'),
    })
    assert.equal(formule.nom, 'Essai')
  })

  it('laisse place au gratuit une fois fini', () => {
    const formule = formuleEffective({
      plan: 'FREE',
      renouvelleLe: null,
      creeLe: inscription,
      maintenant: LE('2026-10-20T10:00:00Z'),
    })
    assert.equal(formule.nom, 'Gratuit')
    assert.equal(formule.quotas.direct.max, 1)
    assert.equal(formule.quotas.cours.max, 1)
  })
})

describe('Les deux formules payantes', () => {
  it('portent les prix annonces', () => {
    assert.equal(FORMULES.PRO.prixGnf, 50000)
    assert.equal(FORMULES.MASTER.prixGnf, 200000)
  })

  it('Decouverte donne quatre cours et deux directs par mois', () => {
    assert.deepEqual(FORMULES.PRO.quotas.cours, { max: 4, periode: 'mois' })
    assert.deepEqual(FORMULES.PRO.quotas.direct, { max: 2, periode: 'mois' })
  })

  it('Illimite n’a aucune limite, et ouvre les deux extras', () => {
    assert.equal(FORMULES.MASTER.quotas.cours.max, null)
    assert.equal(FORMULES.MASTER.quotas.direct.max, null)
    assert.equal(FORMULES.MASTER.quotas.assistant.max, null)
    assert.equal(FORMULES.MASTER.questionsEnDirect, true)
    assert.equal(FORMULES.MASTER.exercicesCorriges, true)
  })

  it('aucune formule sous Illimite n’ouvre les extras', () => {
    for (const code of ['FREE', 'PRO'] as const) {
      assert.equal(FORMULES[code].questionsEnDirect, false, code)
      assert.equal(FORMULES[code].exercicesCorriges, false, code)
    }
  })

  it('expire a la fin du jour paye, pas a l’heure pres', () => {
    const commun = {
      creeLe: LE('2026-01-01T00:00:00Z'),
      plan: 'PRO',
      renouvelleLe: LE('2026-10-15T00:00:00Z'),
    }
    // Le jour meme de l'echeance compte encore.
    assert.equal(
      formuleEffective({ ...commun, maintenant: LE('2026-10-15T23:00:00Z') })
        .code,
      'PRO',
    )
    assert.equal(
      formuleEffective({ ...commun, maintenant: LE('2026-10-16T01:00:00Z') })
        .nom,
      'Gratuit',
    )
  })

  it('une formule payante sans echeance ne vaut rien', () => {
    // Sinon il suffirait d'ecrire `plan = 'MASTER'` pour tout ouvrir.
    const formule = formuleEffective({
      plan: 'MASTER',
      renouvelleLe: null,
      creeLe: LE('2026-01-01T00:00:00Z'),
      maintenant: LE('2026-10-15T00:00:00Z'),
    })
    assert.equal(formule.nom, 'Gratuit')
  })
})

describe('Le verdict', () => {
  it('laisse passer tant qu’il reste du quota', () => {
    const v = verdict(FORMULES.PRO, 'cours', 3)
    assert.equal(v.permis, true)
    assert.equal(v.restant, 1)
  })

  it('refuse au-dela, et dit pourquoi en chiffres', () => {
    const v = verdict(FORMULES.PRO, 'direct', 2)
    assert.equal(v.permis, false)
    assert.equal(v.restant, 0)
    assert.ok(v.message?.includes('2'))
    assert.ok(v.message?.includes('ce mois-ci'))
    assert.ok(v.message?.includes('Découverte'))
  })

  it('nomme la quinzaine du compte gratuit', () => {
    const v = verdict(FORMULES.FREE, 'direct', 1)
    assert.equal(v.permis, false)
    assert.ok(v.message?.includes('quinze derniers jours'))
  })

  it('ne refuse jamais sur une formule sans limite', () => {
    const v = verdict(FORMULES.MASTER, 'cours', 9999)
    assert.equal(v.permis, true)
    assert.equal(v.restant, null)
  })

  it('traite un compteur absurde comme zero', () => {
    // Un compteur negatif viendrait d'une soustraction ratee : il ne doit
    // pas offrir du quota en plus.
    const v = verdict(FORMULES.FREE, 'cours', -5)
    assert.equal(v.permis, true)
    assert.equal(v.restant, 1)
  })
})

describe('Les periodes', () => {
  const maintenant = LE('2026-10-18T14:30:00Z')

  it('le jour commence a minuit', () => {
    assert.equal(
      debutDePeriode('jour', maintenant)?.toISOString(),
      '2026-10-18T00:00:00.000Z',
    )
  })

  it('le mois commence le premier', () => {
    assert.equal(
      debutDePeriode('mois', maintenant)?.toISOString(),
      '2026-10-01T00:00:00.000Z',
    )
  })

  it('la quinzaine glisse, elle ne se cale pas sur le mois', () => {
    /*
     * Un decoupage fixe — « les quinze premiers jours » — donnerait deux
     * directs a qui s'inscrit le 14 (un le 14, un le 16) et un seul a qui
     * s'inscrit le 2. La fenetre glisse donc avec la date du jour.
     */
    assert.equal(
      debutDePeriode('quinzaine', maintenant)?.toISOString(),
      '2026-10-05T00:00:00.000Z',
    )
  })

  it('« jamais » n’a pas de debut', () => {
    assert.equal(debutDePeriode('jamais', maintenant), null)
  })
})

describe('Un code de formule inconnu', () => {
  it('retombe sur le gratuit, sans lever', () => {
    // Une valeur inattendue en base ne doit pas tout ouvrir, ni casser
    // l'ecran : elle doit fermer.
    assert.equal(formuleDe('PLATINE').code, 'FREE')
    assert.equal(formuleDe(null).code, 'FREE')
    assert.equal(formuleDe(undefined).code, 'FREE')
  })
})
