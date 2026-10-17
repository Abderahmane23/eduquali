import { useEffect, useRef, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  discussion,
  serveurDisponible,
  type Groupe,
  type MessageGroupe,
} from '../api/server'
import { useSession } from '../app/session'
import { Tile } from '../components/kit'
import {
  Banner,
  Button,
  EmptyState,
  Icon,
  Skeleton,
  TextInput,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'
import { relative } from '../lib/format'

/**
 * La messagerie.
 *
 * --- Pourquoi c'est la page la plus importante des cinq -----------------
 *
 * Le téléphone et le courriel sont volontairement cachés par RLS jusqu'à la
 * mise en relation (§30). Un professeur qui n'a que le site était donc
 * **injoignable** : un parent intéressé n'avait aucun moyen de le contacter,
 * et réciproquement. Le marché ne se nouait pas.
 *
 * --- Il n'y a ni invitation ni code de groupe --------------------------
 *
 * Un groupe n'existe qu'autour de quelque chose qui existe déjà — un cours en
 * direct, un contrat — et ses membres sont ceux que cette chose lie. Il n'y a
 * donc pas de bouton « créer un groupe », et c'est voulu : pour un produit
 * qui traite des mineurs, c'est la propriété qui décide. Une personne perd
 * l'accès au moment où elle perd la relation, sans que personne y pense.
 *
 * On ne peut donc pas créer un groupe « entre amis ». Le prix est assumé — ce
 * serait une tout autre responsabilité, et la modération n'existe pas encore.
 */
export function Messages() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const groupes = useAsync(() => discussion.groupes(), [])

  if (!serveurDisponible) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Messages</h1>
        <Banner tone="warning">
          La messagerie passe par le serveur EduQuali, qui n’est pas relié à ce
          site.
        </Banner>
      </div>
    )
  }

  if (groupes.loading) {
    return (
      <div className="screen">
        <Skeleton height={72} count={4} />
      </div>
    )
  }

  if (groupes.error) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Messages</h1>
        <Banner tone="warning">{groupes.error}</Banner>
      </div>
    )
  }

  const liste = groupes.data?.groups ?? []

  if (liste.length === 0) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Messages</h1>
        <EmptyState
          icon="chat"
          title="Aucune discussion"
          message="Un groupe s’ouvre tout seul autour d’un cours en direct ou d’un contrat signé : vous et les familles inscrites. Publiez un cours, ou acceptez une demande de cours à domicile, et la discussion apparaîtra ici."
        />
      </div>
    )
  }

  // Sur un téléphone, ouvrir un fil remplace la liste ; sur un ordinateur les
  // deux tiennent côte à côte, et c'est le CSS qui en décide. Le JSX porte
  // donc toujours les deux — un rendu conditionnel sur la largeur de la
  // fenêtre se trompe au premier redimensionnement.
  const choisi = id ?? liste[0]?.id

  return (
    /*
      `data-ouvert` dit au CSS laquelle des deux colonnes se voit sous
      1 024 px. Le JSX rend toujours les deux — un rendu conditionnel sur la
      largeur de la fenetre se trompe au premier redimensionnement — et c'est
      la requete media qui decide.
    */
    <div className="screen chat" data-ouvert={id ? 'true' : undefined}>
      <div className="chat__list">
        {liste.map((groupe) => (
          <GroupeLigne
            key={groupe.id}
            groupe={groupe}
            actif={groupe.id === choisi}
            onOpen={() => navigate(`/messages/${groupe.id}`)}
          />
        ))}
      </div>

      {choisi ? (
        <Fil
          key={choisi}
          groupe={liste.find((g) => g.id === choisi) ?? liste[0]}
          onBack={() => navigate('/messages')}
        />
      ) : null}
    </div>
  )
}

function GroupeLigne({
  groupe,
  actif,
  onOpen,
}: {
  groupe: Groupe
  actif: boolean
  onOpen: () => void
}) {
  return (
    <button
      type="button"
      className="rowitem"
      onClick={onOpen}
      aria-current={actif ? 'true' : undefined}
      style={
        actif
          ? { borderColor: 'var(--violette)', background: 'var(--violette-pale)' }
          : undefined
      }
    >
      <Tile
        icon={groupe.kind === 'COURSE' ? 'clock' : 'briefcase'}
        tone={groupe.kind === 'COURSE' ? 'accent' : 'neutral'}
      />
      <span className="rowitem__body">
        <span className="rowitem__title">{groupe.name}</span>
        <span className="rowitem__sub">
          {groupe.lastBody ?? 'Aucun message pour l’instant'}
        </span>
      </span>
      {groupe.lastAt ? (
        <span className="rowitem__end micro">{relative(groupe.lastAt)}</span>
      ) : null}
    </button>
  )
}

