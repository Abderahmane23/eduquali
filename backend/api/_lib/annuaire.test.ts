import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { describe, it } from 'node:test'

/**
 * L'annuaire repond, et son cout ne depend pas du nombre de professeurs.
 *
 * --- Le defaut qui a motive ce fichier ----------------------------------
 *
 * Le 17/10, `GET /api/v1/teachers` ne revenait pas sur le site en ligne :
 * 60 s sans statut, deux fois de suite, quand `/subjects`, `/levels`,
 * `/institutions` et `/contests` repondaient en moins de trois secondes.
 *
 * Le gestionnaire prenait tous les identifiants de la table, sans limite,
 * puis appelait `loadTeacher` dans une boucle `await`. Chaque fiche coute
 * six requetes en trois vagues : la liste entiere valait donc 3N
 * allers-retours en serie, et le Worker se taisait avant la fin.
 *
 * Rien ne le signalait en developpement, ou la base tient quelques
 * professeurs de demonstration et ou un aller-retour coute une
 * milliseconde. C'est le genre de defaut qui attend les vraies donnees,
 * c'est-a-dire le jour ou l'on montre le produit. Et l'annuaire est
 * l'onglet principal d'une famille, d'un eleve, d'une ecole et d'un
 * visiteur sans compte : c'est la premiere liste qu'on voit.
 *
 * --- Ce que ce controle verifie, et ce qu'il ne verifie pas -------------
 *
 * Il lit le source et compte des formes : un appel par fiche dans une
 * boucle, une requete sans plafond. Il ne mesure pas un temps de reponse —
 * cela demanderait une vraie base, et un controle qui exige une base n'est
 * jamais lance. Il attrape la seule classe de defaut qui a produit la
 * panne : le cout d'une liste qui croit avec son contenu.
 */

const source = readFileSync(
  new URL('../[[...route]].ts', import.meta.url),
  'utf-8',
)

/** Le corps d'un gestionnaire, de sa declaration a sa fermeture. */
function gestionnaire(chemin: string): string {
  const debut = source.indexOf(`app.get('${chemin}'`)
  assert.notEqual(debut, -1, `route ${chemin} introuvable`)
  const fin = source.indexOf('\n})', debut)
  assert.notEqual(fin, -1, `fin du gestionnaire ${chemin} introuvable`)
  return source.slice(debut, fin)
}

/**
 * Les lignes d'une fonction nommee, jusqu'a sa fermeture.
 *
 * La parenthese n'est pas collee au nom : `parPaquets<T>(` est generique, et
 * chercher `parPaquets(` ne la trouvait pas. Le controle passait pourtant —
 * il levait « fonction introuvable », ce qui ressemble a une faute de frappe
 * dans l'epreuve plutot qu'a ce que c'etait.
 */
function fonction(nom: string): string {
  const declaration = new RegExp(`function ${nom}\\s*[(<]`)
  const trouve = declaration.exec(source)
  assert.ok(trouve, `fonction ${nom} introuvable`)
  const fin = source.indexOf('\n}', trouve.index)
  return source.slice(trouve.index, fin)
}

describe('L’annuaire des professeurs', () => {
  it('charge les fiches par lot, et non une par une', () => {
    const corps = gestionnaire('/teachers')

    assert.ok(
      corps.includes('chargerProfesseurs('),
      'l’annuaire doit passer par le chargement par lot',
    )
    assert.ok(
      !corps.includes('loadTeacher('),
      'un appel par fiche ramene la panne du 17/10',
    )
  })

  it('borne la liste qu’elle demande a la base', () => {
    const corps = gestionnaire('/teachers')
    assert.ok(
      corps.includes('.limit('),
      'sans plafond, la route grossit avec la table',
    )
  })

  /*
   * Le filtre le plus selectif passe en SQL. Sans cela, le plafond
   * couperait dans des professeurs qui ne correspondent pas a la recherche,
   * et une famille verrait une liste vide la ou il y avait des reponses.
   */
  it('reduit l’ensemble en SQL avant de charger', () => {
    const corps = gestionnaire('/teachers')
    assert.ok(corps.includes("from('teacher_subjects')"))
    assert.ok(corps.includes("from('tutoring_services')"))
    assert.ok(corps.includes(".in('id', candidats"))
  })

  it('ne lit jamais une fiche a l’unite dans une boucle', () => {
    /*
     * La verification porte sur tout le fichier, et pas seulement sur
     * `/teachers` : le defaut se reproduirait a l'identique dans n'importe
     * quelle route qui rend une liste.
     */
    const lignes = source.split('\n')
    const coupables: string[] = []

    for (let i = 0; i < lignes.length; i += 1) {
      const ouverture = /^(\s*)(for|while)\s*\(/.exec(lignes[i])
      if (!ouverture) continue
      const marge = ouverture[1].length

      for (let j = i + 1; j < lignes.length; j += 1) {
        const suite = lignes[j]
        const creuse = suite.trim().length === 0
        const indentation = suite.length - suite.trimStart().length
        if (!creuse && indentation <= marge) break
        if (/await load[A-Z]/.test(suite)) {
          coupables.push(`L${j + 1} : ${suite.trim()}`)
        }
      }
    }

    assert.deepEqual(
      coupables,
      [],
      `un chargement de fiche par tour de boucle :\n${coupables.join('\n')}`,
    )
  })

  it('tient le nombre de requetes du chargement par lot', () => {
    const corps = fonction('chargerProfesseurs')
    const requetes = corps.match(/\.from\(/g) ?? []

    /*
     * Six tables : teachers, profiles, teacher_subjects, teacher_levels,
     * teacher_certifications, teacher_experiences. Une de plus et ce n'est
     * plus un chargement par lot mais un chargement par lot et demi — le
     * nombre est ecrit ici pour qu'un ajout se decide, au lieu de se
     * glisser.
     */
    assert.equal(
      requetes.length,
      6,
      `le chargement par lot fait ${requetes.length} requetes, six attendues`,
    )

    // Chaque lecture porte sur un paquet d'identifiants, jamais sur un seul.
    assert.ok(corps.includes(".in('id', lot)"))
    assert.ok(corps.includes(".in('teacher_id', lot)"))
    assert.ok(
      corps.includes('Promise.all('),
      'les cinq lectures qui ne dependent de rien doivent partir ensemble',
    )
  })

  /*
   * Deux boucles du fichier ecrivent encore ligne a ligne : l'application
   * d'un plan de synchronisation (`delete` par element) et la cloture des
   * concours echus (`point_ledger` par concours). Ce sont des ecritures,
   * ou l'ordre compte et ou le lot est borne par l'appelant — elles
   * restent, et ce commentaire est la pour qu'on sache qu'elles ont ete
   * regardees. Le controle ci-dessus ne vise que les lectures de fiche.
   */
  it('decoupe les listes d’identifiants', () => {
    assert.ok(
      source.includes('const PAQUET_IDS = 200'),
      'PostgREST met le filtre `in` dans l’adresse : une adresse trop '
      + 'longue est refusee, et le refus ressemble a une liste vide',
    )
    assert.ok(fonction('parPaquets').includes('ids.slice(i, i + PAQUET_IDS)'))
  })
})
