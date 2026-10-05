#!/usr/bin/env node
/**
 * Vérifie que la clé Gemini de `backend/.env` fonctionne.
 *
 *   node scripts/check-gemini.mjs
 *
 * À lancer avant de déployer, et après chaque rotation de clé. Le script
 * n'affiche jamais la clé : seulement sa longueur et son préfixe, de quoi
 * distinguer deux clés sans en divulguer une.
 */
import { readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const API = 'https://generativelanguage.googleapis.com/v1beta'

/*
 * Les modeles viennent de `shared/ai/models.json`, que le Worker lit aussi
 * (`api/_lib/gemini.ts`). Les ecrire ici en plus les aurait fait diverger a la
 * premiere rotation — et le symptome serait un controle qui passe sur un modele
 * que la production n'utilise pas.
 */
const catalogue = JSON.parse(
  readFileSync(join(ROOT, '..', 'shared', 'ai', 'models.json'), 'utf8'),
)

export const MODELS = {
  build: catalogue.models.build.id,
  chat: catalogue.models.chat.id,
}

function readKey() {
  let raw
  try {
    raw = readFileSync(join(ROOT, '.env'), 'utf8')
  } catch {
    fail(
      'backend/.env est absent.',
      'Copier .env.example en .env et y coller la clé.',
      'Ne jamais mettre la clé dans .env.example : ce fichier-là est versionné.',
    )
  }
  const key = raw.match(/^GEMINI_API_KEY=(.*)$/m)?.[1].trim()
  if (!key) fail('GEMINI_API_KEY est vide dans backend/.env.')
  if (key.startsWith('VITE_')) {
    fail('La clé porte le préfixe VITE_ : Vite l’inlinerait dans le site.')
  }
  return key
}

function fail(...lines) {
  for (const line of lines) console.error('  ' + line)
  process.exit(1)
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

/**
 * Un appel, avec reprises.
 *
 * Google renvoie des 503 « high demand » passagers. Sans reprise, un
 * professeur perdrait ses crédits pour un incident qui dure dix secondes —
 * c'est pourquoi la passerelle devra faire pareil.
 */
async function call(model, key, body, tries = 3) {
  for (let attempt = 1; ; attempt++) {
    const started = Date.now()
    const response = await fetch(`${API}/models/${model}:generateContent`, {
      method: 'POST',
      // L'API Gemini attend `x-goog-api-key`. Un `Bearer` est refusé : il
      // n'accepte que les jetons OAuth.
      headers: { 'x-goog-api-key': key, 'content-type': 'application/json' },
      body: JSON.stringify(body),
    })
    const payload = await response.json()
    if (response.ok) return { payload, ms: Date.now() - started, attempt }

    const message = payload.error?.message ?? `HTTP ${response.status}`
    const retryable = response.status === 503 || response.status === 429
    if (!retryable || attempt >= tries) {
      return { error: `HTTP ${response.status} — ${message}`, attempt }
    }
    console.log(`  essai ${attempt} : ${response.status}, on reprend…`)
    await sleep(attempt * 1500)
  }
}

const key = readKey()
console.log(`Clé lue : ${key.length} caractères, préfixe ${key.slice(0, 3)}…\n`)

// 1. La clé ouvre-t-elle un accès ?
const list = await fetch(`${API}/models`, { headers: { 'x-goog-api-key': key } })
if (!list.ok) {
  const body = await list.json().catch(() => ({}))
  fail(`La clé est refusée : HTTP ${list.status}`, body.error?.message ?? '')
}
const models = (await list.json()).models ?? []
const usable = new Set(
  models
    .filter((m) => (m.supportedGenerationMethods ?? []).includes('generateContent'))
    .map((m) => m.name.replace('models/', '')),
)
console.log(`Accès ouvert : ${usable.size} modèles savent générer.`)

// 2. Les modèles retenus existent-ils encore ? Google en retire
//    régulièrement : `gemini-2.0-flash` a disparu entre-temps.
let ok = true
for (const [usage, model] of Object.entries(MODELS)) {
  if (usable.has(model)) continue
  console.error(`  ✗ ${usage} : « ${model} » n’est plus proposé.`)
  ok = false
}
if (!ok) fail('Mettre à jour MODELS dans ce fichier et dans la passerelle.')

// 3. Le cas réel : du JSON structuré, en français, au programme guinéen.
console.log('\nGénération d’un plan de cours…')
const result = await call(MODELS.build, key, {
  contents: [
    {
      parts: [
        {
          text:
            'Tu prépares un cours pour une classe de 12ème année en Guinée, ' +
            'profil sciences expérimentales, matière Biologie, sujet : la ' +
            'cellule. Donne le plan en 3 chapitres.',
        },
      ],
    },
  ],
  generationConfig: {
    responseMimeType: 'application/json',
    responseSchema: {
      type: 'OBJECT',
      properties: {
        titre: { type: 'STRING' },
        chapitres: {
          type: 'ARRAY',
          items: {
            type: 'OBJECT',
            properties: {
              numero: { type: 'INTEGER' },
              titre: { type: 'STRING' },
            },
            required: ['numero', 'titre'],
          },
        },
      },
      required: ['titre', 'chapitres'],
    },
  },
})

if (result.error) fail(result.error)

const plan = JSON.parse(
  result.payload.candidates[0].content.parts.map((p) => p.text).join(''),
)
const used = result.payload.usageMetadata ?? {}
console.log(
  `  ${result.ms} ms | ${used.promptTokenCount} jetons entrée, ` +
    `${used.candidatesTokenCount} sortie`,
)
console.log(`  « ${plan.titre} »`)
for (const c of plan.chapitres) console.log(`   ${c.numero}. ${c.titre}`)

console.log('\nLa clé fonctionne.')
console.log(
  'Reste à vérifier à la main, sur console.cloud.google.com : la\n' +
    'facturation doit être active. En offre gratuite, Google se sert des\n' +
    'données envoyées pour améliorer ses produits — inacceptable pour des\n' +
    'photos de devoirs d’enfants. L’API ne dit pas de quelle offre relève\n' +
    'une clé : ce point ne peut pas être vérifié ici.',
)
