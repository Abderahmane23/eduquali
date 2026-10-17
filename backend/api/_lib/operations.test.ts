import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { deciderLot, deciderRetrait } from './operations.ts'

/**
 * Les gardes qui entourent la seule opération irréversible du produit.
 *
 * L'argent part par Orange Money et ne revient pas. Ces règles sont donc
 * vérifiées ici, sans base et sans réseau — une garde qu'on ne peut tester
 * qu'en montant une infrastructure n'est jamais testée.
 */

const demande = (status = 'REQUESTED', amount = 450_000) => ({
  id: 'p1',
  amount,
  status,
})

describe('régler un retrait', () => {
  it('paie quand le montant retapé correspond', () => {
    const v = deciderRetrait(demande(), {
      decision: 'PAID',
      amountConfirmed: 450_000,
    })
    assert.deepEqual(v, { ok: true, status: 'PAID', note: null })
  })

  it('refuse de payer quand le montant retapé diffère', () => {
    /*
     * Le cas que rien d'autre n'attrape : l'opérateur traite vingt demandes
     * et clique sur la dix-neuvième en pensant à la vingtième. Aucune
     * vérification de permission ne voit cette erreur-là.
     */
    const v = deciderRetrait(demande(), {
      decision: 'PAID',
      amountConfirmed: 45_000,
    })
    assert.equal(v.ok, false)
    assert.equal('code' in v && v.code, 409)
  })

  it('refuse de payer quand aucun montant n’est retapé', () => {
    // Un client qui oublie le champ ne doit pas payer par défaut.
    const v = deciderRetrait(demande(), { decision: 'PAID' })
    assert.equal(v.ok, false)
  })

  it('exige un motif pour un refus', () => {
    // « Refusé » tout seul ne dit ni quoi corriger ni si l'on peut
    // redemander. Le professeur lit la note telle quelle.
    for (const note of [undefined, '', '   ']) {
      const v = deciderRetrait(demande(), { decision: 'REJECTED', note })
      assert.equal(v.ok, false, `note ${JSON.stringify(note)}`)
      assert.equal('code' in v && v.code, 400)
    }
  })

  it('accepte un refus motivé, et retient le motif nettoyé', () => {
    const v = deciderRetrait(demande(), {
      decision: 'REJECTED',
      note: '  Numéro Orange Money inconnu.  ',
    })
    assert.deepEqual(v, {
      ok: true,
      status: 'REJECTED',
      note: 'Numéro Orange Money inconnu.',
    })
  })

  for (const status of ['PAID', 'REJECTED']) {
    it(`ne repaie pas une demande déjà ${status}`, () => {
      /*
       * C'est l'état attendu quand deux opérateurs ouvrent la même file, ou
       * quand on revient sur l'écran. Le verdict porte `deja`, pas une
       * erreur : rendre un échec inviterait à recommencer, et sur un
       * paiement recommencer est précisément ce qu'il ne faut pas faire.
       */
      const v = deciderRetrait(demande(status), {
        decision: 'PAID',
        amountConfirmed: 450_000,
      })
      assert.equal(v.ok, false)
      assert.equal('deja' in v && v.deja, true)
      assert.equal('status' in v && v.status, status)
    })
  }

  it('une demande approuvée reste réglable', () => {
    // `APPROVED` est une étape, pas une fin : l'argent n'est pas parti.
    const v = deciderRetrait(demande('APPROVED'), {
      decision: 'PAID',
      amountConfirmed: 450_000,
    })
    assert.equal(v.ok, true)
  })
})

describe('trancher un lot', () => {
  it('une remise ne demande pas de motif', () => {
    assert.deepEqual(deciderLot({ decision: 'DELIVERED' }), { ok: true })
  })

  it('un refus en demande un', () => {
    /*
     * L'asymétrie est volontaire : une remise est une bonne nouvelle qui se
     * suffit, un refus reprend quelque chose que l'élève croyait avoir — et
     * les points lui sont rendus, ce qui mérite une phrase.
     */
    const v = deciderLot({ decision: 'REFUSED' })
    assert.equal(v.ok, false)
    assert.equal('code' in v && v.code, 400)
  })
})
