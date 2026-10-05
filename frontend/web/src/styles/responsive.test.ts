import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * Les regles de la mise en page adaptative.
 *
 * Ces tests ne disent pas que le site **est beau** a 1 440 px — cela se verifie
 * dans un navigateur, et rien ici ne le remplace. Ils tiennent les quatre
 * regles qui, si elles cedent, cassent quelque chose sans qu'on le voie :
 * un seuil de plus, une requete `max-width`, une cible tactile rapetissee, une
 * ligne de texte interminable.
 */
const css = [
  readFileSync('src/styles/app.css', 'utf-8'),
  readFileSync('src/styles/tokens.css', 'utf-8'),
].join('\n')

/** Les requetes de largeur, telles qu'elles sont ecrites. */
const largeurs = [...css.matchAll(/@media \(([^)]*width[^)]*)\)/g)].map(
  (m) => m[1],
)

describe('les points de rupture', () => {
  it('il n’y en a que deux', () => {
    // Trois valeurs — 600 côté Flutter, 640 et 720 ici — disaient la même
    // chose et se contredisaient : le fond bleu de l'accueil ne touchait plus
    // les bords entre 640 et 720.
    const seuils = new Set(
      largeurs.map((q) => q.match(/(\d+)px/)?.[1]).filter(Boolean),
    )
    expect([...seuils].sort()).toEqual(['1024', '600'])
  })

  it('600 est le même nombre que côté Flutter', () => {
    // `_largeurPourDeuxColonnes` du lecteur de cours. Un seul seuil pour « ça
    // ne tient plus sur une colonne », dans les deux clients.
    const player = readFileSync(
      '../mobile/lib/presentation/screens/catalog/course_player_page.dart',
      'utf-8',
    )
    expect(player).toContain('_largeurPourDeuxColonnes = 600')
  })

  it('aucune n’est une `max-width`', () => {
    // Le téléphone est le cas par défaut, inconditionnel : aucun travail sur
    // grand écran ne peut le casser. Une seule `max-width` suffit à inverser
    // cette garantie.
    const fautives = largeurs.filter((q) => q.includes('max-width'))
    expect(fautives).toEqual([])
  })
})

