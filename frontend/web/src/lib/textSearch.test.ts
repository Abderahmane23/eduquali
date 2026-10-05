import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

import { foldText, matchesSearch } from './textSearch'

/**
 * La recherche sur un clavier guineen.
 *
 * Le drapeau `searchable` etait pose sur les quatre etapes « matieres » depuis
 * le 24/09 et ne produisait rien sur le web : la liste restait un mur de
 * vingt-quatre etiquettes, et on cochait la premiere qui ressemblait.
 */
describe('la comparaison de texte', () => {
  it('ignore les accents et la casse', () => {
    // C'est le cas qui compte : personne ne tape les accents sur un clavier de
    // telephone, et « aucun resultat » sur une liste qui contient la reponse
    // fait conclure que la matiere n'existe pas.
    expect(matchesSearch('Français', 'francais')).toBe(true)
    expect(matchesSearch('Mathématiques', 'MATHE')).toBe(true)
    expect(matchesSearch('Nzérékoré', 'nzerekore')).toBe(true)
    expect(matchesSearch('Éducation civique', 'educ')).toBe(true)
  })

  it('cherche partout dans le libelle, pas seulement au debut', () => {
    // « Sciences de la vie et de la Terre » se cherche par « terre ».
    expect(matchesSearch('Sciences de la vie et de la Terre', 'terre')).toBe(
      true,
    )
  })

  it('une recherche vide laisse tout passer', () => {
    expect(matchesSearch('Physique', '')).toBe(true)
    expect(matchesSearch('Physique', '   ')).toBe(true)
  })

  it('ne rapproche pas ce qui ne se ressemble pas', () => {
    expect(matchesSearch('Physique', 'chimie')).toBe(false)
  })

  it('replie les espaces, affiche l original', () => {
    // `foldText` ne sert qu'a comparer : « Nzérékoré » s'affiche avec ses
    // accents.
    expect(foldText('  Éducation   Civique ')).toBe('education civique')
  })
})

describe('les etapes a chercher', () => {
  const parcours = ['teacher', 'institution', 'parent', 'student']

  it('les quatre etapes « matieres » portent le drapeau et une invite', () => {
    // La verite est dans le JSON partage : ce test echoue si une etape le perd
    // d'un cote sans le perdre de l'autre.
    for (const nom of parcours) {
      const brut = readFileSync(
        `public/data/${nom}_onboarding.json`,
        'utf-8',
      )
      const spec = JSON.parse(brut) as { sections: unknown[] }

      const cherchables: Array<{ searchHint?: string; id: string }> = []
      const walk = (o: unknown) => {
        if (Array.isArray(o)) return o.forEach(walk)
        if (o && typeof o === 'object') {
          const noeud = o as Record<string, unknown>
          if (noeud.searchable === true) {
            cherchables.push(noeud as { searchHint?: string; id: string })
          }
          Object.values(noeud).forEach(walk)
        }
      }
      walk(spec.sections)

      expect(cherchables.length, `${nom} : aucune étape cherchable`).toBe(1)
      // Sans invite, le champ s'affiche vide et on ne sait pas quoi y taper.
      expect(cherchables[0].searchHint, `${nom} : pas d’invite`).toBeTruthy()
    }
  })
})
