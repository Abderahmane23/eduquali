/**
 * Relit `eduquali_schema.sql` en cherchant ce qui casserait a l'execution.
 *
 * Different de `check-sql.mjs`, qui verifie chaque migration isolement. Ici le
 * fichier est joue **en une fois sur une base vide**, et c'est la que les
 * conflits entre migrations apparaissent : deux tables du meme nom, deux
 * politiques du meme nom sur la meme table, une cle etrangere vers une table
 * creee plus bas.
 *
 * --- Pourquoi un vrai analyseur lexical et non des expressions regulieres ---
 *
 * La premiere version de ce script nettoyait les chaines avec
 * `/'(?:[^']|'')*'/g`. Resultat : elle avalait les deux tiers du fichier — 49
 * tables devenaient 22, 81 politiques devenaient 23 — et annonçait « rien a
 * signaler » parce qu'elle ne voyait plus rien. Un controle aveugle est pire
 * qu'aucun controle : il rassure.
 *
 * SQL ne se lexe pas avec une expression reguliere. Les chaines s'echappent en
 * doublant l'apostrophe, les corps de fonction sont delimites par des
 * etiquettes a dollars imbricables (`$$`, `$f$`), et un seul desequilibre fait
 * glisser toutes les correspondances suivantes. Trente lignes de parcours
 * caractere par caractere sont justes ; une expression reguliere ne l'est pas.
 *
 * Il ne remplace pas un vrai Postgres. Il attrape la classe d'erreurs qui
 * ferait echouer le collage a la ligne 1 400, apres avoir cree la moitie du
 * schema.
 *
 * Usage : node scripts/check-schema-file.mjs
 */

import { readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const fichier = join(here, '..', '..', 'eduquali_schema.sql')
const brut = readFileSync(fichier, 'utf8')

/**
 * Remplace commentaires, chaines et corps de fonction par des blancs.
 *
 * Les positions sont conservees — chaque caractere retire laisse un espace —
 * pour que les numeros de ligne signales correspondent au fichier.
 */
function nettoyer(source) {
  const sortie = Array.from(source)
  /** Les corps delimites par une etiquette a dollars, tels qu'ils etaient. */
  const corps = []
  const blanchir = (debut, fin) => {
    for (let k = debut; k < fin && k < sortie.length; k++) {
      if (sortie[k] !== '\n') sortie[k] = ' '
    }
  }

  let i = 0
  while (i < source.length) {
    // Commentaire de ligne.
    if (source.startsWith('--', i)) {
      const fin = source.indexOf('\n', i)
      blanchir(i, fin < 0 ? source.length : fin)
      i = fin < 0 ? source.length : fin
      continue
    }
    // Commentaire de bloc.
    if (source.startsWith('/*', i)) {
      const fin = source.indexOf('*/', i + 2)
      const stop = fin < 0 ? source.length : fin + 2
      blanchir(i, stop)
      i = stop
      continue
    }
    // Identifiant entre guillemets : son contenu est garde — c'est le nom
    // d'une politique, et c'est precisement ce qu'on veut comparer. On le
    // traverse sans l'interpreter, parce qu'une apostrophe y est litterale :
    // « "candidatures : depot par l'enseignant" ». Sans ce cas, cette
    // apostrophe ouvrait une fausse chaine qui blanchissait les neuf
    // instructions suivantes, et le rapport annonçait tout va bien.
    if (source[i] === '"') {
      let j = i + 1
      while (j < source.length) {
        if (source[j] === '"') {
          if (source[j + 1] === '"') {
            j += 2
            continue
          }
          break
        }
        j++
      }
      i = j + 1
      continue
    }
    // Chaine : l'apostrophe se double pour s'echapper.
    if (source[i] === "'") {
      let j = i + 1
      while (j < source.length) {
        if (source[j] === "'") {
          if (source[j + 1] === "'") {
            j += 2
            continue
          }
          break
        }
        j++
      }
      blanchir(i + 1, j)
      i = j + 1
      continue
    }
    // Corps delimite par une etiquette a dollars : $$, $f$, $body$…
    const dollar = /^\$([a-z_0-9]*)\$/i.exec(source.slice(i, i + 32))
    if (dollar) {
      const marque = dollar[0]
      const fin = source.indexOf(marque, i + marque.length)
      const stop = fin < 0 ? source.length : fin + marque.length
      corps.push(source.slice(i, stop))
      blanchir(i, stop)
      i = stop
      continue
    }
    i++
  }
  return { sql: sortie.join(''), corps }
}

const { sql, corps } = nettoyer(brut)

/**
 * Les corps de fonction et les boucles `do $$ … $$`.
 *
 * Trois migrations y posent des politiques par `format()` sur une liste de
 * tables. Ce ne sont pas des instructions litterales : elles n'existent qu'a
 * l'execution, et **ce script ne peut donc pas y chercher de doublons**. C'est
 * une limite, pas un oubli — la dire vaut mieux que de laisser croire a une
 * couverture complete.
 */
const dansLesCorps = corps.join('\n')
const ligneDe = (position) => brut.slice(0, position).split('\n').length

const problemes = []
const avertissements = []

// --- Objets crees deux fois ------------------------------------------------

function doublons(motif, etiquette, cle = (m) => m[1].toLowerCase()) {
  const vus = new Map()
  for (const m of sql.matchAll(motif)) {
    const k = cle(m)
    const lignes = vus.get(k) ?? []
    lignes.push(ligneDe(m.index))
    vus.set(k, lignes)
  }
  for (const [k, lignes] of vus) {
    if (lignes.length > 1) {
      problemes.push(`${etiquette} ${k} : cree ${lignes.length} fois (lignes ${lignes.join(', ')})`)
    }
  }
}

doublons(/\bcreate\s+table\s+(?!if\s+not\s+exists)([a-z_0-9.]+)/gi, 'table')
doublons(
  /\bcreate\s+policy\s+"([^"]+)"\s+on\s+([a-z_0-9.]+)/gi,
  'politique',
  (m) => `"${m[1]}" sur ${m[2].toLowerCase()}`,
)
doublons(/\bcreate\s+index\s+(?!if\s+not\s+exists)([a-z_0-9]+)/gi, 'index')
doublons(
  /\bcreate\s+unique\s+index\s+(?!if\s+not\s+exists)([a-z_0-9]+)/gi,
  'index unique',
)
doublons(/\bcreate\s+view\s+(?!or\s+replace)([a-z_0-9]+)/gi, 'vue')
doublons(/\bcreate\s+function\s+([a-z_0-9]+)/gi, 'fonction (sans or replace)')
doublons(/\bcreate\s+trigger\s+([a-z_0-9]+)/gi, 'declencheur')

