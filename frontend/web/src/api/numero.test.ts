import { readFileSync } from 'node:fs'

import { describe, expect, it } from 'vitest'

import { adresseDuCompte, numeroNational } from './numero'

/*
 * Le tableau des formes vient de `shared/identite/numeros.json`, et pas de ce
 * fichier. L'epreuve jumelle du mobile (`test/numero_test.dart`) lit le meme
 * fichier : c'est la seule facon de garantir que les deux formules disent la
 * meme chose. Deux formules qui divergent feraient deux comptes pour une
 * personne, et ce serait invisible jusqu'au jour ou elle change d'appareil.
 */
const TABLE = JSON.parse(
  readFileSync('../../shared/identite/numeros.json', 'utf-8'),
) as {
  _domaine: string
  meme_personne: { national: string; saisies: string[] }
  intouchables: { cas: { saisi: string; national: string }[] }
}

describe('le numero qui identifie un compte', () => {
  it('ramene toutes les facons de taper un numero a la meme adresse', () => {
    const attendue = `${TABLE.meme_personne.national}@${TABLE._domaine}`

    /*
     * `Array.from` et non `[...new Set()]` : etale sur plusieurs lignes, le
     * second rendait `[]` sous vitest — l'epreuve passait en ne verifiant
     * rien. Verifie le 16/10 en la cassant expres.
     */
    const adresses = Array.from(
      new Set(TABLE.meme_personne.saisies.map((s) => adresseDuCompte(s))),
    )

    expect(adresses).toEqual([attendue])
    expect(TABLE.meme_personne.saisies.length).toBeGreaterThan(5)
  })

  /*
   * L'epreuve qui aurait attrape le defaut. On la garde nommee d'apres lui,
   * pour qu'une regression se lise comme le retour de ce bug precis.
   */
  it('ne cree pas un second compte pour un numero colle avec son indicatif', () => {
    expect(adresseDuCompte('+224620000101')).toBe(adresseDuCompte('620000101'))
    expect(adresseDuCompte('0620000101')).toBe(adresseDuCompte('620000101'))
    expect(adresseDuCompte('00224620000101')).toBe(
      adresseDuCompte('620000101'),
    )
  })

  it('garde les neuf chiffres, et rien devant', () => {
    expect(numeroNational('+224 628 11 22 33')).toBe('628112233')
    expect(numeroNational('628112233')).toHaveLength(9)
  })

  it('ne confond pas un indicatif avec le debut d un numero', () => {
    for (const cas of TABLE.intouchables.cas) {
      expect(numeroNational(cas.saisi)).toBe(cas.national)
    }
  })

  it('ne rend pas une adresse valide pour une saisie vide', () => {
    // Le module identifie, il ne valide pas : la saisie vide ressort vide,
    // et c'est au champ de le dire.
    expect(numeroNational('')).toBe('')
    expect(numeroNational('abc')).toBe('')
  })
})
