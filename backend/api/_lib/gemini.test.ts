import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { Gemini, GeminiError, MODELS } from './gemini.ts'

/**
 * La passerelle Gemini.
 *
 * Deux choses se vérifient sans appeler Google, et ce sont les deux qui
 * comptent : **ce qui part** et **ce qui est refusé avant de partir**. Le reste
 * — la qualité de la phrase rendue — ne se teste pas, et un test qui
 * prétendrait le faire mentirait.
 */

const CLE = 'cle-de-test-suffisamment-longue-pour-passer'

describe('la clé', () => {
  it('est refusée quand elle porte le préfixe VITE_', () => {
    // Vite recopie toute variable `VITE_*` dans le paquet du site. Une clé qui
    // porte ce préfixe a été prévue pour un client : l'accepter côté serveur
    // laisserait croire qu'elle y est à sa place, alors qu'elle est déjà
    // publique.
    assert.throws(
      () => new Gemini({ apiKey: 'VITE_AIza-quelque-chose-de-long-ici' }),
      (erreur: unknown) =>
        erreur instanceof GeminiError && /VITE_/.test(erreur.message),
    )
  })

  it('une clé trop courte ne compte pas comme configurée', () => {
    // Un `.env` où la ligne existe mais la valeur a été tronquée au
    // copier-coller est le cas courant. Mieux vaut un serveur qui dit « pas
    // configuré » qu'un appel qui échoue au milieu d'un cours.
    assert.equal(Gemini.isConfigured({}), false)
    assert.equal(Gemini.isConfigured({ apiKey: '' }), false)
    assert.equal(Gemini.isConfigured({ apiKey: 'AIza-court' }), false)
    assert.equal(Gemini.isConfigured({ apiKey: CLE }), true)
  })
})

describe('les modèles', () => {
  it('viennent de la source partagée', () => {
    // `shared/ai/models.json` est lu par ce module ET par
    // `scripts/check-gemini.mjs`. Les écrire aux deux endroits les aurait fait
    // diverger à la première rotation — et le contrôle passerait alors sur un
    // modèle que la production n'utilise pas.
    assert.match(MODELS.chat, /^gemini-/)
    assert.match(MODELS.build, /^gemini-/)
    assert.notEqual(MODELS.chat, MODELS.build)
  })
})

describe('le résumé d’un point de contrôle', () => {
  const gemini = new Gemini({ apiKey: CLE })

  it('refuse un décompte vide sans appeler Google', async () => {
    // Une invite sur zéro réponse produirait une phrase inventée, et la ferait
    // payer. Le refus arrive avant tout appel réseau — ce test tourne hors
    // ligne, ce qui le prouve.
    await assert.rejects(
      () =>
        gemini.summariseCheckpoint({
          subject: 'Mathématiques',
          level: 'Terminale',
          moduleIndex: 0,
          yes: 0,
          partly: 0,
          no: 0,
        }),
      (erreur: unknown) =>
        erreur instanceof GeminiError &&
        erreur.status === 400 &&
        /Aucune reponse/.test(erreur.message),
    )
  })

  it('la signature n’a aucune place pour une donnée personnelle', () => {
    /*
     * Le contrôle porte sur le type, pas sur une inspection de chaîne : il n'y a
     * **pas de champ** où mettre un prénom, un identifiant ou une phrase écrite
     * par un élève. C'est ce qui rend l'appel acceptable même si l'offre
     * facturée venait à changer — il n'y a rien à fuiter.
     *
     * Les lignes commentées ci-dessous ne doivent pas compiler. Les laisser en
     * commentaire est volontaire : elles documentent la limite, et `tsc` la fait
     * respecter sur la vraie signature.
     */
    const entree = {
      subject: 'Mathématiques',
      level: 'Terminale',
      moduleIndex: 2,
      yes: 9,
      partly: 4,
      no: 2,
      topic: 'Dérivées et tangentes',
      // childName: 'Fatoumata',  ← n'existe pas dans le type
      // enrolmentId: 'se-1',     ← n'existe pas non plus
    }
    const champs = Object.keys(entree).sort()
    assert.deepEqual(champs, [
      'level',
      'moduleIndex',
      'no',
      'partly',
      'subject',
      'topic',
      'yes',
    ])
  })
})
