#!/usr/bin/env node
/**
 * Exécuter vraiment les migrations, sur un vrai Postgres.
 *
 * --- Ce que ce script apporte, et que les autres ne peuvent pas -----------
 *
 * `check-sql.mjs` compte les instructions, `check-schema-file.mjs` vérifie que
 * le fichier assemblé est cohérent. Aucun des deux n'exécute une ligne de SQL.
 * Pendant dix-sept migrations, personne n'a jamais su si le schéma **démarre** —
 * et on ne le découvre normalement qu'en le collant dans la console Supabase, une
 * fois, à la main, le jour de la mise en ligne.
 *
 * Une seule erreur de syntaxe laisse alors la base à moitié créée. C'est arrivé
 * de justesse : `coalesce` dans un index demande ses propres parenthèses, et rien
 * dans le dépôt ne l'aurait dit.
 *
 * --- Pourquoi PGlite et non un conteneur ---------------------------------
 *
 * PGlite est le vrai Postgres compilé en WebAssembly : le même analyseur, le même
 * plpgsql, les mêmes messages d'erreur. Il tourne dans le processus Node, donc
 * sans Docker — ce qui compte ici, la machine de développement n'ayant pas la
 * mémoire pour faire tourner le moteur WSL de Docker Desktop (90 Mo de mémoire
 * virtuelle libre au 02/10). Et il tournera en intégration continue sans service
 * à déclarer.
 *
 * Ce qu'il ne remplace pas : la vérification des politiques RLS elles-mêmes, qui
 * demande de vrais jetons. Voir l'en-tête de `harness/00_supabase_shim.sql`.
 *
 * Usage :  npm run check:db
 */

import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ici = dirname(fileURLToPath(import.meta.url))
const racine = join(ici, '..')
const dossierMigrations = join(racine, 'supabase', 'migrations')
const shim = join(racine, 'supabase', 'harness', '00_supabase_shim.sql')

const { PGlite } = await import('@electric-sql/pglite')

/** Les extensions que le schéma demande, chargées depuis le paquet contrib. */
async function extensions() {
  try {
    const { uuid_ossp } = await import('@electric-sql/pglite/contrib/uuid_ossp')
    return { uuid_ossp }
  } catch {
    // Absente : `uuid-ossp` n'est utilisée que pour `uuid_generate_v4()`, et le
    // schéma s'appuie partout sur `gen_random_uuid()`, qui est dans le cœur
    // depuis Postgres 13. Le dire plutôt que d'échouer sur un détail.
    console.warn(
      'Note : contrib uuid_ossp indisponible — `create extension` sera ignoré.',
    )
    return {}
  }
}

const db = await PGlite.create({ extensions: await extensions() })

const version = (await db.query('select version() as v')).rows[0].v
console.log(`\nPostgres : ${String(version).split(',')[0]}`)
console.log('(PGlite — le vrai Postgres en WebAssembly, pas une imitation)\n')

/**
 * Applique un fichier d'un bloc.
 *
 * `exec` et non `query` : un fichier de migration contient plusieurs
 * instructions, des corps `$$ ... $$` et des commentaires. `exec` les passe au
 * serveur comme le ferait `psql`, ce qui est exactement ce qu'on veut
 * éprouver — y compris le point-virgule à l'intérieur d'une fonction, qui est le
 * piège d'un découpage naïf.
 */
async function appliquer(chemin, etiquette) {
  const sql = readFileSync(chemin, 'utf-8')
  const debut = Date.now()
  try {
    await db.exec(sql)
    const ms = Date.now() - debut
    console.log(`  ${etiquette.padEnd(34)} OK    ${String(ms).padStart(5)} ms`)
    return true
  } catch (cause) {
    console.log(`  ${etiquette.padEnd(34)} ÉCHEC`)
    console.log('')
    console.log(`    ${cause.message}`)
    // La position rend l'erreur utilisable : sans elle, « syntax error » sur un
    // fichier de 400 lignes se cherche à la main.
    if (cause.position) {
      const avant = sql.slice(0, Number(cause.position))
      const ligne = avant.split('\n').length
      const colonne = avant.length - avant.lastIndexOf('\n')
      console.log(`    ${etiquette}:${ligne}:${colonne}`)
      const lignes = sql.split('\n')
      for (let i = Math.max(0, ligne - 3); i < Math.min(lignes.length, ligne + 2); i += 1) {
        const marque = i === ligne - 1 ? '  >' : '   '
        console.log(`    ${marque} ${String(i + 1).padStart(4)} | ${lignes[i]}`)
      }
    }
    console.log('')
    return false
  }
}

console.log('Socle Supabase')
if (!(await appliquer(shim, '00_supabase_shim.sql'))) {
  console.error('Le socle lui-même ne passe pas : rien d’autre n’a de sens.')
  process.exit(1)
}

const migrations = readdirSync(dossierMigrations)
  .filter((f) => f.endsWith('.sql'))
  .sort()

console.log('\nMigrations, dans l’ordre')
let echecs = 0
for (const fichier of migrations) {
  const ok = await appliquer(join(dossierMigrations, fichier), fichier)
  if (!ok) {
    echecs += 1
    // On s'arrête à la première : les suivantes dépendent d'elle, et leurs
    // erreurs en cascade noieraient la vraie cause.
    console.error(
      `Arrêt à ${fichier}. Les migrations suivantes n’ont pas été tentées :\n` +
        '  elles dépendent de celle-ci, et leurs erreurs masqueraient la cause.',
    )
    break
  }
}

if (echecs > 0) process.exit(1)

