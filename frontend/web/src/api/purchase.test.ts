import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * L'achat d'un cours.
 *
 * Une regle porte tout le reste : **le client n'envoie jamais le montant.** Un
 * prix qui vient du navigateur est un prix choisi par le navigateur, et
 * `amount` est ce qui sera reclame a l'operateur de paiement.
 *
 * Et une seconde, qui evite de donner le produit : l'acces aux videos suit
 * l'etat `PAID`, pas l'existence d'une ligne. Il n'y a pas encore
 * d'encaissement — une insertion au clic aurait ouvert le cours gratuitement.
 */
const code = (chemin: string) =>
  readFileSync(chemin, 'utf-8')
    .replace(/\r\n/g, '\n')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^[ \t]*\/\/.*$/gm, '')

const worker = code('../../backend/api/[[...route]].ts')
const supabase = code('src/api/supabase.ts')
const migration = readFileSync(
  '../../backend/supabase/migrations/0012_purchase_payment.sql',
  'utf-8',
).replace(/\r\n/g, '\n')

const endpoint = worker.slice(
  worker.indexOf("app.post('/purchases'"),
  worker.indexOf("app.post('/applications'"),
)

describe('le montant', () => {
  it('n’est pas accepté du client', () => {
    // Le schema de la requete ne contient qu'un identifiant de cours.
    const schema = worker.slice(
      worker.indexOf('const purchaseSchema'),
      worker.indexOf('app.post(\'/purchases\''),
    )
    expect(schema).toContain('courseId')
    expect(schema).not.toMatch(/amount|price|montant/)
  })

  it('est relu dans la base, et la commission calculée là', () => {
    expect(endpoint).toContain("from('video_courses')")
    expect(endpoint).toContain('course.price')
    expect(endpoint).toContain('COURSE_COMMISSION')
  })

  it('le client web n’en envoie aucun', () => {
    // Decoupe sur un repere de code et non sur un commentaire : `code()` les
    // retire, et `indexOf` aurait rendu -1 en avalant tout le fichier.
    const appel = supabase.slice(
      supabase.indexOf('async buyCourse'),
      supabase.indexOf('async promotions('),
    )
    // Le corps ne porte que l'identifiant du cours et, depuis le 02/10, le
    // portefeuille choisi : jamais un montant.
    expect(appel).toContain('body: { courseId, ...wallet }')

    // Le montant est *lu* dans la reponse — c'est le serveur qui le fixe — mais
    // jamais pose dans la requete.
    const corpsEnvoye = appel.slice(0, appel.indexOf('return {'))
    expect(corpsEnvoye).not.toMatch(/amount:|price:/)
    expect(appel).toContain('amount: Number(corps.amount')

    // Et ce qui part dans `wallet` ne contient que la methode et le numero du
    // payeur : le type l'impose.
    const types = code('src/api/types.ts')
    const wallet = types.slice(
      types.indexOf('export type WalletMethod'),
      types.indexOf('export interface PurchaseRequest'),
    )
    expect(wallet).not.toMatch(/amount|price/)
  })
})

describe('l’accès aux vidéos', () => {
  it('suit le paiement, pas la demande', () => {
    const fonction = migration.slice(
      migration.indexOf('create or replace function has_bought_course'),
      migration.indexOf('--- Qui ecrit quoi'),
    )
    expect(fonction).toContain("p.status = 'PAID'")
  })

  it('une demande part en attente', () => {
    expect(endpoint).toContain("status: 'PENDING'")
    expect(migration).toContain("default 'PENDING'")
  })

  it('le client ne peut plus écrire un achat directement', () => {
    // La politique d'insertion de 0007 est retiree : l'ecriture passe par le
    // serveur, qui seul connait le prix.
    expect(migration).toContain(
      'drop policy if exists "achat : c est l acheteur qui achete"',
    )
    // Et aucune politique `update` n'est posee : passer a `PAID` arrive apres
    // la confirmation de l'operateur, que le client ne peut pas prouver.
    expect(migration).not.toMatch(/create policy[^;]*for update[^;]*course_purchases/)
  })
})

