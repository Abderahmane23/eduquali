#!/usr/bin/env node
/**
 * Les migrations du dépôt, et celles posées sur la base.
 *
 * --- Pourquoi ce fichier existe -------------------------------------------
 *
 * Le 17/10, deux migrations écrites le jour même (`0032_operations.sql`,
 * `0033_ecoles_connues.sql`) n'étaient pas appliquées, et rien ne le disait.
 * L'autocomplétion des écoles appelait une vue qui n'existait pas ; elle
 * rendait une liste vide, le champ continuait d'accepter la saisie libre, et
 * l'écran avait l'air de marcher.
 *
 * La base ne tenait aucune trace de ce qui lui avait été appliqué : 34
 * fichiers au dépôt, et aucun moyen de savoir lesquels étaient posés. Ce
 * script crée cette trace, puis s'en sert.
 *
 * --- Ce qu'il fait --------------------------------------------------------
 *
 *   node scripts/migrations.mjs                 dit l'écart, ne touche à rien
 *   node scripts/migrations.mjs --baseline=0031 déclare 0001..0031 déjà posées
 *   node scripts/migrations.mjs --appliquer     applique ce qui manque
 *
 * Le mode par défaut est en lecture seule, et c'est volontaire : une commande
 * qui modifie la base de production ne doit pas être celle qu'on tape pour
 * voir où on en est.
 *
 * --- Le jeton -------------------------------------------------------------
 *
 * Un **jeton d'accès personnel** Supabase (supabase.com/dashboard/account/
 * tokens), pas la clé `service_role` : celle-ci ouvre les données mais ne
 * permet pas de modifier le schéma. Lu dans, par ordre de préférence :
 *
 *   ~/.eduquali/supabase.env     hors du dépôt, comme le keystore Android
 *   backend/.env                 ignoré par git, mais dans l'arborescence
 *
 * Deux lignes :
 *
 *   SUPABASE_ACCESS_TOKEN=sbp_...
 *   SUPABASE_PROJECT_REF=shsjcatuqfnwsmbujkfc
 */

import { createHash } from 'node:crypto'
import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const RACINE = join(dirname(fileURLToPath(import.meta.url)), '..')
const DOSSIER = join(RACINE, 'backend', 'supabase', 'migrations')

/** Lit un fichier de type `.env` sans écraser l'environnement existant. */
function charger(chemin) {
  if (!existsSync(chemin)) return {}
  const valeurs = {}
  for (const ligne of readFileSync(chemin, 'utf-8').split('\n')) {
    const trouve = /^\s*([A-Z0-9_]+)\s*=\s*(.*)$/.exec(ligne)
    if (!trouve) continue
    valeurs[trouve[1]] = trouve[2].trim().replace(/^["']|["']$/g, '')
  }
  return valeurs
}

const secrets = {
  ...charger(join(RACINE, 'backend', '.env')),
  // Le fichier hors du dépôt a le dernier mot : c'est le plus sûr des deux.
  ...charger(join(homedir(), '.eduquali', 'supabase.env')),
  ...process.env,
}

const JETON = secrets.SUPABASE_ACCESS_TOKEN
const PROJET =
  secrets.SUPABASE_PROJECT_REF
  ?? (secrets.SUPABASE_URL ?? '').match(/https:\/\/([a-z0-9]+)\.supabase/)?.[1]

/**
 * Exécute du SQL par l'API de gestion.
 *
 * On passe par là et non par `psql`, absent de ce poste, ni par la clé
 * `service_role`, qui ne permet pas le DDL.
 */
async function sql(requete) {
  const reponse = await fetch(
    `https://api.supabase.com/v1/projects/${PROJET}/database/query`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${JETON}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ query: requete }),
    },
  )
  const texte = await reponse.text()
  if (!reponse.ok) {
    throw new Error(`${reponse.status} — ${texte.slice(0, 400)}`)
  }
  return texte ? JSON.parse(texte) : []
}

const empreinte = (contenu) =>
  createHash('sha256').update(contenu).digest('hex').slice(0, 16)

/** Les fichiers du dépôt, dans l'ordre de leur numéro. */
function auDepot() {
  return readdirSync(DOSSIER)
    .filter((nom) => nom.endsWith('.sql'))
    .sort()
    .map((nom) => ({
      nom,
      numero: nom.slice(0, 4),
      contenu: readFileSync(join(DOSSIER, nom), 'utf-8'),
    }))
}

