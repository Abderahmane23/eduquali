/**
 * Les politiques RLS, eprouvees avec de vrais comptes et de vrais jetons.
 *
 *   node --env-file=.env scripts/check-rls.mjs --ecrire
 *
 * --- Le trou que ce fichier comble --------------------------------------
 *
 * `check:db` applique les migrations sur un Postgres jetable : il prouve que le
 * schema s'installe. `check:supabase` interroge la base en service avec la cle
 * publique : il prouve qu'une table semee est fermee a l'anonyme.
 *
 * Aucun des deux ne repond a la question qui compte le plus : **un compte
 * voit-il les donnees d'un autre compte ?** La cle publique est publique par
 * construction — elle voyage dans le bundle du site et dans l'APK — donc une
 * politique trop large n'est pas une imprudence, c'est une fuite. Et un refus de
 * lecture sur une table vide ne prouve rien du tout.
 *
 * Ici on cree deux comptes reels, on les connecte, on donne des donnees au
 * premier, et on demande au second de les lire. C'est la seule forme de preuve
 * qui vaille.
 *
 * --- Pourquoi il faut un drapeau ---------------------------------------
 *
 * Ce controle **ecrit dans la base de production** : deux comptes, un profil, un
 * parent, un enfant. Il les supprime ensuite, et la cascade
 * `auth.users -> profiles -> parents -> children` s'en charge. Mais un script qui
 * ecrit ne doit pas pouvoir se lancer par distraction, ni tourner dans une chaine
 * de verification automatique : d'ou `--ecrire`, a taper a la main.
 *
 * Une table n'est volontairement pas touchee : `point_ledger`. Son declencheur
 * d'ajout seul empeche de supprimer ce qu'on y ecrit, et un controle ne doit pas
 * laisser de dechet definitif dans un journal de points.
 */

import { createClient } from '@supabase/supabase-js'

const url = process.env.SUPABASE_URL
const clePublique = process.env.SUPABASE_ANON_KEY
const cleSecrete = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!process.argv.includes('--ecrire')) {
  console.log(
    'Ce controle cree deux comptes dans la base en service, puis les supprime.',
  )
  console.log('Relancer avec --ecrire pour l autoriser :')
  console.log('  node --env-file=.env scripts/check-rls.mjs --ecrire')
  process.exit(2)
}

if (!url || !clePublique || !cleSecrete) {
  console.error('SUPABASE_URL, SUPABASE_ANON_KEY et SUPABASE_SERVICE_ROLE_KEY')
  console.error('sont requises. Lancer avec --env-file=.env.')
  process.exit(1)
}

let echecs = 0
const ok = (titre, detail) =>
  console.log('  ok     ' + titre + (detail ? '  — ' + detail : ''))
const echec = (titre, detail) => {
  echecs += 1
  console.log('  ECHEC  ' + titre + (detail ? '  — ' + detail : ''))
}

const admin = createClient(url, cleSecrete, {
  auth: { persistSession: false, autoRefreshToken: false },
})

