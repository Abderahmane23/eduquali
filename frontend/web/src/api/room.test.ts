import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * La salle d'un cours en direct.
 *
 * LiveKit n'a aucune notion de compte : il fait confiance au jeton que nous
 * signons. **Tout le contrôle d'accès à une classe payante tient donc dans le
 * point d'entrée qui émet ce jeton**, et c'est ce qui est vérifié ici en
 * premier.
 */
const code = (chemin: string) =>
  readFileSync(chemin, 'utf-8')
    .replace(/\r\n/g, '\n')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^[ \t]*\/\/.*$/gm, '')

const worker = code('../../backend/api/[[...route]].ts')
const livekit = code('../../backend/api/_lib/livekit.ts')
const ecran = code('src/screens/Room.tsx')

const tokenEndpoint = worker.slice(
  worker.indexOf("app.post('/live/sessions/:id/token'"),
  worker.indexOf("app.get('/videos/:itemId/url'"),
)

describe('le jeton d’entrée', () => {
  it('exige une place payée, pas seulement réservée', () => {
    // Une place retenue sans paiement expire au bout de vingt minutes. Ouvrir
    // la salle sur une réservation non payée reviendrait à donner le cours.
    expect(tokenEndpoint).toContain("eq('status', 'CONFIRMED')")
    expect(tokenEndpoint).toContain('n’est pas encore payee')
  })

  it('n’ouvre que dans la fenêtre de la séance', () => {
    // Un jeton émis trois jours avant serait une porte ouverte trois jours.
    expect(tokenEndpoint).toContain('15 * 60_000')
    expect(tokenEndpoint).toContain('30 * 60_000')
    expect(tokenEndpoint).toContain('La salle ouvre quinze minutes avant')
    expect(tokenEndpoint).toContain('Cette seance est terminee')
  })

  it('expire avec la fenêtre, jamais au-delà', () => {
    expect(tokenEndpoint).toContain('ttlSeconds: Math.max(')
    expect(tokenEndpoint).toContain('fermeture - maintenant')
  })

  it('distingue le professeur du cours d’un autre professeur', () => {
    // Comparer les rôles ne suffirait pas : un autre professeur reste un
    // spectateur dans une classe qui n'est pas la sienne.
    expect(tokenEndpoint).toContain('estLeProfesseur')
    expect(tokenEndpoint).toContain('prof.id === cours.teacher_id')
  })

  it('refuse une séance annulée', () => {
    expect(tokenEndpoint).toContain("seance.status === 'CANCELLED'")
  })
})

describe('les droits dans la salle', () => {
  it('un élève ne publie pas en entrant', () => {
    // Donner caméra et micro à quinze adolescents dès l'entrée rend le cours
    // impossible à tenir. Le droit est refusé dans le jeton, donc le client ne
    // peut pas s'en passer.
    const joinToken = livekit.slice(
      livekit.indexOf('async joinToken'),
      livekit.indexOf('private serviceToken'),
    )
    expect(joinToken).toContain('canPublish: professeur')
    expect(joinToken).toContain('roomAdmin: professeur')
    // Les données restent ouvertes : c'est par là que passe la main levée.
    expect(joinToken).toContain('canPublishData: true')
  })

  it('l’écran ne tente pas de publier pour un élève', () => {
    // Tenter puis échouer afficherait une erreur de permission à quelqu'un qui
    // n'a rien demandé.
    expect(ecran).toContain("acces.role === 'teacher'")
  })

  it('le jeton tolère une horloge décalée', () => {
    // L'horloge d'un téléphone guinéen n'est pas toujours juste, et un jeton
    // « pas encore valable » se lit comme une panne.
    expect(livekit).toContain('nbf: maintenant - 60')
  })
})

describe('la main levée', () => {
  it('est une file, pas une alerte', () => {
    // Trois mains levées en même temps doivent se lire dans l'ordre d'arrivée.
    expect(ecran).toContain('mainsLevees')
    expect(ecran).toContain('[...sans, expediteur.identity]')
    // L'élève voit son rang, sinon il repose la question.
    expect(ecran).toMatch(/rang \+ 1/)
  })

  it('passe par un message de données, sans table', () => {
    // Un état éphémère stocké en base serait une table qu'on ne relirait
    // jamais.
    expect(ecran).toContain('publishData')
    expect(ecran).toContain("type: 'hand'")
  })
})

describe('entrer dans la salle', () => {
  it('un sas précède l’entrée', () => {
    // Entrer directement et découvrir à la dixième minute que le micro ne
    // marche pas gâche le début du cours — le moment où tout le monde est là.
    expect(ecran).toContain('Preflight')
    expect(ecran).toContain('createLocalTracks')
    expect(ecran).toContain('Vérifiez avant d’entrer')
  })

  it('le mode audio seul est un bouton, pas un réglage caché', () => {
    // C'est lui qui sauve un cours sur une mauvaise ligne.
    expect(ecran).toContain('Entrer en audio seulement')
    expect(ecran).toContain('rejoindre(false)')
  })

  it('les pistes du sas sont arrêtées en sortant', () => {
    // Une caméra laissée allumée après avoir quitté l'écran est une lumière
    // rouge que personne ne comprend.
    const preflight = ecran.slice(ecran.indexOf('function Preflight'))
    expect(preflight).toContain('p.stop()')
  })

  it('quitter la salle déconnecte vraiment', () => {
    // LiveKit compte les minutes participant : une salle qu'on ne quitte pas
    // continue d'être facturée.
    expect(ecran).toContain('room.disconnect()')
  })
})

describe('le poids du client vidéo', () => {
  it('n’est chargé qu’en entrant dans une salle', () => {
    // LiveKit pèse ~150 ko compressés. Un visiteur qui parcourt le catalogue
    // n'a aucune raison de les télécharger.
    const app = code('src/App.tsx')
    expect(app).toContain("import('./screens/Room')")
    expect(app).toContain('lazy(')

    // Et aucun autre écran ne l'importe, ce qui le ferait entrer dans un
    // morceau partagé.
    for (const fichier of [
      'src/screens/Live.tsx',
      'src/screens/Courses.tsx',
      'src/App.tsx',
    ]) {
      expect(code(fichier)).not.toContain("from 'livekit-client'")
    }
  })
})