const TRACE = `
  create table if not exists migrations_appliquees (
    nom          text primary key,
    empreinte    text not null,
    appliquee_le timestamptz not null default now()
  );
  comment on table migrations_appliquees is
    'Ce qui a ete applique a cette base. Ecrite par scripts/migrations.mjs.';
`

async function main() {
  const arguments_ = process.argv.slice(2)
  const appliquer = arguments_.includes('--appliquer')
  const baseline = arguments_
    .find((a) => a.startsWith('--baseline='))
    ?.split('=')[1]

  const fichiers = auDepot()
  console.log(`${fichiers.length} migrations au dépôt`)

  if (!JETON || !PROJET) {
    console.log()
    console.log('Jeton absent : on ne peut que lister le dépôt.')
    console.log()
    console.log('Créez ~/.eduquali/supabase.env avec deux lignes :')
    console.log('  SUPABASE_ACCESS_TOKEN=sbp_...   (jeton d’accès personnel)')
    console.log('  SUPABASE_PROJECT_REF=...        (la référence du projet)')
    console.log()
    console.log('Le jeton se crée sur supabase.com/dashboard/account/tokens.')
    console.log('Ce n’est pas la clé service_role : celle-ci ouvre les')
    console.log('données mais ne permet pas de modifier le schéma.')
    process.exitCode = 2
    return
  }

  await sql(TRACE)

  if (baseline) {
    /*
     * Déclarer un socle sans rien exécuter.
     *
     * Les premières migrations sont posées depuis longtemps — l'application
     * fonctionne — mais la base n'en garde aucune trace. Les rejouer serait
     * au mieux inutile, au pire destructeur. On les déclare donc, une fois.
     */
     const socle = fichiers.filter((f) => f.numero <= baseline)
     for (const f of socle) {
       await sql(
         `insert into migrations_appliquees (nom, empreinte)
            values ('${f.nom}', '${empreinte(f.contenu)}')
          on conflict (nom) do nothing;`,
       )
     }
     console.log(`socle déclaré : ${socle.length} migrations jusqu'à ${baseline}`)
  }

  const posees = await sql('select nom, empreinte from migrations_appliquees;')
  const connues = new Map(posees.map((r) => [r.nom, r.empreinte]))

  const manquantes = fichiers.filter((f) => !connues.has(f.nom))

  /*
   * Une migration déjà appliquée dont le contenu a changé.
   *
   * C'est une erreur de méthode, pas un retard : la base porte une version,
   * le dépôt une autre, et aucune des deux ne sait laquelle. Elle se signale
   * et ne se corrige pas automatiquement.
   */
  const modifiees = fichiers.filter(
    (f) => connues.has(f.nom) && connues.get(f.nom) !== empreinte(f.contenu),
  )

  console.log(`${connues.size} appliquées, ${manquantes.length} manquantes`)

  for (const f of modifiees) {
    console.log(`  MODIFIÉE APRÈS COUP : ${f.nom}`)
  }

  if (manquantes.length === 0) {
    console.log('La base est à jour avec le dépôt.')
    if (modifiees.length > 0) process.exitCode = 1
    return
  }

  for (const f of manquantes) {
    console.log(`  manque : ${f.nom}`)
  }

  if (!appliquer) {
    console.log()
    console.log('Rien n’a été modifié. Pour appliquer :')
    console.log('  node scripts/migrations.mjs --appliquer')
    process.exitCode = 1
    return
  }

  for (const f of manquantes) {
    process.stdout.write(`applique ${f.nom} ... `)
    try {
      await sql(f.contenu)
      await sql(
        `insert into migrations_appliquees (nom, empreinte)
           values ('${f.nom}', '${empreinte(f.contenu)}');`,
      )
      console.log('fait')
    } catch (souci) {
      console.log('ÉCHEC')
      console.error(String(souci.message ?? souci))
      // On s'arrête à la première : les suivantes supposent celle-ci posée,
      // et enchaîner produirait une base dans un état qu'aucun fichier ne
      // décrit.
      process.exitCode = 1
      return
    }
  }
}

main().catch((souci) => {
  console.error(String(souci.message ?? souci))
  process.exitCode = 1
})
