import { useState } from 'react'
import { boutique, serveurDisponible, type LotBoutique } from '../api/server'
import { PageHead, Tile } from '../components/kit'
import {
  Banner,
  Button,
  Chip,
  EmptyState,
  Icon,
  Progress,
  Skeleton,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'
import { formatDate, money } from '../lib/format'

/**
 * La boutique des points.
 *
 * --- Pourquoi des points, et d'où ils viennent -------------------------
 *
 * Une minute de présence en cours rapporte un point tous les cinq minutes ;
 * répondre à un point de contrôle en rapporte aussi. Aucun de ces événements
 * n'est déclaré par le client : la présence est comptée par le serveur de
 * visioconférence, et la réponse exige une place payée et un vote encore
 * ouvert. **On ne peut donc pas moissonner des points en cliquant** — c'est
 * la différence avec les plateformes où l'XP récompense le fait d'avoir
 * appuyé sur « continuer ».
 *
 * --- Ce que l'écran doit dire avant tout -------------------------------
 *
 * La distance au lot suivant. Un catalogue de lots sans savoir combien il
 * manque est un décor : la seule information utile est « il vous manque 40
 * points », parce qu'elle dit s'il faut suivre un cours de plus ou dix.
 */
export function Shop() {
  const catalogue = useAsync(() => boutique.lots(), [])
  const echanges = useAsync(() => boutique.echanges(), [])
  const [occupe, setOccupe] = useState<string>()
  const [souci, setSouci] = useState<string>()
  const [fait, setFait] = useState<string>()

  if (!serveurDisponible) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Boutique</h1>
        <Banner tone="warning">
          La boutique passe par le serveur Eduquali, qui n’est pas relié à ce
          site.
        </Banner>
      </div>
    )
  }

  if (catalogue.loading) {
    return (
      <div className="screen">
        <Skeleton height={120} count={3} />
      </div>
    )
  }

  if (catalogue.error || !catalogue.data) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Boutique</h1>
        <Banner tone="warning">
          {catalogue.error ?? 'Lecture impossible pour le moment.'}
        </Banner>
      </div>
    )
  }

  const { items, balance, nextId, missing } = catalogue.data
  const suivant = items.find((lot) => lot.id === nextId)

  const echanger = async (lot: LotBoutique) => {
    setOccupe(lot.id)
    setSouci(undefined)
    setFait(undefined)
    try {
      await boutique.echanger(lot.id)
      setFait(
        lot.kind === 'DRAW'
          ? `Votre chance est enregistrée pour « ${lot.name} ».`
          : `« ${lot.name} » est réservé. Nous vous contactons pour la remise.`,
      )
      catalogue.reload()
      echanges.reload()
    } catch (cause) {
      setSouci(cause instanceof Error ? cause.message : 'Échange impossible.')
    } finally {
      setOccupe(undefined)
    }
  }

  const basculerFavori = async (lot: LotBoutique) => {
    try {
      await boutique.favori(lot.id, !lot.favorite)
      catalogue.reload()
    } catch {
      // Mettre de côté est un confort : un échec ne mérite pas un bandeau
      // d'erreur en travers de la page.
    }
  }

  return (
    <div className="screen stack stack--loose">
      <PageHead
        title="Vos points"
        lede="Ils se gagnent en suivant des cours : un point toutes les cinq minutes de présence, et des points pour chaque question à laquelle vous répondez en séance."
        stats={[
          { value: balance, label: 'points' },
          { value: items.filter((lot) => lot.affordable).length, label: 'lots accessibles' },
          {
            value: echanges.data?.redemptions.length ?? 0,
            label: 'échanges faits',
          },
        ]}
      />

      {/* La distance au lot suivant, avant le catalogue. */}
      {suivant && missing > 0 ? (
        <div className="card card--accent">
          <div className="stack stack--tight">
            <strong>
              Il vous manque {missing} point{missing > 1 ? 's' : ''} pour «{' '}
              {suivant.name} »
            </strong>
            <Progress
              value={balance / Math.max(1, suivant.points_price)}
            />
            <span className="small">
              Soit environ {Math.ceil(missing / 18)} séance
              {Math.ceil(missing / 18) > 1 ? 's' : ''} de 90 minutes.
            </span>
          </div>
        </div>
      ) : null}

      {fait ? <Banner>{fait}</Banner> : null}
      {souci ? <Banner tone="warning">{souci}</Banner> : null}

      {items.length === 0 ? (
        <EmptyState
          icon="gift"
          title="Aucun lot pour l’instant"
          message="Le catalogue change chaque mois. Continuez à suivre vos cours : les points, eux, ne se perdent pas."
        />
      ) : (
        <section className="stack">
          <h2 className="section-title">Le catalogue</h2>
          <div className="shopgrid">
            {items.map((lot) => (
              <article className="shopitem" key={lot.id}>
                <div className="shopitem__visual">
                  {lot.image ? (
                    /* `loading="lazy"` : un catalogue de vingt lots sur une
                       connexion guinéenne ne doit pas télécharger vingt
                       images avant d'afficher la première ligne. */
                    <img src={lot.image} alt="" loading="lazy" />
                  ) : (
                    <Tile icon="gift" tone="neutral" />
                  )}
                </div>

                <span className="shopitem__name">{lot.name}</span>
                {lot.summary ? (
                  <span className="faint micro">{lot.summary}</span>
                ) : null}

                <div className="row row--between">
                  <span className="shopitem__cost">
                    {lot.points_price} pts
                  </span>
                  <button
                    type="button"
                    className="iconbtn"
                    onClick={() => basculerFavori(lot)}
                    aria-label={
                      lot.favorite
                        ? `Retirer ${lot.name} de mes envies`
                        : `Mettre ${lot.name} de côté`
                    }
                    aria-pressed={lot.favorite}
                    style={{
                      color: lot.favorite
                        ? 'var(--c-accent)'
                        : 'var(--c-ink-faint)',
                    }}
                  >
                    <Icon name={lot.favorite ? 'check' : 'plus'} size={18} />
                  </button>
                </div>

                {lot.value_gnf ? (
                  <span className="faint micro">
                    Valeur {money(lot.value_gnf)}
                  </span>
                ) : null}

                {/* Un tirage vend des chances, pas l'objet : le dire évite
                    qu'on croie avoir acheté le lot. */}
                {lot.kind === 'DRAW' ? (
                  <span className="faint micro">
                    Tirage
                    {lot.draws_at ? ` le ${formatDate(lot.draws_at)}` : ''}
                    {lot.entries > 0
                      ? ` · ${lot.entries} chance${lot.entries > 1 ? 's' : ''} déjà prise${lot.entries > 1 ? 's' : ''}`
                      : ''}
                  </span>
                ) : lot.stock !== null && lot.stock <= 3 ? (
                  <Chip tone="warning">
                    {lot.stock === 0
                      ? 'épuisé'
                      : `${lot.stock} restant${lot.stock > 1 ? 's' : ''}`}
                  </Chip>
                ) : null}

                <Button
                  block
                  variant={lot.affordable ? 'primary' : 'ghost'}
                  disabled={
                    !lot.affordable
                    || occupe === lot.id
                    || lot.stock === 0
                  }
                  onClick={() => echanger(lot)}
                >
                  {occupe === lot.id
                    ? 'Échange…'
                    : lot.stock === 0
                      ? 'Épuisé'
                      : lot.affordable
                        ? lot.kind === 'DRAW'
                          ? 'Prendre une chance'
                          : 'Échanger'
                        : `${lot.points_price - balance} pts de plus`}
                </Button>
              </article>
            ))}
          </div>
        </section>
      )}

      {echanges.data && echanges.data.redemptions.length > 0 ? (
        <section className="stack stack--tight">
          <h2 className="section-title">Mes échanges</h2>
          {echanges.data.redemptions.map((echange) => (
            <div className="rowitem" key={echange.id}>
              <Tile
                icon="gift"
                tone={echange.status === 'DELIVERED' ? 'success' : 'neutral'}
              />
              <span className="rowitem__body">
                <span className="rowitem__title">
                  {items.find((lot) => lot.id === echange.item_id)?.name
                    ?? 'Un lot'}
                </span>
                <span className="rowitem__sub">
                  {echange.points_spent} points · demandé le{' '}
                  {formatDate(echange.requested_at)}
                  {echange.note ? ` — ${echange.note}` : ''}
                </span>
              </span>
              <span className="rowitem__end">
                <Chip
                  tone={echange.status === 'DELIVERED' ? 'success' : undefined}
                >
                  {echange.status === 'DELIVERED'
                    ? 'remis'
                    : echange.status === 'PENDING'
                      ? 'à remettre'
                      : echange.status.toLowerCase()}
                </Chip>
              </span>
            </div>
          ))}
        </section>
      ) : null}
    </div>
  )
}
