import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { describe, it } from 'node:test'

/**
 * Un lien de notification mene quelque part.
 *
 * --- Le defaut qui a motive ce fichier ----------------------------------
 *
 * Une notification porte une colonne `route`, et l'ecran des notifications
 * fait `context.push(item.route!)` quand elle est remplie. Le chemin est donc
 * ecrit **ici**, dans le Worker, et resolu **la-bas**, par go_router : rien ne
 * reliait les deux.
 *
 * Le 04/10, la notification « le cours commence » partait avec
 * `/live/<id>` alors que la salle est enregistree sous
 * `/direct/<id>/salle`. Le professeur appuyait sur « Prevenir », quinze
 * familles recevaient une ligne, et la toucher n'ouvrait rien — au moment
 * precis ou le cours commencait. Les deux cotes compilaient, les deux suites
 * de tests passaient.
 *
 * --- Ce que ce controle fait, et ce qu'il ne fait pas --------------------
 *
 * Il compare des **formes de chemin** : nombre de segments, et segments fixes
 * identiques. Il ne verifie pas qu'un identifiant est valide ni qu'un compte a
 * le droit d'ouvrir l'ecran — ce sont des questions d'execution. Il attrape la
 * seule classe de defaut qui echappe a tout le reste : un chemin qui ne
 * correspond a aucune route declaree.
 *
 * Il lit aussi les notifications ecrites par l'application elle-meme
 * (`notification_repository.dart`) : le meme defaut s'y logerait aussi bien.
 */

const lire = (chemin: string): string =>
  readFileSync(new URL(chemin, import.meta.url), 'utf-8')

const MOBILE = '../../../frontend/mobile/lib/'

/**
 * Les chemins poses dans `route:` par le serveur et par le client.
 *
 * `route: r.route` et `route: Value(route)` passent une variable et non un
 * litteral : il n'y a rien a verifier, et les ignorer vaut mieux que de les
 * compter comme des chemins vides.
 */
const liens = (): { source: string; chemin: string }[] => {
  const sources: [string, string][] = [
    ['worker', lire('../[[...route]].ts')],
    [
      'notification_repository.dart',
      lire(`${MOBILE}data/repositories/notification_repository.dart`),
    ],
  ]
  const trouves: { source: string; chemin: string }[] = []
  for (const [source, texte] of sources) {
    // Guillemets simples, doubles, ou gabarit : les trois s'ecrivent dans les
    // deux langages.
    for (const trouve of texte.matchAll(/route:\s*['"`](\/[^'"`]*)['"`]/g)) {
      trouves.push({ source, chemin: trouve[1] })
    }
  }
  return trouves
}

/** Les chemins que go_router sait resoudre, lus dans le routeur. */
const routesDeclarees = (): string[] => {
  const routeur = lire(`${MOBILE}presentation/router/app_router.dart`)

  // Les constantes : `static const parentHome = '/parent';`
  const constantes = new Map<string, string>()
  for (const trouve of routeur.matchAll(
    /static const (\w+)\s*=\s*'([^']+)'/g,
  )) {
    constantes.set(trouve[1], trouve[2])
  }

  // Les fabriques : `static String liveRoom(String id) => '/direct/$id/salle';`
  // Elles ne sont pas des routes en soi, mais leur corps est un chemin que
  // quelqu'un ouvrira.
  const chemins: string[] = []
  for (const trouve of routeur.matchAll(/path:\s*'([^']+)'/g)) {
    chemins.push(trouve[1])
  }
  for (const trouve of routeur.matchAll(/path:\s*Routes\.(\w+)/g)) {
    const valeur = constantes.get(trouve[1])
    if (valeur) chemins.push(valeur)
  }
  return chemins
}

/**
 * Deux chemins ont la meme forme quand ils ont autant de segments et que les
 * segments fixes concordent. Un segment interpole (`${id}`, `$id`) cote appel
 * et un parametre (`:sessionId`) cote route sont tous deux des trous.
 */
const concorde = (appele: string, declare: string): boolean => {
  const trou = (s: string) =>
    s.startsWith(':') || s.includes('$') || s.includes('{')
  const a = appele.split('/').filter(Boolean)
  const b = declare.split('/').filter(Boolean)
  if (a.length !== b.length) return false
  return a.every((seg, i) => trou(seg) || trou(b[i]) || seg === b[i])
}

describe('un lien de notification mène quelque part', () => {
  it('le contrôle lit bien les deux sources', () => {
    // Un plancher : si une expression change et que plus rien ne correspond,
    // ce fichier passerait au vert sans rien verifier. Trois liens existent au
    // 04/10 — la salle du direct, l'identite et les tests du professeur.
    const trouves = liens()
    assert.ok(
      trouves.length >= 3,
      `seuls ${trouves.length} liens lus : l’expression de lecture ne trouve ` +
        'plus les `route:` — ce contrôle ne vérifie plus rien.',
    )
    assert.ok(
      routesDeclarees().length >= 40,
      'le routeur mobile n’a pas été lu correctement',
    )
  })

  it('chaque chemin écrit dans une notification est une route déclarée', () => {
    const declarees = routesDeclarees()
    for (const { source, chemin } of liens()) {
      assert.ok(
        declarees.some((route) => concorde(chemin, route)),
        `« ${chemin} » (${source}) ne correspond à aucune route de ` +
          'app_router.dart : la notification s’affichera et ne s’ouvrira pas. ' +
          'Corriger le chemin, ou déclarer la route.',
      )
    }
  })

  it('la salle du direct est bien celle que le professeur fait rejoindre', () => {
    // Le defaut d'origine, fige : le Worker ecrivait `/live/<id>`.
    const worker = lire('../[[...route]].ts')
    assert.ok(
      worker.includes('/direct/${sessionId}/salle'),
      'la notification « le cours commence » doit pointer vers la salle',
    )
    assert.ok(
      !/route:\s*[`'"]\/live\//.test(worker),
      '`/live/...` n’est pas un chemin de l’application mobile',
    )
  })
})
