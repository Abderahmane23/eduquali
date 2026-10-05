import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * La présence, le temps de cours et la rediffusion.
 *
 * Trois règles portent cette fonction, et chacune se casse en silence :
 *
 *   1. **la présence est constatée, jamais déclarée.** Un client qui pourrait
 *      écrire du temps de cours rendrait faux le seul chiffre qu'un parent
 *      regarde ;
 *   2. **le parent ne voit pas l'image de son enfant.** C'est une présence, pas
 *      une surveillance vidéo, et rien dans le code ne doit ouvrir cette porte ;
 *   3. **une rediffusion est une vidéo payée.** Son adresse se signe après
 *      vérification, jamais avant.
 */
const code = (chemin: string) =>
  readFileSync(chemin, 'utf-8')
    .replace(/\r\n/g, '\n')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^[ \t]*\/\/.*$/gm, '')

const brut = (chemin: string) => readFileSync(chemin, 'utf-8').replace(/\r\n/g, '\n')

const worker = code('../../backend/api/[[...route]].ts')
const migration = brut('../../backend/supabase/migrations/0017_attendance.sql')
const bandeau = code('src/components/PresenceBanner.tsx')
const rediffusion = code('src/screens/Replay.tsx')
const salle = code('src/screens/Room.tsx')

const bloc = (depuis: string, jusqu: string) =>
  worker.slice(worker.indexOf(depuis), worker.indexOf(jusqu))

describe('la présence est constatée, jamais déclarée', () => {
  it('n’a aucune politique d’écriture', () => {
    // Le seul moyen d'écrire du temps de cours doit être la clé de service, donc
    // le webhook. Une politique `insert` ou `update` ici suffirait à laisser un
    // élève fabriquer ses 90 minutes.
    const politiques = migration.match(/create policy[\s\S]*?;/g) ?? []
    expect(politiques.length).toBeGreaterThan(0)
    for (const politique of politiques) {
      expect(politique).toContain('for select')
      expect(politique).not.toMatch(/for (insert|update|delete|all)/)
    }
  })

  it('s’écrit depuis le webhook LiveKit et pas depuis une route de client', () => {
    const webhook = bloc(
      "app.post('/live/webhooks/livekit'",
      'async function accountBehind',
    )
    expect(webhook).toContain('verifyWebhook')
    expect(webhook).toContain("case 'participant_joined'")
    expect(webhook).toContain("case 'participant_left'")
    expect(webhook).toContain("case 'room_finished'")

    // La signature est vérifiée avant toute lecture du corps.
    expect(webhook.indexOf('verifyWebhook')).toBeLessThan(
      webhook.indexOf("case 'participant_joined'"),
    )

    // Et aucune autre route n'insère de présence.
    const insertions = worker.match(/from\('session_attendance'\)\s*\n?\s*\.insert/g) ?? []
    expect(insertions).toHaveLength(1)
  })

  it('ferme la ligne précédente avant d’en ouvrir une', () => {
    // Une reconnexion est un nouveau `participant_joined`. Sans fermeture, l'index
    // unique refuse l'insertion et toute la présence du reste du cours est perdue.
    const webhook = bloc(
      "case 'participant_joined'",
      "case 'participant_left'",
    )
    expect(webhook).toContain(".is('left_at', null)")
    expect(webhook.indexOf('left_at: new Date')).toBeLessThan(
      webhook.indexOf('.insert('),
    )
  })

  it('ferme les lignes restées ouvertes à la fin de la séance', () => {
    // Un navigateur qui plante n'envoie pas de départ. Une ligne ouverte pour
    // toujours ne compte jamais ses minutes, et le parent lirait zéro pour un
    // cours entièrement suivi.
    expect(worker).toContain('async function closeDanglingAttendance')
    const fermeture = bloc(
      "app.post('/live/sessions/:id/close'",
      'async function closeDanglingAttendance',
    )
    expect(fermeture).toContain('closeDanglingAttendance')
    const fin = bloc("case 'room_finished'", "case 'egress_ended'")
    expect(fin).toContain('closeDanglingAttendance')
  })

  it('compte les minutes sur l’horloge du serveur', () => {
    // L'horloge d'un téléphone guinéen n'est pas toujours juste, et ce chiffre
    // est celui sur lequel un parent juge si l'abonnement sert.
    expect(worker).toContain('function minutesBetween')
    expect(worker).toContain('Math.max(0, Math.floor(')
    expect(migration).toContain('minutes_so_far')
    expect(migration).toContain('extract(epoch from (now() - a.joined_at))')
  })
})