// --- Tables referencees avant d'exister -----------------------------------

const creationDe = new Map()
for (const m of sql.matchAll(
  /\bcreate\s+table\s+(?:if\s+not\s+exists\s+)?([a-z_0-9.]+)/gi,
)) {
  const nom = m[1].toLowerCase()
  if (!creationDe.has(nom)) creationDe.set(nom, m.index)
}

for (const m of sql.matchAll(/\breferences\s+([a-z_0-9.]+)/gi)) {
  const cible = m[1].toLowerCase()
  // `auth.users` est fourni par Supabase.
  if (cible === 'auth.users') continue
  const creeeA = creationDe.get(cible)
  if (creeeA === undefined) {
    problemes.push(
      `ligne ${ligneDe(m.index)} : reference vers ${cible}, jamais creee`,
    )
  } else if (creeeA > m.index) {
    problemes.push(
      `ligne ${ligneDe(m.index)} : reference vers ${cible} avant sa creation ` +
        `(ligne ${ligneDe(creeeA)})`,
    )
  }
}

// --- `alter table` sur une table absente ----------------------------------

for (const m of sql.matchAll(/\balter\s+table\s+([a-z_0-9.]+)/gi)) {
  const cible = m[1].toLowerCase()
  const creeeA = creationDe.get(cible)
  if (creeeA === undefined) {
    problemes.push(
      `ligne ${ligneDe(m.index)} : alter table ${cible}, jamais creee`,
    )
  } else if (creeeA > m.index) {
    problemes.push(
      `ligne ${ligneDe(m.index)} : alter table ${cible} avant sa creation`,
    )
  }
}

// --- Politiques sur une table dont RLS n'est pas active -------------------
//
// Une politique sans RLS active ne s'applique pas : la table reste
// entierement lisible. Postgres ne previent pas.

