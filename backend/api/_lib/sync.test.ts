import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { describe, it } from 'node:test'
import { REFUSED, WRITABLE, planWrite, unhandled } from './sync.ts'

/**
 * Ce qu'un téléphone a le droit d'écrire.
 *
 * `planWrite` est pure, donc toutes les règles de refus s'éprouvent ici sans
 * Postgres — et c'est ce qui permet de les éprouver vraiment, une par une, au
 * lieu de faire confiance à une relecture.
 *
 * Le contrôle le plus important de ce fichier n'est pourtant aucune de ces
 * règles : c'est « chaque entité que le client pousse est connue du serveur ».
 * C'est celui qui aurait signalé que `/sync/push` n'existait pas.
 */

const item = (
  partiel: Partial<Parameters<typeof planWrite>[0]>,
): Parameters<typeof planWrite>[0] => ({
  clientRef: 1,
  entity: 'child',
  entityId: 'e-1',
  operation: 'UPDATE',
  payload: {},
  ...partiel,
})

describe('la liste blanche des colonnes', () => {
  it('retient les colonnes permises et écarte les autres', () => {
    const plan = planWrite(
      item({
        entity: 'teacher',
        entityId: 't-1',
        payload: { headline: 'Prof de maths', bio: 'Dix ans', city: 'Conakry' },
      }),
    )
    assert.equal(plan.kind, 'upsert')
    if (plan.kind !== 'upsert') return
    assert.equal(plan.table, 'teachers')
    assert.equal(plan.row.headline, 'Prof de maths')
    assert.equal(plan.row.id, 't-1')
    assert.deepEqual(plan.ignored, [])
  })

  it('refuse à un professeur de se vérifier lui-même', () => {
    /*
     * LE contrôle qui justifie ce fichier.
     *
     * Un professeur **possède** sa ligne `teachers` : RLS le laisserait écrire
     * `identity_status = 'VERIFIED'` sur lui-même. Seule la liste de colonnes
     * l'arrête. Les deux barrières sont nécessaires, et aucune ne remplace
     * l'autre.
     */
    const plan = planWrite(
      item({
        entity: 'teacher',
        entityId: 't-1',
        payload: {
          headline: 'Prof de maths',
          identity_status: 'VERIFIED',
          diploma_status: 'VERIFIED',
        },
      }),
    )
    assert.equal(plan.kind, 'upsert')
    if (plan.kind !== 'upsert') return
    assert.equal(plan.row.identity_status, undefined)
    assert.equal(plan.row.diploma_status, undefined)
    assert.deepEqual(plan.ignored.sort(), ['diploma_status', 'identity_status'])
  })

  it('refuse à un professeur de s’offrir Visibilité+', () => {
    // La mise en avant se paie. Un client qui écrirait `boosted_until`
    // s'accorderait gratuitement ce que les autres achètent.
    const plan = planWrite(
      item({
        entity: 'teacher',
        entityId: 't-1',
        payload: { city: 'Kankan', boosted_until: '2030-01-01T00:00:00Z' },
      }),
    )
    assert.equal(plan.kind, 'upsert')
    if (plan.kind !== 'upsert') return
    assert.equal(plan.row.boosted_until, undefined)
    assert.equal(plan.row.city, 'Kankan')
  })

  it('refuse à un professeur d’accepter une demande à la place de l’élève', () => {
    const plan = planWrite(
      item({
        entity: 'tutoring_request',
        entityId: 'tr-1',
        payload: { message: 'Bonjour', status: 'ACCEPTED' },
      }),
    )
    assert.equal(plan.kind, 'upsert')
    if (plan.kind !== 'upsert') return
    assert.equal(plan.row.status, undefined)
  })

  it('refuse de poser soi-même son score de correspondance', () => {
    // `cover_note`, et non `note` : la colonne de `applications` porte ce nom
    // depuis la migration 0001. Ce test envoyait `note` et passait quand même,
    // parce que `note` figurait aussi — à tort — dans la liste blanche. Les
    // deux erreurs se couvraient, et la candidature d'un professeur partait
    // sans sa lettre. Voir `sync-columns.test.ts`.
    const plan = planWrite(
      item({
        entity: 'application',
        entityId: 'a-1',
        payload: { cover_note: 'Candidature', match_score: 100 },
      }),
    )
    assert.equal(plan.kind, 'upsert')
    if (plan.kind !== 'upsert') return
    assert.equal(plan.row.match_score, undefined)
  })

  it('l’identifiant vient de `entityId`, jamais du corps', () => {
    // Laisser le corps le contredire ferait écrire une autre ligne que celle que
    // le client croit modifier — et il attendrait indéfiniment une confirmation
    // sur la première.
    const plan = planWrite(
      item({ entityId: 'e-1', payload: { id: 'e-999', first_name: 'Fatou' } }),
    )
    assert.equal(plan.kind, 'upsert')
    if (plan.kind !== 'upsert') return
    assert.equal(plan.row.id, 'e-1')
  })

  it('une charge utile sans aucune colonne reconnue est refusée', () => {
    // Sinon on écrirait une ligne ne contenant que son identifiant, ce qui
    // écraserait silencieusement des champs existants avec des valeurs par
    // défaut.
    const plan = planWrite(
      item({ payload: { champ_inconnu: 1, autre: 2 } }),
    )
    assert.equal(plan.kind, 'refuse')
    if (plan.kind !== 'refuse') return
    assert.equal(plan.status, 'failed')
    assert.match(plan.message, /Aucune colonne reconnue/)
  })
})