describe('une présence n’est pas une surveillance', () => {
  it('le serveur ne rend ni piste, ni salle, ni image', () => {
    const presence = bloc("app.get('/live/presence'", "app.get('/live/study-minutes'")

    // La forme exacte de la reponse, et non une liste de mots interdits : le
    // contrôle doit échouer quand un champ s'ajoute, pas quand une variable
    // interne porte un nom malheureux.
    const corps = presence.slice(
      presence.indexOf('.map((ligne) => ({'),
      presence.indexOf('})),'),
    )
    const champs = [...corps.matchAll(/^\s{6}(\w+):/gm)].map((m) => m[1]).sort()
    expect(champs).toEqual([
      'childName',
      'courseTitle',
      'id',
      'minutes',
      'sessionId',
      'startsAt',
      'subjectName',
    ])
  })

  it('le bandeau n’affiche aucun flux et ne charge pas LiveKit', () => {
    // Importer le client vidéo ici le ferait entrer dans le paquet principal, et
    // surtout rendrait la caméra de l'enfant techniquement accessible au parent.
    expect(bandeau).not.toContain("from 'livekit-client'")
    expect(bandeau).not.toContain('<video')
    expect(bandeau).not.toContain('createLocalTracks')
  })

  it('le bandeau se taît quand il n’y a rien à dire', () => {
    // Un bandeau vide en haut de chaque page, ou un message d'erreur pour un
    // compte enseignant, serait du bruit permanent.
    expect(bandeau).toContain('if (presences.length === 0) return null')
    expect(bandeau).toContain('setPresences([])')
  })

  it('le bandeau relit périodiquement et s’arrête en partant', () => {
    // Une minuterie laissée en vie continue d'appeler le serveur après le
    // démontage, et React s'en plaint à juste titre.
    expect(bandeau).toContain('clearTimeout')
    expect(bandeau).toContain('vivant = false')
  })
})

describe('le temps de cours', () => {
  it('compte la semaine à partir du lundi', () => {
    // « Cette semaine » doit dire la même chose un vendredi qu'un dimanche. Le
    // dimanche ferme la semaine, il ne l'ouvre pas.
    const fonction = worker.slice(worker.indexOf('function startOfWeek'))
    expect(fonction).toContain('jour === 0 ? 6 : jour - 1')
  })

  it('n’affiche rien pour une semaine à zéro', () => {
    // Un gros « 0 min » sur le profil d'une famille qui vient de s'inscrire se
    // lit comme un reproche.
    const profil = code('src/screens/Profile.tsx')
    expect(profil).toContain('totalMinutes === 0')
    expect(profil).toContain('return null')
  })
})

describe('l’enregistrement et la rediffusion', () => {
  it('l’egress s’arrête avant que la salle soit vidée', () => {
    // Dans l'autre ordre, le fichier peut se terminer sur quelques secondes de
    // salle vide.
    const fermeture = bloc(
      "app.post('/live/sessions/:id/close'",
      'async function closeDanglingAttendance',
    )
    expect(fermeture.indexOf('stopRecording')).toBeLessThan(
      fermeture.indexOf('closeRoom'),
    )
  })

  it('ouvrir deux fois ne lance pas deux enregistrements', () => {
    // Un professeur dont le navigateur plante reclique. Un second egress
    // écrirait sur la même clé et perdrait la première moitié du cours.
    const ouverture = bloc(
      "app.post('/live/sessions/:id/open'",
      "app.post('/live/sessions/:id/close'",
    )
    expect(ouverture).toContain('if (!egressId && recordings && video)')
    expect(ouverture).toContain('alreadyOpen')
  })

  it('un échec d’enregistrement n’empêche pas le cours', () => {
    // Refuser d'ouvrir la salle parce qu'on ne peut pas enregistrer annulerait un
    // cours payé pour un confort.
    const ouverture = bloc(
      "app.post('/live/sessions/:id/open'",
      "app.post('/live/sessions/:id/close'",
    )
    expect(ouverture).toContain("etatEnregistrement = 'FAILED'")
    expect(ouverture).toContain("status: 'LIVE'")
  })

  it('le fichier part vers Cloudflare Stream par une URL signée et temporaire', () => {
    // Un dépôt public rendrait chaque séance téléchargeable par qui devine un
    // nom de fichier — et un nom dérivé d'un identifiant se devine.
    const transfert = worker.slice(
      worker.indexOf('async function handleEgressEnded'),
    )
    expect(transfert).toContain('recordings.presign(')
    expect(transfert).toContain('expiresInSeconds: 2 * 3600')
    expect(transfert).toContain('video.ingestFromUrl')
  })

  it('un webhook rejoué ne crée pas une seconde vidéo', () => {
    const transfert = worker.slice(
      worker.indexOf('async function handleEgressEnded'),
    )
    expect(transfert).toContain('if (seance.recording_video_id) return')
  })

  it('la rediffusion vérifie le paiement avant de signer', () => {
    const replay = bloc("app.get('/live/sessions/:id/replay'", 'app.get(\'/videos/:itemId/url\'')
    expect(replay).toContain("eq('status', 'CONFIRMED')")
    expect(replay).toContain('autorise')
    // Et l'ordre : le refus arrive avant toute signature. `playbackUrls` est le
    // seul appel qui émet un jeton de lecture — l'atteindre sans avoir refusé
    // reviendrait à signer l'accès à un cours non payé.
    expect(replay.indexOf('403')).toBeLessThan(replay.indexOf('playbackUrls'))
  })

  it('l’écran de rediffusion n’embarque pas de lecteur HLS', () => {
    // `hls.js` plus la gestion des qualités, de la reprise et des erreurs réseau
    // sur 90 minutes de vidéo : c'est le code qu'on écrit mal. Le lecteur de
    // Cloudflare Stream le fait déjà.
    expect(rediffusion).toContain('iframe')
    expect(rediffusion).not.toContain('hls')
    expect(rediffusion).not.toContain('Hls')
    const paquet = JSON.parse(readFileSync('package.json', 'utf-8'))
    expect(Object.keys(paquet.dependencies ?? {})).not.toContain('hls.js')
  })

  it('l’écran distingue les quatre états d’attente', () => {
    // « Indisponible » ne dit pas s'il faut attendre deux minutes, revenir demain
    // ou prévenir quelqu'un — et produit exactement l'appel au support qu'on
    // essaie d'éviter.
    for (const etat of ['RECORDING', 'TRANSFERRING', 'FAILED']) {
      expect(rediffusion).toContain(etat)
    }
    expect(rediffusion).toContain('Vérifier à nouveau')
  })
})

