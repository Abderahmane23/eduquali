import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { readFileSync } from 'node:fs'

/**
 * Le contexte d'identification du Worker.
 *
 * --- Pourquoi ce fichier existe -------------------------------------------
 *
 * `c.get('userId')` etait lu par sept routes et pose par aucune. Toutes
 * repondaient « Connectez-vous. » a un appelant parfaitement authentifie : le
 * jeton d'entree dans une salle, l'achat d'un cours, l'inscription a une
 * seance. Rien ne l'a signale, parce que les tests du depot lisent le source et
 * qu'aucun ne verifiait la correspondance entre les lectures et les ecritures de
 * ce contexte.
 *
 * Le controle ci-dessous est celui qui aurait dit non. Il est volontairement
 * structurel : il ne verifie pas un comportement — il verifie qu'une variable
 * lue est ecrite, ce qu'aucune relecture humaine ne fait de maniere fiable sur
 * 2 800 lignes.
 */

const source = readFileSync(
  new URL('./[[...route]].ts', import.meta.url),
  'utf-8',
).replace(/\r\n/g, '\n')

/** Le source sans ses commentaires : un exemple en commentaire ne compte pas. */
const code = source
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/^[ \t]*\/\/.*$/gm, '')

describe('les variables de contexte', () => {
  it('chaque variable lue est posee quelque part', () => {
    const lues = new Set(
      [...code.matchAll(/c\.get\('([^']+)'\)/g)].map((m) => m[1]),
    )
    const posees = new Set(
      [...code.matchAll(/c\.set\('([^']+)'/g)].map((m) => m[1]),
    )

    assert.ok(lues.size > 0, 'aucune lecture trouvee : le motif a change')
    for (const nom of lues) {
      assert.ok(
        posees.has(nom),
        `« ${nom} » est lu par une route et pose par aucun intergiciel : ` +
          'la route repondra toujours comme si personne n’etait connecte.',
      )
    }
  })

  it('l’identite est verifiee par Supabase, pas lue dans le jeton', () => {
    // Le `sub` d'un JWT se lit sans cle. Ce serait suffisant si `userId` ne
    // servait qu'a choisir un affichage — mais les routes qui s'en servent
    // passent ensuite par `asService()`, qui contourne RLS. Un identifiant
    // recopie d'un jeton non verifie donnerait a quiconque la salle, les achats
    // et les inscriptions de n'importe qui.
    const intergiciel = code.slice(
      code.indexOf("app.use('*', async (c, next) => {\n  const path"),
    )
    assert.match(intergiciel, /auth\.getUser\(jeton\)/)
    assert.doesNotMatch(
      intergiciel,
      /atob|JSON\.parse\(.*split\('\.'\)/,
      'l’identite ne doit pas etre decodee du jeton sans verification',
    )
  })

  it('un jeton absent ne fait pas echouer une lecture publique', () => {
    // Les listes doivent rester lisibles sans compte : c'est la promesse de la
    // page d'accueil, et RLS l'autorise depuis la migration 0009.
    const intergiciel = code.slice(
      code.indexOf("app.use('*', async (c, next) => {\n  const path"),
    )
    assert.match(intergiciel, /if \(!jeton\) return next\(\)/)
    assert.match(intergiciel, /catch/)
  })

  it('les webhooks ne passent pas par Supabase', () => {
    // Celui de LiveKit porte un `Authorization` signe avec le secret du projet
    // video. Le soumettre a Supabase ferait un appel perdu par evenement —
    // seize par classe qui commence — pour un refus garanti.
    const intergiciel = code.slice(
      code.indexOf("app.use('*', async (c, next) => {\n  const path"),
    )
    assert.match(intergiciel, /path\.includes\('\/webhook'\)\) return next\(\)/)
  })
})

describe('les routes qui exigent un compte', () => {
  it('le disent toutes de la meme facon', () => {
    // Une route qui lit `userId` sans le verifier traiterait `undefined` comme un
    // identifiant et interrogerait la base avec. Postgres ne rendrait rien, et le
    // symptome serait « seance introuvable » au lieu de « connectez-vous ».
    /*
     * La regle porte sur la liaison `const userId = c.get('userId')`, qui est la
     * forme qu'emploie une route. Deux autres lectures existent, et sont
     * legitimes :
     *
     *   * l'intergiciel d'audit, qui journalise l'identite si elle existe ;
     *   * `startPayment()`, un auxiliaire appele par des routes qui ont deja
     *     fait la verification, et dont le repli `?? ''` ne rend simplement
     *     aucun profil.
     *
     * Les distinguer par la forme de la liaison plutot que par une liste de
     * numeros de ligne fait que le controle survit a un deplacement de code.
     */
    const lignes = code.split('\n')
    let gardes = 0
    for (const [index, ligne] of lignes.entries()) {
      if (!/const userId = c\.get\('userId'\)/.test(ligne)) continue
      gardes += 1
      assert.match(
        lignes[index + 1] ?? '',
        /if \(!userId\)/,
        `ligne ${index + 1} : « userId » est lie sans etre verifie juste apres`,
      )
    }
    assert.ok(gardes >= 7, `attendu au moins sept routes gardees, vu ${gardes}`)
  })
})
