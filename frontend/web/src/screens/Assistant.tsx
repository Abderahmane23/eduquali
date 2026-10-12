import { useEffect, useRef, useState } from 'react'
import {
  assistant,
  serveurDisponible,
  type MessageIA,
  type UsageAssistant,
} from '../api/server'
import { useSession } from '../app/session'
import { SegmentedToggle } from '../components/kit'
import {
  Banner,
  Button,
  EmptyState,
  Icon,
  Skeleton,
  TextInput,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'

/**
 * L'assistant.
 *
 * --- Où vit la clé, et pourquoi -----------------------------------------
 *
 * Le navigateur ne parle jamais à Google. Il parle à `POST /ai/chat`, qui
 * détient l'unique clé et décide qui a le droit de s'en servir. Une clé
 * préfixée `VITE_` serait recopiée dans le paquet du site par Vite, donc
 * lisible par n'importe quel visiteur — la passerelle refuse d'ailleurs une
 * clé qui porte ce préfixe plutôt que de la laisser passer.
 *
 * --- Ce qui part chez Google, et ce qui n'en part pas -------------------
 *
 * Ni prénom, ni identifiant de compte, ni ville, ni nom d'école. Le serveur
 * envoie les consignes de rôle, l'historique borné à huit tours, et la
 * question. Google ne peut pas relier deux conversations à la même personne.
 *
 * --- Pourquoi l'assistant ne donne pas la réponse ----------------------
 *
 * Pour un élève, la consigne système l'interdit : il donne la méthode, une
 * étape à la fois, et pose une question pour vérifier qu'on suit. Un
 * assistant qui donne la réponse fait les devoirs ; il n'apprend rien, et le
 * lendemain l'élève est devant la même difficulté.
 */

const USAGES: { value: UsageAssistant; label: string; invite: string }[] = [
  {
    value: 'HOMEWORK',
    label: 'Aide aux devoirs',
    invite: 'Je ne comprends pas comment résoudre…',
  },
  {
    value: 'COURSE',
    label: 'Préparer un cours',
    invite: 'Prépare-moi un cours de 90 minutes sur…',
  },
  {
    value: 'GENERAL',
    label: 'Autre question',
    invite: 'Comment fonctionne…',
  },
]

/** Des entrées en matière, par usage : une page vide ne dit pas quoi taper. */
const SUGGESTIONS: Record<UsageAssistant, string[]> = {
  HOMEWORK: [
    'Explique-moi le théorème de Thalès avec un exemple',
    'Comment on factorise x² − 5x + 6 ?',
    'Je dois faire un résumé en français, par où commencer ?',
  ],
  COURSE: [
    'Un cours de 90 min sur les limites, en terminale',
    'Dix exercices sur les équations du second degré, avec corrigés',
    'Comment introduire la photosynthèse en 8e année ?',
  ],
  GENERAL: [
    'Comment je passe un test de certification ?',
    'Qu’est-ce que ça change d’avoir un diplôme vérifié ?',
  ],
}

export function Assistant() {
  const { session } = useSession()
  const [usage, setUsage] = useState(0)
  const [messages, setMessages] = useState<MessageIA[]>([])
  const [filId, setFilId] = useState<string>()
  const [texte, setTexte] = useState('')
  const [occupe, setOccupe] = useState(false)
  const [erreur, setErreur] = useState<string>()
  const bas = useRef<HTMLDivElement>(null)

  const quota = useAsync(() => assistant.quota(), [])

  useEffect(() => {
    bas.current?.scrollIntoView({ block: 'end' })
  }, [messages.length, occupe])

  const choisi = USAGES[usage]

  if (!serveurDisponible) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Assistant</h1>
        <Banner tone="warning">
          L’assistant passe par le serveur Eduquali, qui détient l’unique clé
          du modèle. Il n’est pas relié à ce site.
        </Banner>
      </div>
    )
  }

  const demander = async (question: string) => {
    const corps = question.trim()
    if (!corps || occupe) return

    setOccupe(true)
    setErreur(undefined)
    setTexte('')

    // La question apparaît tout de suite : une réponse met trois à huit
    // secondes, et une page qui ne bouge pas pendant ce temps se lit comme
    // une page figée — on réécrit, et on paie deux appels.
    const provisoire: MessageIA = {
      id: `local-${Date.now()}`,
      role: 'USER',
      body: corps,
      createdAt: new Date().toISOString(),
    }
    setMessages((avant) => [...avant, provisoire])

    try {
      const reponse = await assistant.demander({
        message: corps,
        feature: choisi.value,
        conversationId: filId,
      })
      setFilId(reponse.conversationId)
      setMessages((avant) => [
        ...avant,
        {
          id: reponse.id ?? `model-${Date.now()}`,
          role: 'MODEL',
          body: reponse.body,
          createdAt: reponse.createdAt,
        },
      ])
      quota.reload()
    } catch (cause) {
      setErreur(
        cause instanceof Error
          ? cause.message
          : 'L’assistant n’a pas répondu. Réessayez.',
      )
      /*
       * La question reste affichée, et c'est voulu : le serveur l'a déjà
       * enregistrée avant d'appeler le modèle, précisément pour qu'elle ne
       * soit pas perdue. La retirer de l'écran la ferait réapparaître au
       * rechargement, ce qui est plus déroutant qu'une réponse manquante.
       */
    } finally {
      setOccupe(false)
    }
  }

  const indispo = quota.data && !quota.data.available
  const epuise =
    quota.data && quota.data.remaining !== undefined && quota.data.remaining <= 0

  return (
    <div className="screen screen--narrow stack stack--loose">
      <div className="stack stack--tight">
        <h1 className="page-title">Assistant</h1>
        <p className="page-lede" style={{ marginBottom: 0 }}>
          {session?.role === 'TEACHER'
            ? 'Un plan de cours, des exercices, des corrigés — sur le programme guinéen.'
            : 'Il explique la méthode, pas la réponse : c’est à cette condition qu’on apprend quelque chose.'}
        </p>
      </div>

      <SegmentedToggle
        label="Ce que vous cherchez"
        labels={USAGES.map((u) => u.label)}
        selected={usage}
        onSelect={(index) => {
          setUsage(index)
          // Changer d'usage change les consignes système : poursuivre le même
          // fil ferait répondre un répétiteur avec les consignes d'un
          // préparateur de cours. On repart d'un fil neuf.
          setFilId(undefined)
          setMessages([])
        }}
      />

      {indispo ? (
        <Banner tone="warning">
          L’assistant est en pause jusqu’au mois prochain : le budget mensuel
          est atteint. Rien ne vous a été débité.
        </Banner>
      ) : null}

      {quota.data && !indispo ? (
        <span className="faint micro">
          {quota.data.used} message{quota.data.used > 1 ? 's' : ''} aujourd’hui
          sur {quota.data.limit}. Le compteur repart demain.
        </span>
      ) : null}

      <section className="chat__room" style={{ minHeight: 360 }}>
        <div className="chat__thread">
          {quota.loading ? (
            <Skeleton height={48} count={2} />
          ) : messages.length === 0 ? (
            <div className="stack">
              <EmptyState
                icon="sparkle"
                title={choisi.label}
                message={
                  choisi.value === 'HOMEWORK'
                    ? 'Posez la question telle qu’elle est dans le cahier. L’assistant ne donnera pas la réponse : il montrera comment y arriver.'
                    : choisi.value === 'COURSE'
                      ? 'Dites la matière, le niveau et la durée. Vous repartez avec un déroulé minute par minute et des exercices corrigés.'
                      : 'Une question sur Eduquali, les tests, la scolarité en Guinée.'
                }
              />
              <div className="suggests">
                {SUGGESTIONS[choisi.value].map((idee) => (
                  <button
                    key={idee}
                    type="button"
                    className="chip chip--action"
                    onClick={() => demander(idee)}
                    disabled={Boolean(indispo)}
                  >
                    {idee}
                  </button>
                ))}
              </div>
            </div>
          ) : (
            messages.map((message) => (
              <div
                key={message.id}
                className={`bubble${message.role === 'USER' ? ' bubble--mine' : ''}`}
              >
                <span className={message.role === 'MODEL' ? 'aireply' : undefined}>
                  {message.body}
                </span>
              </div>
            ))
          )}

          {occupe ? (
            <div className="bubble">
              <span className="faint">L’assistant réfléchit…</span>
            </div>
          ) : null}

          <div ref={bas} />
        </div>

        {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

        <form
          className="chat__compose"
          onSubmit={(event) => {
            event.preventDefault()
            demander(texte)
          }}
        >
          <TextInput
            value={texte}
            onChange={(e) => setTexte(e.target.value)}
            placeholder={choisi.invite}
            maxLength={4000}
            aria-label="Votre question"
            disabled={Boolean(indispo) || Boolean(epuise)}
          />
          <Button
            type="submit"
            disabled={occupe || texte.trim() === '' || Boolean(indispo)}
          >
            <Icon name="send" size={18} />
            <span className="sr-only">Envoyer</span>
          </Button>
        </form>
      </section>

      <p className="faint micro measure">
        Vos questions partent chez le fournisseur du modèle, sans votre nom ni
        aucun identifiant. Ne collez pas de données personnelles — ni numéro,
        ni adresse, ni nom d’élève : elles ne servent pas à la réponse.
      </p>
    </div>
  )
}
