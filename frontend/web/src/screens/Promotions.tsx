import { useState } from 'react'
import { api } from '../api'
import type { MaPromotion } from '../api/types'
import { useSession } from '../app/session'
import { PageHead, Statut } from '../components/kit'
import {
  Banner,
  Button,
  Card,
  EmptyState,
  Field,
  Skeleton,
  TextInput,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'
import { formatDate } from '../lib/format'

/**
 * Les mises en avant d'un établissement.
 *
 * --- Ce que cet écran remplace ------------------------------------------
 *
 * Rien, sur le site. La table existe depuis la migration 0006, l'application
 * Android a son onglet, et le web n'avait aucun écran : une école qui
 * s'inscrivait depuis un navigateur ne pouvait ni publier une annonce ni
 * savoir combien de fois elle avait été vue.
 *
 * --- Pourquoi les affichages sont le cœur de l'écran --------------------
 *
 * C'est la seule chose que l'école achète. Sans le compteur, elle paie pour
 * une visibilité qu'elle ne peut pas vérifier — et une dépense invérifiable
 * ne se renouvelle pas. Le serveur ne compte qu'un affichage par personne et
 * par jour : le chiffre dit combien de familles ont vu l'annonce, pas
 * combien de fois une page a été rechargée.
 *
 * --- Ce que l'écran ne fait pas -----------------------------------------
 *
 * Il ne vend rien. La colonne `credit_cost` existe et vaut zéro : aucun
 * barème n'a été arrêté, et en inventer un ici le rendrait vrai. Quand il le
 * sera, il se posera entre le formulaire et la publication.
 */
export function Promotions() {
  const { session } = useSession()
  const etat = useAsync(
    () => (session ? api.mesPromotions() : Promise.resolve([])),
    [session?.userId],
  )

  if (session && session.role !== 'INSTITUTION') {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Mises en avant</h1>
        <Banner tone="warning">
          Cet écran est réservé aux établissements.
        </Banner>
      </div>
    )
  }

  if (etat.loading) {
    return (
      <div className="screen">
        <Skeleton height={120} count={3} />
      </div>
    )
  }

  const liste = etat.data ?? []
  const enLigne = liste.filter((p) => p.status === 'ACTIVE')
  const terminees = liste.filter((p) => p.status !== 'ACTIVE')
  const vues = liste.reduce((total, p) => total + p.views, 0)

  return (
    <div className="screen stack stack--loose">
      <PageHead
        title="Mises en avant"
        lede="Votre annonce, montrée aux familles qui cherchent une école."
        stats={[
          { value: enLigne.length, label: 'en ligne' },
          { value: vues, label: 'familles atteintes' },
        ]}
      />

      {etat.error ? <Banner tone="warning">{etat.error}</Banner> : null}

      <Publier onPubliee={() => etat.reload()} />

      {liste.length === 0 ? (
        <EmptyState
          icon="briefcase"
          title="Aucune mise en avant"
          message={
            'Une annonce paraît sur l’écran des familles qui cherchent une ' +
            'école. Les affichages sont comptés, école par école.'
          }
        />
      ) : null}

      {enLigne.length > 0 ? (
        <section className="stack stack--tight">
          <h2 className="section-title">En ligne</h2>
          {enLigne.map((promo) => (
            <Carte
              key={promo.id}
              promo={promo}
              onRetiree={() => etat.reload()}
            />
          ))}
        </section>
      ) : null}

      {terminees.length > 0 ? (
        <section className="stack stack--tight">
          <h2 className="section-title">Terminées</h2>
          {terminees.map((promo) => (
            <Carte key={promo.id} promo={promo} />
          ))}
        </section>
      ) : null}
    </div>
  )
}