/*
 * Le semis du programme scolaire, applique pour de vrai.
 *
 * 348 chapitres qui citent chacun une matiere et une classe par cle etrangere,
 * plus une contrainte de longueur sur le titre. C'est le seul endroit ou une
 * extraction ratee se voit : un identifiant absent du referentiel ou un titre de
 * 300 caracteres echoue ici, et non six semaines plus tard dans la console
 * Supabase.
 *
 * Le referentiel doit etre pose d'abord — les chapitres en dependent.
 */
console.log('\nSemis')
const seeds = [
  ['seed.sql', 'referentiel et demonstration'],
  ['seed_curriculum.sql', 'programme scolaire'],
]
for (const [fichier, quoi] of seeds) {
  const chemin = join(racine, 'supabase', fichier)
  if (!existsSync(chemin)) {
    console.log(`  ${fichier.padEnd(34)} absent (ignore)`)
    continue
  }
  if (!(await appliquer(chemin, fichier))) {
    console.error(`Le semis « ${quoi} » a echoue : voir ci-dessus.`)
    process.exit(1)
  }
}

// --- Ce que le schéma a réellement produit ---------------------------------
//
// Appliquer sans erreur ne suffit pas : une migration peut passer en ne créant
// rien du tout (un `if not exists` sur un objet mal nommé, par exemple). On
// relit donc le catalogue.

const un = async (sql) => (await db.query(sql)).rows[0]
const tous = async (sql) => (await db.query(sql)).rows

const tables = await tous(`
  select c.relname as nom, c.relrowsecurity as rls
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
   order by c.relname
`)
const vues = await tous(`
  select c.relname as nom,
         coalesce((
           select option_value = 'true'
             from pg_options_to_table(c.reloptions)
            where option_name = 'security_invoker'
         ), false) as invoker
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'v'
   order by c.relname
`)
const politiques = await un(
  `select count(*)::int as n from pg_policies where schemaname = 'public'`,
)
const fonctions = await un(`
  select count(*)::int as n
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prokind = 'f'
`)
const index = await un(
  `select count(*)::int as n from pg_indexes where schemaname = 'public'`,
)

console.log('\nCe que la base contient')
console.log(`  ${tables.length} tables`)
console.log(`  ${vues.length} vues`)
console.log(`  ${politiques.n} politiques`)
console.log(`  ${fonctions.n} fonctions`)
console.log(`  ${index.n} index`)

const problemes = []

// Une table sans RLS dans une base Supabase est ouverte à la clé anonyme, qui
// est publique par construction : elle voyage dans le paquet du site et dans
// l'APK. C'est le défaut le plus coûteux du modèle, et le seul que ce contrôle
// peut attraper mécaniquement.
const sansRls = tables.filter((t) => !t.rls).map((t) => t.nom)
if (sansRls.length > 0) {
  problemes.push(
    `${sansRls.length} table(s) sans RLS, donc ouvertes à la clé anonyme :\n` +
      sansRls.map((n) => `      - ${n}`).join('\n'),
  )
}

/*
 * Les vues et le mode de sécurité.
 *
 * Il n'y a pas de bonne réponse unique ici, et c'est le piège : une vue en
 * `security_definer` — le défaut historique de Postgres — contourne les
 * politiques des tables qu'elle lit.
 *
 *   * Pour `attendance_detail`, ce serait une fuite : la présence de toute la
 *     plateforme deviendrait lisible par n'importe quel compte.
 *   * Pour les trois autres, c'est **le mécanisme voulu**. Postgres n'a pas de
 *     politique par colonne ; exposer un titre sans le chemin du fichier, ou un
 *     nom sans le téléphone, passe donc par une vue qui lit plus que son
 *     appelant. C'est un trou percé exprès, dans une direction choisie.
 *
 * La liste ci-dessous les déclare une par une. Toute **nouvelle** vue en
 * `definer` fait donc échouer ce contrôle, ce qui est exactement ce qu'on veut :
 * le mode par défaut de Postgres est le mode dangereux, et on ne doit pas
 * pouvoir en hériter par distraction.
 */
const DEFINER_ASSUME = {
  course_item_titles:
    'projection de colonnes (0010) : le titre et la durée d’un élément, jamais ' +
    'son fichier',
  public_teacher_identities:
    'projection de colonnes (0009) : prénom, nom et photo, jamais le téléphone ' +
    'ni le courriel',
  test_questions_public:
    'projection de colonnes (0001) : l’énoncé sans la réponse, servi pendant le ' +
    'test',
}

const definerInattendues = vues
  .filter((v) => !v.invoker && !(v.nom in DEFINER_ASSUME))
  .map((v) => v.nom)
if (definerInattendues.length > 0) {
  problemes.push(
    `vue(s) en \`security_definer\` non déclarée(s) — elles contournent RLS :\n` +
      definerInattendues.map((n) => `      - ${n}`).join('\n') +
      '\n      Si c’est voulu, ajoutez-la à DEFINER_ASSUME avec la raison.',
  )
}

// L'inverse compte aussi : une vue déclarée comme projection volontaire qui
// passerait en `invoker` cesserait de montrer quoi que ce soit, et la recherche
// rendrait des fiches anonymes sans qu'une erreur soit levée.
for (const [nom, raison] of Object.entries(DEFINER_ASSUME)) {
  const vue = vues.find((v) => v.nom === nom)
  if (!vue) {
    problemes.push(`vue \`${nom}\` déclarée dans DEFINER_ASSUME mais absente`)
  } else if (vue.invoker) {
    problemes.push(
      `vue \`${nom}\` est passée en \`security_invoker\` : elle ne montrera ` +
        `plus rien à un appelant anonyme, alors qu'elle existe pour ${raison}`,
    )
  }
}

// --- Les invariants qu'on ne peut vérifier qu'en exécutant ----------------
//
// Trois constructions du schéma reposent sur un comportement de Postgres plutôt
// que sur une déclaration. Les lire ne dit pas si elles marchent.

