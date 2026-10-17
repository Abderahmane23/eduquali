#!/usr/bin/env node
/**
 * Ce qui est en ligne, comparé à ce que dit le dépôt.
 *
 * --- Pourquoi ce fichier existe -------------------------------------------
 *
 * Le 17/10, trois décalages tenaient en même temps, et aucun ne se voyait :
 *
 *   * le site servait un build d'avant la charte — son titre annonçait
 *     « Acalia », le nom de deux renommages en arrière — parce que le projet
 *     Cloudflare Pages est en dépôt direct et ne se reconstruit pas depuis
 *     GitHub. Quatre commits n'avaient jamais été mis en ligne ;
 *   * le Worker déployé ne servait pas `/schools/names`, écrit le jour même :
 *     l'autocomplétion des écoles rendait une liste vide sans rien dire ;
 *   * deux migrations n'étaient pas appliquées, et la base n'en gardait
 *     aucune trace.
 *
 * Chacun de ces états ressemble à un produit qui marche. C'est la forme que
 * prennent les pannes de ce projet : une liste vide, un champ qui accepte
 * tout, une page qui s'affiche. Ce script va donc les chercher.
 *
 *   node scripts/verifier-production.mjs
 *
 * Il ne modifie rien, ne demande aucun jeton, et sort en échec si un écart
 * est trouvé — pour qu'il puisse être lancé après chaque mise en ligne.
 */