describe('ce qu’un client ne pousse jamais', () => {
  it('l’argent est refusé, avec sa raison', () => {
    for (const entite of [
      'course_purchase',
      'contract_payment',
      'teacher_boost',
      'payment_method',
    ]) {
      const plan = planWrite(item({ entity: entite }))
      assert.equal(plan.kind, 'refuse', entite)
      if (plan.kind !== 'refuse') continue
      // Le message dit POURQUOI : sans cela, quelqu'un l'ajouterait à WRITABLE
      // en croyant combler un oubli.
      assert.ok(plan.message.length > 40, entite)
    }
  })

  it('les décisions d’un tiers sont refusées', () => {
    for (const entite of ['contract', 'interview', 'teacher_review']) {
      assert.equal(planWrite(item({ entity: entite })).kind, 'refuse', entite)
    }
  })

  it('une session de test est arbitrée par le serveur', () => {
    // Il détient les bonnes réponses et le chronomètre. Laisser un client
    // pousser une session reviendrait à le laisser se noter.
    const plan = planWrite(item({ entity: 'test_session' }))
    assert.equal(plan.kind, 'refuse')
    if (plan.kind !== 'refuse') return
    assert.match(plan.message, /bonnes reponses|bonnes réponses/)
  })

  it('une entité inconnue est refusée sans être devinée', () => {
    const plan = planWrite(item({ entity: 'quelque_chose_de_nouveau' }))
    assert.equal(plan.kind, 'refuse')
    if (plan.kind !== 'refuse') return
    assert.match(plan.message, /jamais en bloc/)
  })
})

describe('les opérations', () => {
  it('une suppression permise produit un plan de suppression', () => {
    const plan = planWrite(item({ operation: 'DELETE', entityId: 'e-1' }))
    assert.equal(plan.kind, 'delete')
    if (plan.kind !== 'delete') return
    assert.equal(plan.table, 'children')
  })

  it('une suppression interdite est un conflit, pas un échec', () => {
    /*
     * La distinction décide du comportement du téléphone : `failed` se remet en
     * file et se réessaie, `conflict` s'arrête. Réessayer une suppression que le
     * serveur refusera toujours occuperait la file indéfiniment, et la personne
     * verrait un compteur d'erreurs qui ne descend jamais.
     */
    const plan = planWrite(
      item({ entity: 'teacher', operation: 'DELETE', entityId: 't-1' }),
    )
    assert.equal(plan.kind, 'refuse')
    if (plan.kind !== 'refuse') return
    assert.equal(plan.status, 'conflict')
  })

  it('un fichier ne passe pas par la synchronisation JSON', () => {
    const plan = planWrite(item({ operation: 'UPLOAD' }))
    assert.equal(plan.kind, 'refuse')
    if (plan.kind !== 'refuse') return
    assert.equal(plan.status, 'conflict')
  })

  it('une opération inconnue est refusée', () => {
    assert.equal(planWrite(item({ operation: 'TRUNCATE' })).kind, 'refuse')
  })

  it('un élément sans identifiant est refusé', () => {
    assert.equal(planWrite(item({ entityId: '' })).kind, 'refuse')
  })
})

describe('le client et le serveur parlent de la même chose', () => {
  /**
   * Les entités que l'application mobile pousse réellement, lues dans son code.
   *
   * C'est LE contrôle qui aurait signalé que `/sync/push` n'existait pas : les
   * deux côtés étaient cohérents avec eux-mêmes, et rien ne vérifiait qu'un
   * chemin appelé par un client existe côté serveur. Le même raisonnement que
   * pour `userId` dans `auth-context.test.ts`, appliqué aux entités.
   */
  const poussees = (): string[] => {
    const racine = new URL('../../../frontend/mobile/lib/', import.meta.url)
    const fichiers = [
      'data/sync/sync_engine.dart',
      'data/repositories/children_repository.dart',
      'data/repositories/teacher_repository.dart',
      'data/repositories/tutoring_repository.dart',
    ]
    const vues = new Set<string>()
    for (const fichier of fichiers) {
      let source: string
      try {
        source = readFileSync(new URL(fichier, racine), 'utf-8')
      } catch {
        continue
      }
      for (const trouve of source.matchAll(/entity:\s*'([a-z_]+)'/g)) {
        vues.add(trouve[1])
      }
    }
    return [...vues]
  }

  it('la route existe côté serveur', () => {
    // Le défaut d'origine, figé : le client postait vers `/sync/push` et le
    // Worker ne l'exposait pas.
    const worker = readFileSync(
      new URL('../[[...route]].ts', import.meta.url),
      'utf-8',
    )
    const client = readFileSync(
      new URL(
        '../../../frontend/mobile/lib/data/remote/sync_api.dart',
        import.meta.url,
      ),
      'utf-8',
    )
    for (const chemin of ['/sync/push', '/sync/pull']) {
      assert.ok(client.includes(`'${chemin}'`), `le client appelle ${chemin}`)
      assert.ok(
        worker.includes(`'${chemin}'`),
        `le serveur doit exposer ${chemin} — le client l’appelle`,
      )
    }
  })

  it('chaque entité poussée est traitée ou refusée explicitement', () => {
    const inconnues = unhandled(poussees())
    assert.deepEqual(
      inconnues,
      [],
      'ces entités sont poussées par le client et absentes de WRITABLE comme de ' +
        `REFUSED : ${inconnues.join(', ')}. Les ajouter avec leurs colonnes, ou ` +
        'avec la raison du refus.',
    )
  })

  it('aucune entité n’est à la fois permise et refusée', () => {
    const deuxFois = Object.keys(WRITABLE).filter((e) => e in REFUSED)
    assert.deepEqual(deuxFois, [])
  })

  it('chaque refus porte une raison lisible', () => {
    for (const [entite, raison] of Object.entries(REFUSED)) {
      assert.ok(
        raison.length > 30,
        `« ${entite} » est refusée sans explication suffisante`,
      )
    }
  })
})
