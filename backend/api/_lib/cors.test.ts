import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { DEV_ORIGINS, parseOrigins, resolveOrigin } from './cors.ts'

/**
 * Qui peut appeler l'API depuis un navigateur, et qui n'a pas besoin de le
 * demander.
 *
 * --- Le malentendu que ce fichier fige ----------------------------------
 *
 * « Ajouter l'application mobile à `ALLOWED_ORIGINS` » est une demande naturelle
 * et une fausse piste : **CORS est une règle de navigateur.** Un client natif —
 * Dio sur Android — n'envoie aucun en-tête `Origin` et n'est soumis à rien.
 * L'APK joint donc le serveur quelle que soit la valeur d'`ALLOWED_ORIGINS`.
 *
 * Le danger est l'inverse de celui qu'on imagine : une implémentation qui
 * **refuserait** une requête sans `Origin` couperait l'APK du serveur, et aucun
 * essai depuis un navigateur ne le verrait.
 *
 * Ce qui rend vraiment l'application capable de parler au serveur est ailleurs :
 * `--dart-define=ACALIA_API=<url>` à la compilation.
 */

const production = { allowed: ['https://eduquali.pages.dev'], isProduction: true }
const sandbox = { allowed: ['https://preview.eduquali.pages.dev'], isProduction: false }

describe('l’application mobile n’a rien à demander', () => {
  it('une requête sans Origin n’est jamais refusée', () => {
    // LE contrôle de ce fichier. `undefined` fait que le middleware ne pose
    // aucun en-tête et laisse passer ; `null` refuserait.
    for (const vide of [undefined, '']) {
      const verdict = resolveOrigin(vide, production)
      assert.equal(
        verdict,
        undefined,
        'une requête sans origine est celle de l’APK : ni autorisée ni refusée, ' +
          'simplement hors du sujet de CORS',
      )
      assert.notEqual(verdict, null, 'un refus couperait l’application mobile')
    }
  })
})

describe('le site web doit être déclaré', () => {
  it('une origine listée est autorisée, et renvoyée telle quelle', () => {
    assert.equal(
      resolveOrigin('https://eduquali.pages.dev', production),
      'https://eduquali.pages.dev',
    )
  })

  it('une origine inconnue est refusée', () => {
    // Sinon n'importe quel site ferait exécuter des requêtes authentifiées par
    // le navigateur de la personne, avec ses jetons.
    assert.equal(resolveOrigin('https://quelquun-dautre.example', production), null)
  })

  it('jamais d’étoile, pour aucune origine', () => {
    /*
     * `credentials: true` et `Access-Control-Allow-Origin: *` sont
     * incompatibles — le navigateur rejette la combinaison — mais la vraie
     * raison est plus simple : une étoile ouvrirait l'API à tout le web.
     */
    for (const origine of [
      'https://eduquali.pages.dev',
      'https://inconnu.test',
      'http://localhost:5173',
      undefined,
    ]) {
      assert.notEqual(resolveOrigin(origine, production), '*')
      assert.notEqual(resolveOrigin(origine, sandbox), '*')
    }
  })

  it('une origine très proche ne passe pas', () => {
    // Comparaison exacte, pas « commence par » : un sous-domaine ou un suffixe
    // ajouté suffirait à contourner une comparaison laxiste.
    for (const voisine of [
      'https://eduquali.pages.dev.attaquant.test',
      'https://eduquali.pages.dev/',
      'http://eduquali.pages.dev',
      'https://EDUQUALI.pages.dev',
    ]) {
      assert.equal(
        resolveOrigin(voisine, production),
        null,
        `« ${voisine} » ne doit pas être confondue avec l’origine déclarée`,
      )
    }
  })
})

describe('les adresses de développement', () => {
  it('passent hors production, et pas en production', () => {
    for (const origine of DEV_ORIGINS) {
      assert.equal(resolveOrigin(origine, sandbox), origine)
      assert.equal(
        resolveOrigin(origine, production),
        null,
        `${origine} ne doit pas être acceptée par la production`,
      )
    }
  })

  it('restent acceptées même si la liste déclarée est vide', () => {
    // Le cas du premier `wrangler dev` : rien de posé, et le site local doit
    // quand même pouvoir appeler.
    assert.equal(
      resolveOrigin('http://localhost:5173', { allowed: [], isProduction: false }),
      'http://localhost:5173',
    )
  })
})

describe('la lecture de la variable', () => {
  it('découpe, nettoie et ignore le vide', () => {
    assert.deepEqual(
      parseOrigins(' https://a.test , https://b.test ,, '),
      ['https://a.test', 'https://b.test'],
    )
  })

  it('une variable absente ne donne aucune origine, et ne casse rien', () => {
    // Une liste vide ferme le site web, mais laisse l'APK passer : c'est
    // exactement le comportement voulu tant qu'aucun domaine n'est déclaré.
    assert.deepEqual(parseOrigins(undefined), [])
    assert.deepEqual(parseOrigins(''), [])
  })
})