const rlsActivee = new Set()
for (const m of sql.matchAll(
  /\balter\s+table\s+([a-z_0-9.]+)\s+enable\s+row\s+level\s+security/gi,
)) {
  rlsActivee.add(m[1].toLowerCase())
}
// Les boucles `do $$ … foreach t in array[…] … %1$I … $$` activent RLS sur des
// tables nommees dans une liste : leur corps a ete blanchi, donc on relit le
// fichier brut pour ces listes.
for (const m of brut.matchAll(/enable\s+row\s+level\s+security/gi)) {
  const avant = brut.slice(Math.max(0, m.index - 1200), m.index)
  for (const t of avant.matchAll(/'([a-z_0-9]+)'/g)) rlsActivee.add(t[1])
}

const tablesAvecPolitique = new Set()
for (const m of sql.matchAll(/\bcreate\s+policy\s+"[^"]+"\s+on\s+([a-z_0-9.]+)/gi)) {
  tablesAvecPolitique.add(m[1].toLowerCase())
}
for (const t of tablesAvecPolitique) {
  if (!rlsActivee.has(t)) {
    avertissements.push(
      `${t} porte des politiques — verifier que RLS y est active, sinon elles ` +
        'ne protegent rien',
    )
  }
}

// --- Rattachement a l'authentification ------------------------------------

if (!/references\s+auth\.users/i.test(sql)) {
  problemes.push(
    'aucune reference a auth.users : le schema ne serait pas rattache a ' +
      "l'authentification de Supabase",
  )
}

// --- Equilibre des parentheses --------------------------------------------

const ouvrantes = (sql.match(/\(/g) ?? []).length
const fermantes = (sql.match(/\)/g) ?? []).length
if (ouvrantes !== fermantes) {
  problemes.push(
    `parentheses desequilibrees : ${ouvrantes} ouvrantes pour ${fermantes} fermantes`,
  )
}

// --- Garde-fou sur l'analyseur lui-meme -----------------------------------
//
// La version precedente de ce script annonçait « rien a signaler » en ayant
// avale les deux tiers du fichier. On compare donc ce qu'on voit a ce que le
// texte brut contient : un ecart signifie que l'analyse est aveugle, et c'est
// un echec, pas un detail.

const compte = (texte, motif) => (texte.match(motif) ?? []).length
for (const [etiquette, motif] of [
  ['create table', /create\s+table/gi],
  ['create policy', /create\s+policy/gi],
  ['create index', /create\s+(unique\s+)?index/gi],
]) {
  const vus = compte(sql, motif)
  // Ce qui vit dans une boucle n'est pas une instruction litterale : on ne le
  // compte pas comme manquant.
  const genere = compte(dansLesCorps, motif)
  const attendus = compte(brut, motif) - genere
  if (vus !== attendus) {
    problemes.push(
      `ANALYSE AVEUGLE : ${vus} « ${etiquette} » vus sur ${attendus} attendus ` +
        `(${genere} dans des boucles). Le nettoyage a avale du SQL — ne pas se ` +
        'fier au reste de ce rapport.',
    )
  }
}

// --- Bilan ----------------------------------------------------------------

console.log('eduquali_schema.sql')
console.log(`  ${brut.split('\n').length} lignes`)
// Ce nombre compte les `create table` du fichier, **sans retirer les `drop`**.
// Il depasse donc d'une unite ce que `check:db` trouve dans une base reellement
// construite : `credit_ledger` est cree en 0001 et supprime en 0008, quand le
// systeme de credits a laisse la place aux formules. Les deux nombres sont justes
// et ne comptent pas la meme chose — `check:db` est celui qui decrit la base.
console.log(`  ${creationDe.size} tables declarees (voir check:db pour celles qui restent)`)
console.log(`  ${tablesAvecPolitique.size} tables avec politiques`)
console.log(
  `  ${compte(sql, /create\s+policy/gi)} politiques litterales, ` +
    `${compte(dansLesCorps, /create\s+policy/gi)} posees par une boucle`,
)
console.log(
  '  (les politiques d\'une boucle ne sont pas verifiees contre les doublons :\n' +
    "   elles n'existent qu'a l'execution)",
)

if (avertissements.length > 0) {
  console.log('')
  for (const a of avertissements) console.log(`  ~ ${a}`)
}

if (problemes.length > 0) {
  console.log('')
  for (const p of problemes) console.error(`  ! ${p}`)
  console.error(`\n${problemes.length} probleme(s).`)
  process.exit(1)
}

console.log("\nRien qui empecherait le fichier de s'executer d'un bloc.")
