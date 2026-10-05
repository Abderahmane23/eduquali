/**
 * Verification du projet Supabase reel.
 *
 *   node --env-file=.env scripts/check-supabase.mjs
 *
 * --- Ce que ce fichier prouve, et ce qu'il ne prouve pas ------------------
 *
 * `check:db` applique les migrations sur un Postgres jetable : il prouve que le
 * schema s'installe. Il ne prouve rien sur la base en service, parce qu'il y
 * pose `auth.uid()` lui-meme au lieu de le lire dans un jeton.
 *
 * Ici, c'est la vraie base, avec les vraies cles. Le controle central est le
 * couple B/C : la MEME requete, avec la cle publique puis avec la cle secrete.
 * La publique doit voir 0 question, la secrete toutes. Deux chiffres differents
 * pour une requete identique, c'est RLS qui agit — et c'est la seule forme de
 * preuve qui resiste a une table vide.
 *
 * Ce que ce fichier ne prouve PAS : le cloisonnement entre deux comptes. Il
 * faudrait deux utilisateurs reels et leurs jetons ; cela ecrit dans la base et
 * vit donc dans un script a part.
 */

import { createClient } from '@supabase/supabase-js'
import { readFileSync, readdirSync } from 'node:fs'

const url = process.env.SUPABASE_URL
const clePublique = process.env.SUPABASE_ANON_KEY
const cleSecrete = process.env.SUPABASE_SERVICE_ROLE_KEY

let echecs = 0
let reserves = 0
/** Echecs imputables au reseau, et non a la base. */
let coupures = 0

const ok = (titre, detail) =>
  console.log('  ok       ' + titre + (detail ? '  — ' + detail : ''))
const echec = (titre, detail) => {
  echecs += 1
  console.log('  ECHEC    ' + titre + (detail ? '  — ' + detail : ''))
}
const reserve = (titre, detail) => {
  reserves += 1
  console.log('  reserve  ' + titre + (detail ? '  — ' + detail : ''))
}

/* ----------------------------------------------------------------------- *
 * A. Les cles
 *
 * La confusion la plus couteuse du projet n'est pas une cle manquante, c'est
 * la cle secrete collee dans la case de la cle publique. Tout fonctionnerait —
 * mieux, meme : plus aucun refus. Et la cle qui contourne toutes les regles
 * partirait dans le bundle du site et dans l'APK, qui circule par Bluetooth.
 * Rien dans l'application ne s'en plaindrait jamais. D'ou ce controle en
 * premier.
 * ----------------------------------------------------------------------- */
console.log('A. Les cles')

if (!url || !clePublique || !cleSecrete) {
  console.log(
    '  ECHEC    SUPABASE_URL, SUPABASE_ANON_KEY et SUPABASE_SERVICE_ROLE_KEY' +
      ' sont requises.',
  )
  console.log(
    '           Lancer avec : node --env-file=.env scripts/check-supabase.mjs',
  )
  process.exit(1)
}

const publiqueEstPrivilegiee =
  clePublique.startsWith('sb_secret_') ||
  clePublique.includes('service_role') ||
  clePublique === cleSecrete

if (publiqueEstPrivilegiee) {
  echec(
    'SUPABASE_ANON_KEY contient une cle privilegiee',
    'elle voyage dans le site et dans l APK : la regenerer, puis remettre la' +
      ' cle publiable',
  )
} else {
  ok('la cle publique est bien une cle publique')
}

if (cleSecrete.startsWith('sb_publishable_')) {
  echec(
    'SUPABASE_SERVICE_ROLE_KEY contient la cle publiable',
    'les operations privilegiees echoueront toutes',
  )
} else {
  ok('la cle secrete est distincte de la publique')
}

if (url.startsWith('https://') && url.includes('.supabase.')) {
  ok('URL du projet', url)
} else {
  echec('SUPABASE_URL inattendue', url)
}

const anonyme = createClient(url, clePublique, {
  auth: { persistSession: false, autoRefreshToken: false },
})
const service = createClient(url, cleSecrete, {
  auth: { persistSession: false, autoRefreshToken: false },
})

/*
 * « Injoignable » et « absent » ne sont pas la meme nouvelle.
 *
 * La premiere version de ce fichier confondait les deux : un `TypeError: fetch
 * failed` — une coupure reseau — etait rapporte comme « la migration n a pas ete
 * appliquee ». Quelqu un serait alors reparti coller du SQL dans l editeur pour
 * un probleme qui n existait pas, et aurait conclu que le controle raconte
 * n importe quoi. Un controle qui accuse a tort est pire qu absent.
 *
 * PostgREST nomme l absence (`42P01`, ou `PGRST205` quand le schema est en
 * cache) ; une coupure n a pas de code du tout. C est ce qui les distingue.
 */
const ABSENCE = new Set(['42P01', 'PGRST205', 'PGRST202'])