describe('l’achat ne se fait pas deux fois', () => {
  it('une demande existante est rendue telle quelle', () => {
    // La contrainte d'unicite refuserait la seconde ligne, et un 409 ferait
    // croire a une panne alors que la demande est deja enregistree.
    expect(endpoint).toContain('alreadyRequested: true')
    expect(endpoint).toContain('.maybeSingle()')
  })

  it('une référence d’opérateur ne sert qu’une fois', () => {
    // Deux lignes portant la meme transaction compteraient un reglement deux
    // fois.
    expect(migration).toContain('course_purchases_provider_ref_idx')
    expect(migration).toContain('where provider_ref is not null')
  })
})

describe('l’écran dit la vérité', () => {
  const ecran = code('src/screens/Courses.tsx')

  it('ne dit jamais « acheté » avant le règlement', () => {
    // La confirmation d'achat n'apparait que dans la branche `PAID`, celle que
    // seul un webhook signe peut atteindre.
    const avantPaiement = ecran.slice(0, ecran.indexOf("if (statut === 'PAID')"))
    expect(avantPaiement).not.toMatch(/Paiement confirmé|cours est à vous/)

    // Et ce qui s'affiche avant dit que rien n'est preleve.
    // Fragment court : une phrase entiere se coupe au retour a la ligne
    // de JSX, et le test echouerait au premier reformatage.
    expect(ecran).toMatch(/est débité avant votre validation/)
  })

  it('l’état affiché vient du serveur, jamais de l’URL', () => {
    // Djomy ajoute `?transactionId=…&status=SUCCESS` a l'URL de retour, et
    // n'importe qui peut taper cela. L'ecran interroge notre serveur.
    expect(ecran).toContain('api.purchaseState(')
    expect(ecran).not.toMatch(/searchParams.*status|get\('status'\)/)
  })

  it('n’annonce une confirmation que si l’opérateur a été appelé', () => {
    // `awaiting_confirmation` vient du serveur : sans compte marchand il rend
    // `none`, et faire attendre un SMS qui ne partira pas serait un mensonge.
    expect(ecran).toContain("demande.payment === 'awaiting_confirmation'")
    const mock = code('src/api/mock.ts')
    const achat = mock.slice(
      mock.indexOf('async buyCourse'),
      mock.indexOf('async purchaseState'),
    )
    expect(achat).toContain("payment: 'none'")
  })

  it('n’offre le bouton qu’à un compte qui peut acheter', () => {
    // Un professeur ou un etablissement n'a pas de fiche famille : lui montrer
    // le bouton pour le refuser apres le clic serait pire que la porte.
    expect(ecran).toContain('session?.parentId != null')
    expect(ecran).toContain('AppGate')
  })
})

describe('bac à sable et production', () => {
  const worker = code('../../backend/api/[[...route]].ts')
  const wrangler = readFileSync('../../backend/wrangler.toml', 'utf-8')

  it('l’environnement est déclaré par cible de déploiement', () => {
    // Deux cibles : `wrangler deploy` sans `--env` pour le bac à sable, avec
    // `--env production` pour la production. Les secrets sont par cible, donc
    // un jeu de clés ne peut pas fuir d'un environnement à l'autre.
    expect(wrangler).toContain('DJOMY_ENVIRONMENT = "sandbox"')
    expect(wrangler).toContain('DJOMY_ENVIRONMENT = "production"')
  })

  it('des clés sans environnement déclaré n’encaissent pas', () => {
    // Les deux erreurs possibles sont silencieuses : « production » par défaut
    // facturerait de vrais clients depuis un poste de développement,
    // « sandbox » par défaut laisserait une mise en ligne encaisser dans le
    // vide. D'où un refus, pas une valeur par défaut.
    expect(worker).toContain("process.env.DJOMY_ENVIRONMENT")
    expect(worker).toContain("[djomy] cles presentes mais configuration incomplete")
    // Et jamais devine depuis l'URL.
    expect(worker).not.toMatch(/baseUrl.*includes\(['"]sandbox/)
  })

  it('/health dit quelle caisse est active', () => {
    const health = worker.slice(
      worker.indexOf("app.get('/health'"),
      worker.indexOf("app.get('/subjects'"),
    )
    expect(health).toContain('environment: djomy.environment')
  })

  it('un paiement de test se voit à l’écran', () => {
    const ecran = code('src/screens/Courses.tsx')
    expect(ecran).toContain('demande.sandbox')
    expect(ecran).toMatch(/Paiement de test/)
    // Y compris quand il « réussit » : c'est là que la confusion coûte cher.
    const paye = ecran.slice(ecran.indexOf("if (statut === 'PAID')"))
    expect(paye.slice(0, 400)).toContain('bandeauTest')
  })
})
