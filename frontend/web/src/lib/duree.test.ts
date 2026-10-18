import { describe, expect, it } from 'vitest'

import { duree, dureeSecondes } from './format'

/**
 * Une duree s'ecrit avec ses deux chiffres de minutes.
 *
 * --- Le defaut qui a motive ce fichier ----------------------------------
 *
 * La carte du catalogue annoncait « 3 chapitres · 6 videos · 1 h 2 » pour un
 * cours d'une heure et deux minutes. Vu en pilotant le vrai site a 1440
 * points, le 18/10. La fonction qui l'ecrivait promettait pourtant « 1 h 12 »
 * dans sa propre documentation.
 *
 * En francais, les minutes prennent deux chiffres apres l'heure. Sans le
 * zero, « 1 h 2 » se lit aussi bien deux minutes que vingt — et sur une carte
 * qu'on parcourt avant d'acheter, c'est la duree qui dit ce qu'on en a pour
 * son argent.
 *
 * Trois ecrans portaient chacun leur copie de ce calcul, et une seule des
 * trois oubliait le zero. Le meme defaut avait deja ete corrige dans
 * l'application mobile : il a survecu ici parce qu'il y avait trois
 * endroits ou le corriger. Il n'y en a plus qu'un.
 */
describe('la duree affichee', () => {
  it('garde les deux chiffres des minutes', () => {
    expect(duree(62)).toBe('1 h 02')
    expect(duree(61)).toBe('1 h 01')
    expect(duree(69)).toBe('1 h 09')
  })

  it('n’ecrit pas de minutes quand il n’y en a pas', () => {
    expect(duree(60)).toBe('1 h')
    expect(duree(120)).toBe('2 h')
  })

  it('reste en minutes sous l’heure', () => {
    expect(duree(44)).toBe('44 min')
    expect(duree(59)).toBe('59 min')
    expect(duree(0)).toBe('0 min')
  })

  it('ne rend jamais une duree negative', () => {
    // Une soustraction de dates mal ordonnee ne doit pas afficher « -3 min ».
    expect(duree(-30)).toBe('0 min')
  })

  it('convertit les secondes sans changer de regle', () => {
    expect(dureeSecondes(3720)).toBe('1 h 02')
    expect(dureeSecondes(2640)).toBe('44 min')
  })

  /*
   * L'epreuve qui aurait attrape le defaut, nommee d'apres lui.
   */
  it('n’ecrit jamais « 1 h 2 »', () => {
    const suspectes = []
    for (let minutes = 60; minutes <= 60 * 12; minutes += 1) {
      const rendu = duree(minutes)
      // Deux chiffres apres « h », ou rien du tout.
      if (/ h \d$/.test(rendu)) suspectes.push(`${minutes} -> ${rendu}`)
    }
    expect(suspectes).toEqual([])
  })
})