const injoignable = (erreur) =>
  !erreur?.code && /fetch failed|ENOTFOUND|ECONNRESET|ETIMEDOUT|network/i.test(
    `${erreur?.message ?? ''}`,
  )

/**
 * Compte les lignes, avec quelques reprises.
 *
 * Trois essais espaces : la connexion depuis laquelle ce controle tourne est
 * parfois celle d un reseau guineen, et un echec unique ne dit rien sur la base.
 */
const compte = async (client, table, essais = 3) => {
  let derniere
  for (let essai = 1; essai <= essais; essai += 1) {
    const { count, error } = await client
      .from(table)
      .select('*', { count: 'exact', head: true })
    if (!error) return { count }
    derniere = error
    if (!injoignable(error)) break
    if (essai < essais) {
      await new Promise((resolve) => setTimeout(resolve, 400 * essai))
    }
  }
  return {
    erreur: derniere,
    absente: ABSENCE.has(derniere?.code),
    coupure: injoignable(derniere),
  }
}

/* ----------------------------------------------------------------------- *
 * B. Le referentiel est en place
 *
 * Les nombres attendus ne sont pas recopies ici : ils se derivent des fichiers
 * qui ont servi au semis. Un chiffre recopie se desynchronise au premier ajout
 * de matiere, et le controle se met alors a mentir dans les deux sens — il
 * passe quand la base est fausse, il echoue quand elle est juste.
 * ----------------------------------------------------------------------- */
console.log('')
console.log('B. Le referentiel')

const NL = String.fromCharCode(10)
const racine = new URL('../', import.meta.url)
const dossierMigrations = new URL('supabase/migrations/', racine)
const catalogue = JSON.parse(
  readFileSync(new URL('../shared/seed/catalog.json', racine), 'utf8'),
)
const inserts = (fichier, table) => {
  const sql = readFileSync(new URL('supabase/' + fichier, racine), 'utf8')
  return sql.split(NL + 'insert into ' + table + ' ').length - 1
}

const attendus = {
  subjects: catalogue.subjects.length,
  levels: catalogue.levels.length,
  tests: catalogue.tests.length,
  institutions: catalogue.institutions.length,
  jobs: catalogue.jobs.length,
  test_questions: inserts('seed.sql', 'test_questions'),
  curriculum_chapters: inserts('seed_curriculum.sql', 'curriculum_chapters'),
  curriculum_textbooks: inserts('seed_curriculum.sql', 'curriculum_textbooks'),
  curriculum_sources: inserts('seed_curriculum.sql', 'curriculum_sources'),
}

/*
 * Les objets qu'une migration doit avoir poses.
 *
 * Verifies par leur existence et non par leur contenu : ces tables sont vides
 * sur une base neuve, et c'est normal. Ce que le controle attrape, c'est une
 * migration qu'on a oublie de passer — le cas exact de 0020, applique a la main
 * dans l'editeur SQL apres les autres.
 */
/*
 * Ce que les migrations declarent, lu dans les migrations.
 *
 * --- Pourquoi ce n'est plus une liste ecrite a la main -------------------
 *
 * Elle en etait une, et elle a rate trois fois de suite la table qu'on venait
 * d'ajouter — `shop_favorites` la derniere, pendant que le controle annoncait
 * « conforme ». Une liste qu'il faut penser a mettre a jour est une liste qu'on
 * oublie, et un controle incomplet qui dit « conforme » est pire qu'absent :
 * il donne la permission de ne pas regarder.
 *
 * Les noms viennent donc des fichiers de migration. Toute table ajoutee demain
 * est verifiee le jour meme, sans que personne n'y pense.
 */
const DECLARATION =
  /create\s+(?:table|view|materialized\s+view)\s+(?:if\s+not\s+exists\s+)?(?:or\s+replace\s+)?([a-z_][a-z0-9_]*)/gi
const VUE = /create\s+(?:or\s+replace\s+)?view\s+([a-z_][a-z0-9_]*)/gi

const objetsAttendus = []
const migrationDe = {}

