#!/usr/bin/env node
/**
 * Compare le schema local de l'application au schema Postgres du serveur.
 *
 * Pourquoi ce controle existe : au 24/09, vingt-cinq des quarante-cinq tables
 * de l'application n'avaient aucun equivalent serveur. Rien ne le signalait —
 * l'application fonctionne entierement hors ligne, donc tout marchait sur le
 * telephone pendant que le serveur etait incapable de recevoir la moitie de
 * ce qu'elle produit. On ne l'aurait decouvert qu'au premier deploiement.
 *
 * Les deux schemas partagent leurs noms de tables et de colonnes a dessein :
 * la synchronisation est une correspondance directe, sans table de
 * transcodage (§44). Ce controle verifie que cette promesse tient encore.
 *
 * Usage : npm run check:schema
 *         npm run check:schema -- --json   (pour l'integration continue)
 */

import { readFileSync, readdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ici = dirname(fileURLToPath(import.meta.url))
const racine = join(ici, '..', '..')
const TABLES_DART = join(
  racine,
  'frontend/mobile/lib/data/local/database/tables.dart',
)
const MIGRATIONS = join(ici, '..', 'supabase', 'migrations')

/**
 * Tables qui n'ont volontairement pas d'equivalent serveur.
 *
 * Chacune porte sa raison : une exception sans motif finit par servir de
 * tapis sous lequel on glisse les oublis.
 */
const LOCALES = new Map([
  ['app_meta', 'cle-valeur du telephone : curseur de synchro, preferences'],
  ['sync_queue', 'file d’envoi locale — c’est elle qui alimente le serveur'],
  ['audit_logs', 'journal local ; le serveur a sa table audit_events'],
])

/** Correspondances de nom entre les deux cotes. */
const ALIAS = new Map([
  // L'authentification vit dans `auth.users` de Supabase ; les donnees
  // metier sont dans `profiles`.
  ['users', 'profiles'],
])

const enSnake = (nom) =>
  nom.replace(/(?<!^)(?=[A-Z])/g, '_').toLowerCase()

function tablesDeLApplication() {
  const source = readFileSync(TABLES_DART, 'utf8')
  const trouvees = new Set()
  for (const m of source.matchAll(/class\s+(\w+)\s+extends\s+Table/g)) {
    trouvees.add(enSnake(m[1]))
  }
  return trouvees
}

const nomNu = (brut) => brut.replaceAll('"', '').split('.').pop()

/**
 * Le schema tel qu'il est APRES la derniere migration.
 *
 * Les fichiers sont rejoues dans l'ordre, creations et suppressions
 * comprises. Ne lire que les `create table` laissait une table supprimee
 * dans la liste pour toujours : le compte restait juste par hasard tant
 * qu'une table manquait des deux cotes, et la comparaison ne voulait plus
 * rien dire. C'est arrive avec `credit_ledger`, retire en 0008.
 */
function tablesDuServeur() {
  const trouvees = new Set()
  for (const fichier of readdirSync(MIGRATIONS).sort()) {
    if (!fichier.endsWith('.sql')) continue
    const sql = readFileSync(join(MIGRATIONS, fichier), 'utf8')
    for (const m of sql.matchAll(
      /(create|drop)\s+table\s+(?:if\s+(?:not\s+)?exists\s+)?([a-z_."]+)/gi,
    )) {
      const nom = nomNu(m[2])
      if (m[1].toLowerCase() === 'drop') trouvees.delete(nom)
      else trouvees.add(nom)
    }
  }
  return trouvees
}

const application = tablesDeLApplication()
const serveur = tablesDuServeur()

const attendues = [...application]
  .filter((t) => !LOCALES.has(t))
  .map((t) => ALIAS.get(t) ?? t)

const manquantes = attendues.filter((t) => !serveur.has(t)).sort()

if (process.argv.includes('--json')) {
  console.log(JSON.stringify({ manquantes, application: application.size, serveur: serveur.size }, null, 2))
} else {
  console.log(`Application : ${application.size} tables`)
  console.log(`Serveur     : ${serveur.size} tables`)
  console.log(`Locales par dessein : ${LOCALES.size}`)
  if (manquantes.length === 0) {
    console.log('\nLes deux schemas concordent.')
  } else {
    console.log(`\n${manquantes.length} table(s) sans equivalent serveur :`)
    for (const t of manquantes) console.log('  -', t)
    console.log(
      '\nUne table absente cote serveur ne provoque aucune erreur visible :',
    )
    console.log(
      "l'application continue de fonctionner hors ligne, et la synchronisation",
    )
    console.log('rejette silencieusement ce qu’elle ne sait pas ranger.')
  }
}

process.exit(manquantes.length === 0 ? 0 : 1)