/*
 * Un jeu d'essai minimal : une famille, un professeur, un cours, une séance.
 *
 * Posé sous la clé de service (PGlite n'applique pas RLS au superutilisateur),
 * parce que ce qui est éprouvé ici est le schéma, pas les politiques. Les
 * colonnes obligatoires viennent du catalogue : `subjects.code` et
 * `levels.category` sont `not null`, ce que le premier jet ignorait — l'insertion
 * échouait alors et faisait tomber trois invariants d'un coup, tous pour la même
 * raison étrangère à ce qu'ils vérifiaient.
 */
const PARENT = '11111111-1111-1111-1111-111111111111'
const PROF = '22222222-2222-2222-2222-222222222222'

await db.exec(`
  insert into auth.users (id) values ('${PARENT}'), ('${PROF}');
  insert into profiles (id, role, first_name, last_name, phone) values
    ('${PARENT}', 'PARENT',  'Mariama', 'Bah',   '+224600000001'),
    ('${PROF}',   'TEACHER', 'Alpha',   'Camara','+224600000002');

  -- Pas de matiere ni de classe inventee : le semis vient de les poser, et en
  -- recreer une faisait entrer son code en collision avec le referentiel
  -- (« MATH » existe deja). On se sert donc du vrai referentiel, ce qui a
  -- l'avantage d'eprouver les donnees reellement deployees.
  -- (Sans accent grave dans ce commentaire : il vit dans un litteral de
  -- gabarit JavaScript, qu'un accent grave refermerait.)

  insert into teachers (id, user_id) values ('t-1', '${PROF}');
  insert into parents  (id, user_id) values ('p-1', '${PARENT}');
  insert into children (id, parent_id, first_name, level_id)
    values ('e-1', 'p-1', 'Fatoumata', 'lvl_terminale');

  insert into live_courses (id, teacher_id, subject_id, level_id, price, seats, status)
    values ('lc-1', 't-1', 'sub_math', 'lvl_terminale', 45000, 2, 'PUBLISHED');
  insert into live_sessions (id, live_course_id, slot_id, starts_at)
    values ('ls-1', 'lc-1', 'WD_18', now() + interval '1 day');
  insert into session_enrolments (id, session_id, parent_id, child_id, status)
    values ('se-1', 'ls-1', 'p-1', 'e-1', 'CONFIRMED');
  insert into session_attendance (session_id, user_id, enrolment_id)
    values ('ls-1', '${PARENT}', 'se-1');
`)

console.log('\nLes invariants qui demandent une exécution')

async function invariant(titre, fn) {
  try {
    await fn()
    console.log(`  ✓ ${titre}`)
  } catch (cause) {
    console.log(`  ✗ ${titre}`)
    console.log(`      ${cause.message}`)
    problemes.push(`invariant « ${titre} » : ${cause.message}`)
  }
}

const attendu = (condition, message) => {
  if (!condition) throw new Error(message)
}

/**
 * Vérifie qu'une insertion est refusée **par la contrainte visée**.
 *
 * Le contrôle qui manquait au premier jet, et il a immédiatement menti : un
 * `insert` citant une colonne inexistante échouait, le test voyait un refus et
 * se déclarait satisfait — sans jamais atteindre la contrainte qu'il prétendait
 * éprouver. Un test qui passe pour la mauvaise raison est pire qu'un test absent,
 * parce qu'il décourage de regarder.
 */
async function refusePar(sql, contrainte) {
  try {
    await db.exec(sql)
  } catch (cause) {
    const nomme =
      cause.constraint === contrainte ||
      String(cause.message).includes(contrainte)
    if (!nomme) {
      throw new Error(
        `refusé, mais par « ${cause.constraint ?? cause.message} » ` +
          `et non par « ${contrainte} »`,
      )
    }
    return
  }
  throw new Error(`accepté, alors que « ${contrainte} » devait le refuser`)
}

await invariant(
  'l’index partiel n’autorise qu’une présence ouverte par place',
  async () => {
    // La même place deux fois, sans fermer la première : refus attendu, et par
    // l'index partiel nommément.
    await refusePar(
      `insert into session_attendance (session_id, user_id, enrolment_id)
         values ('ls-1', '${PARENT}', 'se-1');`,
      'session_attendance_open_idx',
    )

    // Fermée, la première laisse place à la suivante : c'est une reconnexion.
    await db.exec(`
      update session_attendance set left_at = now(), minutes = 12
       where session_id = 'ls-1' and left_at is null;
      insert into session_attendance (session_id, user_id, enrolment_id)
        values ('ls-1', '11111111-1111-1111-1111-111111111111', 'se-1');
    `)
    const n = await un(
      `select count(*)::int as n from session_attendance where session_id = 'ls-1'`,
    )
    attendu(n.n === 2, `attendu 2 lignes de présence, vu ${n.n}`)
  },
)

await invariant('la vue attendance_detail calcule les minutes en cours', async () => {
  const ligne = await un(`
    select minutes, minutes_so_far
      from attendance_detail
     where session_id = 'ls-1' and left_at is null
  `)
  attendu(ligne != null, 'aucune ligne ouverte dans la vue')
  attendu(
    ligne.minutes === null,
    `une ligne ouverte ne doit pas avoir de minutes figées (vu ${ligne.minutes})`,
  )
  attendu(
    Number(ligne.minutes_so_far) >= 0,
    `minutes_so_far doit être calculable (vu ${ligne.minutes_so_far})`,
  )
})

