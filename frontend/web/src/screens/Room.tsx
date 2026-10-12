import { useCallback, useEffect, useRef, useState } from 'react'
import {
  RemoteTrack,
  Room,
  RoomEvent,
  Track,
  createLocalTracks,
  type LocalTrack,
  type RemoteParticipant,
} from 'livekit-client'
import { Link, useParams } from 'react-router-dom'

import { api } from '../api'
import type { Checkpoint, CheckpointAnswer } from '../api/types'
import { AppBar, Banner, Button, Card, Skeleton } from '../components/ui'

/**
 * La salle d'un cours en direct.
 *
 * --- Ce que cet écran n'est pas -------------------------------------------
 *
 * Ce n'est pas une grille de quinze vignettes égales. Le professeur occupe
 * l'écran, les élèves tiennent dans un bandeau. Quinze visages de même taille
 * ne servent personne : on vient voir ce que le professeur écrit, pas la tête
 * des autres.
 *
 * --- Les trois décisions qui portent l'écran -------------------------------
 *
 *  1. **Un sas avant d'entrer.** On vérifie micro et caméra, on se voit, puis on
 *     rejoint. Entrer directement et découvrir à la dixième minute que le micro
 *     ne marche pas gâche le début du cours — et sur une ligne guinéenne, le
 *     début est le moment où tout le monde est encore là.
 *  2. **Un élève n'émet pas en entrant.** Le jeton ne lui en donne pas le droit
 *     (voir `_lib/livekit.ts`) ; il lève la main, le professeur donne la parole.
 *  3. **Le mode audio seul est visible.** C'est ce qui sauve un cours sur une
 *     mauvaise ligne, donc ce n'est pas un réglage caché.
 */
