import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * La navigation mène quelque part.
 *
 * --- Le défaut que ces tests empêchent de revenir -----------------------
 *
 * Deux fois dans ce projet, un lien a pointé vers une adresse qui n'existait
 * pas : une notification vers `/live/<id>` quand la route s'appelle
 * `/direct/<id>/salle`, et un onglet « Direct » qui amenait un professeur sur
 * une grille où ses propres cours n'apparaissaient pas.
 *
 * Aucun des deux ne lève d'erreur. Le premier affiche « cette page n'existe
 * pas », le second affiche une page vide — et une page vide se lit comme
 * « vous n'avez rien », pas comme « le lien est faux ».
 *
 * Ces tests lisent les deux listes et vérifient qu'elles se correspondent.
 */
const app = readFileSync('src/App.tsx', 'utf-8')

/** Les chemins déclarés par `<Route path="…">`. */
const routes = new Set(
  [...app.matchAll(/<Route\s+path="([^"]+)"/g)].map((m) => m[1]),
)

/** Les destinations des onglets, tous rôles confondus. */
const onglets = [...app.matchAll(/\{ to: '([^']+)', label: '([^']+)'/g)].map(
  (m) => ({ to: m[1], label: m[2] }),
)

describe('chaque onglet mène à une route déclarée', () => {
  it('il y en a, et ils sont nombreux', () => {
    // Un garde-fou sur le garde-fou : si l'expression cesse de reconnaître la
    // forme des onglets, elle rend une liste vide et le test suivant passe en
    // ne vérifiant rien.
    expect(onglets.length).toBeGreaterThan(15)
    expect(routes.size).toBeGreaterThan(20)
  })

  it('aucune destination n’est une adresse inexistante', () => {
    for (const onglet of onglets) {
      expect(
        routes.has(onglet.to),
        `l’onglet « ${onglet.label} » mène à ${onglet.to}, qui n’est pas une route`,
      ).toBe(true)
    }
  })
})

describe('les sept écrans ouverts le 11/10 sont atteignables', () => {
  /*
   * Chaque page de cette liste comblait un vide précis, et toutes ont en
   * commun d'avoir existé côté serveur avant d'exister à l'écran. Une route
   * déclarée sans onglet qui y mène est une page que personne ne trouvera.
   */
  const ATTENDUES: [string, string][] = [
    ['/tableau', 'le tableau de bord du professeur'],
    ['/messages', 'la messagerie, sans quoi un professeur est injoignable'],
    ['/revenus', 'les revenus et les retraits'],
    ['/domicile', 'les cours à domicile, la ligne la mieux payée'],
    ['/assistant', 'l’assistant'],
    ['/boutique', 'la boutique des points'],
    ['/offres', 'les offres d’emploi'],
  ]

  for (const [chemin, role] of ATTENDUES) {
    it(`${chemin} — ${role}`, () => {
      expect(routes.has(chemin), `route ${chemin} absente`).toBe(true)
      expect(
        onglets.some((o) => o.to === chemin),
        `aucun onglet ne mène à ${chemin}`,
      ).toBe(true)
    })
  }

  it('les écrans de détail existent, même sans onglet', () => {
    // Ils s'atteignent depuis une liste, pas depuis la barre : un onglet
    // « Les inscrits » n'aurait aucun sens sans séance choisie.
    for (const chemin of [
      '/direct/:id/inscrits',
      '/profil/dossier',
      '/cours/nouveau',
      '/cours/:id/contenu',
      '/messages/:id',
    ]) {
      expect(routes.has(chemin), `route ${chemin} absente`).toBe(true)
    }
  })
})

describe('chaque rôle arrive sur son propre écran', () => {
  it('la racine délègue à `accueilDe`, et ne décide pas elle-même', () => {
    /*
     * C'était le défaut d'origine : `session ? <Navigate to="/offres" />`. Un
     * professeur qui se connectait atterrissait sur les annonces d'écoles,
     * sans aucun chemin vers ses propres cours — et `myLiveCourses`, qui
     * existait dans les deux backends, n'était appelée par aucun écran.
     *
     * La correction du 11/10 écrivait le rôle en ternaire dans la route ; une
     * seconde liste de rôles vivait dans la redirection d'après inscription,
     * et les deux divergeaient déjà le 17/10. Une seule fonction, désormais,
     * et ce test vérifie qu'on y passe.
     */
    const racine = app.slice(
      app.indexOf('path="/"'),
      app.indexOf('path="/recherche"'),
    )
    expect(racine).toContain('accueilDe(session.role)')
    expect(racine).not.toContain("role === 'TEACHER' ?")
  })

  it('et `accueilDe` envoie chaque rôle sur une route déclarée', () => {
    /*
     * Le corps de la fonction, lu dans le fichier : une famille envoyée sur
     * `/accueil` alors que la route s'appellerait `/famille` verrait « cette
     * page n'existe pas » à chaque connexion — et c'est le genre de défaut
     * qu'on ne découvre qu'en se connectant avec le bon rôle.
     */
    const corps = app.slice(
      app.indexOf('export function accueilDe'),
      app.indexOf('/** Squelette plutot que roue'),
    )
    const destinations = [...corps.matchAll(/return '([^']+)'/g)].map(
      (m) => m[1],
    )
    expect(destinations.length).toBeGreaterThanOrEqual(4)
    for (const destination of destinations) {
      expect(
        routes.has(destination),
        `accueilDe renvoie ${destination}, qui n’est pas une route`,
      ).toBe(true)
    }
    // Les deux qui comptent, nommément : ce sont les deux rôles qui paient.
    expect(corps).toContain("'/tableau'")
    expect(corps).toContain("'/accueil'")
  })

  it('le tableau de bord mène à la salle de sa propre séance', () => {
    /*
     * Le trou le plus coûteux : il n'existait aucun lien vers sa propre
     * salle. « Mes séances » lisait `mySessions()`, que le serveur remplit
     * depuis les places achetées par les familles — et son commentaire le
     * dit : « Un compte enseignant n'a pas de fiche famille : liste vide, pas
     * une erreur. » La section était donc vide, et il fallait taper
     * `/direct/<id>/salle` de mémoire.
     */
    const tableau = readFileSync('src/screens/Dashboard.tsx', 'utf-8')
    expect(tableau).toContain('/salle')
    expect(tableau, 'la route du professeur n’est pas appelée').toContain(
      'prof.seances()',
    )
    expect(tableau, 'la liste des inscrits n’est pas atteignable').toContain(
      '/inscrits',
    )
  })
})

describe('les écrans qui demandent le serveur le disent avant', () => {
  /*
   * Ces sept pages ne peuvent pas exister sans serveur : les revenus
   * traversent des tables dont les politiques appartiennent aux familles,
   * l'assistant tient l'unique clé du modèle, un dépôt est signé avec les
   * clés R2. Sans `VITE_API_BASE_URL`, l'appel lève.
   *
   * Le dire **avant** la première question plutôt qu'après la dernière : un
   * candidat pouvait répondre à soixante questions de test avant d'apprendre
   * que rien ne serait enregistré. C'est le même piège.
   */
  const ECRANS = [
    'Dashboard',
    'Messages',
    'Revenue',
    'Dossier',
    'Tutoring',
    'Assistant',
    'Shop',
    'Roster',
    'CourseStudio',
  ]

  for (const ecran of ECRANS) {
    it(`${ecran} vérifie la présence du serveur`, () => {
      const source = readFileSync(`src/screens/${ecran}.tsx`, 'utf-8')
      expect(
        source,
        `${ecran} appelle le serveur sans vérifier qu’il existe`,
      ).toContain('serveurDisponible')
    })
  }
})