for (const fichier of readdirSync(dossierMigrations).sort()) {
  if (!fichier.endsWith('.sql')) continue
  const sql = readFileSync(new URL(fichier, dossierMigrations), 'utf8')
  // Les commentaires contiennent des exemples de SQL : les retirer evite de
  // reclamer une table qui n'existe que dans une explication.
  const code = sql
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*--.*$/gm, '')

  for (const motif of [DECLARATION, VUE]) {
    motif.lastIndex = 0
    for (const trouve of code.matchAll(motif)) {
      const nom = trouve[1].toLowerCase()
      // `auth.users` vient de Supabase, pas de nous.
      if (nom === 'users' && /auth\.users/.test(code)) continue
      if (objetsAttendus.includes(nom)) continue
      objetsAttendus.push(nom)
      migrationDe[nom] = fichier
    }
  }

  /*
   * Ce qu'une migration ulterieure supprime n'est plus attendu.
   *
   * `credit_ledger` est cree en 0006 et supprime en 0008 — il a fait payer
   * l'usage de l'IA a l'unite, et c'est precisement ce qu'on ne voulait plus.
   * Sans cette passe, le controle reclamait une table dont l'absence est le
   * resultat recherche, et accusait la base d'un defaut qui n'en est pas un.
   *
   * L'ordre des fichiers compte : les migrations sont parcourues triees, donc
   * un `drop` ne retire que ce qui a ete declare avant lui.
   */
  for (const trouve of code.matchAll(
    /drop\s+(?:table|view|materialized\s+view)\s+(?:if\s+exists\s+)?([a-z_][a-z0-9_]*)/gi,
  )) {
    const nom = trouve[1].toLowerCase()
    const place = objetsAttendus.indexOf(nom)
    if (place >= 0) {
      objetsAttendus.splice(place, 1)
      delete migrationDe[nom]
    }
  }
}


/*
 * L'existence se verifie par une VRAIE lecture, jamais par un `head: true`.
 *
 * Le controle precedent comptait les lignes avec `head: true`. Sur une table
 * absente, PostgREST repond 404 avec un corps vide — et supabase-js, n'ayant
 * rien a lire, ne remplit pas `error`. Le compte revenait donc « sans erreur »
 * et le controle annoncait « shop_items existe » pour une table qui n'existait
 * pas. Un controle qui rassure a tort est pire qu'absent.
 *
 * Un `select` ordinaire, lui, rapporte bien `PGRST205`.
 */
const existe = async (client, table) => {
  const { error } = await client.from(table).select('*').limit(1)
  if (!error) return { ok: true }
  return {
    erreur: error,
    absente: ABSENCE.has(error.code),
    coupure: injoignable(error),
  }
}

for (const objet of objetsAttendus) {
  const { erreur, absente, coupure } = await existe(service, objet)
  if (absente) {
    echec(
      `${objet} est absent`,
      'la migration qui le cree n a pas ete appliquee : passer ' +
        `backend/supabase/migrations/${migrationDe[objet] ?? '?'}`,
    )
  } else if (coupure) {
    coupures += 1
    echec(`${objet} : serveur injoignable`, 'ceci ne dit rien du schema')
  } else if (erreur) {
    echec(objet, erreur.message)
  } else {
    ok(`${objet} existe`)
  }
}

for (const [table, attendu] of Object.entries(attendus)) {
  // Avec la cle secrete : ici on verifie le CONTENU, pas la visibilite.
  // Melanger les deux questions donnerait un echec ambigu.
  const { count, erreur, coupure } = await compte(service, table)
  if (coupure) {
    coupures += 1
    echec(`${table} : serveur injoignable`, 'ceci ne dit rien du schema')
  } else if (erreur) {
    echec(table, erreur.message)
  } else if (count === attendu) {
    ok(table, count + ' lignes')
  } else {
    echec(table, 'attendu ' + attendu + ', trouve ' + count)
  }
}

/* ----------------------------------------------------------------------- *
 * C. Ce que la cle publique ne doit pas voir
 *
 * La cle publique part dans le bundle du site et dans l'APK. RLS est donc la
 * seule barriere, et c'est ici qu'elle est mise a l'epreuve pour la premiere
 * fois depuis le debut du projet.
 * ----------------------------------------------------------------------- */
console.log('')
console.log('C. Ce que la cle publique ne voit pas')

{
  const avecService = await compte(service, 'test_questions')
  const avecAnon = await compte(anonyme, 'test_questions')
  const vuAnon = avecAnon.erreur ? 0 : avecAnon.count

  if (avecService.count > 0 && vuAnon === 0) {
    ok(
      'test_questions est ferme',
      avecService.count + ' lignes pour le serveur, 0 pour la cle publique',
    )
  } else if (vuAnon > 0) {
    echec(
      'test_questions est LISIBLE avec la cle publique',
      vuAnon + ' lignes — les bonnes reponses des tests sont exposees',
    )
  } else {
    echec('test_questions parait vide des deux cotes', 'semis incomplet ?')
  }
}

{
  // La vue publique doit, elle, etre lisible : c'est elle que l'ecran de test
  // sert. Fermee, le test s'affiche sans aucune question.
  const { count, erreur } = await compte(anonyme, 'test_questions_public')
  if (erreur) echec('test_questions_public illisible', erreur.message)
  else if (count > 0) ok('test_questions_public est lisible', count + ' lignes')
  else echec('test_questions_public ne rend aucune ligne')
}

