import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'
import { describe, it } from 'node:test'

import { WRITABLE } from './sync.ts'

/**
 * Chaque colonne que le serveur accepte existe-t-elle vraiment ?
 *
 * --- Pourquoi ce fichier ------------------------------------------------
 *
 * `planWrite` ne retient d'une charge utile que les cles qui **portent le nom
 * exact** d'une colonne listee dans `WRITABLE`. Rien ne verifiait que ces noms
 * correspondent a quelque chose : la liste etait un contrat avec le schema que
 * personne ne relisait.
 *
 * L'audit du 04/10 y a trouve une entiere entree fantome —
 * `teacher_tutoring_availability`, une table qu'aucune migration n'a jamais
 * creee, avec des colonnes (`weekday`, `start_time`, `end_time`) que le client
 * n'envoie pas. L'ecran de disponibilite d'un professeur poussait vers elle a
 * chaque enregistrement : chaque envoi echouait, d'abord sur les cles puis en
 * `42P01`, sans que rien ne le signale.
 *
 * `npm run check:schema` ne pouvait pas le voir : il compare les **noms de
 * tables**, pas les colonnes.
 *
 * --- Ce que ce controle lit ---------------------------------------------
 *
 * Les migrations, en texte. C'est la seule description du schema qui vive dans
 * le depot ; interroger la base demanderait un reseau et une cle, que les
 * tests n'ont pas. On y suit `create table` et `add column`, et on honore les
 * `drop` pour ne pas exiger une colonne retiree depuis.
 */

const MIGRATIONS = new URL('../../supabase/migrations/', import.meta.url)

/** Les colonnes de chaque table, d'apres les migrations appliquees en ordre. */
function schema(): Map<string, Set<string>> {
  const tables = new Map<string, Set<string>>()
  const fichiers = readdirSync(MIGRATIONS)
    .filter((f) => f.endsWith('.sql'))
    .sort()

  for (const fichier of fichiers) {
    const brut = readFileSync(new URL(fichier, MIGRATIONS), 'utf-8')
    // Les commentaires d'abord : ils citent des noms de colonnes en prose, et
    // en tenir compte ferait passer ce controle pour de mauvaises raisons.
    const texte = brut
      .replace(/\/\*[\s\S]*?\*\//g, ' ')
      .replace(/--[^\n]*/g, ' ')

    // create table <nom> ( ... )
    for (const trouve of texte.matchAll(
      /create\s+table\s+(?:if\s+not\s+exists\s+)?([a-z_][a-z0-9_]*)\s*\(([\s\S]*?)\n\s*\);/gi,
    )) {
      const nom = trouve[1].toLowerCase()
      const colonnes = tables.get(nom) ?? new Set<string>()
      for (const ligne of trouve[2].split('\n')) {
        // Une definition de colonne commence par son nom ; `unique (...)`,
        // `check (...)`, `primary key` et `foreign key` n'en sont pas.
        const m = ligne
          .trim()
          .match(/^([a-z_][a-z0-9_]*)\s+[a-z]/i)
        if (!m) continue
        const colonne = m[1].toLowerCase()
        if (
          ['unique', 'check', 'primary', 'foreign', 'constraint'].includes(
            colonne,
          )
        ) {
          continue
        }
        colonnes.add(colonne)
      }
      tables.set(nom, colonnes)
    }

    // alter table <nom> ... add column [if not exists] <colonne>
    for (const trouve of texte.matchAll(
      /alter\s+table\s+(?:only\s+)?([a-z_][a-z0-9_]*)([\s\S]*?);/gi,
    )) {
      const nom = trouve[1].toLowerCase()
      const corps = trouve[2]
      const colonnes = tables.get(nom) ?? new Set<string>()
      for (const ajout of corps.matchAll(
        /add\s+column\s+(?:if\s+not\s+exists\s+)?([a-z_][a-z0-9_]*)/gi,
      )) {
        colonnes.add(ajout[1].toLowerCase())
      }
      for (const retrait of corps.matchAll(
        /drop\s+column\s+(?:if\s+exists\s+)?([a-z_][a-z0-9_]*)/gi,
      )) {
        colonnes.delete(retrait[1].toLowerCase())
      }
      tables.set(nom, colonnes)
    }

    for (const trouve of texte.matchAll(
      /drop\s+table\s+(?:if\s+exists\s+)?([a-z_][a-z0-9_]*)/gi,
    )) {
      tables.delete(trouve[1].toLowerCase())
    }
  }
  return tables
}

describe('le contrat de synchronisation colle au schéma', () => {
  const tables = schema()

  it('les migrations ont bien été lues', () => {
    // Un plancher : si l'expression de lecture casse, ce fichier passerait au
    // vert sans rien vérifier.
    assert.ok(
      tables.size >= 40,
      `seulement ${tables.size} tables lues dans les migrations`,
    )
    assert.ok(
      (tables.get('teachers')?.size ?? 0) >= 15,
      'la table `teachers` n’a pas été lue correctement',
    )
  })

  it('chaque table de WRITABLE existe', () => {
    for (const [entite, regle] of Object.entries(WRITABLE)) {
      assert.ok(
        tables.has(regle.table),
        `« ${entite} » écrit dans « ${regle.table} », qu’aucune migration ne ` +
          'crée. Un client qui pousse cette entité échoue en 42P01.',
      )
    }
  })

  it('chaque colonne de WRITABLE existe', () => {
    const manquantes: string[] = []
    for (const [entite, regle] of Object.entries(WRITABLE)) {
      const colonnes = tables.get(regle.table)
      if (!colonnes) continue
      for (const colonne of regle.columns) {
        if (!colonnes.has(colonne)) {
          manquantes.push(`${entite} → ${regle.table}.${colonne}`)
        }
      }
    }
    assert.deepEqual(
      manquantes,
      [],
      'Ces colonnes sont acceptées par le serveur et absentes du schéma : ' +
        `${manquantes.join(', ')}. Une charge utile qui les porte est ` +
        'silencieusement vidée, puis refusée faute de colonne reconnue.',
    )
  })

  it('les colonnes réservées au serveur existent aussi', () => {
    // `serverOwned` sert à refuser une écriture avec un motif lisible. Nommer
    // une colonne qui n'existe pas y écrirait une explication sur du vide.
    const manquantes: string[] = []
    for (const [entite, regle] of Object.entries(WRITABLE)) {
      const colonnes = tables.get(regle.table)
      if (!colonnes || !regle.serverOwned) continue
      for (const colonne of Object.keys(regle.serverOwned)) {
        if (!colonnes.has(colonne)) {
          manquantes.push(`${entite} → ${regle.table}.${colonne}`)
        }
      }
    }
    assert.deepEqual(manquantes, [])
  })
})