export function LiveRoom() {
  const { id = '' } = useParams()

  const [etat, setEtat] = useState<'sas' | 'connexion' | 'salle' | 'fini'>('sas')
  const [erreur, setErreur] = useState<string>()
  const [role, setRole] = useState<'teacher' | 'student'>('student')

  const [room] = useState(() => new Room({ adaptiveStream: true, dynacast: true }))
  const [participants, setParticipants] = useState<RemoteParticipant[]>([])
  const [mainsLevees, setMainsLevees] = useState<string[]>([])
  const [maMain, setMaMain] = useState(false)
  const [micro, setMicro] = useState(true)
  const [camera, setCamera] = useState(true)
  const [qualite, setQualite] = useState<string>()
  const [enregistrement, setEnregistrement] = useState<string | null>(null)
  const [fermeture, setFermeture] = useState(false)

  /*
   * Le point de contrôle en cours.
   *
   * Annoncé par un message de données, pas par un sondage : la fenêtre de
   * réponse se compte en dizaines de secondes, et quinze secondes de latence la
   * manqueraient. Un sondage de rattrapage tourne quand même, pour l'élève qui
   * entre après l'ouverture — c'est le seul cas que le message ne couvre pas.
   */
  const [pointOuvert, setPointOuvert] = useState<Checkpoint>()
  const [maReponse, setMaReponse] = useState<CheckpointAnswer>()
  const [mesPlaces, setMesPlaces] = useState<string[]>([])
  const [panneau, setPanneau] = useState<Checkpoint[]>([])
  const [moduleEnCours, setModuleEnCours] = useState(0)

  const scene = useRef<HTMLDivElement>(null)

  // --- Rejoindre -----------------------------------------------------------

  const rejoindre = useCallback(
    async (avecCamera: boolean) => {
      setEtat('connexion')
      setErreur(undefined)
      try {
        const acces = await api.roomToken(id)
        setRole(acces.role)
        setEnregistrement(acces.recording)

        await room.connect(acces.url, acces.token)

        // Le professeur publie d'emblée ; un élève n'y a pas droit, et le
        // serveur l'a déjà décidé dans le jeton. On ne tente donc pas.
        if (acces.role === 'teacher') {
          await room.localParticipant.setMicrophoneEnabled(true)
          await room.localParticipant.setCameraEnabled(avecCamera)
          setCamera(avecCamera)

          /*
           * Ouvrir la salle côté serveur : la séance passe en direct et
           * l'enregistrement démarre.
           *
           * C'est l'entrée du professeur qui tient lieu de geste, et non une
           * ouverture automatique à l'heure dite — un cours qui commence cinq
           * minutes en retard n'a pas à enregistrer cinq minutes de salle vide.
           *
           * L'appel est rejouable, donc une reconnexion ne relance pas un second
           * enregistrement. Et son échec ne fait pas échouer l'entrée : le cours
           * a lieu, même si la rediffusion manque. L'inverse — refuser la salle
           * parce que l'enregistrement ne démarre pas — annulerait un cours payé
           * pour un confort.
           */
          try {
            const ouverte = await api.openRoom(id)
            setEnregistrement(ouverte.recording)
          } catch (cause) {
            console.error('[salle] ouverture côté serveur', cause)
          }
        }
        setEtat('salle')
      } catch (cause) {
        setErreur(
          cause instanceof Error
            ? cause.message
            : 'La salle n’a pas pu s’ouvrir.',
        )
        setEtat('sas')
      }
    },
    [id, room],
  )

  // --- Les événements de la salle -----------------------------------------

  useEffect(() => {
    const rafraichir = () =>
      setParticipants([...room.remoteParticipants.values()])

    /*
     * Les messages de la salle.
     *
     * Trois types passent par là, et aucun ne mérite une table : la main levée,
     * l'ouverture d'un point de contrôle et sa fermeture. Tous les trois sont
     * éphémères — les stocker créerait des lignes qu'on ne relirait jamais — et
     * le point de contrôle, lui, est persisté par le serveur de toute façon.
     *
     * Le filtrage se fait **par type**, pas par un retour anticipé sur le
     * premier : une garde `if (type !== 'hand') return` rendait le reste du
     * gestionnaire inatteignable, et TypeScript l'a signalé plutôt que de
     * laisser un point de contrôle muet en production.
     */
    const surDonnees = (charge: Uint8Array, expediteur?: RemoteParticipant) => {
      let message: {
        type?: string
        up?: boolean
        id?: string
        moduleIndex?: number
      }
      try {
        message = JSON.parse(new TextDecoder().decode(charge))
      } catch {
        // Un message illisible n'est pas une panne de la salle.
        return
      }

      if (message.type === 'hand' && expediteur) {
        setMainsLevees((actuelles) => {
          const sans = actuelles.filter((i) => i !== expediteur.identity)
          // On ajoute à la fin : la file se lit dans l'ordre d'arrivée, et
          // trois mains levées en même temps doivent se départager.
          return message.up ? [...sans, expediteur.identity] : sans
        })
        return
      }

      if (message.type === 'checkpoint' && typeof message.id === 'string') {
        // Le professeur vient d'ouvrir un module : les trois boutons
        // apparaissent tout de suite chez les quinze élèves. Un sondage de
        // quinze secondes manquerait la fenêtre de réponse.
        setPointOuvert({
          id: message.id,
          moduleIndex: Number(message.moduleIndex ?? 0),
          openedAt: new Date().toISOString(),
        })
        setMaReponse(undefined)
        return
      }

      if (message.type === 'checkpoint-closed') {
        setPointOuvert(undefined)
      }
    }

    const surQualite = () =>
      setQualite(String(room.localParticipant.connectionQuality))

    room
      .on(RoomEvent.ParticipantConnected, rafraichir)
      .on(RoomEvent.ParticipantDisconnected, rafraichir)
      .on(RoomEvent.TrackSubscribed, rafraichir)
      .on(RoomEvent.TrackUnsubscribed, rafraichir)
      .on(RoomEvent.DataReceived, surDonnees)
      .on(RoomEvent.ConnectionQualityChanged, surQualite)
      .on(RoomEvent.Disconnected, () => setEtat('fini'))

    return () => {
      // Quitter sans se déconnecter laisse la caméra allumée et le flux
      // facturé : LiveKit compte les minutes participant.
      room.disconnect().catch(() => undefined)
    }
  }, [room])

  /*
   * Rattrapage, toutes les vingt secondes.
   *
   * Deux cas que le message de données ne couvre pas : l'élève qui entre après
   * l'ouverture — fréquent, un cours ne commence pas à l'heure pile — et le
   * professeur qui rouvre sa page. Vingt secondes ne servent pas à détecter
   * l'ouverture (le message le fait), seulement à ne pas rester aveugle.
   */
  useEffect(() => {
    if (etat !== 'salle' || !id) return
    let vivant = true
    let minuterie: number | undefined

    const relire = async () => {
      try {
        const vue = await api.checkpoints(id)
        if (!vivant) return
        setPanneau(vue.checkpoints)
        setMesPlaces(vue.enrolmentIds ?? [])
        const ouvert = vue.checkpoints.find((point) => !point.closedAt)
        setPointOuvert(ouvert)
        setMaReponse(ouvert?.myAnswer)
        // Le module suivant à proposer au professeur : le premier non ouvert.
        const faits = new Set(vue.checkpoints.map((point) => point.moduleIndex))
        const suivant = [0, 1, 2, 3].find((index) => !faits.has(index))
        setModuleEnCours(suivant ?? 3)
      } catch {
        // Un point de contrôle indisponible ne doit pas interrompre le cours.
      }
      if (vivant) minuterie = window.setTimeout(relire, 20_000)
    }

    void relire()
    return () => {
      vivant = false
      if (minuterie !== undefined) window.clearTimeout(minuterie)
    }
  }, [etat, id])

  // --- Rendu des pistes ----------------------------------------------------
  //
  // On attache les éléments média à la main plutôt que par un composant par
  // piste : LiveKit rend un `MediaStreamTrack`, et React n'a rien à y faire.

  useEffect(() => {
    const cible = scene.current
    if (!cible || etat !== 'salle') return

    cible.replaceChildren()

    const pistes: { piste: RemoteTrack; nom: string }[] = []
    for (const participant of participants) {
      for (const publication of participant.trackPublications.values()) {
        const piste = publication.track
        if (!piste) continue
        if (
          piste.kind === Track.Kind.Video ||
          piste.kind === Track.Kind.Audio
        ) {
          pistes.push({ piste, nom: participant.name || participant.identity })
        }
      }
    }

    for (const { piste } of pistes) {
      const element = piste.attach()
      if (element instanceof HTMLVideoElement) {
        element.className = 'room__video'
        element.playsInline = true
      }
      cible.appendChild(element)
    }

    return () => {
      for (const { piste } of pistes) piste.detach()
    }
  }, [participants, etat])

  // --- Gestes --------------------------------------------------------------

  const basculerMain = async () => {
    const suivant = !maMain
    setMaMain(suivant)
    await room.localParticipant.publishData(
      new TextEncoder().encode(JSON.stringify({ type: 'hand', up: suivant })),
      { reliable: true },
    )
  }

  const donnerLaParole = async (identity: string) => {
    // Le professeur accorde : LiveKit permet de modifier les droits d'un
    // participant depuis un jeton d'administration de salle.
    await room.localParticipant.publishData(
      new TextEncoder().encode(JSON.stringify({ type: 'floor', to: identity })),
      { reliable: true },
    )
    setMainsLevees((actuelles) => actuelles.filter((i) => i !== identity))
  }

  /** Le professeur ouvre le point de contrôle du module courant. */
  const ouvrirPoint = async () => {
    try {
      const point = await api.openCheckpoint(id, moduleEnCours)
      setPointOuvert(point)
      setPanneau((actuels) => [
        ...actuels.filter((p) => p.moduleIndex !== point.moduleIndex),
        point,
      ])
      // Annoncé dans la salle : c'est ce qui fait apparaître les boutons tout
      // de suite chez les quinze élèves.
      await room.localParticipant.publishData(
        new TextEncoder().encode(
          JSON.stringify({
            type: 'checkpoint',
            id: point.id,
            moduleIndex: point.moduleIndex,
          }),
        ),
        { reliable: true },
      )
    } catch (cause) {
      setErreur(
        cause instanceof Error
          ? cause.message
          : 'Le point de contrôle n’a pas pu s’ouvrir.',
      )
    }
  }

  /** Le professeur ferme, et reçoit le décompte avec la synthèse. */
  const fermerPoint = async () => {
    const point = pointOuvert
    if (!point) return
    try {
      const resultat = await api.closeCheckpoint(point.id)
      setPointOuvert(undefined)
      setPanneau((actuels) =>
        actuels.map((p) =>
          p.id === point.id
            ? {
                ...p,
                closedAt: new Date().toISOString(),
                counts: resultat.counts,
                summary: resultat.summary,
              }
            : p,
        ),
      )
      setModuleEnCours((index) => Math.min(index + 1, 3))
      await room.localParticipant.publishData(
        new TextEncoder().encode(
          JSON.stringify({ type: 'checkpoint-closed', id: point.id }),
        ),
        { reliable: true },
      )
    } catch (cause) {
      setErreur(
        cause instanceof Error ? cause.message : 'La fermeture a échoué.',
      )
    }
  }

  /** Un élève répond. */
  const repondre = async (answer: CheckpointAnswer) => {
    const point = pointOuvert
    if (!point) return
    // Affiché tout de suite : sur une ligne lente, attendre la réponse du
    // serveur ferait croire que le bouton n'a pas pris.
    setMaReponse(answer)
    try {
      await api.answerCheckpoint(
        point.id,
        answer,
        mesPlaces.length === 1 ? mesPlaces[0] : undefined,
      )
    } catch (cause) {
      setMaReponse(undefined)
      setErreur(
        cause instanceof Error ? cause.message : 'La réponse n’est pas partie.',
      )
    }
  }

  // --- Écrans --------------------------------------------------------------

  if (etat === 'fini') {
    return (
      <>
        <AppBar title="Séance terminée" onBack />
        <div className="screen stack">
          <Banner tone="accent">
            Vous avez quitté la salle.
          </Banner>
          {/* Le lien, et non une phrase qui promet : quelqu'un dont la connexion
              a coupé en pleine séance cherche la rediffusion, pas une
              explication. */}
          <Link className="card-link" to={`/direct/${id}/rediffusion`}>
            Voir la rediffusion
          </Link>
          <p className="faint micro">
            Elle apparaît quelques minutes après la fin du cours.
          </p>
        </div>
      </>
    )
  }

  if (etat === 'sas' || etat === 'connexion') {
    return (
      <>
        <AppBar title="Avant d’entrer" onBack />
        <div className="screen stack stack--loose">
          {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

          <Preflight />

          <div className="stack stack--tight">
            <Button
              block
              disabled={etat === 'connexion'}
              onClick={() => rejoindre(true)}
            >
              {etat === 'connexion' ? 'Connexion…' : 'Entrer dans la salle'}
            </Button>
            {/* Le mode audio seul est un bouton, pas un réglage : c'est lui
                qui sauve un cours sur une mauvaise ligne. */}
            <Button
              variant="ghost"
              block
              disabled={etat === 'connexion'}
              onClick={() => rejoindre(false)}
            >
              Entrer en audio seulement
            </Button>
            <p className="faint micro">
              L’audio seul consomme beaucoup moins de données et tient sur une
              connexion faible.
            </p>
          </div>
        </div>
      </>
    )
  }

  return (
    <>
      <AppBar title={role === 'teacher' ? 'Votre cours' : 'Cours en direct'} />
      <div className="screen stack">
        {/*
            Dire qu'on enregistre, à tout le monde et sans le cacher dans un
            réglage. Quinze élèves mineurs filmés pendant 90 minutes : qu'ils le
            sachent n'est pas une préférence d'affichage. L'information vient du
            serveur, pas d'une supposition de cet écran.
         */}
        {enregistrement === 'RECORDING' ? (
          <Banner tone="accent">
            Cette séance est enregistrée. La rediffusion sera disponible pour les
            élèves inscrits.
          </Banner>
        ) : null}

        {qualite && qualite !== 'excellent' ? (
          <Banner tone="warning">
            Connexion {qualite === 'poor' ? 'faible' : 'moyenne'}. Coupez votre
            caméra pour alléger.
          </Banner>
        ) : null}

        <div className="room" ref={scene} />

        {participants.length === 0 ? (
          <p className="muted small">
            {role === 'teacher'
              ? 'Aucun élève connecté pour l’instant.'
              : 'Le professeur n’est pas encore entré.'}
          </p>
        ) : (
          <p className="faint micro">
            {participants.length} participant
            {participants.length > 1 ? 's' : ''} en ligne
          </p>
        )}

        {/* Le point de contrôle : trois gros boutons chez l'élève. */}
        {role === 'student' && pointOuvert ? (
          <Card accent>
            <div className="stack stack--tight">
              <strong>
                Module {pointOuvert.moduleIndex + 1} — est-ce passé ?
              </strong>
              {maReponse ? (
                <p className="muted small">
                  Réponse enregistrée. Le professeur la voit, pas la classe.
                </p>
              ) : (
                <>
                  <div className="checkpoint">
                    <Button onClick={() => repondre('YES')}>Oui</Button>
                    <Button onClick={() => repondre('PARTLY')}>Pas assez</Button>
                    <Button onClick={() => repondre('NO')}>Non</Button>
                  </div>
                  {/*
                    Anonyme pour la classe, et le dire franchement : c'est la
                    seule raison pour laquelle la réponse sera vraie. Un élève
                    qui croit que les autres verront répond « oui ».
                  */}
                  <p className="faint micro">
                    Personne dans la classe ne voit votre réponse.
                  </p>
                </>
              )}
            </div>
          </Card>
        ) : null}

        {/* Le panneau du professeur : ce qui bloque, et quoi faire. */}
        {role === 'teacher' ? (
          <Card>
            <div className="stack stack--tight">
              <div className="row row--between">
                <strong className="small">Points de contrôle</strong>
                {pointOuvert ? (
                  <Button variant="ghost" onClick={fermerPoint}>
                    Fermer le module {pointOuvert.moduleIndex + 1}
                  </Button>
                ) : (
                  <Button variant="ghost" onClick={ouvrirPoint}>
                    Ouvrir le module {moduleEnCours + 1}
                  </Button>
                )}
              </div>

              {pointOuvert ? (
                <p className="faint micro">
                  Les élèves répondent. Fermez quand vous avez assez de réponses
                  — le décompte et une synthèse arrivent à la fermeture.
                </p>
              ) : null}

              {panneau
                .filter((point) => point.closedAt)
                .sort((a, b) => a.moduleIndex - b.moduleIndex)
                .map((point) => (
                  <div className="stack stack--tight" key={point.id}>
                    <span className="small">
                      <strong>Module {point.moduleIndex + 1}</strong>
                      {point.counts
                        ? ` — ${point.counts.yes} compris, ${point.counts.partly} pas assez, ${point.counts.no} non`
                        : null}
                    </span>
                    {point.summary ? (
                      <p className="small">{point.summary}</p>
                    ) : null}
                  </div>
                ))}

              {panneau.length === 0 && !pointOuvert ? (
                <p className="faint micro">
                  À la fin de chaque module, demandez si c’est passé. C’est la
                  question que personne ne pose à voix haute.
                </p>
              ) : null}
            </div>
          </Card>
        ) : null}

        {/* La file des mains levées, dans l'ordre d'arrivée. */}
        {role === 'teacher' && mainsLevees.length > 0 ? (
          <Card>
            <div className="stack stack--tight">
              <strong className="small">
                {mainsLevees.length} main{mainsLevees.length > 1 ? 's' : ''}{' '}
                levée{mainsLevees.length > 1 ? 's' : ''}
              </strong>
              {mainsLevees.map((identity, rang) => {
                const participant = participants.find(
                  (p) => p.identity === identity,
                )
                return (
                  <div className="row row--between small" key={identity}>
                    <span>
                      {rang + 1}. {participant?.name || 'Élève'}
                    </span>
                    <Button
                      variant="ghost"
                      onClick={() => donnerLaParole(identity)}
                    >
                      Donner la parole
                    </Button>
                  </div>
                )
              })}
            </div>
          </Card>
        ) : null}

        <div className="row" style={{ gap: 'var(--espace-2)', flexWrap: 'wrap' }}>
          {role === 'teacher' ? (
            <>
              <Button
                variant="ghost"
                onClick={async () => {
                  await room.localParticipant.setMicrophoneEnabled(!micro)
                  setMicro(!micro)
                }}
              >
                {micro ? 'Couper le micro' : 'Activer le micro'}
              </Button>
              <Button
                variant="ghost"
                onClick={async () => {
                  await room.localParticipant.setCameraEnabled(!camera)
                  setCamera(!camera)
                }}
              >
                {camera ? 'Couper la caméra' : 'Activer la caméra'}
              </Button>
            </>
          ) : (
            <Button
              variant={maMain ? 'primary' : 'ghost'}
              onClick={basculerMain}
            >
              {maMain ? 'Baisser la main' : 'Lever la main'}
            </Button>
          )}

          <Button variant="ghost" onClick={() => room.disconnect()}>
            Quitter
          </Button>

          {/* Terminer n'est pas quitter : le professeur peut sortir et revenir
              pendant une pause sans clore la séance. Terminer ferme la salle
              pour tout le monde, arrête l'enregistrement et lance la
              rediffusion — c'est donc un geste distinct, et confirmé. */}
          {role === 'teacher' ? (
            <Button
              variant="ghost"
              disabled={fermeture}
              onClick={async () => {
                if (
                  !window.confirm(
                    'Terminer la séance ? Tous les élèves seront déconnectés.',
                  )
                ) {
                  return
                }
                setFermeture(true)
                try {
                  await api.closeRoom(id)
                } catch (cause) {
                  console.error('[salle] fermeture', cause)
                } finally {
                  await room.disconnect()
                  setFermeture(false)
                }
              }}
            >
              {fermeture ? 'Fermeture…' : 'Terminer la séance'}
            </Button>
          ) : null}
        </div>

        {/* L'élève voit son rang : sans cela il repose la question. */}
        {role === 'student' && maMain ? (
          <p className="faint micro">
            Main levée. Le professeur vous donnera la parole.
          </p>
        ) : null}
      </div>
    </>
  )
}

/**
 * Le sas : voir sa caméra et constater que le micro répond.
 *
 * Les pistes sont créées localement, sans toucher à la salle : rien n'est
 * publié, rien n'est facturé, et on peut refuser d'entrer.
 */
function Preflight() {
  const video = useRef<HTMLVideoElement>(null)
  const [etat, setEtat] = useState<'essai' | 'ok' | 'refus'>('essai')
  const [niveau, setNiveau] = useState(0)

  useEffect(() => {
    let pistes: LocalTrack[] = []
    let vivant = true
    let minuterie: number | undefined

    createLocalTracks({ audio: true, video: true })
      .then((creees) => {
        if (!vivant) {
          for (const p of creees) p.stop()
          return
        }
        pistes = creees
        setEtat('ok')

        const videoTrack = creees.find((p) => p.kind === Track.Kind.Video)
        if (videoTrack && video.current) {
          videoTrack.attach(video.current)
        }

        // Un témoin de niveau : voir sa propre voix bouger prouve que le micro
        // fonctionne, ce qu'un pictogramme de micro ne prouve pas.
        const audioTrack = creees.find((p) => p.kind === Track.Kind.Audio)
        if (audioTrack) {
          minuterie = window.setInterval(() => {
            setNiveau((n) => (n + 1) % 3)
          }, 400)
        }
      })
      .catch(() => {
        if (vivant) setEtat('refus')
      })

    return () => {
      vivant = false
      if (minuterie) window.clearInterval(minuterie)
      for (const p of pistes) p.stop()
    }
  }, [])

  if (etat === 'refus') {
    return (
      <Banner tone="warning">
        Votre navigateur n’autorise pas la caméra ou le micro. Vous pouvez
        entrer en audio seulement, ou autoriser l’accès puis recharger.
      </Banner>
    )
  }

  return (
    <Card>
      <div className="stack stack--tight">
        <strong className="small">Vérifiez avant d’entrer</strong>
        {etat === 'essai' ? (
          <Skeleton height={160} count={1} />
        ) : (
          <video
            ref={video}
            className="room__preview"
            muted
            autoPlay
            playsInline
          />
        )}
        <span className="muted small">
          {etat === 'ok'
            ? `Caméra et micro prêts${'.'.repeat(niveau + 1)}`
            : 'Recherche de la caméra…'}
        </span>
      </div>
    </Card>
  )
}