/**
 * Un fil de discussion.
 *
 * Les messages arrivent par le haut (`before`) : une discussion se lit par le
 * bas, et l'on remonte. Cinquante à la fois — assez pour remplir un écran
 * deux fois, pas assez pour faire attendre sur un réseau lent.
 */
function Fil({ groupe, onBack }: { groupe: Groupe; onBack: () => void }) {
  const { session } = useSession()
  const [messages, setMessages] = useState<MessageGroupe[]>()
  const [erreur, setErreur] = useState<string>()
  const [texte, setTexte] = useState('')
  const [envoi, setEnvoi] = useState(false)
  const bas = useRef<HTMLDivElement>(null)

  useEffect(() => {
    let vivant = true
    discussion
      .messages(groupe.id)
      .then((corps) => {
        if (vivant) setMessages(corps.messages)
      })
      .catch((cause: unknown) => {
        if (vivant) {
          setErreur(
            cause instanceof Error ? cause.message : 'Lecture impossible.',
          )
        }
      })
    return () => {
      vivant = false
    }
  }, [groupe.id])

  // Au bas du fil à l'ouverture et après chaque envoi : une discussion
  // ouverte en haut demande de faire défiler avant de lire la dernière ligne,
  // qui est la seule qu'on venait lire.
  useEffect(() => {
    bas.current?.scrollIntoView({ block: 'end' })
  }, [messages?.length])

  const envoyer = async (event: React.FormEvent) => {
    event.preventDefault()
    const corps = texte.trim()
    if (!corps || envoi) return

    setEnvoi(true)
    setErreur(undefined)
    try {
      const ecrit = await discussion.envoyer(groupe.id, corps)
      /*
       * La bulle est composée ici et non relue du serveur.
       *
       * La route ne rend que l'identifiant et l'heure — elle n'a pas à
       * renvoyer un message qu'on vient d'écrire. Sur une connexion lente,
       * attendre une relecture complète ferait disparaître le texte du champ
       * pendant deux secondes sans que rien apparaisse, et l'on réécrit.
       */
      setMessages((avant) => [
        ...(avant ?? []),
        {
          id: ecrit.id,
          groupId: groupe.id,
          authorId: session?.userId ?? '',
          authorName: session?.displayName ?? 'Moi',
          authorRole: session?.role ?? 'TEACHER',
          body: corps,
          sentAt: ecrit.sentAt,
        },
      ])
      setTexte('')
    } catch (cause) {
      setErreur(
        cause instanceof Error
          ? cause.message
          : 'Message non envoyé. Réessayez.',
      )
    } finally {
      setEnvoi(false)
    }
  }

  return (
    <section className="chat__room">
      <header className="chat__head">
        {/* La fleche n'existe que sur un telephone, ou le fil a remplace la
            liste. Sur un ordinateur les deux sont visibles et elle ne menerait
            nulle part : c'est le CSS qui la retire. */}
        <button
          type="button"
          className="iconbtn chat__back"
          onClick={onBack}
          aria-label="Revenir aux discussions"
        >
          <Icon name="back" size={20} />
        </button>
        <Tile icon={groupe.kind === 'COURSE' ? 'clock' : 'briefcase'} size={18} />
        <div className="stack stack--tight" style={{ gap: 0 }}>
          <strong>{groupe.name}</strong>
          <span className="faint micro">
            {groupe.kind === 'COURSE'
              ? 'Le groupe du cours : vous et les familles inscrites'
              : 'Le groupe du contrat'}
          </span>
        </div>
      </header>

      <div className="chat__thread">
        {messages === undefined ? (
          <Skeleton height={48} count={3} />
        ) : messages.length === 0 ? (
          <p className="faint small centered">
            Personne n’a encore écrit. Un premier message — « bonjour, le cours
            commence lundi à 17 h » — suffit souvent à lancer les questions.
          </p>
        ) : (
          messages.map((message) => {
            const mien = message.authorId === session?.userId
            return (
              <div
                key={message.id}
                className={`bubble${mien ? ' bubble--mine' : ''}`}
              >
                {/* Le nom de l'auteur seulement sur les messages des autres :
                    sur les siens, il est redondant avec la position. */}
                {mien ? null : (
                  <span className="bubble__author">{message.authorName}</span>
                )}
                {message.body}
                <span className="bubble__time">{relative(message.sentAt)}</span>
              </div>
            )
          })
        )}
        <div ref={bas} />
      </div>

      {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

      <form className="chat__compose" onSubmit={envoyer}>
        <TextInput
          value={texte}
          onChange={(e) => setTexte(e.target.value)}
          placeholder="Écrire au groupe…"
          maxLength={2000}
          aria-label="Votre message"
        />
        <Button type="submit" disabled={envoi || texte.trim() === ''}>
          <Icon name="send" size={18} />
          <span className="sr-only">Envoyer</span>
        </Button>
      </form>
    </section>
  )
}