await invariant('claim_session_seat respecte le nombre de places', async () => {
  // Deux places déclarées sur `lc-1`. Une est déjà prise par l'insertion
  // ci-dessus ? Non : `claim_session_seat` incrémente `seats_taken`, que
  // l'insertion directe n'a pas touché. On part donc de zéro.
  const premier = await un(`select claim_session_seat('ls-1') as ok`)
  attendu(premier.ok === true, 'la première place a été refusée')
  const second = await un(`select claim_session_seat('ls-1') as ok`)
  attendu(second.ok === true, 'la deuxième place a été refusée')
  const troisieme = await un(`select claim_session_seat('ls-1') as ok`)
  attendu(
    troisieme.ok === false,
    'une troisième place a été accordée sur un cours à deux places',
  )
})

await invariant(
  'un achat vise un cours OU une inscription, jamais ni l’un ni l’autre',
  async () => {
    // Les deux côtés de la contrainte, nommément. Sans cible : refus.
    await refusePar(
      `insert into course_purchases (id, parent_id, course_id, enrolment_id, amount)
         values ('cp-vide', 'p-1', null, null, 45000);`,
      'course_purchases_target_check',
    )

    // Avec une inscription seule : accepté — c'est le cas qu'a ouvert la
    // migration 0015, et celui qui aurait levé en production avant elle.
    await db.exec(
      `insert into course_purchases (id, parent_id, course_id, enrolment_id, amount)
         values ('cp-seance', 'p-1', null, 'se-1', 45000);`,
    )
    const pose = await un(
      `select enrolment_id from course_purchases where id = 'cp-seance'`,
    )
    attendu(
      pose.enrolment_id === 'se-1',
      'un achat rattaché à une inscription n’a pas été enregistré',
    )
  },
)

await invariant(
  'un point de controle par module, meme si on l’ouvre deux fois',
  async () => {
    // Un professeur qui clique deux fois, ou dont le navigateur a plante, ne
    // doit pas scinder les reponses en deux decomptes dont aucun n'est vrai.
    await db.exec(`
      insert into session_checkpoints (id, session_id, module_index)
        values ('cp-0', 'ls-1', 0);
    `)
    await refusePar(
      `insert into session_checkpoints (id, session_id, module_index)
         values ('cp-0-bis', 'ls-1', 0);`,
      'session_checkpoints_session_id_module_index_key',
    )

    // Un cinquieme module n'existe pas dans le format de 90 minutes.
    await refusePar(
      `insert into session_checkpoints (id, session_id, module_index)
         values ('cp-4', 'ls-1', 4);`,
      'session_checkpoints_module_index_check',
    )
  },
)

await invariant('une reponse par place et par point de controle', async () => {
  await db.exec(`
    insert into checkpoint_answers (checkpoint_id, enrolment_id, answer)
      values ('cp-0', 'se-1', 'PARTLY');
  `)

  // Deux reponses de la meme place fausseraient le decompte dans les deux sens
  // selon l'ordre de lecture.
  await refusePar(
    `insert into checkpoint_answers (checkpoint_id, enrolment_id, answer)
       values ('cp-0', 'se-1', 'YES');`,
    'checkpoint_answers_pkey',
  )

  // Et seules trois reponses existent : « peut-etre » n'est pas une option, il
  // ne se decompte pas.
  await refusePar(
    `insert into checkpoint_answers (checkpoint_id, enrolment_id, answer)
       values ('cp-0', 'se-1', 'MAYBE');`,
    'checkpoint_answers_answer_check',
  )

  const total = await un(
    `select count(*)::int as n from checkpoint_answers where checkpoint_id = 'cp-0'`,
  )
  attendu(total.n === 1, `attendu une reponse, vu ${total.n}`)
})

await invariant('le role « universitaire » est accepte par profiles', async () => {
  /*
   * `0001_schema.sql` ne connait que TEACHER, INSTITUTION, ADMIN et PARENT ;
   * c'est `0011_student_role.sql` qui ajoute STUDENT. Lire la premiere seule
   * fait croire a un trou — et resserrer la contrainte un jour, en relisant
   * 0001, casserait silencieusement toute inscription d'universitaire : le
   * compte existerait dans `auth.users` sans profil, donc sans role, donc sans
   * acces a quoi que ce soit.
   *
   * Le libelle affiche est « Universitaire » depuis le 03/10 ; le code reste
   * STUDENT, et c'est lui que la contrainte doit accepter.
   */
  await db.exec(`
    insert into auth.users (id) values ('33333333-3333-3333-3333-333333333333');
    insert into profiles (id, role, phone)
      values ('33333333-3333-3333-3333-333333333333', 'STUDENT', '+224600000903');
  `)
  const lu = await un(
    `select role from profiles
      where id = '33333333-3333-3333-3333-333333333333'`,
  )
  attendu(lu.role === 'STUDENT', `profiles a garde le role ${lu.role}`)

  await refusePar(
    `insert into auth.users (id) values ('44444444-4444-4444-4444-444444444444');
     insert into profiles (id, role, phone)
       values ('44444444-4444-4444-4444-444444444444', 'ELEVE', '+224600000904');`,
    'profiles_role_check',
  )
})

