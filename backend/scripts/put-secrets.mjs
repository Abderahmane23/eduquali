/**
 * Pose les secrets du Worker, depuis `.env`.
 *
 *   node scripts/put-secrets.mjs            # bac a sable
 *   node scripts/put-secrets.mjs production # production
 *
 * --- Pourquoi un script et non sept commandes a la main -------------------
 *
 * Les secrets sont **par cible**. Il faut donc les poser deux fois, une par
 * environnement, et c'est exactement le genre de repetition ou l'on en oublie
 * un : le Worker se deploie, repond, et echoue seulement sur l'ecran qui
 * utilise la cle manquante — souvent en production, souvent devant quelqu'un.
 *
 * Ici la liste est ecrite une fois, et le script dit ce qui manque avant de
 * commencer plutot que de s'arreter au milieu.
 *
 * --- Ce qu'il ne fait pas ------------------------------------------------
 *
 * Il n'affiche aucune valeur, ni dans la sortie ni dans une erreur. Un secret
 * recopie dans un journal de terminal est un secret qui a fuite.
 */

import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

const cible = process.argv[2] ?? ''
const env = join(process.cwd(), '.env')

/**
 * Les secrets que le Worker attend.
 *
 * `ALLOWED_ORIGINS`, `AI_MONTHLY_BUDGET_USD` et `DJOMY_ENVIRONMENT` n'y sont
 * pas : ce sont des `[vars]` de `wrangler.toml`, publiques par nature, et les
 * voir versionnees dit qui peut appeler l'API et quelle cible encaisse pour de
 * vrai.
 */
const REQUIS = [
  'SUPABASE_URL',
  'SUPABASE_ANON_KEY',
  'SUPABASE_SERVICE_ROLE_KEY',
  'GEMINI_API_KEY',
  'LIVEKIT_URL',
  'LIVEKIT_API_KEY',
  'LIVEKIT_API_SECRET',
]

/**
 * Ceux qu'on pose s'ils existent, sans se plaindre de leur absence.
 *
 * R2 et Stream vont ensemble : l'enregistrement ne demarre que si les deux sont
 * configures (`if (recordings && video)`), donc poser R2 seul n'enregistre
 * rien — et ne remplit pas le depot non plus. Djomy absent laisse les achats
 * « en attente », ce qui est le mode normal tant qu'il n'y a pas de compte
 * marchand.
 */
const FACULTATIFS = [
  'CF_ACCOUNT_ID',
  'CF_STREAM_API_TOKEN',
  'CF_STREAM_CUSTOMER_CODE',
  'R2_ENDPOINT',
  'R2_RECORDINGS_BUCKET',
  'R2_ACCESS_KEY_ID',
  'R2_SECRET_ACCESS_KEY',
  'R2_REGION',
  'DJOMY_BASE_URL',
  'DJOMY_CLIENT_ID',
  'DJOMY_CLIENT_SECRET',
  'DJOMY_WEBHOOK_SECRET',
  'DJOMY_COUNTRY',
]

if (!existsSync(env)) {
  console.error('backend/.env introuvable. Lancer depuis le dossier backend/.')
  process.exit(1)
}

const valeurs = new Map()
for (const ligne of readFileSync(env, 'utf8').split('\n')) {
  const propre = ligne.trim()
  if (!propre || propre.startsWith('#')) continue
  const separateur = propre.indexOf('=')
  if (separateur < 0) continue
  const cle = propre.slice(0, separateur).trim()
  const valeur = propre.slice(separateur + 1).trim()
  if (valeur) valeurs.set(cle, valeur)
}

// Tout verifier AVANT de poser quoi que ce soit : s'arreter au quatrieme
// laisserait une cible a moitie configuree, qui repond et echoue par endroits.
const manquants = REQUIS.filter((cle) => !valeurs.has(cle))
if (manquants.length > 0) {
  console.error('Valeurs absentes de .env :')
  for (const cle of manquants) console.error(`  ${cle}`)
  process.exit(1)
}

const aPoser = [
  ...REQUIS,
  ...FACULTATIFS.filter((cle) => valeurs.has(cle)),
]

console.log(
  `${aPoser.length} secret(s) vers « ${cible || 'bac a sable'} »` +
    `${FACULTATIFS.some((c) => valeurs.has(c)) ? '' : ' (ni R2, ni Stream, ni Djomy)'}`,
)

for (const cle of aPoser) {
  const args = ['wrangler', 'secret', 'put', cle]
  if (cible) args.push('--env', cible)
  try {
    execFileSync('npx', args, {
      input: valeurs.get(cle),
      stdio: ['pipe', 'pipe', 'pipe'],
      shell: true,
    })
    console.log(`  ok      ${cle}`)
  } catch (cause) {
    // Le message de wrangler peut contenir la valeur refusee : on ne relaie
    // que le nom de la cle.
    console.error(`  ECHEC   ${cle} — voir wrangler (valeur non affichee)`)
    process.exitCode = 1
  }
}

console.log('')
console.log(
  process.exitCode === 1
    ? 'Au moins un secret n a pas ete pose : la cible est incomplete.'
    : 'Tous les secrets sont poses. `npm run deploy` peut suivre.',
)
