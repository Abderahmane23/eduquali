import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'

import { api } from '../api'
import type { LivePresence } from '../api/types'

/**
 * « Fatoumata suit Mathématiques — en direct depuis 23 min ».
 *
 * --- Pourquoi ce bandeau existe -------------------------------------------
 *
 * C'est la fonction qui justifie l'abonnement d'un parent. Il ne demande pas un
 * tableau de bord : il demande, à 18 h 20, si son enfant est bien en cours. Une
 * phrase à laquelle il peut répondre en un regard vaut mieux qu'un écran de
 * statistiques qu'il n'ouvrira pas.
 *
 * --- La limite, qui est tenue ici et dans le schéma ----------------------
 *
 * **Jamais la caméra de l'enfant.** C'est une présence, pas une surveillance
 * vidéo. Le serveur ne rend aucune image (`/live/presence` ne renvoie qu'un
 * prénom, une matière et des minutes), et ce composant n'en demande aucune. La
 * distinction se tient dans le dessin comme dans le code, et c'est volontaire :
 * un parent qui pourrait regarder son enfant pendant le cours changerait la
 * nature de ce qu'on vend, et les adolescents cesseraient de lever la main.
 *
 * --- Pourquoi un sondage et non le temps réel ----------------------------
 *
 * Supabase Realtime maintiendrait une connexion WebSocket ouverte sur toutes les
 * pages du site, pour une information qui change toutes les quelques minutes. Sur
 * une ligne guinéenne payée au mégaoctet, un appel de quelques centaines
 * d'octets toutes les trente secondes coûte moins — et se reprend tout seul
 * après une coupure, ce qu'une connexion persistante ne fait pas gratuitement.
 */
const INTERVALLE_MS = 30_000

export function PresenceBanner() {
  const [presences, setPresences] = useState<LivePresence[]>([])

  useEffect(() => {
    let vivant = true
    let minuterie: number | undefined

    const relire = async () => {
      try {
        const lignes = await api.livePresence()
        if (vivant) setPresences(lignes)
      } catch {
        /*
         * Silence volontaire. Ce bandeau est un supplément : un compte
         * enseignant, un backend non configuré ou une coupure réseau le font
         * échouer, et aucune de ces situations ne mérite un message d'erreur en
         * haut de chaque page. L'absence d'information est l'affichage correct.
         */
        if (vivant) setPresences([])
      }
      if (vivant) minuterie = window.setTimeout(relire, INTERVALLE_MS)
    }

    void relire()
    return () => {
      vivant = false
      if (minuterie !== undefined) window.clearTimeout(minuterie)
    }
  }, [])

  if (presences.length === 0) return null

  return (
    <div className="presence" role="status">
      {presences.map((presence) => (
        <Link
          className="presence__ligne"
          key={presence.id}
          to={`/direct/${presence.sessionId}/salle`}
        >
          <span className="presence__point" aria-hidden="true" />
          <span className="presence__texte">
            <strong>{presence.childName ?? 'Votre place'}</strong> suit{' '}
            {presence.subjectName ?? presence.courseTitle ?? 'un cours'}
            {' — '}
            <span className="presence__duree">{duree(presence.minutes)}</span>
          </span>
        </Link>
      ))}
    </div>
  )
}

/**
 * « depuis 23 min », « depuis 1 h 05 ».
 *
 * Les minutes viennent du serveur et non de l'horloge du navigateur : celle d'un
 * téléphone n'est pas toujours juste, et ce chiffre est celui sur lequel un
 * parent juge si l'abonnement sert à quelque chose.
 */
function duree(minutes: number): string {
  if (minutes < 1) return 'vient d’entrer'
  if (minutes < 60) return `en direct depuis ${minutes} min`
  const heures = Math.floor(minutes / 60)
  const reste = minutes % 60
  return `en direct depuis ${heures} h ${String(reste).padStart(2, '0')}`
}