await invariant('apprendre rapporte des points, une fois et une seule', async () => {
  /*
   * La source qui manquait, et le piege qui l'accompagne.
   *
   * Les points se gagnent par des evenements que le serveur mesure : les
   * minutes de presence viennent du serveur de visioconference, le vote exige
   * une place payee. Mais ces evenements se **rejouent** — un webhook LiveKit
   * renvoye, une mise a jour de presence qui repasse — et crediter deux fois
   * une seance de 90 minutes donnerait 36 points a qui n'en a merite que 18.
   *
   * C'est la `reference` qui l'empeche, et c'est elle qu'on eprouve ici.
   */
  const NOUVEAU = '55555555-5555-5555-5555-555555555555'

  await db.exec(`
    insert into auth.users (id) values ('${NOUVEAU}');
    insert into profiles (id, role, phone)
      values ('${NOUVEAU}', 'STUDENT', '+224600000905');
  `)

  // 1. Les cent points de bienvenue, poses par le declencheur sur `profiles`.
  const bienvenue = await un(
    `select balance, entries from point_balances where owner_id = '${NOUVEAU}'`,
  )
  attendu(
    Number(bienvenue.balance) === 100 && Number(bienvenue.entries) === 1,
    `un compte neuf devrait valoir 100 points, il en a ${bienvenue?.balance}`,
  )

  // Ils ne suffisent a rien acheter : sinon creer des comptes deviendrait une
  // facon de recolter des forfaits internet.
  const plusPetit = await un(
    `select min(points_price) as prix from shop_items where active`,
  )
  attendu(
    Number(plusPetit.prix) > 100,
    `le plus petit lot coute ${plusPetit.prix} : un compte neuf peut le prendre`,
  )

  // 2. La presence : un point par tranche de cinq minutes, au moment ou la
  //    presence se ferme.
  await db.exec(`
    insert into session_attendance (id, session_id, user_id, joined_at)
      values ('att-pts', 'ls-1', '${NOUVEAU}', now() - interval '90 minutes');
  `)
  const avantSortie = await un(
    `select balance from point_balances where owner_id = '${NOUVEAU}'`,
  )
  attendu(
    Number(avantSortie.balance) === 100,
    'entrer en salle ne doit rien rapporter : seul le temps passe compte',
  )

  await db.exec(`
    update session_attendance set left_at = now(), minutes = 90
     where id = 'att-pts';
  `)
  const apresSortie = await un(
    `select balance from point_balances where owner_id = '${NOUVEAU}'`,
  )
  attendu(
    Number(apresSortie.balance) === 118,
    `90 minutes valent 18 points : solde a ${apresSortie.balance}, attendu 118`,
  )

  // 3. Rejoue : le meme evenement ne paie pas deux fois.
  await db.exec(`
    update session_attendance set minutes = 90, left_at = now()
     where id = 'att-pts';
  `)
  const rejoue = await un(
    `select balance from point_balances where owner_id = '${NOUVEAU}'`,
  )
  attendu(
    Number(rejoue.balance) === 118,
    `une seconde fermeture a recredite : solde a ${rejoue.balance}`,
  )

  // 4. Une presence trop courte ne paie rien, et surtout ne casse pas la
  //    fermeture : `delta <> 0` ferait echouer l'insertion.
  await db.exec(`
    insert into session_attendance (id, session_id, user_id, joined_at)
      values ('att-court', 'ls-1', '${NOUVEAU}', now());
    update session_attendance set left_at = now(), minutes = 3
     where id = 'att-court';
  `)
  const court = await un(
    `select balance from point_balances where owner_id = '${NOUVEAU}'`,
  )
  attendu(
    Number(court.balance) === 118,
    `trois minutes ne valent rien : solde a ${court.balance}`,
  )
})

await invariant('le journal de points est en ajout seul, pour tout le monde', async () => {
  /*
   * Le controle le plus important de cette table.
   *
   * Une politique RLS ne suffirait pas : le serveur travaille avec la cle de
   * service, qui les contourne toutes. Seul un declencheur s'applique aussi a
   * lui — et a quiconque ouvre l'editeur SQL un soir de correction de bug.
   *
   * Sans cela, un solde pourrait etre reecrit sans laisser de trace, et la
   * question « pourquoi ai-je 340 points ? » n'aurait plus de reponse.
   */
  await db.exec(`
    insert into point_ledger (id, owner_id, delta, reason)
      values ('pl-1', '${PARENT}', 50, 'Concours hebdomadaire — 3e place');
  `)

  await refusePar(
    `update point_ledger set delta = 5000 where id = 'pl-1';`,
    'ajout seul',
  )
  await refusePar(`delete from point_ledger where id = 'pl-1';`, 'ajout seul')

  // Une ligne a zero n'apprend rien et fait douter de celles qui l'entourent.
  await refusePar(
    `insert into point_ledger (id, owner_id, delta, reason)
       values ('pl-0', '${PARENT}', 0, 'Rien du tout');`,
    'point_ledger_delta_check',
  )

  // Une raison vide rendrait l'historique illisible.
  await refusePar(
    `insert into point_ledger (id, owner_id, delta, reason)
       values ('pl-vide', '${PARENT}', 10, '  ');`,
    'point_ledger_reason_check',
  )

  // Le solde EST la somme du journal : une correction s'ecrit a l'envers.
  //
  // Mesure RELATIVE, jamais absolue : ce compte porte deja les cent points de
  // bienvenue poses par le declencheur de 0023, et il en portera d'autres le
  // jour ou une source s'ajoute. Affirmer « le solde vaut 30 » faisait echouer
  // ce controle pour une raison qui n'a rien a voir avec l'ajout seul.
  const avantCorrection = await un(
    `select balance, entries from point_balances where owner_id = '${PARENT}'`,
  )
  await db.exec(`
    insert into point_ledger (id, owner_id, delta, reason)
      values ('pl-2', '${PARENT}', -20, 'Correction : concours annule');
  `)
  const solde = await un(
    `select balance, entries from point_balances where owner_id = '${PARENT}'`,
  )
  attendu(
    Number(solde.balance) === Number(avantCorrection.balance) - 20 &&
      Number(solde.entries) === Number(avantCorrection.entries) + 1,
    `le solde est passe de ${avantCorrection.balance} a ${solde.balance} ` +
      `(attendu -20) sur ${solde.entries} ecritures`,
  )
})