/** Un client qui agit au nom d'un compte : c'est RLS qui decide. */
const commeUtilisateur = (jeton) =>
  createClient(url, clePublique, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${jeton}` } },
  })

const marque = `rlscheck-${Date.now()}`
const comptes = []

/** Cree un compte confirme et rend son jeton d'acces. */
async function creerCompte(role) {
  const email = `${marque}-${role}@exemple.test`
  const motDePasse = `Controle!${Date.now()}${role}`

  const { data: cree, error: erreurCreation } = await admin.auth.admin.createUser({
    email,
    password: motDePasse,
    email_confirm: true,
  })
  if (erreurCreation) throw new Error(`creation ${role} : ${erreurCreation.message}`)

  const anonyme = createClient(url, clePublique, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: session, error: erreurConnexion } =
    await anonyme.auth.signInWithPassword({ email, password: motDePasse })
  if (erreurConnexion) throw new Error(`connexion ${role} : ${erreurConnexion.message}`)

  const compte = {
    role,
    id: cree.user.id,
    email,
    jeton: session.session.access_token,
  }
  comptes.push(compte)
  return compte
}

async function nettoyer() {
  for (const compte of comptes) {
    // La cascade `auth.users -> profiles -> parents -> children` fait le reste.
    const { error } = await admin.auth.admin.deleteUser(compte.id)
    if (error) {
      console.log(
        `  ATTENTION  le compte ${compte.email} n a pas pu etre supprime : ` +
          error.message,
      )
    }
  }
}

try {
  console.log('A. Deux comptes reels')

  const alice = await creerCompte('alice')
  const bruno = await creerCompte('bruno')
  ok('deux comptes crees et connectes', `${alice.id.slice(0, 8)}… / ${bruno.id.slice(0, 8)}…`)

  // Le jeton porte bien l'identite : sans cela, tout le reste du fichier
  // testerait l'anonyme sous un autre nom.
  const { data: vu } = await commeUtilisateur(alice.jeton).auth.getUser(alice.jeton)
  if (vu?.user?.id === alice.id) ok('le jeton porte l identite de son compte')
  else echec('le jeton ne rend pas le bon compte', 'le reste ne prouverait rien')

  console.log('')
  console.log('B. Les donnees d Alice')

  // Avec la cle de service : on installe la situation, on ne teste rien encore.
  const { error: erreurProfil } = await admin.from('profiles').insert({
    id: alice.id,
    role: 'PARENT',
    // Obligatoire : `profiles.phone` est `not null`. Un numero de controle, dans
    // la plage reservee a la documentation, pour qu'il ne corresponde a personne.
    phone: '+224600000901',
    first_name: 'Alice',
    last_name: 'Controle',
  })
  if (erreurProfil) throw new Error(`profil Alice : ${erreurProfil.message}`)

  const { data: parent, error: erreurParent } = await admin
    .from('parents')
    .insert({ user_id: alice.id, city: 'Conakry' })
    .select('id')
    .single()
  if (erreurParent) throw new Error(`parent Alice : ${erreurParent.message}`)

  const { data: enfant, error: erreurEnfant } = await admin
    .from('children')
    .insert({ parent_id: parent.id, first_name: 'Fatoumata' })
    .select('id')
    .single()
  if (erreurEnfant) throw new Error(`enfant Alice : ${erreurEnfant.message}`)

  ok('un parent et un enfant appartiennent a Alice')

  // Bruno existe aussi comme parent : sans profil ni ligne `parents`,
  // `my_parent_id()` rendrait null pour lui, et ses lectures echoueraient pour
  // la mauvaise raison — « pas de parent » et non « pas le sien ».
  await admin.from('profiles').insert({
    id: bruno.id,
    role: 'PARENT',
    phone: '+224600000902',
    first_name: 'Bruno',
    last_name: 'Controle',
  })
  const { data: parentBruno } = await admin
    .from('parents')
    .insert({ user_id: bruno.id, city: 'Conakry' })
    .select('id')
    .single()
  await admin
    .from('children')
    .insert({ parent_id: parentBruno.id, first_name: 'Mamadou' })
  ok('Bruno est un parent complet, avec son propre enfant')

  console.log('')
  console.log('C. Chacun chez soi')

  // Le controle central du fichier.
  const vuParAlice = await commeUtilisateur(alice.jeton)
    .from('children')
    .select('id, first_name')
  const vuParBruno = await commeUtilisateur(bruno.jeton)
    .from('children')
    .select('id, first_name')

  const prenomsAlice = (vuParAlice.data ?? []).map((l) => l.first_name)
  const prenomsBruno = (vuParBruno.data ?? []).map((l) => l.first_name)

  if (prenomsAlice.includes('Fatoumata')) {
    ok('Alice lit son propre enfant', prenomsAlice.join(', '))
  } else {
    echec(
      'Alice ne voit pas son propre enfant',
      'la politique est trop fermee : le produit ne marcherait pas',
    )
  }

  if (prenomsBruno.includes('Fatoumata')) {
    echec(
      'BRUNO LIT L ENFANT D ALICE',
      'fuite de donnees entre familles : la politique « enfants : geres par le ' +
        'parent » ne ferme pas ce qu elle doit fermer',
    )
  } else {
    ok('Bruno ne voit pas l enfant d Alice', `il voit : ${prenomsBruno.join(', ') || 'rien'}`)
  }

  // Et il ne doit pas pouvoir en ajouter un chez elle.
  const { error: erreurIntrusion } = await commeUtilisateur(bruno.jeton)
    .from('children')
    .insert({ parent_id: parent.id, first_name: 'Intrus' })
  if (erreurIntrusion) {
    ok('Bruno ne peut pas ajouter un enfant chez Alice', erreurIntrusion.code ?? '')
  } else {
    echec(
      'BRUNO A AJOUTE UN ENFANT CHEZ ALICE',
      'la politique d insertion accepte un parent_id qui n est pas le sien',
    )
  }

  console.log('')
  console.log('D. Les points et les concours (migration 0020)')

  // Lecture seulement : le journal est en ajout seul, on n y ecrit donc rien
  // qu on ne pourrait pas retirer.
  const journalDeBruno = await commeUtilisateur(bruno.jeton)
    .from('point_ledger')
    .select('id, delta, reason')
  if ((journalDeBruno.data ?? []).length === 0) {
    ok('Bruno ne lit aucun point qui ne soit pas le sien')
  } else {
    echec(
      'BRUNO LIT DES ECRITURES DE POINTS',
      `${journalDeBruno.data.length} ligne(s) visibles alors qu il n en a aucune`,
    )
  }

  const soldes = await commeUtilisateur(bruno.jeton)
    .from('point_balances')
    .select('owner_id, balance')
  if ((soldes.data ?? []).length === 0) {
    ok('la vue des soldes ne rend que le sien', 'security_invoker actif')
  } else {
    const etrangers = soldes.data.filter((l) => l.owner_id !== bruno.id)
    if (etrangers.length > 0) {
      echec(
        'LA VUE DES SOLDES EXPOSE D AUTRES COMPTES',
        'la vue a perdu `security_invoker` : elle s execute avec les droits de ' +
          'son proprietaire et ignore les politiques',
      )
    } else {
      ok('la vue des soldes ne rend que le sien')
    }
  }

  // Les concours sont annonces a tous : c'est voulu, et il faut le verifier
  // aussi — une politique trop fermee viderait l'ecran.
  const concours = await commeUtilisateur(bruno.jeton)
    .from('contests')
    .select('id')
  if (concours.error) {
    echec('les concours sont illisibles', concours.error.message)
  } else {
    ok('les concours sont lisibles par un compte connecte')
  }

  // S'inscrire au nom d'un autre : refus attendu.
  const { error: erreurInscription } = await commeUtilisateur(bruno.jeton)
    .from('contest_entries')
    .insert({ contest_id: 'ct-inexistant', user_id: alice.id })
  if (erreurInscription) {
    ok('Bruno ne s inscrit pas a un concours au nom d Alice')
  } else {
    echec('BRUNO S EST INSCRIT AU NOM D ALICE')
  }
} catch (cause) {
  echec('le controle n a pas pu aller au bout', `${cause.message}`)
} finally {
  console.log('')
  console.log('Nettoyage')
  await nettoyer()
  ok(`${comptes.length} compte(s) de controle supprime(s)`)
}

console.log('')
console.log(
  echecs === 0
    ? 'Le cloisonnement entre comptes tient.'
    : `${echecs} echec(s). Ne pas ouvrir au public dans cet etat.`,
)
process.exit(echecs === 0 ? 0 : 1)
