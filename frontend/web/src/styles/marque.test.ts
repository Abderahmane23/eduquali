import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

/**
 * Les signes de marque, tenus sur le site.
 *
 * --- Pourquoi des tests là-dessus ---------------------------------------
 *
 * Une faute de marque ne lève rien et ne se voit pas tout de suite : elle
 * s'écrit une fois dans un écran, puis se recopie dans le suivant. Le site
 * a porté « Eduquali » sur quinze fichiers — dont la barre de navigation et
 * le titre d'accueil, les deux endroits où le nom est le plus lu — alors que
 * la charte écrit « EduQuali », le nom en deux temps.
 *
 * Même chose pour le bandeau de page : la moitié des écrans ouvraient sur le
 * bandeau de la charte, l'autre moitié sur une barre de navigation blanche
 * qui répétait le nom de l'onglet déjà surligné au-dessus.
 */

/** Tous les fichiers de `src`, sauf les tests. */
function sources(dossier = 'src'): string[] {
  const trouves: string[] = []
  for (const entree of readdirSync(dossier, { withFileTypes: true })) {
    const chemin = join(dossier, entree.name)
    if (entree.isDirectory()) {
      trouves.push(...sources(chemin))
    } else if (
      /\.tsx?$/.test(entree.name) &&
      !entree.name.includes('.test.')
    ) {
      trouves.push(chemin)
    }
  }
  return trouves
}

const fichiers = sources()

describe('le garde-fou se tient lui-même', () => {
  it('il y a des fichiers à lire', () => {
    // Une liste vide ferait passer tous les tests d'absence ci-dessous sans
    // rien vérifier.
    expect(fichiers.length).toBeGreaterThan(20)
  })
})

describe('le nom de la marque', () => {
  it('s’écrit « EduQuali », avec la capitale du second temps', () => {
    /*
     * « Le nom en deux temps » est l'un des cinq signes de la charte : deux
     * mots soudés, le second avec sa capitale. C'est ce que dessine le logo,
     * et c'est ce que le texte doit écrire.
     */
    const fautifs: string[] = []
    for (const fichier of fichiers) {
      const contenu = readFileSync(fichier, 'utf-8')
      if (/\bEduquali\b/.test(contenu)) fautifs.push(fichier)
    }
    expect(fautifs, `« Eduquali » dans : ${fautifs.join(', ')}`).toEqual([])
  })

  it('et la barre de navigation le porte', () => {
    /*
     * C'est le premier mot de chaque page, et il était faux.
     *
     * Un test sur « le nom ancien n'apparaît nulle part » a été écrit puis
     * retiré : `VeriProf` survit dans des identifiants — le type
     * `VeriprofApi`, la clé `veriprof.session`, l'étiquette de journal
     * `[veriprof]` — et aucune expression régulière ne sépare de façon
     * fiable un identifiant d'une chaîne affichée. Un test qui signale
     * quatre fichiers sains à chaque lancement finit désactivé.
     *
     * On vérifie donc ce qui se lit : l'enseigne de la barre du haut.
     */
    const app = readFileSync('src/App.tsx', 'utf-8')
    // L'element entier, et non ses deux cents premiers caracteres : un
    // commentaire pose dedans repoussait le nom hors de la fenetre, et le
    // test signalait une enseigne parfaitement correcte.
    const debut = app.indexOf('topbar__brand')
    const enseigne = app.slice(debut, app.indexOf('</Link>', debut))
    expect(enseigne.length).toBeGreaterThan(20)
    expect(enseigne).toContain('EduQuali')
    // Et elle porte la marque, pas seulement le mot.
    expect(enseigne).toContain('topbar__marque')
  })
})

describe('le bandeau de page', () => {
  /*
   * `AppBar` est une barre de navigation : un titre, et un bouton retour.
   * Sur un écran de détail elle sert. Sur un onglet de premier rang, il n'y
   * a pas de retour à proposer et l'onglet est déjà surligné dans la barre
   * du haut : elle ne fait que répéter le nom de la page, à la place du
   * bandeau que la charte donne à chaque écran.
   */
  const PREMIER_RANG = [
    'src/screens/Teachers.tsx',
    'src/screens/Live.tsx',
    'src/screens/Courses.tsx',
    'src/screens/Famille.tsx',
    'src/screens/Dashboard.tsx',
    'src/screens/Revenue.tsx',
  ]

  for (const fichier of PREMIER_RANG) {
    it(`${fichier.split('/').pop()} ouvre sur le bandeau de la charte`, () => {
      const contenu = readFileSync(fichier, 'utf-8')
      expect(contenu).toContain('<PageHead')
    })
  }

  it('une barre de navigation garde son bouton retour', () => {
    /*
     * Ce qui reste d'`AppBar` dans ces écrans est sur un sous-écran — la
     * fiche d'un professeur, le détail d'un cours — et porte donc `onBack`.
     * Une `AppBar` sans retour sur un écran de premier rang est le défaut
     * que ces tests empêchent de revenir.
     */
    for (const fichier of PREMIER_RANG) {
      const contenu = readFileSync(fichier, 'utf-8')
      const barres = contenu.match(/<AppBar[^/]*?\/>/gs) ?? []
      for (const barre of barres) {
        expect(
          barre.includes('onBack'),
          `${fichier} : ${barre.replace(/\s+/g, ' ')}`,
        ).toBe(true)
      }
    }
  })
})
