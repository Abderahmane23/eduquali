/**
 * Assemble `eduquali_schema.sql` a la racine du depot.
 *
 * Pourquoi un fichier genere et non ecrit a la main : les onze migrations sont
 * la verite — `check-schema.mjs` les compare au schema Drift du telephone, et
 * `check-sql.mjs` les relit instruction par instruction. Une copie saisie a la
 * main serait une douzieme source, qui divergerait a la premiere migration
 * suivante sans que rien ne le dise.
 *
 * Le fichier produit sert a **une seule chose** : etre colle dans l'editeur SQL
 * d'un projet Supabase neuf. Pour un projet deja en service, on applique la
 * migration manquante, jamais ce fichier entier.
 *
 * Usage : node scripts/build-schema-file.mjs
 */

import { readFileSync, writeFileSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const migrations = join(here, '..', 'supabase', 'migrations')
const racine = join(here, '..', '..')
const sortie = join(racine, 'eduquali_schema.sql')

const fichiers = readdirSync(migrations)
  .filter((f) => f.endsWith('.sql'))
  .sort()

if (fichiers.length === 0) {
  console.error('Aucune migration trouvee.')
  process.exit(1)
}

const aujourdhui = new Date().toISOString().slice(0, 10)

const entete = `-- =====================================================================
-- Eduquali — schema complet pour un projet Supabase NEUF
-- =====================================================================
--
-- Genere le ${aujourdhui} par \`node backend/scripts/build-schema-file.mjs\`.
-- NE PAS MODIFIER CE FICHIER : il est reecrit a chaque appel du script. La
-- verite vit dans \`backend/supabase/migrations/\`, que deux controles
-- verifient (\`npm run check\` dans \`backend/\`).
--
-- --- Ce qu'il fait ----------------------------------------------------------
--
-- Les ${fichiers.length} migrations, dans l'ordre. Certaines defont ce que les
-- precedentes ont fait — la 0008 retire le systeme de credits que la 0006
-- avait pose. C'est voulu : rejouer l'histoire donne exactement l'etat que les
-- deux controles valident, alors qu'un schema « nettoye » serait une version
-- que personne ne verifie.
--
-- --- Comment l'appliquer ----------------------------------------------------
--
-- Projet NEUF uniquement :
--   Supabase > SQL Editor > New query > coller ce fichier > Run.
--
-- Projet DEJA EN SERVICE : ne pas coller ceci. Appliquer seulement la
-- migration manquante, depuis \`backend/supabase/migrations/\`.
--
-- Puis, dans l'ordre :
--   1. \`backend/supabase/seed.sql\`            — matieres, niveaux, tests
--   2. \`backend/supabase/seed_demo_teachers.sql\` — donnees de demonstration
--      (a NE PAS charger sur une base destinee a de vrais comptes : elle
--      nomme des etablissements reels avec des offres inventees)
--
-- --- Ce qu'il ne fait pas ---------------------------------------------------
--
-- Il ne touche pas a \`auth\`. L'authentification reste celle de Supabase ;
-- \`profiles.id\` reference \`auth.users (id)\`, donc un compte metier n'existe
-- qu'en prolongement d'un compte d'authentification.
--
-- Il n'ouvre aucune donnee : chaque table est en RLS. **La cle anonyme est
-- publique par construction** — elle part dans le bundle du site — donc RLS
-- est la seule barriere. La cle \`service_role\` ne doit jamais quitter
-- \`backend/.env\`.
--
-- =====================================================================

`

/*
 * Tout ou rien.
 *
 * Le fichier n'etait pas transactionnel : une erreur a la 2000e ligne laissait
 * la base a moitie construite, et la reprise etait penible — 59 des
 * `create table` n'ont pas de `if not exists`, donc rejouer echouait sur ceux qui
 * etaient passes. Il fallait alors supprimer le projet Supabase et recommencer.
 *
 * Le DDL de Postgres est transactionnel, et aucune instruction de ces migrations
 * ne l'empeche (ni `create index concurrently`, ni `vacuum`, ni `alter system` —
 * un controle le verifie ci-dessous). Les envelopper rend l'application atomique :
 * soit le schema entier est la, soit la base est intacte.
 */
const NON_TRANSACTIONNEL = /\b(create\s+index\s+concurrently|vacuum|create\s+database|alter\s+system|reindex)\b/i

const morceaux = [
  entete,
  '',
  '-- Tout ou rien : une erreur en cours de route ne doit pas laisser la base a',
  '-- moitie construite. Le DDL de Postgres est transactionnel.',
  'begin;',
]

for (const fichier of fichiers) {
  const contenu = readFileSync(join(migrations, fichier), 'utf8').trim()

  /*
   * Une instruction non transactionnelle casserait l'enveloppe.
   *
   * Mieux vaut refuser de generer le fichier que d'en produire un qui echoue a
   * la premiere ligne chez Supabase, avec un message qui ne nomme pas la cause.
   */
  if (NON_TRANSACTIONNEL.test(contenu)) {
    console.error(
      `\n${fichier} contient une instruction qui ne peut pas tourner dans une\n` +
        'transaction (create index concurrently, vacuum, alter system...).\n' +
        'Le fichier assemble ne peut donc plus etre atomique : sortir cette\n' +
        'instruction dans un fichier a part, ou retirer l\'enveloppe begin/commit.\n',
    )
    process.exit(1)
  }

  morceaux.push(
    [
      '',
      '-- ---------------------------------------------------------------------',
      `-- ${fichier}`,
      '-- ---------------------------------------------------------------------',
      '',
      contenu,
      '',
    ].join('\n'),
  )
}

morceaux.push('', 'commit;', '')

const texte = morceaux.join('\n')
writeFileSync(sortie, texte, 'utf8')

const lignes = texte.split('\n').length
console.log(`eduquali_schema.sql : ${fichiers.length} migrations, ${lignes} lignes`)
for (const f of fichiers) console.log(`  ${f}`)
