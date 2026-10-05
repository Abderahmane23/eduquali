import assert from 'node:assert/strict'
import { createHash, createHmac } from 'node:crypto'
import { test } from 'node:test'

import { LiveKit, sessionFromRoom } from './livekit.ts'
import { CloudflareStream } from './stream.ts'

/**
 * Les deux fournisseurs vidéo.
 *
 * LiveKit n'a pas de notion de compte : il fait confiance au jeton que nous
 * signons. Tout le contrôle d'accès à une classe payante tient donc dans la
 * forme de ce jeton, et c'est ce qui est vérifié ici.
 */

const livekit = new LiveKit({
  url: 'wss://projet-test.livekit.cloud',
  apiKey: 'APItest',
  apiSecret: 'secret-de-test-assez-long',
})

/** Décode la charge utile d'un JWT, sans vérifier la signature. */
function payload(jeton: string): Record<string, unknown> {
  const partie = jeton.split('.')[1]
  const base64 = partie.replace(/-/g, '+').replace(/_/g, '/')
  return JSON.parse(Buffer.from(base64, 'base64').toString('utf8'))
}

/** Vérifie la signature avec une autre implémentation que la nôtre. */
function signatureValide(jeton: string, secret: string): boolean {
  const [entete, corps, signature] = jeton.split('.')
  const attendue = createHmac('sha256', secret)
    .update(`${entete}.${corps}`)
    .digest('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
  return signature === attendue
}

test('le jeton est un JWT HS256 correctement signé', async () => {
  const { token } = await livekit.joinToken({
    sessionId: 'sess-1',
    identity: 'user-1',
    name: 'Mamadou Diallo',
    role: 'student',
    ttlSeconds: 3600,
  })

  const [entete] = token.split('.')
  const decodeEntete = JSON.parse(
    Buffer.from(entete.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString(),
  )
  assert.equal(decodeEntete.alg, 'HS256')
  assert.equal(decodeEntete.typ, 'JWT')

  // Signé avec le secret du projet, vérifié par `node:crypto` — si notre
  // base64url était fausse, LiveKit refuserait le jeton sans expliquer pourquoi.
  assert.ok(
    signatureValide(token, 'secret-de-test-assez-long'),
    'signature invalide',
  )
})

test('le jeton est nominatif, donc une place ne se partage pas', async () => {
  const { token } = await livekit.joinToken({
    sessionId: 'sess-1',
    identity: 'user-42',
    name: 'Aissatou Bah',
    role: 'student',
    ttlSeconds: 3600,
  })
  const corps = payload(token)
  assert.equal(corps.sub, 'user-42')
  assert.equal(corps.name, 'Aissatou Bah')
})

test('un élève n’a pas le droit de publier d’emblée', async () => {
  // Donner la caméra et le micro à quinze adolescents dès l'entrée rend le
  // cours impossible à tenir. Il demande la parole, le professeur la donne.
  const { token } = await livekit.joinToken({
    sessionId: 'sess-1',
    identity: 'eleve',
    name: 'Élève',
    role: 'student',
    ttlSeconds: 3600,
  })
  const video = payload(token).video as Record<string, unknown>

  assert.equal(video.roomJoin, true)
  assert.equal(video.canSubscribe, true)
  assert.equal(video.canPublish, false)
  assert.equal(video.roomAdmin, false)
  // Les données restent ouvertes : c'est par là que passe la main levée.
  assert.equal(video.canPublishData, true)
})

test('le professeur publie et anime', async () => {
  const { token } = await livekit.joinToken({
    sessionId: 'sess-1',
    identity: 'prof',
    name: 'Professeur',
    role: 'teacher',
    ttlSeconds: 3600,
  })
  const video = payload(token).video as Record<string, unknown>

  assert.equal(video.canPublish, true)
  assert.equal(video.roomAdmin, true)
})

test('le jeton expire, et tolère une horloge décalée', async () => {
  const avant = Math.floor(Date.now() / 1000)
  const { token } = await livekit.joinToken({
    sessionId: 'sess-1',
    identity: 'user',
    name: 'Nom',
    role: 'student',
    ttlSeconds: 1800,
  })
  const corps = payload(token)

  // Une demi-heure, pas un mois : un jeton qui traîne est une porte ouverte.
  assert.ok(Number(corps.exp) - avant <= 1801)
  assert.ok(Number(corps.exp) - avant >= 1799)

  // `nbf` reculé : l'horloge d'un téléphone n'est pas toujours juste, et un
  // jeton « pas encore valable » se lit comme une panne.
  assert.ok(Number(corps.nbf) < avant)
})

test('la salle d’une séance est toujours la même', async () => {
  // Recalculable sans lecture en base : deux jetons émis pour la même séance
  // doivent mener à la même salle.
  assert.equal(LiveKit.roomFor('abc'), 'seance-abc')
  const a = await livekit.joinToken({
    sessionId: 'abc',
    identity: 'u1',
    name: 'A',
    role: 'student',
    ttlSeconds: 60,
  })
  const b = await livekit.joinToken({
    sessionId: 'abc',
    identity: 'u2',
    name: 'B',
    role: 'teacher',
    ttlSeconds: 60,
  })
  assert.equal(a.room, b.room)
  assert.equal(a.url, 'wss://projet-test.livekit.cloud')
})

test('la configuration incomplète désactive la visioconférence', () => {
  assert.equal(LiveKit.isConfigured({}), false)
  assert.equal(
    LiveKit.isConfigured({ url: 'wss://x', apiKey: 'a' }),
    false,
  )
  assert.equal(
    LiveKit.isConfigured({
      url: 'wss://x',
      apiKey: 'a',
      apiSecret: 'b',
    }),
    true,
  )
})

// --- Cloudflare Stream -----------------------------------------------------
//
// Depuis le 03/10, l'hebergement video est Cloudflare Stream et non Bunny. Ce
// qui s'eprouve hors ligne a change de nature : chez Bunny, la signature etait
// calculee ici (`SHA256(tokenKey + videoId + expiration)`) et donc verifiable ;
// Stream l'emet par API, et c'est un progres — il n'y a plus de formule a se
// tromper, mais plus rien a verifier sans reseau non plus.
//
// Reste ce qui compte et qui ne demande pas d'appel : la **forme des adresses**,
// ou une erreur rend une video noire plutot qu'une exception, et les garanties
// structurelles de la configuration.

const flux = new CloudflareStream({
  accountId: 'compte-de-test',
  apiToken: 'jeton-de-test',
  customerCode: 'customer-abc123',
})

test('le jeton remplace l’identifiant dans le chemin', () => {
  // C'est la forme que Cloudflare attend pour une video en `requireSignedURLs` :
  // le jeton est un segment de chemin, pas un parametre de requete. Mettre
  // `?token=` rend un 403 que rien n'explique.
  const urls = flux.urlsForToken('jeton-signe-opaque')
  assert.equal(
    urls.hls,
    'https://customer-abc123.cloudflarestream.com/jeton-signe-opaque/manifest/video.m3u8',
  )
  assert.equal(
    urls.iframe,
    'https://customer-abc123.cloudflarestream.com/jeton-signe-opaque/iframe',
  )
  // Et l'identifiant de la video n'y figure nulle part : c'est le jeton qui
  // porte l'autorisation, et le laisser fuiter donnerait la video.
  assert.ok(!urls.hls.includes('video-'))
})

test('les deux clients recoivent chacun sa forme', () => {
  // HLS pour Flutter (`video_player` le lit nativement par ExoPlayer, zero octet
  // de plus dans l'APK) ; `iframe` pour le site, ou Chrome et Firefox ne lisent
  // pas HLS sans bibliotheque.
  const urls = flux.urlsForToken('t')
  assert.match(urls.hls, /\.m3u8$/)
  assert.match(urls.iframe, /\/iframe$/)
})

test('les URL de lecture sont signees par construction', () => {
  // Chez Bunny, la signature dependait d'une option de zone qu'on pouvait
  // oublier d'activer — le serveur journalisait un avertissement a chaque
  // demarrage. Stream pose `requireSignedURLs` a l'ingestion de chaque video :
  // il n'y a plus de reglage a oublier.
  assert.equal(flux.signsUrls, true)
})

test('une configuration incomplete desactive la video', () => {
  // Les trois valeurs sont necessaires : sans le code client, on construirait
  // une adresse vers un sous-domaine qui n'existe pas, et la video serait noire
  // sans message.
  assert.equal(CloudflareStream.isConfigured({}), false)
  assert.equal(
    CloudflareStream.isConfigured({ accountId: 'a', apiToken: 't' }),
    false,
  )
  assert.equal(
    CloudflareStream.isConfigured({
      accountId: 'a',
      apiToken: 't',
      customerCode: 'customer-x',
    }),
    true,
  )
})

// --- L'identité dans la salle ---------------------------------------------

test('l’identité est la place payée, pas le compte', () => {
  // LiveKit déconnecte le premier participant quand un second arrive avec la
  // même identité. Deux enfants d'une même famille, deux places payées, deux
  // tablettes : si l'identité était le compte, ils se chasseraient l'un l'autre.
  const une = LiveKit.identityFor({ role: 'student', enrolmentId: 'insc-1' })
  const autre = LiveKit.identityFor({ role: 'student', enrolmentId: 'insc-2' })
  assert.notEqual(une, autre)

  // Et la propriété devient utile dans l'autre sens : une place, une connexion.
  // Un mot de passe partagé ne donne pas deux entrées.
  assert.equal(
    LiveKit.identityFor({ role: 'student', enrolmentId: 'insc-1' }),
    une,
  )
})

test('une identité se relit, et une identité étrangère est refusée', () => {
  assert.deepEqual(LiveKit.parseIdentity('place-insc-9'), {
    role: 'student',
    enrolmentId: 'insc-9',
  })
  assert.deepEqual(LiveKit.parseIdentity('prof-t-3'), {
    role: 'teacher',
    teacherId: 't-3',
  })

  // Le webhook de présence s'appuie sur cette lecture. Deviner sur un nom
  // inconnu écrirait du temps de cours au hasard, donc elle rend `null`.
  for (const inconnue of ['', 'place-', 'prof-', 'bob', 'placeinsc-1']) {
    assert.equal(LiveKit.parseIdentity(inconnue), null, inconnue)
  }
})

test('une séance se retrouve depuis le nom de sa salle', () => {
  const salle = LiveKit.roomFor('sess-77')
  assert.equal(sessionFromRoom(salle), 'sess-77')
  // Un webhook pour une salle qui n'est pas la nôtre doit être ignoré, pas
  // traité au hasard.
  assert.equal(sessionFromRoom('autre-chose'), null)
  assert.equal(sessionFromRoom('seance-'), null)
  assert.equal(sessionFromRoom(undefined), null)
})

// --- Les webhooks : la source de vérité de la présence ---------------------

/**
 * Fabrique un webhook LiveKit tel que le service en envoie : un JWT dans
 * `Authorization`, dont la revendication `sha256` porte l'empreinte du corps.
 */
function webhookSigne(
  corps: string,
  options: { secret?: string; empreinte?: string; exp?: number } = {},
): string {
  const b64 = (texte: string) =>
    Buffer.from(texte, 'utf8').toString('base64url')
  const entete = b64(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
  const charge = b64(
    JSON.stringify({
      iss: 'APItest',
      exp: options.exp ?? Math.floor(Date.now() / 1000) + 300,
      sha256:
        options.empreinte ??
        createHash('sha256').update(corps, 'utf8').digest('base64'),
    }),
  )
  const signature = createHmac(
    'sha256',
    options.secret ?? 'secret-de-test-assez-long',
  )
    .update(`${entete}.${charge}`)
    .digest('base64url')
  return `${entete}.${charge}.${signature}`
}

const CORPS = JSON.stringify({
  event: 'participant_joined',
  room: { name: 'seance-sess-1' },
  participant: { identity: 'place-insc-1' },
})

test('un webhook correctement signé est accepté', async () => {
  const evenement = await livekit.verifyWebhook(webhookSigne(CORPS), CORPS)
  assert.equal(evenement.event, 'participant_joined')
  assert.equal(evenement.participant?.identity, 'place-insc-1')
})

test('le préfixe Bearer est toléré', async () => {
  // LiveKit envoie le jeton nu ; un relais ou un proxy peut le préfixer, et
  // refuser pour cette raison ferait perdre toute la présence d'une séance.
  const evenement = await livekit.verifyWebhook(
    `Bearer ${webhookSigne(CORPS)}`,
    CORPS,
  )
  assert.equal(evenement.event, 'participant_joined')
})

test('un corps modifié après signature est refusé', async () => {
  // C'est la raison d'être de la revendication `sha256`. Sans ce contrôle, un
  // jeton valable intercepté permettrait d'annoncer n'importe quelle présence —
  // et le temps de cours que le parent lit viendrait de l'extérieur.
  const jeton = webhookSigne(CORPS)
  const falsifie = CORPS.replace('insc-1', 'insc-2')
  await assert.rejects(
    () => livekit.verifyWebhook(jeton, falsifie),
    /altere/i,
  )
})

test('une signature faite avec un autre secret est refusée', async () => {
  await assert.rejects(
    () => livekit.verifyWebhook(webhookSigne(CORPS, { secret: 'autre' }), CORPS),
    /invalide/i,
  )
})

test('un jeton expiré est refusé', async () => {
  await assert.rejects(
    () =>
      livekit.verifyWebhook(
        webhookSigne(CORPS, { exp: Math.floor(Date.now() / 1000) - 3600 }),
        CORPS,
      ),
    /expire/i,
  )
})

test('un webhook sans jeton ou mal formé est refusé', async () => {
  await assert.rejects(() => livekit.verifyWebhook(undefined, CORPS), /jeton/i)
  await assert.rejects(() => livekit.verifyWebhook('a.b', CORPS), /forme/i)
})

test('le corps doit être le texte reçu, pas un objet réanalysé', async () => {
  // Le piège de cette intégration : `JSON.parse` puis `JSON.stringify` change
  // les espaces, et l'empreinte ne correspond plus. On croit alors à un mauvais
  // secret et on cherche pendant des heures du mauvais côté.
  const espace = '{\n  "event": "room_finished",\n  "room": { "name": "seance-x" }\n}'
  const jeton = webhookSigne(espace)
  const evenement = await livekit.verifyWebhook(jeton, espace)
  assert.equal(evenement.event, 'room_finished')

  const reanalyse = JSON.stringify(JSON.parse(espace))
  await assert.rejects(() => livekit.verifyWebhook(jeton, reanalyse), /altere/i)
})

// --- Le lecteur du site ----------------------------------------------------

test('l’adresse du lecteur ne demarre pas la lecture toute seule', () => {
  // 90 minutes de video sur une connexion payee au megaoctet se declenchent sur
  // un geste. Stream ne lit pas automatiquement sans `?autoplay=true`, donc
  // l'adresse nue est deja le bon defaut — contrairement a Bunny, ou il fallait
  // le dire explicitement.
  const urls = flux.urlsForToken('t')
  assert.ok(!urls.iframe.includes('autoplay'))
})