await invariant('une seule participation par concours et par compte', async () => {
  // Sans cela on recommencerait jusqu'a obtenir un bon score, et le classement
  // ne voudrait plus rien dire.
  await db.exec(`
    insert into contests (id, test_id, title, opens_at, closes_at, points_prize)
      values ('ct-1', 'test_math_lycee', 'Concours de maths',
              now() - interval '1 hour', now() + interval '1 hour', 100);
    insert into contest_entries (id, contest_id, user_id)
      values ('ce-1', 'ct-1', '${PARENT}');
  `)

  await refusePar(
    `insert into contest_entries (id, contest_id, user_id)
       values ('ce-1-bis', 'ct-1', '${PARENT}');`,
    'contest_entries_contest_id_user_id_key',
  )

  // Une fenetre fermee avant d'etre ouverte n'accepterait jamais personne, et
  // l'erreur ne se verrait qu'au silence des participations.
  await refusePar(
    `insert into contests (id, test_id, title, opens_at, closes_at)
       values ('ct-envers', 'test_math_lycee', 'A l envers',
               now() + interval '1 day', now());`,
    'contests_fenetre',
  )
})

await invariant('un echange verifie le solde, le stock et le journal ensemble', async () => {
  /*
   * Les trois conditions de `redeem_shop_item` tiennent-elles vraiment ensemble ?
   *
   * Ecrites en trois requetes depuis le serveur, deux demandes simultanees
   * passeraient toutes deux la verification de solde et debiteraient deux fois.
   * Les telephones reessaient quand le reseau coupe : ce n'est pas un cas
   * theorique, c'est le cas courant.
   */
  await db.exec(
    `select set_config('request.jwt.claim.sub', '${PARENT}', false);`,
  )

  const stockDepart = await un(
    `select stock from shop_items where id = 'lot_forfait_500mo'`,
  )
  attendu(
    Number(stockDepart.stock) === 100,
    `le semis devrait poser 100 exemplaires, il y en a ${stockDepart.stock}`,
  )

  // Sans points, l'echange est refuse — et c'est une REPONSE, pas une erreur :
  // l'ecran doit pouvoir dire « il vous manque X points ».
  const sansPoints = await un(
    `select redemption_id, reason from redeem_shop_item('lot_forfait_500mo')`,
  )
  attendu(
    sansPoints.redemption_id === null &&
      sansPoints.reason === 'NOT_ENOUGH_POINTS',
    `refus attendu, obtenu (${sansPoints.redemption_id}, ${sansPoints.reason})`,
  )

  const stockApresRefus = await un(
    `select stock from shop_items where id = 'lot_forfait_500mo'`,
  )
  attendu(
    Number(stockApresRefus.stock) === 100,
    'un refus ne doit pas toucher au stock',
  )

  // Avec de quoi payer : le debit, le stock et la demande en une seule fois.
  //
  // Le solde de depart est RELEVE, jamais suppose : ce compte porte deja les
  // ecritures de l'invariant precedent. Affirmer une valeur absolue ferait
  // echouer ce controle des qu'on ajoute une ligne ailleurs, pour une raison
  // qui n'aurait rien a voir avec l'echange.
  const avant = await un(
    `select coalesce(balance, 0) as solde from point_balances
      where owner_id = '${PARENT}'`,
  )
  const soldeAvant = Number(avant?.solde ?? 0)

  await db.exec(`
    insert into point_ledger (owner_id, delta, reason)
      values ('${PARENT}', 5000, 'Credit de controle');
  `)
  const echange = await un(
    `select redemption_id, reason from redeem_shop_item('lot_forfait_500mo')`,
  )
  attendu(
    echange.redemption_id !== null && echange.reason === null,
    `echange attendu, obtenu (${echange.redemption_id}, ${echange.reason})`,
  )

  const apres = await un(`
    select (select stock from shop_items where id = 'lot_forfait_500mo') as stock,
           (select balance from point_balances where owner_id = '${PARENT}') as solde,
           (select count(*) from redemptions where user_id = '${PARENT}') as demandes
  `)
  attendu(Number(apres.stock) === 99, `stock a ${apres.stock}, attendu 99`)
  // 5000 credites moins 4500 preleves : le prix vient de la base, jamais de
  // l'appelant.
  const attenduApres = soldeAvant + 5000 - 150
  attendu(
    Number(apres.solde) === attenduApres,
    `solde a ${apres.solde}, attendu ${attenduApres} (${soldeAvant} + 5000 - 150)`,
  )
  attendu(Number(apres.demandes) === 1, 'une demande devrait exister')

  // Le debit porte le nom du lot : un solde qui baisse sans raison lisible est
  // pire qu'un solde qui monte sans raison.
  const debit = await un(`
    select reason from point_ledger
     where owner_id = '${PARENT}' and delta < 0
     order by created_at desc limit 1
  `)
  attendu(
    String(debit.reason).includes('500 Mo'),
    `le debit dit « ${debit.reason} » et ne nomme pas le lot`,
  )

  // Et une deuxieme fois, sans solde suffisant : refus, stock intact.
  // Depenser jusqu'a ne plus pouvoir : le refus doit venir du solde, pas d'une
  // exception.
  for (let i = 0; i < 40; i += 1) {
    await db.query(`select redeem_shop_item('lot_forfait_500mo')`)
  }
  const encore = await un(
    `select reason from redeem_shop_item('lot_forfait_500mo')`,
  )
  attendu(
    encore.reason === 'NOT_ENOUGH_POINTS',
    `une fois le solde epuise : ${encore.reason}`,
  )

  const inconnu = await un(
    `select reason from redeem_shop_item('lot_inexistant')`,
  )
  attendu(inconnu.reason === 'UNKNOWN_ITEM', `lot inconnu : ${inconnu.reason}`)

  await db.exec(`select set_config('request.jwt.claim.sub', '', false);`)
})