{
  // Et elle ne doit pas porter la reponse. Une vue qui expose `correct_key`
  // rendrait le test entier sans valeur, sans qu'aucun ecran ne change
  // d'apparence.
  const { error } = await anonyme
    .from('test_questions_public')
    .select('correct_key')
    .limit(1)
  if (error) ok('correct_key absent de la vue publique')
  else echec('correct_key est SERVI par la vue publique')
}

/* ----------------------------------------------------------------------- *
 * D. Les ecritures refusees
 *
 * Sur une base neuve, la plupart des tables privees sont vides : y lire zero
 * ligne avec la cle publique ne prouve rien du tout. L'ecriture, elle, se
 * teste sur une table vide — c'est la seule preuve disponible a ce stade.
 * ----------------------------------------------------------------------- */
console.log('')
console.log('D. Les ecritures refusees')

const refuse = async (table, ligne, pourquoi) => {
  const { error } = await anonyme.from(table).insert(ligne)
  if (error) {
    ok('insert refuse sur ' + table, pourquoi)
    return
  }
  // L'ecriture a passe : la politique est trop large. On retire aussitot la
  // ligne, sinon un controle laisserait des dechets dans la base de production a
  // chaque passage — et on finirait par ne plus le lancer.
  await service.from(table).delete().eq('id', ligne.id)
  echec(
    'insert ACCEPTE sur ' + table,
    pourquoi + ' (la ligne de controle a ete retiree)',
  )
}

await refuse(
  'subjects',
  { id: 'sub_zz_controle', code: 'ZZCTRL', name: 'Controle' },
  'sinon n importe qui ajoute une matiere au referentiel',
)
await refuse(
  'children',
  { id: 'enf_zz_controle', first_name: 'Controle' },
  'sinon n importe qui inscrit un enfant dans une autre famille',
)
await refuse(
  'teachers',
  { id: 'prof_zz_controle', headline: 'Controle' },
  'sinon n importe qui cree un faux profil de professeur',
)

/*
 * Les points, surtout.
 *
 * `point_ledger` n'a AUCUNE politique d'ecriture : les points se gagnent par une
 * decision du serveur. Un client qui pourrait ecrire ici s'accorderait lui-meme
 * la monnaie de fidelite, et la boutique n'aurait plus aucun sens.
 *
 * Ce controle vaut sur une table vide, contrairement a une lecture — c'est
 * pourquoi il porte sur l'ecriture.
 */
await refuse(
  'point_ledger',
  {
    id: 'pl_zz_controle',
    owner_id: '00000000-0000-0000-0000-000000000000',
    delta: 10000,
    reason: 'Controle',
  },
  'sinon n importe qui s accorde des points',
)
await refuse(
  'contest_entries',
  {
    id: 'ce_zz_controle',
    contest_id: 'ct_zz_inexistant',
    user_id: '00000000-0000-0000-0000-000000000000',
    score: 100,
  },
  'sinon on s inscrit au nom d un autre, avec son propre score',
)

/* ----------------------------------------------------------------------- *
 * Ce qui reste hors de portee de ce controle
 *
 * Ecrit noir sur blanc, parce qu'un rapport vert laisse croire qu'il a tout
 * verifie. Ces deux lignes disent ce qu'il n'a pas regarde.
 * ----------------------------------------------------------------------- */
console.log('')
console.log('Ce qui reste a eprouver')
reserve(
  'le cloisonnement entre deux comptes',
  'hors de portee d ici, et eprouve ailleurs : npm run check:rls cree deux ' +
    'comptes reels, les connecte et verifie que l un ne lit pas les donnees de ' +
    'l autre. Il ecrit donc dans la base, et exige --ecrire ; ce fichier-ci n y ' +
    'ecrit jamais rien, et peut tourner a tout moment.',
)
reserve(
  'les politiques des tables encore vides',
  'un refus de lecture sur une table vide ne prouve rien',
)
reserve(
  'le declencheur d ajout seul de point_ledger',
  'l eprouver demanderait d ecrire une ligne que le declencheur empeche ' +
    'ensuite de supprimer : un dechet definitif dans un vrai journal de ' +
    'points. Il est eprouve par check:db, sur un Postgres jetable.',
)

console.log('')
if (echecs === 0) {
  console.log('Base en service conforme. ' + reserves + ' reserves ci-dessus.')
} else if (coupures > 0 && coupures === echecs) {
  // Tous les echecs viennent du reseau : ne rien conclure sur la base.
  console.log(coupures + ' appel(s) n ont pas abouti : serveur injoignable.')
  console.log('Ce controle ne dit RIEN de la base dans cet etat — relancer sur')
  console.log('une connexion stable avant d en tirer une conclusion.')
} else {
  console.log(
    echecs -
      coupures +
      ' echec(s) reels' +
      (coupures > 0 ? ` (et ${coupures} coupure(s) reseau)` : '') +
      '. La base n est pas prete.',
  )
}
process.exit(echecs === 0 ? 0 : 1)
