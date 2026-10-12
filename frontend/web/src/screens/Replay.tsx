import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'

import { api } from '../api'
import type { SessionReplay } from '../api/types'
import { AppBar, Banner, Button, Skeleton } from '../components/ui'

/**
 * La rediffusion d'une séance.
 *
 * --- Pourquoi cet écran compte ici ---------------------------------------
 *
 * Une coupure de courant pendant le cours est la première raison de rater une
 * séance en Guinée, et elle n'a rien à voir avec l'élève. Sans rediffusion, un
 * cours payé est un cours perdu — et c'est au deuxième incident que la famille
 * arrête de payer. La rediffusion n'est donc pas un bonus : c'est ce qui rend
 * l'abonnement tenable sur un réseau électrique qui ne l'est pas.
 *
 * --- Pourquoi un `iframe` et non notre lecteur ---------------------------
 *
 * La vidéo est servie en HLS. Safari le lit nativement, Chrome et Firefox non :
 * il leur faudrait `hls.js`, plus la gestion des niveaux de qualité, de la
 * reprise après coupure et des erreurs réseau. Pour 90 minutes de vidéo sur une
 * ligne instable, c'est exactement le code qu'on écrit mal.
 *
 * Le lecteur de Cloudflare Stream fait déjà tout cela, depuis le même réseau
 * que la vidéo. Il nous reste la seule chose que personne ne peut faire à notre
 * place : **vérifier le paiement avant de signer l'adresse**. C'est le serveur
 * qui s'en charge, et cet écran ne reçoit un lien que lorsque le droit est
 * établi.
 */
export function Replay() {
  const { id = '' } = useParams()

  const [etat, setEtat] = useState<SessionReplay>()
  const [erreur, setErreur] = useState<string>()
  const [relecture, setRelecture] = useState(0)

  /*
   * Le module où commencer.
   *
   * Un élève qui a manqué le module 3 ne veut pas faire défiler 90 minutes. Le
   * repère est un paramètre de l'adresse du lecteur, donc changer de module
   * recharge l'`iframe` à la bonne seconde — sans quatre vidéos à produire, à
   * stocker et à signer.
   */
  const [depart, setDepart] = useState(0)

  useEffect(() => {
    let vivant = true
    setErreur(undefined)
    api
      .sessionReplay(id)
      .then((reponse) => {
        if (vivant) setEtat(reponse)
      })
      .catch((cause: unknown) => {
        if (!vivant) return
        setErreur(
          cause instanceof Error
            ? cause.message
            : 'La rediffusion n’a pas pu être lue.',
        )
      })
    return () => {
      vivant = false
    }
  }, [id, relecture])

  return (
    <>
      <AppBar title={etat?.title ?? 'Rediffusion'} onBack />
      <div className="screen stack stack--loose">
        {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

        {!etat && !erreur ? <Skeleton height={200} count={1} /> : null}

        {etat?.available && etat.embed ? (
          <>
            <div className="replay">
              <iframe
                className="replay__cadre"
                // `key` sur le départ : changer `src` seul ne fait pas toujours
                // recharger un `iframe`, et le module resterait au premier.
                key={depart}
                src={depart > 0 ? `${etat.embed}&t=${depart}` : etat.embed}
                title={etat.title ?? 'Rediffusion de la séance'}
                loading="lazy"
                allow="accelerometer; gyroscope; autoplay; encrypted-media; picture-in-picture; fullscreen"
                allowFullScreen
              />
            </div>
            {/*
                Les quatre modules, quand la séance a eu ses points de contrôle.
                Sans eux, pas de repère : on ne coupe pas au hasard, et une
                rediffusion sans chapitres vaut mieux qu'une rediffusion dont les
                chapitres mentent.
             */}
            {etat.chapters && etat.chapters.length > 0 ? (
              <div className="stack stack--tight">
                <strong className="small">Reprendre à</strong>
                <div className="row" style={{ gap: 'var(--espace-2)', flexWrap: 'wrap' }}>
                  {etat.chapters.map((chapitre) => (
                    <Button
                      key={chapitre.index}
                      variant={
                        chapitre.startSeconds === depart ? 'primary' : 'ghost'
                      }
                      onClick={() => setDepart(chapitre.startSeconds)}
                    >
                      {chapitre.label}
                    </Button>
                  ))}
                </div>
              </div>
            ) : null}

            {etat.startsAt ? (
              <p className="faint micro">
                Séance du {dateLisible(etat.startsAt)}.
              </p>
            ) : null}
            {/* Le lien est signé et temporaire : le dire évite qu'on le copie
                dans un groupe en croyant partager le cours. */}
            <p className="faint micro">
              Ce lien est personnel et expire au bout de quelques heures.
            </p>
          </>
        ) : null}

        {etat && !etat.available ? (
          <Attente etat={etat.status} onRelire={() => setRelecture((n) => n + 1)} />
        ) : null}
      </div>
    </>
  )
}

/**
 * Ce qu'on affiche quand il n'y a pas encore de vidéo.
 *
 * Quatre états et quatre phrases différentes, parce que « indisponible » ne dit
 * pas s'il faut attendre deux minutes, revenir demain, ou prévenir quelqu'un.
 * Une seule phrase pour les quatre produirait exactement l'appel au support
 * qu'on essaie d'éviter.
 */
function Attente({
  etat,
  onRelire,
}: {
  etat: SessionReplay['status']
  onRelire: () => void
}) {
  if (etat === 'RECORDING') {
    return (
      <Banner tone="accent">
        La séance est en cours. La rediffusion sera prête peu après la fin.
      </Banner>
    )
  }

  if (etat === 'TRANSFERRING') {
    return (
      <div className="stack stack--tight">
        <Banner tone="accent">
          La rediffusion est en préparation. Comptez quelques minutes après la fin
          du cours.
        </Banner>
        <Button variant="ghost" onClick={onRelire}>
          Vérifier à nouveau
        </Button>
      </div>
    )
  }

  if (etat === 'FAILED') {
    return (
      <Banner tone="warning">
        L’enregistrement de cette séance n’a pas abouti. Votre professeur peut
        reprendre les points manqués au prochain cours — signalez-le-lui.
      </Banner>
    )
  }

  return (
    <Banner tone="accent">
      Cette séance n’a pas d’enregistrement.
    </Banner>
  )
}

function dateLisible(iso: string): string {
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return iso
  return date.toLocaleDateString('fr-FR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  })
}