describe('les cibles tactiles', () => {
  it('ne rapetissent que selon le pointeur, jamais selon la largeur', () => {
    // Une tablette de 900 px se touche avec un pouce ; un ordinateur portable
    // de 1 280 px ne se touche pas. Ce qui dépend du doigt dépend du pointeur.
    const app = readFileSync('src/styles/app.css', 'utf-8')

    // Chaque bloc `@media (min-width: …)` est isolé, et on vérifie qu'aucun ne
    // réduit une hauteur minimale.
    for (const m of app.matchAll(/@media \(min-width: \d+px\) \{/g)) {
      const debut = m.index! + m[0].length
      let profondeur = 1
      let i = debut
      while (i < app.length && profondeur > 0) {
        if (app[i] === '{') profondeur++
        else if (app[i] === '}') profondeur--
        i++
      }
      const bloc = app.slice(debut, i)
      expect(
        bloc,
        'une requête de largeur ne doit pas toucher à min-height',
      ).not.toMatch(/min-height/)
    }

    // Et la réduction autorisée existe bien, derrière le pointeur.
    expect(app).toContain('@media (pointer: fine)')
  })

  it('le plancher de 44 px est toujours déclaré', () => {
    const tokens = readFileSync('src/styles/tokens.css', 'utf-8')
    const tap = tokens.match(/--tap:\s*(\d+)px/)
    expect(tap).not.toBeNull()
    expect(Number(tap![1])).toBeGreaterThanOrEqual(44)
  })
})

describe('la largeur gagnée sert à montrer plus, pas à étirer', () => {
  it('les paragraphes ont une mesure de lecture', () => {
    // Au-delà d'environ 70 caractères, l'œil perd la ligne en revenant à la
    // marge gauche. C'est la raison pour laquelle un écran large doit porter
    // plus de cartes, et non des phrases plus longues.
    const tokens = readFileSync('src/styles/tokens.css', 'utf-8')
    expect(tokens).toMatch(/--measure:\s*\d+ch/)

    const app = readFileSync('src/styles/app.css', 'utf-8')
    for (const classe of ['.page-lede', '.measure', '.flow__body-text']) {
      const i = app.indexOf(classe + ' {')
      expect(i, `${classe} introuvable`).toBeGreaterThan(-1)
      expect(
        app.slice(i, app.indexOf('}', i)),
        `${classe} sans mesure de lecture`,
      ).toContain('max-width: var(--measure)')
    }
  })

  it('les listes de cartes deviennent une grille', () => {
    const app = readFileSync('src/styles/app.css', 'utf-8')
    const i = app.indexOf('.grid-cards {')
    expect(i).toBeGreaterThan(-1)
    const bloc = app.slice(i, app.indexOf('}', i))
    expect(bloc).toContain('display: grid')
    // `auto-fill` plutôt qu'un nombre de colonnes figé : la grille suit la
    // largeur disponible au lieu d'imposer trois colonnes à 700 px.
    expect(bloc).toContain('auto-fill')
    // Sans cela, une carte courte prend la hauteur de la plus haute de sa
    // rangée et se retrouve avec un grand vide.
    expect(bloc).toContain('align-items: start')
  })

  it('les cinq listes publiques l’utilisent', () => {
    for (const ecran of [
      'Teachers',
      'Schools',
      'Courses',
      'Offers',
      'Tests',
    ]) {
      const source = readFileSync(`src/screens/${ecran}.tsx`, 'utf-8')
      expect(source, `${ecran} : liste encore en colonne`).toContain(
        'stack grid-cards',
      )
    }
  })

  it('le programme d’un cours reste une liste, pas une grille', () => {
    // Les chapitres sont ordonnés : le chapitre 1 se lit avant le 2. Une
    // grille les répartit en colonnes et casse cet ordre de lecture.
    const cours = readFileSync('src/screens/Courses.tsx', 'utf-8')
    const programme = cours.slice(cours.indexOf('Programme'))
    expect(programme).not.toContain('grid-cards')
  })
})

describe('le cadre cesse d’être un téléphone', () => {
  it('s’élargit sur un ordinateur', () => {
    const app = readFileSync('src/styles/app.css', 'utf-8')
    // 720 px était la largeur d'un téléphone centré sur du blanc.
    const i = app.indexOf('.shell {')
    expect(app.slice(i, app.indexOf('}', i))).toContain('max-width: 720px')
    expect(app).toMatch(/@media \(min-width: 1024px\)[\s\S]*?\.shell \{/)
  })

  it('le dégradé de l’accueil touche les bords', () => {
    // Il débordait de `--s-5` en dur alors que la gouttière passe à 40 px :
    // deux bandes blanches encadraient le bleu dès 640 px.
    const app = readFileSync('src/styles/app.css', 'utf-8')
    const i = app.indexOf('.hero {')
    const bloc = app.slice(i, app.indexOf('}', i))
    expect(bloc).toContain('margin-inline: calc(-1 * var(--gutter))')
  })
})

describe('la navigation change de forme', () => {
  it('un seul composant, deux mises en page', () => {
    // Dupliquer la navigation en JSX aurait donné deux choses à tenir à jour,
    // et l'une des deux aurait fini par mentir.
    const app = readFileSync('src/App.tsx', 'utf-8')
    expect(app.match(/className="tabbar"/g) ?? []).toHaveLength(1)

    const css = readFileSync('src/styles/app.css', 'utf-8')
    const i = css.indexOf('@media (min-width: 600px)')
    const bloc = css.slice(i, css.indexOf('@media (min-width: 1024px)', i))
    // En haut, et non en bas : une barre d'onglets en bas d'un écran de
    // 1 440 px, c'est la navigation garée au bord le plus lointain.
    expect(bloc).toContain('.tabbar {')
    expect(bloc).toContain('order: -1')
    expect(bloc).toContain('top: 0')
  })
})