await invariant('un tirage vend des chances, pas l’objet', async () => {
  /*
   * La difference qui justifie tout le mecanisme.
   *
   * Un achat direct decremente le stock : un exemplaire part. Une mise, non —
   * le stock compte les objets a gagner, pas les entrees vendues, et le
   * decrementer a chaque mise epuiserait le lot avant meme le tirage.
   *
   * Et miser plusieurs fois est permis : c'est ce qui rend le tirage
   * interessant, et chaque mise est une ligne, donc une chance.
   */
  await db.exec(
    `select set_config('request.jwt.claim.sub', '${PARENT}', false);`,
  )
  await db.exec(`
    insert into point_ledger (owner_id, delta, reason)
      values ('${PARENT}', 2000, 'Credit de controle (tirage)');
  `)

  const depart = await un(
    `select stock, kind from shop_items where id = 'lot_galaxy_a5'`,
  )
  attendu(depart.kind === 'RAFFLE', `le semis pose un tirage (${depart.kind})`)

  for (let i = 0; i < 3; i += 1) {
    const mise = await un(
      `select reason from redeem_shop_item('lot_galaxy_a5')`,
    )
    attendu(mise.reason === null, `mise ${i + 1} refusee : ${mise.reason}`)
  }

  const apres = await un(`
    select (select stock from shop_items where id = 'lot_galaxy_a5') as stock,
           (select count(*) from redemptions
             where item_id = 'lot_galaxy_a5' and kind = 'RAFFLE') as entrees
  `)
  attendu(
    Number(apres.stock) === Number(depart.stock),
    `une mise ne doit pas toucher au stock (${depart.stock} -> ${apres.stock})`,
  )
  attendu(Number(apres.entrees) === 3, `trois chances (${apres.entrees})`)

  // Le tirage tranche TOUTES les entrees : en laisser en attente ferait croire
  // que le tirage n'a pas eu lieu.
  const tire = await un(`select winner, entries from draw_raffle('lot_galaxy_a5')`)
  attendu(tire.winner != null, 'un gagnant est tire')
  attendu(Number(tire.entries) === 3, `sur trois entrees (${tire.entries})`)

  const restes = await un(`
    select count(*) as n from redemptions
     where item_id = 'lot_galaxy_a5' and kind = 'RAFFLE' and status = 'PENDING'
  `)
  attendu(Number(restes.n) === 0, `${restes.n} entree(s) laissees en attente`)

  await db.exec(`select set_config('request.jwt.claim.sub', '', false);`)
})

await invariant('on n’offre pas plus de deux points par jour', async () => {
  /*
   * Le plafond, et la raison du chiffre.
   *
   * Le plan en prevoyait dix. Une seance suivie en rapporte 18 : a dix par
   * jour, quatre comptes complices concentrent leur monnaie vers un seul en
   * quelques jours, et la boutique recompense qui a le plus d'amis plutot que
   * qui a le plus suivi.
   *
   * Le plafond se verifie dans la meme instruction que l'ecriture, sinon deux
   * dons simultanes passeraient tous les deux.
   */
  const DONNEUR = '66666666-6666-6666-6666-666666666666'
  const RECEVEUR = '77777777-7777-7777-7777-777777777777'

  await db.exec(`
    insert into auth.users (id) values ('${DONNEUR}'), ('${RECEVEUR}');
    insert into profiles (id, role, phone, first_name) values
      ('${DONNEUR}',  'STUDENT', '+224600000906', 'Aissatou'),
      ('${RECEVEUR}', 'STUDENT', '+224600000907', 'Ousmane');
    select set_config('request.jwt.claim.sub', '${DONNEUR}', false);
  `)

  const premier = await un(`select ok, reason from offrir_points('${RECEVEUR}', 2)`)
  attendu(premier.ok === true, `premier don refuse : ${premier.reason}`)

  // Les deux ecritures existent, et se rapprochent par la meme reference.
  const paire = await un(`
    select count(*)::int as n, count(distinct reference)::int as liens
      from point_ledger where reference like 'gift:%'
  `)
  attendu(
    Number(paire.n) === 2 && Number(paire.liens) === 1,
    `un transfert = deux lignes liees (${paire.n} lignes, ${paire.liens} lien)`,
  )

  const trop = await un(`select ok, reason from offrir_points('${RECEVEUR}', 1)`)
  attendu(
    trop.ok === false && trop.reason === 'DAILY_LIMIT',
    `le plafond du jour devrait fermer : ${trop.reason}`,
  )

  // S'offrir a soi-meme : refuse, et pour une raison nommee.
  const soi = await un(`select reason from offrir_points('${DONNEUR}', 1)`)
  attendu(soi.reason === 'SELF_GIFT', `don a soi-meme : ${soi.reason}`)

  // Le receveur a bien recu, et sait de qui.
  const recu = await un(`
    select reason from point_ledger
     where owner_id = '${RECEVEUR}' and delta > 0 and reference like 'gift:%'
     order by created_at desc limit 1
  `)
  attendu(
    String(recu.reason).includes('Aissatou'),
    `le credit devrait nommer le donneur : « ${recu.reason} »`,
  )

  await db.exec(`select set_config('request.jwt.claim.sub', '', false);`)
})