/** Le formulaire : un titre, un message, et c'est en ligne. */
function Publier({ onPubliee }: { onPubliee: () => void }) {
  const [ouvert, setOuvert] = useState(false)
  const [titre, setTitre] = useState('')
  const [message, setMessage] = useState('')
  const [envoi, setEnvoi] = useState(false)
  const [erreur, setErreur] = useState<string>()

  if (!ouvert) {
    return (
      <Button block onClick={() => setOuvert(true)}>
        Publier une mise en avant
      </Button>
    )
  }

  const publier = async () => {
    setEnvoi(true)
    setErreur(undefined)
    try {
      await api.creerPromotion({
        title: titre.trim(),
        message: message.trim() === '' ? undefined : message.trim(),
      })
      setTitre('')
      setMessage('')
      setOuvert(false)
      onPubliee()
    } catch (cause) {
      setErreur(
        cause instanceof Error
          ? cause.message
          : 'La publication n’a pas abouti.',
      )
    } finally {
      setEnvoi(false)
    }
  }

  return (
    <Card>
      <div className="stack stack--tight">
        <strong>Une nouvelle annonce</strong>

        {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

        <Field
          label="Le titre"
          hint="Ce qu’une famille lit en premier. Huit mots au plus."
        >
          <TextInput
            value={titre}
            maxLength={120}
            onChange={(e) => setTitre(e.target.value)}
            placeholder="Inscriptions ouvertes pour la rentrée"
          />
        </Field>

        <Field
          label="Le message"
          hint="Les classes ouvertes, les dates, où se présenter."
        >
          <TextInput
            value={message}
            maxLength={400}
            onChange={(e) => setMessage(e.target.value)}
          />
        </Field>

        <div className="row row--actions">
          <Button disabled={envoi || titre.trim() === ''} onClick={publier}>
            {envoi ? 'Publication…' : 'Mettre en ligne'}
          </Button>
          <Button variant="ghost" onClick={() => setOuvert(false)}>
            Annuler
          </Button>
        </div>
      </div>
    </Card>
  )
}

function Carte({
  promo,
  onRetiree,
}: {
  promo: MaPromotion
  onRetiree?: () => void
}) {
  const [envoi, setEnvoi] = useState(false)
  const [confirme, setConfirme] = useState(false)
  const [erreur, setErreur] = useState<string>()

  const retirer = async () => {
    setEnvoi(true)
    setErreur(undefined)
    try {
      await api.terminerPromotion(promo.id)
      onRetiree?.()
    } catch (cause) {
      setErreur(
        cause instanceof Error ? cause.message : 'Le retrait n’a pas abouti.',
      )
      setEnvoi(false)
    }
  }

  return (
    <Card>
      <div className="stack stack--tight">
        <div className="row row--between">
          <strong>{promo.title}</strong>
          <Statut ton={promo.status === 'ACTIVE' ? 'ok' : 'attente'}>
            {promo.status === 'ACTIVE' ? 'En ligne' : 'Terminée'}
          </Statut>
        </div>

        {promo.message ? (
          <p className="muted small">{promo.message}</p>
        ) : null}

        {/*
          Le chiffre qu'on vient chercher, et sa définition à côté.

          « 142 » seul ne dit pas ce qui est compté. Une famille par jour :
          c'est ce qui sépare une audience d'un nombre de rechargements.
        */}
        <p className="row row--baseline">
          <span className="chiffre chiffre--petit">{promo.views}</span>
          <span className="muted">
            famille{promo.views > 1 ? 's' : ''} · une par jour au plus
          </span>
        </p>

        <p className="faint micro">
          Publiée le {formatDate(promo.createdAt)}
          {promo.endsAt ? ` · jusqu’au ${formatDate(promo.endsAt)}` : ''}
        </p>

        {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

        {promo.status === 'ACTIVE' && onRetiree ? (
          confirme ? (
            <div className="stack stack--tight">
              {/* Retirer est définitif : on le dit avant, pas après. */}
              <p className="small">
                Elle ne sera plus montrée aux familles. Vous pourrez en
                publier une autre quand vous voudrez.
              </p>
              <div className="row row--actions">
                <Button disabled={envoi} onClick={retirer}>
                  {envoi ? 'Retrait…' : 'Retirer'}
                </Button>
                <Button variant="ghost" onClick={() => setConfirme(false)}>
                  Garder en ligne
                </Button>
              </div>
            </div>
          ) : (
            <Button variant="ghost" onClick={() => setConfirme(true)}>
              Retirer de la mise en avant
            </Button>
          )
        ) : null}
      </div>
    </Card>
  )
}
