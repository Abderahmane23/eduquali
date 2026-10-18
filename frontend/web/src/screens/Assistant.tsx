import {
  useCallback,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from 'react'
import {
  assistant,
  lireEnBase64,
  serveurDisponible,
  PIECE_FORMATS,
  PIECE_POIDS_MAX,
  type MessageIA,
  type UsageAssistant,
} from '../api/server'
import {
  Banner,
  Button,
  EmptyState,
  Icon,
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

/*
 * Deux libellés par usage, et pourquoi.
 *
 * `label` tient dans la bascule — un mot. « Aide aux devoirs » passait sur
 * trois lignes sur un téléphone de 390 points, et la bascule mangeait alors
 * le tiers de la hauteur du fil : il restait 274 points pour lire une
 * réponse de dix lignes.
 *
 * `titre` reprend la phrase entière dans l'en-tête, où il y a la place et
 * où elle dit ce que fait l'assistant au moment de taper.
 */
const USAGES: {
  value: UsageAssistant
  label: string
  titre: string
  invite: string
}[] = [
  {
    value: 'HOMEWORK',
    label: 'Devoirs',
    titre: 'Aide aux devoirs',
    invite: 'Une question sur un exercice…',
  },
  {
    value: 'COURSE',
    label: 'Cours',
    titre: 'Préparer un cours',
    invite: 'Un cours de 90 minutes sur…',
  },
  {
    value: 'GENERAL',
    label: 'Autre',
    titre: 'Autre question',
    invite: 'Votre question…',
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
  /*
   * Un seul usage, et il n'est plus choisi a la main.
   *
   * La bascule « Devoirs / Cours / Autre » occupait la premiere tranche de
   * l'ecran pour un reglage qu'on ne touche presque jamais : on vient poser
   * une question. Le tableau `USAGES` reste — il porte l'invite du champ,
   * les suggestions et le `feature` envoye au serveur — mais l'ecran se
   * tient desormais sur le premier, l'aide aux devoirs, qui est la raison
   * pour laquelle un eleve ouvre cette page.
   */
  const usage = 0
  const [messages, setMessages] = useState<MessageIA[]>([])
  const [filId, setFilId] = useState<string>()
  const [texte, setTexte] = useState('')
  const [occupe, setOccupe] = useState(false)
  const [erreur, setErreur] = useState<string>()
  const [piece, setPiece] = useState<File>()
  const fil = useRef<HTMLDivElement>(null)
  const champ = useRef<HTMLTextAreaElement>(null)
  const fichier = useRef<HTMLInputElement>(null)

  const quota = useAsync(() => assistant.quota(), [])

  /**
   * Suit-on encore le fil, ou est-on remonté lire plus haut ?
   *
   * Tant qu'on est près du bas, chaque message fait descendre. Dès qu'on
   * remonte, on arrête : rien n'est plus agaçant qu'un fil qui vous arrache
   * au paragraphe qu'on était en train de relire.
   */
  const suit = useRef(true)

  /**
   * Le défilement en cours vient-il de nous ?
   *
   * Sans cette distinction, la descente se saborde : elle déclenche un
   * événement `scroll`, l'écouteur mesure une distance au bas encore grande
   * — le texte ne s'est pas encore replié — et en conclut que la personne
   * est remontée lire. Le suivi se coupe, et la descente suivante refuse de
   * s'exécuter.
   */
  const nous = useRef(false)

  /**
   * Descendre au dernier message.
   *
   * --- Pourquoi `scrollTop` et non `scrollIntoView` ---------------------
   *
   * L'écran appelait `scrollIntoView` sur une ancre vide en bas du fil.
   * Cette méthode remonte la chaîne des parents et choisit elle-même qui
   * faire défiler : avec un fil en hauteur fixe à l'intérieur d'une page qui
   * ne défile pas, elle ne bougeait rien. Il fallait faire défiler à la main
   * pour voir partir sa propre question.
   *
   * On écrit donc dans le conteneur qui défile. Il n'y a qu'un candidat, et
   * il ne peut pas se tromper.
   */
  const descendre = useCallback((force = false) => {
    const boite = fil.current
    if (!boite) return
    if (!force && !suit.current) return
    nous.current = true
    boite.scrollTop = boite.scrollHeight
  }, [])

  /*
   * Descendre **avant** la peinture, puis à chaque fois que le fil grandit.
   *
   * --- Pourquoi `useEffect` seul ne suffisait pas ------------------------
   *
   * Mesure faite sur une vraie conversation : après une réponse, il restait
   * 1 596 points sous le dernier message, alors que forcer `scrollTop` à la
   * main fonctionnait. Le conteneur défilait donc bien — c'était le moment
   * de la mesure qui était faux.
   *
   * La hauteur lue après la peinture est celle d'avant le repli du texte :
   * Lexend et Gabarito arrivent en différé, le texte se replie sur deux fois
   * plus de lignes, et le fil grandit **après** la descente. Une trame
   * d'animation plus tard n'y suffit pas non plus — le repli peut venir
   * plusieurs centaines de millisecondes après.
   *
   * On observe donc la taille réelle du contenu, et l'on redescend quand
   * elle change. Une réponse qui arriverait par morceaux ferait exactement
   * la même chose.
   */
  useLayoutEffect(() => {
    // Un nouveau message : on suit de nouveau, même si l'on avait remonté.
    suit.current = true
    descendre(true)
  }, [messages.length, occupe, descendre])

  useEffect(() => {
    const boite = fil.current
    if (!boite) return

    const oeil = new ResizeObserver(() => descendre())
    // Le conteneur **et** son contenu : le premier change quand le clavier
    // du téléphone s'ouvre, le second quand le texte se replie.
    oeil.observe(boite)
    for (const enfant of Array.from(boite.children)) oeil.observe(enfant)

    const surDefilement = () => {
      // Un défilement que nous avons provoqué ne dit rien de l'intention de
      // la personne : on le laisse passer sans juger.
      if (nous.current) {
        nous.current = false
        return
      }
      const reste =
        boite.scrollHeight - boite.clientHeight - boite.scrollTop
      // Quarante points de tolérance : un défilement par inertie ne
      // s'arrête jamais exactement au pixel près.
      suit.current = reste < 40
    }
    boite.addEventListener('scroll', surDefilement, { passive: true })

    return () => {
      oeil.disconnect()
      boite.removeEventListener('scroll', surDefilement)
    }
  }, [messages, occupe, descendre])

  const choisi = USAGES[usage]

  if (!serveurDisponible) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Assistant</h1>
        <Banner tone="warning">
          L’assistant passe par le serveur EduQuali, qui détient l’unique clé
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
    const jointe = piece
    setPiece(undefined)

    // La question apparaît tout de suite : une réponse met trois à huit
    // secondes, et une page qui ne bouge pas pendant ce temps se lit comme
    // une page figée — on réécrit, et on paie deux appels.
    const provisoire: MessageIA = {
      id: `local-${Date.now()}`,
      role: 'USER',
      // La mention de la pièce, comme le serveur l'écrira dans le fil : les
      // deux doivent dire la même chose, sinon un rechargement change le
      // texte sous les yeux.
      body: jointe ? `${corps}\n\n[Image jointe : ${jointe.name}]` : corps,
      createdAt: new Date().toISOString(),
    }
    setMessages((avant) => [...avant, provisoire])

    try {
      const reponse = await assistant.demander({
        message: corps,
        feature: choisi.value,
        conversationId: filId,
        ...(jointe
          ? {
              attachment: {
                mimeType: jointe.type,
                data: await lireEnBase64(jointe),
                name: jointe.name,
              },
            }
          : {}),
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
    /*
      `assistant` et non `stack--loose` : les blocs se touchent de plus pres
      et le fil prend la hauteur qui reste, pour que la boite de saisie soit
      toujours visible sans defiler.

      La phrase d'explication a quitte cet en-tete : elle vit dans le fil
      vide, ou elle a la place et ou elle se lit au bon moment — juste avant
      la premiere question.
    */
    <div className="screen screen--narrow assistant">
      {indispo ? (
        <Banner tone="warning">
          L’assistant est en pause jusqu’au mois prochain : le budget mensuel
          est atteint. Rien ne vous a été débité.
        </Banner>
      ) : null}

      <section className="chat__room">
        {/*
          Plus d'en-tete.

          Il portait le titre de l'usage et le compteur du jour
          (« 1 / 100 aujourd'hui »). Le titre repetait ce que le fil montre
          deja, et le compteur annoncait une limite que personne n'atteint :
          c'est une precision utile le jour ou elle tombe, et ce jour-la le
          bandeau et le champ ferme le disent bien mieux. Le quota continue
          d'etre lu — `indispo` et `epuise` en viennent — il n'est plus
          affiche.
        */}
        <div className="chat__thread" ref={fil}>
          {/*
            Le fil ne dépend pas du compteur.

            Il affichait un squelette tant que `quota` chargeait — et
            `quota.reload()` est appelé après **chaque** réponse. La
            conversation entière disparaissait donc une fraction de seconde
            à chaque tour, le contenu du conteneur était détruit, et le
            défilement retombait à zéro : on se retrouvait en haut du fil
            juste après avoir reçu la réponse qu'on attendait.

            Le compteur est une précision dans l'en-tête ; il n'a pas à
            gouverner ce qu'on lit.
          */}
          {messages.length === 0 ? (
            <div className="stack">
              <EmptyState
                icon="sparkle"
                title={
                  choisi.value === 'HOMEWORK'
                    ? 'La méthode, pas la réponse'
                    : choisi.value === 'COURSE'
                      ? 'Un cours prêt à donner'
                      : 'Une question sur EduQuali'
                }
                message={
                  choisi.value === 'HOMEWORK'
                    ? 'Posez la question telle qu’elle est dans le cahier. L’assistant ne donne pas la réponse : il montre comment y arriver.'
                    : choisi.value === 'COURSE'
                      ? 'Dites la matière, le niveau et la durée. Vous repartez avec un déroulé minute par minute et des exercices corrigés, sur le programme guinéen.'
                      : 'Les tests, la scolarité en Guinée, le fonctionnement d’EduQuali.'
                }
              />
              {/*
                La phrase sur les donnees personnelles se lit ici, et non
                sous la boite de saisie ou elle prenait de la hauteur a
                chaque tour. C'est avant la premiere question qu'elle sert.

                La photo d'un cahier porte souvent le prenom de l'enfant. Le
                serveur ne garde pas l'image — seulement la mention qu'il y
                en avait une — et c'est ce qui permet de le dire sans detour.
              */}
              <p className="faint small centered">
                Ne collez ni numéro, ni adresse, ni nom d’élève. Les images
                ne sont pas conservées.
              </p>
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
              /*
                Un tour, et non une bulle.

                Les bulles alternées gauche-droite conviennent à une
                conversation de trois mots. Une réponse d'assistant fait dix
                lignes : coupée à 78 % de la largeur et poussée à gauche, elle
                se lit mal, et la colonne de blanc à droite ne sert à rien.

                La question reste dans une carte — c'est ce qu'on relit pour
                se rappeler ce qu'on a demandé. La réponse prend la largeur,
                avec la marque en tête de tour pour dire qui parle.
              */
              <article
                key={message.id}
                className={`tour${message.role === 'USER' ? ' tour--moi' : ''}`}
              >
                <span className="tour__qui" aria-hidden="true">
                  {message.role === 'USER' ? (
                    <Icon name="user" size={16} />
                  ) : (
                    <img src="/favicon.svg" alt="" />
                  )}
                </span>
                <div className="tour__corps">
                  <span className="tour__nom">
                    {message.role === 'USER' ? 'Vous' : 'EduQuali'}
                  </span>
                  <div className="tour__texte">{message.body}</div>
                </div>
              </article>
            ))
          )}

          {occupe ? (
            <article className="tour">
              <span className="tour__qui" aria-hidden="true">
                <img src="/favicon.svg" alt="" />
              </span>
              <div className="tour__corps">
                <span className="tour__nom">EduQuali</span>
                {/* Trois points qui respirent : on ne sait pas combien de
                    temps la réponse prendra, et une barre de progression qui
                    ment est pire qu'une attente franche. */}
                <span className="tour__attente" aria-label="L’assistant répond">
                  <i /><i /><i />
                </span>
              </div>
            </article>
          ) : null}
        </div>

        {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

        <form
          className="compose"
          onSubmit={(event) => {
            event.preventDefault()
            demander(texte)
          }}
        >
          {piece ? (
            <div className="compose__piece">
              <Icon name="file" size={16} />
              <span className="compose__nom">{piece.name}</span>
              <button
                type="button"
                className="iconbtn"
                aria-label="Retirer l’image"
                onClick={() => setPiece(undefined)}
              >
                ×
              </button>
            </div>
          ) : null}

          {/*
            Un `textarea` qui grandit, et non un champ d'une ligne.

            Une question d'élève tient en une ligne ; une consigne de
            professeur en fait cinq. Le champ s'ouvrait sur une ligne et
            faisait défiler le texte à l'intérieur : on ne relisait jamais
            ce qu'on venait d'écrire avant d'envoyer.

            Entrée envoie, Maj+Entrée passe à la ligne — la convention de
            tous les fils de discussion.
          */}
          <textarea
            ref={champ}
            className="compose__champ"
            value={texte}
            rows={1}
            onChange={(e) => {
              setTexte(e.target.value)
              const zone = e.currentTarget
              zone.style.height = 'auto'
              zone.style.height = `${Math.min(zone.scrollHeight, 180)}px`
            }}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault()
                demander(texte)
              }
            }}
            placeholder={choisi.invite}
            maxLength={4000}
            aria-label="Votre question"
            disabled={Boolean(indispo) || Boolean(epuise)}
          />

          <div className="compose__actions">
            <input
              ref={fichier}
              type="file"
              accept={PIECE_FORMATS.join(',')}
              hidden
              onChange={(e) => {
                const choisiFichier = e.target.files?.[0]
                e.target.value = ''
                if (!choisiFichier) return
                /*
                 * Les deux refus se disent avant l'envoi.
                 *
                 * Un fichier trop lourd ou d'un format que le modèle ne lit
                 * pas revient en erreur du serveur après une minute de
                 * téléversement sur un réseau guinéen. Le dire ici coûte
                 * zéro octet.
                 */
                if (!PIECE_FORMATS.includes(choisiFichier.type)) {
                  setErreur(
                    'Seules les images JPEG, PNG et WebP sont lisibles par ' +
                      'l’assistant.',
                  )
                  return
                }
                if (choisiFichier.size > PIECE_POIDS_MAX) {
                  setErreur(
                    'Image trop lourde : 3 Mo au plus. Une photo prise au ' +
                      'téléphone tient largement dedans.',
                  )
                  return
                }
                setErreur(undefined)
                setPiece(choisiFichier)
              }}
            />
            <button
              type="button"
              className="iconbtn"
              aria-label="Joindre une image"
              disabled={Boolean(indispo) || Boolean(epuise) || occupe}
              onClick={() => fichier.current?.click()}
            >
              <Icon name="upload" size={18} />
            </button>

            <span className="compose__aide">
              Entrée pour envoyer · Maj + Entrée pour aller à la ligne
            </span>

            <Button
              type="submit"
              disabled={occupe || texte.trim() === '' || Boolean(indispo)}
            >
              <Icon name="send" size={18} />
              <span className="sr-only">Envoyer</span>
            </Button>
          </div>
        </form>
      </section>

    </div>
  )
}
