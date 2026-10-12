import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * La structure des pages, sur un téléphone comme sur un ordinateur.
 *
 * --- Les quatre défauts que ces tests empêchent de revenir --------------
 *
 * Tous les quatre se sont produits le 11/10, et aucun ne lève d'erreur :
 *
 *   1. une page en dégradé qui ne remplit pas l'écran, parce qu'un
 *      pourcentage de hauteur se calcule sur un parent qui n'en a pas ;
 *   2. deux colonnes **inversées**, parce que la latérale est première dans
 *      le DOM et que le placement automatique la met dans la première
 *      colonne de la grille ;
 *   3. un fil de discussion et sa liste empilés dans 580 px sur un
 *      téléphone, alors que le commentaire annonçait le contraire ;
 *   4. un montant qui déborde de sa cellule de bandeau.
 *
 * Ils s'affichent. C'est tout le problème : il n'y a rien à rattraper, il n'y
 * a qu'à regarder — et on ne regarde pas toutes les pages à toutes les
 * largeurs à chaque changement.
 */
const app = readFileSync('src/styles/app.css', 'utf-8')

/**
 * La feuille sans ses commentaires.
 *
 * Deux de ces tests se sont trompés avant de servir : ils cherchaient
 * `min-height: 100%` dans une règle et le trouvaient dans le commentaire qui
 * explique *pourquoi cette valeur a été retirée*. Un test qui lit la prose
 * autour du code ne vérifie pas le code.
 */
