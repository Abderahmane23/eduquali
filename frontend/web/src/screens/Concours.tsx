import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  boutique,
  concours as api,
  serveurDisponible,
  type Classement,
  type Concours as Epreuve,
} from '../api/server'
import { PageHead, RowItem, Statut } from '../components/kit'
import {
  Banner,
  Button,
  Card,
  Chip,
  EmptyState,
  Skeleton,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'
import { formatDate } from '../lib/format'

/**
 * Les concours hebdomadaires, et le classement national.
 *
 * --- Ce que cet écran remplace -------------------------------------------
 *
 * Rien, sur le site. Les quatre routes existent depuis la migration 0024 et
 * l'application Android a son écran ; le web n'en avait aucun. Un élève qui
 * n'a pas de téléphone Android voyait donc une boutique où dépenser des
 * points, sans la moitié des moyens d'en gagner.
 *
 * --- Pourquoi le rang personnel passe avant le podium --------------------
 *
 * « Afficher son propre rang avant le top 10 : c'est ce que l'élève
 * cherche. » Un podium où l'on ne se trouve pas ne dit rien à celui qui le
 * regarde — et à l'échelle d'un pays, on n'y est presque jamais.
 *
 * --- Pourquoi le podium peut rester fermé -------------------------------
 *
 * En dessous de dix copies rendues, le serveur ne le publie pas. Annoncer un
 * classement national à quatre participants n'est pas une approximation,
 * c'est une affirmation fausse sur le pays. L'écran dit combien il manque,
 * au lieu de montrer un podium qui ne vaut rien.
 */
export function Concours() {
  const etat = useAsync(() => api.liste(), [])
  const solde = useAsync(() => boutique.solde(), [])

  if (!serveurDisponible) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Concours</h1>
        <Banner tone="warning">
          Les concours passent par le serveur EduQuali, qui n’est pas relié à
          ce site.
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

  const epreuves = etat.data?.contests ?? []
  const ouverts = epreuves.filter((e) => e.state === 'OPEN')
  const aVenir = epreuves.filter((e) => e.state === 'UPCOMING')
  const passes = epreuves.filter((e) => e.state === 'CLOSED')

  return (
    <div className="screen stack stack--loose">
      <PageHead
        title="Concours"
        lede={
          'Un quiz par semaine, sur le programme guinéen. Les points gagnés ' +
          'se dépensent à la boutique.'
        }
        stats={
          solde.data
            ? [{ value: solde.data.balance, label: 'points' }]
            : undefined
        }
      />

      {etat.error ? <Banner tone="warning">{etat.error}</Banner> : null}

      {epreuves.length === 0 ? (
        <EmptyState
          icon="gift"
          title="Aucun concours pour l’instant"
          message={
            'Il y en a un par semaine. Celui de la semaine prochaine ' +
            'apparaîtra ici dès qu’il sera ouvert.'
          }
        />
      ) : null}

      {ouverts.length > 0 ? (
        <section className="stack stack--tight">
          <h2 className="section-title">Ouvert maintenant</h2>
          {ouverts.map((epreuve) => (
            <CarteOuverte key={epreuve.id} epreuve={epreuve} />
          ))}
        </section>
      ) : null}

      {aVenir.length > 0 ? (
        <section className="stack stack--tight">
          <h2 className="section-title">À venir</h2>
          {aVenir.map((epreuve) => (
            <RowItem
              key={epreuve.id}
              icon="clock"
              tone="neutral"
              title={epreuve.title}
              sub={`Ouvre le ${formatDate(epreuve.opens_at)}`}
              end={<Chip>{epreuve.points_prize} pts</Chip>}
            />
          ))}
        </section>
      ) : null}

      {passes.length > 0 ? (
        <section className="stack stack--tight">
          <h2 className="section-title">Terminés</h2>
          {passes.map((epreuve) => (
            <CarteFermee key={epreuve.id} epreuve={epreuve} />
          ))}
        </section>
      ) : null}
    </div>
  )
}

/** Un concours ouvert : la seule carte qui porte une action. */
function CarteOuverte({ epreuve }: { epreuve: Epreuve }) {
  const navigate = useNavigate()
  const [envoi, setEnvoi] = useState(false)
  const [erreur, setErreur] = useState<string>()

  const participer = async () => {
    setEnvoi(true)
    setErreur(undefined)
    try {
      await api.participer(epreuve.id)
      // Le test lui-même vit sur `/tests/:id` : c'est le même moteur que les
      // tests de compétence, et en écrire un second ferait deux façons de
      // corriger la même copie.
      navigate(`/tests/${epreuve.test_id}`)
    } catch (cause) {
      setErreur(
        cause instanceof Error
          ? cause.message
          : 'L’inscription n’a pas abouti.',
      )
      setEnvoi(false)
    }
  }

  return (
    <Card>
      <div className="stack stack--tight">
        <div className="row row--between">
          <strong>{epreuve.title}</strong>
          <Statut ton="ok" icon="clock">
            Ouvert
          </Statut>
        </div>

        <p className="muted small">
          {/* La date de fermeture, et non « bientôt » : c'est elle qui
              décide si l'on s'y met ce soir. */}
          Jusqu’au {formatDate(epreuve.closes_at)} · {epreuve.points_prize}{' '}
          points pour le premier
        </p>

        {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

        <Button block disabled={envoi} onClick={participer}>
          {envoi ? 'Ouverture…' : 'Participer'}
        </Button>
      </div>
    </Card>
  )
}

/** Un concours terminé : son classement. */
function CarteFermee({ epreuve }: { epreuve: Epreuve }) {
  const [ouvert, setOuvert] = useState(false)
  const classement = useAsync(
    () => (ouvert ? api.classement(epreuve.id) : Promise.resolve(null)),
    [ouvert, epreuve.id],
  )

  return (
    <Card>
      <div className="stack stack--tight">
        <div className="row row--between">
          <strong>{epreuve.title}</strong>
          <span className="muted small">{formatDate(epreuve.closes_at)}</span>
        </div>

        {ouvert ? (
          classement.loading ? (
            <Skeleton height={32} count={3} />
          ) : classement.data ? (
            <Tableau classement={classement.data} />
          ) : (
            <Banner tone="warning">
              {classement.error ?? 'Classement indisponible.'}
            </Banner>
          )
        ) : (
          <Button variant="ghost" onClick={() => setOuvert(true)}>
            Voir le classement
          </Button>
        )}
      </div>
    </Card>
  )
}

/** Le rang personnel d'abord, le podium ensuite. */
function Tableau({ classement }: { classement: Classement }) {
  return (
    <div className="stack stack--tight">
      {/*
        Son propre rang, en premier et en grand.

        C'est ce qu'un élève vient lire. Le podium national vient après, et
        il n'est publié qu'à partir de dix copies rendues.
      */}
      {classement.me ? (
        <div className="row row--baseline">
          <span className="chiffre chiffre--petit">
            {classement.me.rank}
          </span>
          <span className="muted">
            sur {classement.participants} · {classement.me.score} points
          </span>
        </div>
      ) : (
        <p className="muted small">Vous n’avez pas rendu de copie.</p>
      )}

      {classement.published ? (
        <ol className="stack stack--tight liste-nue">
          {classement.podium.map((rang) => (
            <li
              className="row row--between small"
              key={`${rang.rank}-${rang.userId}`}
            >
              <span>
                {rang.rank}<sup>e</sup>
                {rang.userId === classement.me?.userId ? ' — vous' : ''}
              </span>
              <span className="muted">
                {rang.score} points · {Math.round(rang.durationSeconds / 60)}{' '}
                min
              </span>
            </li>
          ))}
        </ol>
      ) : (
        <p className="faint micro">
          {/*
            On dit pourquoi, et combien il manque.

            « Classement bientôt disponible » n'apprend rien. Le nombre
            manquant dit si cela se jouera cette semaine.
          */}
          Le podium s’ouvre à dix copies rendues. Il en manque{' '}
          {classement.missing}.
        </p>
      )}
    </div>
  )
}