import { execFileSync } from 'node:child_process'
import { readFileSync, existsSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const RACINE = join(dirname(fileURLToPath(import.meta.url)), '..')
const SITE = 'https://eduquali.pages.dev'
const API = 'https://eduquali-api.abder4it.workers.dev/api/v1'

/*
 * Le budget de l'annuaire.
 *
 * Huit secondes : large pour une liste de cent vingt fiches chargées en six
 * requêtes, et bien en dessous du temps qu'un visiteur accorde à une page.
 * La route mettait plus de soixante secondes avant correction — sans jamais
 * répondre.
 */
const BUDGET_ANNUAIRE_MS = 8000

const constats = []

function dire(etat, sujet, detail) {
  constats.push({ etat, sujet, detail })
  const marque = { ok: '  OK  ', souci: ' ÉCART', note: ' note ' }[etat]
  console.log(`${marque}  ${sujet}`)
  if (detail) console.log(`         ${detail}`)
}

/**
 * Un appel avec délai maximal : une route muette est un résultat.
 *
 * Deux tentatives, et c'est le point important. La première version n'en
 * faisait qu'une et a annoncé « le site ne répond pas » sur un site qui
 * répondait — vérifié dans la seconde qui suivait. Un contrôle qui crie au
 * loup est pire que pas de contrôle : on apprend à ignorer sa sortie, et le
 * jour où l'écart est réel on ne le lit plus.
 *
 * Le second essai ne masque rien : une route vraiment muette échoue deux
 * fois, et le détail porte la cause plutôt qu'un simple « statut 0 ».
 */
async function appeler(url, limiteMs, essais = 2) {
  let dernier = { statut: 0, corps: 'aucune tentative', ms: 0 }
  for (let tour = 1; tour <= essais; tour += 1) {
    const horloge = Date.now()
    try {
      const reponse = await fetch(url, {
        signal: AbortSignal.timeout(limiteMs),
      })
      const corps = await reponse.text()
      return { statut: reponse.status, corps, ms: Date.now() - horloge }
    } catch (souci) {
      const cause = souci.cause?.code ?? souci.cause?.message ?? ''
      dernier = {
        statut: 0,
        corps: `${souci.name} : ${souci.message}${cause ? ` (${cause})` : ''}`,
        ms: Date.now() - horloge,
      }
    }
  }
  return dernier
}

// --- 1. Le site ------------------------------------------------------------

async function verifierSite() {
  const page = await appeler(`${SITE}/?v=${Date.now()}`, 20000)
  if (page.statut !== 200) {
    dire('souci', 'le site ne répond pas', `statut ${page.statut} — ${page.corps.slice(0, 120)}`)
    return
  }

  const titre = /<title>([^<]*)<\/title>/.exec(page.corps)?.[1] ?? ''
  if (!titre.includes('EduQuali')) {
    dire(
      'souci',
      'le site sert un build d’avant le nom EduQuali',
      `titre servi : « ${titre} » — déposez frontend/web/dist dans Pages`,
    )
  } else {
    dire('ok', 'le site porte le nom et la charte', `titre : ${titre}`)
  }

  /*
   * Le bundle servi, comparé au dernier build local.
   *
   * C'est ce qui aurait dit, le 12/10, que la mise en ligne n'avait pas eu
   * lieu : le titre peut être bon et le code en retard d'un commit.
   */
  const servi = /assets\/(index-[A-Za-z0-9_-]+\.js)/.exec(page.corps)?.[1]
  const local = join(RACINE, 'frontend', 'web', 'dist', 'index.html')
  if (existsSync(local)) {
    const construit = /assets\/(index-[A-Za-z0-9_-]+\.js)/.exec(
      readFileSync(local, 'utf-8'),
    )?.[1]
    if (construit && servi && construit !== servi) {
      dire(
        'souci',
        'le bundle en ligne n’est pas le dernier construit',
        `en ligne ${servi}, local ${construit}`,
      )
    } else if (construit === servi) {
      dire('ok', 'le bundle en ligne est le dernier construit', servi)
    }
  } else {
    dire('note', 'pas de build local à comparer', 'lancez npm run build')
  }
}

// --- 2. Le Worker ----------------------------------------------------------

async function verifierApi() {
  const sante = await appeler(`${API}/health`, 20000)
  if (sante.statut !== 200) {
    dire('souci', 'l’API ne répond pas', `statut ${sante.statut}`)
    return
  }

  let etat = {}
  try {
    etat = JSON.parse(sante.corps)
  } catch {
    dire('souci', 'l’API répond autre chose que du JSON', sante.corps.slice(0, 80))
    return
  }

  dire('ok', 'l’API répond', `base : ${etat.database}`)

  /*
   * Les intégrations déclarées non configurées.
   *
   * Ce ne sont pas des pannes : ce sont des secrets qui ne sont pas posés
   * sur le Worker. Mais chacune ferme une fonction entière du produit, et
   * l'écran correspondant ne dit pas pourquoi il ne marche pas.
   */
  const conséquences = {
    payments: 'aucun paiement possible — une famille ne peut rien régler',
    video: 'aucun cours enregistré ne peut être déposé ni lu',
    recording: 'aucune rediffusion de cours en direct',
    live: 'aucune salle de cours en direct',
  }
  for (const [clef, phrase] of Object.entries(conséquences)) {
    const bloc = etat[clef]
    if (bloc && bloc.configured === false) {
      dire('souci', `${clef} : secrets absents sur le Worker`, phrase)
    }
  }

  /*
   * Une route écrite le 17/10. Si elle rend 404, le Worker déployé est plus
   * vieux que le dépôt — exactement le décalage qu'on cherche.
   */
  const ecoles = await appeler(`${API}/schools/names`, 20000)
  if (ecoles.statut === 404) {
    dire(
      'souci',
      'le Worker déployé est plus vieux que le dépôt',
      '/schools/names rend 404 — lancez `wrangler deploy` dans backend/',
    )
  } else if (ecoles.statut === 200) {
    dire('ok', '/schools/names est servie')
  } else {
    dire('note', `/schools/names rend ${ecoles.statut}`, ecoles.corps.slice(0, 80))
  }

  // L'annuaire : l'onglet principal de quatre profils sur cinq.
  const annuaire = await appeler(`${API}/teachers`, BUDGET_ANNUAIRE_MS + 2000)
  if (annuaire.statut !== 200) {
    dire(
      'souci',
      'l’annuaire des professeurs ne répond pas',
      `statut ${annuaire.statut} après ${annuaire.ms} ms — c’est l’onglet `
      + 'principal d’une famille, d’un élève, d’une école et d’un visiteur',
    )
  } else if (annuaire.ms > BUDGET_ANNUAIRE_MS) {
    dire(
      'souci',
      'l’annuaire répond, mais trop lentement',
      `${annuaire.ms} ms pour un budget de ${BUDGET_ANNUAIRE_MS} ms`,
    )
  } else {
    dire('ok', 'l’annuaire répond dans son budget', `${annuaire.ms} ms`)
  }
}

// --- 3. Les migrations -----------------------------------------------------

function verifierMigrations() {
  try {
    const sortie = execFileSync(
      process.execPath,
      [join(RACINE, 'scripts', 'migrations.mjs')],
      { encoding: 'utf-8', stdio: ['ignore', 'pipe', 'pipe'] },
    )
    dire('ok', 'les migrations du dépôt sont posées', sortie.trim().split('\n')[1])
  } catch (souci) {
    const sortie = String(souci.stdout ?? '')
    if (sortie.includes('Jeton absent')) {
      dire(
        'note',
        'l’écart de migrations n’a pas pu être mesuré',
        'jeton Supabase absent — voir l’en-tête de scripts/migrations.mjs',
      )
      return
    }
    const manquantes = sortie
      .split('\n')
      .filter((l) => l.includes('manque :'))
      .map((l) => l.trim().replace('manque : ', ''))
    dire(
      'souci',
      `${manquantes.length} migration(s) non appliquée(s)`,
      manquantes.join(', ') || sortie.trim().slice(0, 160),
    )
  }
}

// --- La conclusion ---------------------------------------------------------

console.log('Ce qui est en ligne, comparé au dépôt')
console.log('─'.repeat(64))

await verifierSite()
await verifierApi()
verifierMigrations()

console.log('─'.repeat(64))
const ecarts = constats.filter((c) => c.etat === 'souci')
if (ecarts.length === 0) {
  console.log('Aucun écart. La production correspond au dépôt.')
} else {
  console.log(`${ecarts.length} écart(s) :`)
  for (const e of ecarts) console.log(`  • ${e.sujet}`)
  process.exitCode = 1
}