const regles = app.replace(/\/\*[\s\S]*?\*\//g, '')

/**
 * Le corps d'une règle, par son sélecteur exact.
 *
 * Ancré en début de ligne, et c'est le second piège rencontré :
 * `indexOf('.chat__list {')` trouvait d'abord la fin de
 * `.chat[data-ouvert='true'] .chat__list {`, donc le test lisait une règle
 * de masquage en croyant lire la règle de base.
 */
function regle(selecteur: string, depuis = 0): string {
  /*
   * Construit sans une seule sequence d'echappement, et ce n'est pas une
   * coquetterie.
   *
   * La premiere version s'ecrivait `^\\s*...` dans un litteral gabarit. Dans
   * un gabarit, `\\s` n'est pas une sequence reconnue : elle vaut « s ». Le
   * motif cherchait donc « debut de ligne, zero ou plusieurs lettres s », et
   * l'aide ne trouvait plus rien — en rendant `null`, elle faisait echouer
   * les tests pour la mauvaise raison.
   *
   * `[ ]` pour l'espace, `[.]` pour le point, `[{]` pour l'accolade : des
   * classes de caracteres disent la meme chose et ne traversent aucun
   * mecanisme d'echappement.
   */
  const motif = new RegExp(`^[ ]*[.]${selecteur.slice(1)} [{]`, 'm')
  const trouve = motif.exec(regles.slice(depuis))
  expect(trouve, `${selecteur} introuvable`).not.toBeNull()
  const i = depuis + trouve!.index
  return regles.slice(i, regles.indexOf('}', i))
}

describe('une page en dégradé remplit l’écran', () => {
  it('et sa hauteur ne dépend pas d’un parent qui n’en a pas', () => {
    /*
     * `min-height: 100%` ne résolvait rien : le parent est `<main>`, qui n'a
     * aucune hauteur déclarée, donc la règle retombait sur `auto`. Le
     * dégradé faisait la hauteur de son contenu et le fond clair reprenait
     * en dessous — exactement le défaut que cette page devait corriger.
     */
    const bloc = regle('.hero-page')
    expect(bloc, 'un pourcentage de hauteur sans parent dimensionné').not.toMatch(
      /min-height:\s*100%/,
    )
    expect(bloc).toContain('100dvh')
  })

  it('en `dvh` et jamais en `vh`', () => {
    /*
     * Sur un navigateur de téléphone, `vh` compte la fenêtre **barre
     * d'adresse masquée**. 100vh dépasse donc l'écran visible de la hauteur
     * de cette barre, et ce qui est posé en bas de page tombe dessous — les
     * deux pastilles « Créer mon compte » et « Me connecter », par exemple.
     */
    const fautives = [...app.matchAll(/^\s*(?:min-|max-)?height:\s*([^;]*\bvh\b[^;]*);/gm)]
      .map((m) => m[1].trim())
      .filter((v) => !v.includes('dvh'))
    expect(fautives, 'hauteurs en vh plutôt qu’en dvh').toEqual([])
  })
})

describe('les deux colonnes ne s’inversent pas', () => {
  it('chacune est placée explicitement', () => {
    /*
     * Sur trois des quatre pages, l'aside est **premier dans le DOM** : c'est
     * l'ordre qu'il faut sur un téléphone — le montant disponible avant
     * l'historique, la progression du dossier avant les pièces, les filtres
     * avant les résultats.
     *
     * En placement automatique, cet aside tombe donc dans la *première*
     * colonne — celle de 1fr — et la colonne principale se retrouve dans les
     * 360 px. Les deux sont inversées, et la page s'affiche quand même.
     */
    /*
     * L'indice doit porter sur `regles`, pas sur `app`.
     *
     * Il venait de `app.indexOf(...)`, donc d'une chaine qui contient encore
     * les commentaires et qui est plus longue de plusieurs milliers de
     * signes. Passe a `regles.slice(depuis)`, il pointait bien au-dela de la
     * regle cherchee, et l'aide ne trouvait rien.
     */
    const grille = regles.indexOf('display: grid', regles.indexOf('.pagegrid {'))
    expect(grille, '.pagegrid ne devient jamais une grille').toBeGreaterThan(-1)

    const principal = regle('.pagegrid__main', grille)
    const lateral = regle('.pagegrid__aside', grille)
    expect(principal).toContain('grid-column: 1')
    expect(principal).toContain('grid-row: 1')
    expect(lateral).toContain('grid-column: 2')
    expect(lateral).toContain('grid-row: 1')
  })

  it('`.detail` suit la même règle, et depuis plus longtemps', () => {
    // Le même piège y avait été évité le 02/10. Si l'un des deux perd son
    // placement, l'autre dit encore quelle était l'intention.
    expect(regle('.detail__main')).toContain('grid-column: 1')
  })

  it('la colonne latérale peut défiler dans la sienne', () => {
    // Une colonne collante plus haute que la fenêtre ne colle plus : elle se
    // fige au premier défilement et son bouton devient inatteignable.
    /*
     * L'indice doit porter sur `regles`, pas sur `app`.
     *
     * Il venait de `app.indexOf(...)`, donc d'une chaine qui contient encore
     * les commentaires et qui est plus longue de plusieurs milliers de
     * signes. Passe a `regles.slice(depuis)`, il pointait bien au-dela de la
     * regle cherchee, et l'aide ne trouvait rien.
     */
    const grille = regles.indexOf('display: grid', regles.indexOf('.pagegrid {'))
    const lateral = regle('.pagegrid__aside', grille)
    expect(lateral).toContain('position: sticky')
    expect(lateral).toContain('max-height')
    expect(lateral).toContain('overflow-y: auto')
  })
})

describe('les quatre pages à deux colonnes sont équilibrées', () => {
  const PAGES = ['Dashboard', 'Revenue', 'Dossier', 'Tutoring']

  for (const page of PAGES) {
    it(`${page} a une grille, une colonne principale et une latérale`, () => {
      const source = readFileSync(`src/screens/${page}.tsx`, 'utf-8')
      // Un déséquilibre — deux asides, ou une grille sans principale — passe
      // le compilateur sans difficulté et casse la mise en page.
      expect(
        (source.match(/className="pagegrid"/g) ?? []).length,
        'nombre de grilles',
      ).toBe(1)
      expect(
        (source.match(/className="pagegrid__main"/g) ?? []).length,
        'nombre de colonnes principales',
      ).toBe(1)
      expect(
        (source.match(/className="pagegrid__aside"/g) ?? []).length,
        'nombre de colonnes latérales',
      ).toBe(1)
    })
  }
})

describe('la discussion ne montre qu’une chose sur un téléphone', () => {
  it('et le CSS le fait vraiment', () => {
    /*
     * Le commentaire de `Messages.tsx` annonçait « sur un téléphone, ouvrir
     * un fil remplace la liste ». Le CSS ne le faisait pas : les deux étaient
     * toujours rendus, et avec huit groupes il restait deux cents pixels pour
     * lire une discussion.
     */
    expect(app).toContain(".chat:not([data-ouvert='true']) .chat__room")
    expect(app).toContain(".chat[data-ouvert='true'] .chat__list")

    // Et le JSX pose bien l'attribut dont le CSS dépend.
    const source = readFileSync('src/screens/Messages.tsx', 'utf-8')
    expect(source).toContain('data-ouvert=')
  })

  it('les deux panneaux reviennent sur un ordinateur', () => {
    const i = regles.indexOf('@media (min-width: 1024px)')
    const bloc = regles.slice(i)
    expect(bloc).toContain(".chat:not([data-ouvert='true']) .chat__room")
    // La flèche de retour ne mènerait nulle part : la liste est déjà là.
    expect(bloc).toContain('.chat__back')
  })

  it('la liste défile dans sa propre hauteur', () => {
    // Sans `flex: 1` et `min-height: 0`, elle prend sa taille naturelle et se
    // dispute la hauteur avec le fil au lieu de défiler.
    const bloc = regle('.chat__list')
    expect(bloc).toContain('flex: 1')
    expect(bloc).toContain('min-height: 0')
    expect(bloc).toContain('overflow-y: auto')
  })
})

describe('un chiffre de bandeau ne déborde pas de sa cellule', () => {
  it('sa taille suit la largeur', () => {
    // Une cellule fait un tiers du bandeau, soit environ 74 px de texte utile
    // sur un écran de 360 px. « 1 200 000 GNF » en Poppins 22 gras en demande
    // 140.
    const bloc = regle('.statstrip__value')
    expect(bloc).toMatch(/font-size:\s*clamp\(/)
    expect(bloc).toContain('overflow-wrap: anywhere')
  })

  it('les montants des bandeaux passent par le format court', () => {
    /*
     * La vraie correction. Abréger n'est pas une concession à la petite
     * taille : une cellule de bandeau porte un ordre de grandeur, qu'on lit
     * d'un coup d'œil. Le montant exact a sa place dans `.money`, qui a
     * toute la largeur, et dans les lignes d'historique, où il doit être
     * vérifiable.
     */
    for (const page of ['Dashboard', 'Revenue']) {
      const source = readFileSync(`src/screens/${page}.tsx`, 'utf-8')
      const strips = [...source.matchAll(/stats=\{[\s\S]*?\]\}/g)].map((m) => m[0])
      expect(strips.length, `${page} : aucun bandeau trouvé`).toBeGreaterThan(0)
      for (const strip of strips) {
        // `gnf(` sans le `Court` : c'est le format long, il déborde.
        expect(
          strip.match(/[^t]gnf\(/),
          `${page} : un bandeau affiche un montant en entier`,
        ).toBeNull()
      }
    }
  })
})

describe('un champ de saisie garde une largeur de lecture', () => {
  it('les formulaires des pages larges sont bornés', () => {
    // Au-delà d'environ 520 px, un champ donne l'impression qu'on attend un
    // paragraphe là où l'on attend un prénom.
    expect(regle('.form-col')).toContain('max-width: 520px')

    for (const [page, combien] of [
      ['Revenue', 1],
      ['Tutoring', 1],
    ] as const) {
      const source = readFileSync(`src/screens/${page}.tsx`, 'utf-8')
      expect(
        (source.match(/form-col/g) ?? []).length,
        `${page} : formulaire sans largeur de saisie`,
      ).toBe(combien)
    }
  })
})