describe('la salle dit qu’elle enregistre', () => {
  it('le serveur transmet l’état dans la réponse du jeton', () => {
    // Quinze élèves mineurs filmés pendant 90 minutes : qu'ils le sachent n'est
    // pas une option d'affichage, et l'information doit venir du serveur plutôt
    // que d'une supposition de l'écran.
    const jeton = bloc(
      "app.post('/live/sessions/:id/token'",
      "app.post('/live/sessions/:id/open'",
    )
    expect(jeton).toContain('recording: seance.recording_status')
  })

  it('l’écran l’affiche à tout le monde, pas seulement au professeur', () => {
    const banniere = salle.slice(
      salle.indexOf("enregistrement === 'RECORDING'"),
    )
    expect(banniere).toContain('Cette séance est enregistrée')
    // Pas de garde sur le rôle autour de ce bandeau : il précède les contrôles
    // réservés au professeur.
    expect(salle.indexOf("enregistrement === 'RECORDING'")).toBeLessThan(
      salle.indexOf("role === 'teacher' ? ("),
    )
  })

  it('terminer la séance est un geste distinct de quitter', () => {
    // Un professeur peut sortir et revenir pendant une pause sans clore la
    // séance pour quinze élèves.
    expect(salle).toContain('Terminer la séance')
    expect(salle).toContain('window.confirm')
    expect(salle).toContain('api.closeRoom(id)')
  })
})

describe('une séance payée reste trouvable', () => {
  it('la famille a une liste de ses séances, passées comprises', () => {
    // Sans elle, une séance payée disparaît dès le lendemain : ni rediffusion, ni
    // trace de l'achat. Un cours acheté qu'on ne retrouve pas est un
    // remboursement demandé.
    expect(worker).toContain("app.get('/live/my-sessions'")
    const live = code('src/screens/Live.tsx')
    expect(live).toContain('api.mySessions()')
    expect(live).toContain('rediffusion')
  })

  it('une place non payée se voit', () => {
    // Elle est relâchée au bout de vingt minutes, et quelqu'un qui croit avoir
    // payé se présenterait à 18 h devant une porte fermée.
    const live = code('src/screens/Live.tsx')
    expect(live).toContain('paiement non confirmé')
  })

  it('la liste ne transporte pas l’identifiant de la vidéo', () => {
    // Il n'est pas lisible sans signature, et le faire circuler n'apporte rien
    // qu'une occasion de fuite.
    const mes = bloc("app.get('/live/my-sessions'", "app.get('/live/presence'")
    expect(mes).toContain('replay:')
    expect(mes).not.toContain('recording_video_id:')
  })
})