await invariant('un groupe n’admet que ceux que la relation lie', async () => {
  /*
   * La règle de sécurité de cette fonction, éprouvée à l'exécution.
   *
   * L'appartenance à un groupe est **dérivée** et non stockée : elle se
   * recalcule depuis la relation (un cours en direct, un contrat). Tout le
   * cloisonnement tient donc dans `est_membre_groupe`, et une erreur dedans
   * ouvre la porte d'un groupe d'adolescents. Ce contrôle vérifie les trois
   * cas qui comptent : le professeur entre, l'inscrit payé entre, l'étranger
   * reste dehors.
   */
  const PROF = '88888888-8888-8888-8888-888888888888'
  const INSCRIT = '99999999-9999-9999-9999-999999999999'
  const ETRANGER = 'aaaaaaaa-0000-4000-8000-aaaaaaaaaaaa'

  await db.exec(`
    insert into auth.users (id) values ('${PROF}'), ('${INSCRIT}'), ('${ETRANGER}');
    insert into profiles (id, role, phone, first_name) values
      ('${PROF}',     'TEACHER', '+224600000910', 'Mamadou'),
      ('${INSCRIT}',  'PARENT',  '+224600000911', 'Kadiatou'),
      ('${ETRANGER}', 'PARENT',  '+224600000912', 'Sekou');

    insert into teachers (id, user_id) values ('t_grp', '${PROF}');
    insert into parents (id, user_id) values
      ('p_grp', '${INSCRIT}'), ('p_hors', '${ETRANGER}');

    insert into live_courses (id, teacher_id, subject_id, level_id, price, status)
      select 'lc_grp', 't_grp', s.id, l.id, 20000, 'PUBLISHED'
        from subjects s, levels l limit 1;
    insert into live_sessions (id, live_course_id, slot_id, starts_at)
      values ('ls_grp', 'lc_grp', 'slot_x', now() + interval '1 day');

    insert into chat_groups (id, kind, source_id, name)
      values ('g_grp', 'COURSE', 'lc_grp', 'Maths Terminale');
  `)

  // Le professeur du cours : membre.
  let r = await un(`select est_membre_groupe('g_grp', '${PROF}') as ok`)
  attendu(r.ok === true, 'le professeur du cours devrait être membre')

  // Une place encore impayée ne donne pas accès.
  await db.exec(`
    insert into session_enrolments (id, session_id, parent_id, status)
      values ('se_grp', 'ls_grp', 'p_grp', 'PENDING');
  `)
  r = await un(`select est_membre_groupe('g_grp', '${INSCRIT}') as ok`)
  attendu(
    r.ok === false,
    'une place PENDING ne devrait pas ouvrir le groupe : le flux est le ' +
      'produit vendu',
  )

  // Payée, elle l'ouvre.
  await db.exec(
    `update session_enrolments set status = 'CONFIRMED' where id = 'se_grp';`,
  )
  r = await un(`select est_membre_groupe('g_grp', '${INSCRIT}') as ok`)
  attendu(r.ok === true, 'une place CONFIRMED devrait ouvrir le groupe')

  // Un compte sans lien : dehors.
  r = await un(`select est_membre_groupe('g_grp', '${ETRANGER}') as ok`)
  attendu(r.ok === false, 'un compte sans place ne devrait pas être membre')

  /*
   * Ce banc d'essai ne dit **pas** que la politique ferme.
   *
   * Il execute tout sous un role proprietaire, pour qui RLS ne s'applique pas
   * — c'est la limite annoncee en fin de ce fichier. Une assertion « un
   * etranger ne lit pas la table » passerait donc au vert ici pour une raison
   * qui n'a rien a voir avec la politique, ou echouerait en la croyant
   * cassee ; c'est ce qui est arrive en l'ecrivant.
   *
   * Ce qui est verifie ici est la **regle** — `est_membre_groupe` —, et c'est
   * elle que les deux politiques appellent. Que la politique soit bien posee
   * et bien appliquee releve de `npm run check:rls`, avec deux comptes reels
   * et leurs jetons.
   */

  // L'annulation de la place referme la porte — sans qu'aucune ligne de
  // membre n'ait eu besoin d'être retirée. C'est tout l'intérêt du calcul.
  await db.exec(
    `update session_enrolments set status = 'CANCELLED' where id = 'se_grp';`,
  )
  r = await un(`select est_membre_groupe('g_grp', '${INSCRIT}') as ok`)
  attendu(
    r.ok === false,
    'une place annulée devrait refermer le groupe d’elle-même',
  )
})

await invariant('auth.uid() rend null sans session, et l’identifiant avec', async () => {
  const anonyme = await un(`select auth.uid() is null as vide`)
  attendu(anonyme.vide === true, 'auth.uid() devrait être nul sans réglage')
  const avec = await un(`
    select set_config(
      'request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', false
    ) is not null as pose
  `)
  attendu(avec.pose === true, 'le réglage de session n’a pas pu être posé')
  const lu = await un(`select auth.uid()::text as id`)
  attendu(
    lu.id === '11111111-1111-1111-1111-111111111111',
    `auth.uid() a rendu ${lu.id}`,
  )
})

await db.close()

console.log('')
if (problemes.length > 0) {
  console.error('Problèmes :')
  for (const probleme of problemes) console.error(`  - ${probleme}`)
  console.error('')
  process.exit(1)
}

console.log(
  `Les ${migrations.length} migrations s’exécutent d’un bloc sur Postgres, et les\n` +
    'invariants vérifiés à l’exécution tiennent.',
)
console.log(
  '\nCe contrôle ne dit pas qu’une politique ferme bien ce qu’elle doit fermer :\n' +
    'ici `auth.uid()` est une valeur de session posée par le banc d’essai, pas une\n' +
    'revendication extraite d’un JWT. Voir supabase/harness/00_supabase_shim.sql.\n' +
    '\nC’est `npm run check:rls` qui l’éprouve, avec deux comptes réels et leurs\n' +
    'jetons, sur le projet Supabase en service.',
)
