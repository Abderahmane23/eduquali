import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import { api } from '../api'
import { promotions } from '../api/server'
import { AppGate } from '../components/AppGate'
import {
  AppBar,
  Banner,
  Button,
  Card,
  Chip,
  EmptyState,
  Icon,
  Select,
  Skeleton,
} from '../components/ui'
import { institutionTypeLabel } from '../lib/format'
import { useAsync } from '../lib/useAsync'

/**
 * Accueil de l'eleve : les etablissements.
 *
 * C'est l'ecran le plus utile pour ce profil, donc l'accueil — pas un menu
 * de liens (§10 du design_skill). Un eleve vient chercher une place ou un
 * repetiteur ; les deux partent d'ici.
 *
 * **Publique**, comme la liste des professeurs : on compare les ecoles d'une
 * ville avant d'ouvrir un compte, et c'est souvent la premiere raison de
 * venir.
 */
export function Schools() {
  const [city, setCity] = useState('')
  const [type, setType] = useState('')

  const cities = useAsync(() => api.cities(), [])
  const schools = useAsync(
    () => api.institutions({ city: city || undefined, type: type || undefined }),
    [city, type],
  )

  return (
    <>
      <AppBar title="Établissements" />
      <div className="screen stack">
        <Select
          value={city}
          onChange={(e) => setCity(e.target.value)}
          aria-label="Filtrer par ville"
        >
          <option value="">Toutes les villes</option>
          {(cities.data ?? []).map((name) => (
            <option key={name} value={name}>
              {name}
            </option>
          ))}
        </Select>

        <Select
          value={type}
          onChange={(e) => setType(e.target.value)}
          aria-label="Filtrer par type d’établissement"
        >
          <option value="">Tous les types</option>
          <option value="SCHOOL">École</option>
          <option value="HIGH_SCHOOL">Lycée</option>
          <option value="UNIVERSITY">Université</option>
          <option value="INSTITUTE">Institut</option>
          <option value="TRAINING_CENTER">Centre de formation</option>
        </Select>

        {/* Les mises en avant d'abord : c'est ce que l'etablissement a paye,
            et ce qu'une famille lit avant de parcourir la liste. */}
        <Promotions />

        {schools.loading ? (
          <Skeleton height={112} />
        ) : schools.error ? (
          <Banner tone="warning">{schools.error}</Banner>
        ) : (schools.data ?? []).length === 0 ? (
          <EmptyState
            title="Aucun établissement ici"
            message="Changez de ville ou de type pour élargir la recherche."
            action={
              <Button
                variant="ghost"
                onClick={() => {
                  setCity('')
                  setType('')
                }}
              >
                Voir tous les établissements
              </Button>
            }
          />
        ) : (
          <div className="stack grid-cards">
            {(schools.data ?? []).map((school) => (
            <Link
              key={school.id}
              to={`/etablissements/${school.id}`}
              className="card-link"
            >
              <Card>
                <div className="stack stack--tight">
                  <div className="row row--between">
                    <strong>{school.name}</strong>
                    {school.verified ? (
                      <Chip tone="success">Vérifié</Chip>
                    ) : null}
                  </div>
                  <div
                    className="row small faint"
                    style={{ gap: 'var(--espace-2)' }}
                  >
                    <Icon name="place" size={14} />
                    {school.city}
                  </div>
                  <div className="row" style={{ gap: 'var(--espace-2)' }}>
                    <Chip>{institutionTypeLabel(school.type)}</Chip>
                  </div>
                  {school.description ? (
                    <p className="muted small">{school.description}</p>
                  ) : null}
                </div>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </div>
    </>
  )
}

/**
 * La fiche d'un etablissement.
 *
 * `api.institutions()` rend deja l'adresse et la description, et la liste les
 * jetait : les donnees etaient la, l'ecran pour les lire manquait.
 *
 * Il n'y a pas d'appel par identifiant dans le contrat — l'ajouter supposerait
 * un point d'API et une migration. La fiche se prend donc dans la liste, qui
 * est de l'ordre de la centaine d'ecoles et deja chargee la plupart du temps.
 * Le jour ou elle atteint le millier, c'est un `institution(id)` qu'il faudra,
 * pas un filtre plus malin.
 */
export function SchoolDetail() {
  const { id = '' } = useParams()
  const state = useAsync(() => api.institutions({}), [])

  const school = (state.data ?? []).find((e) => e.id === id)

  if (state.loading) {
    return (
      <>
        <AppBar title="Établissement" onBack />
        <div className="screen">
          <Skeleton height={40} count={4} />
        </div>
      </>
    )
  }

  if (state.error) {
    return (
      <>
        <AppBar title="Établissement" onBack />
        <div className="screen">
          <Banner tone="warning">{state.error}</Banner>
        </div>
      </>
    )
  }

  if (!school) {
    return (
      <>
        <AppBar title="Établissement" onBack />
        <EmptyState
          title="Établissement introuvable"
          message="Cet établissement n’est plus référencé."
        />
      </>
    )
  }

  return (
    <>
      <AppBar title={school.name} onBack />
      <div className="screen detail stack stack--loose">
        <aside className="detail__aside stack">
          <Card>
            <div className="stack stack--tight">
              <div className="row row--between">
                <strong>{school.name}</strong>
                {school.verified ? <Chip tone="success">Vérifié</Chip> : null}
              </div>
              <div className="row" style={{ gap: 'var(--espace-2)' }}>
                <Chip>{institutionTypeLabel(school.type)}</Chip>
              </div>
              <div className="row small faint" style={{ gap: 'var(--espace-2)' }}>
                <Icon name="place" size={14} />
                {school.address
                  ? `${school.address}, ${school.city}`
                  : school.city}
              </div>
            </div>
          </Card>

          <AppGate
            action="demander une inscription"
            because="La demande se suit dans l’application : l’établissement répond, et vous recevez sa réponse sur votre téléphone sans avoir à revenir voir."
          />

          {/* Les offres de cet etablissement sont publiques : y mener depuis
              sa fiche evite de repasser par la liste complete. */}
          <Link className="btn btn--ghost btn--block" to="/offres">
            Voir les postes à pourvoir
          </Link>
        </aside>

        <div className="detail__main stack stack--loose">
          {school.description ? (
            <section className="stack stack--tight">
              <h2 className="section-title">Présentation</h2>
              <p className="muted small measure">{school.description}</p>
            </section>
          ) : null}
        </div>
      </div>
    </>
  )
}

/**
 * Les ecoles qui se mettent en avant.
 *
 * Rien ne s'affiche quand il n'y en a aucune — une bande vide intitulee
 * « A la une » ferait croire a un defaut de chargement. Le mot « publicite »
 * n'apparait pas : ce sont des annonces d'ecoles, et les presenter comme de la
 * publicite les ferait ignorer.
 */
function Promotions() {
  /*
   * Le fil vient du serveur, et non de Supabase en direct.
   *
   * Deux choses s'y perdaient, et ce sont les deux qui font qu'une école
   * paie : qui voit la publicité — « payer, c'est ne plus en voir » est une
   * règle de formule, qu'aucune politique de ligne ne peut tenir — et le
   * comptage des affichages, qui n'existait pas. L'école achetait une
   * visibilité qu'elle ne pouvait pas mesurer.
   */
  const state = useAsync(() => promotions.fil(), [])
  const promos = state.data?.promotions ?? []

  /*
   * Un affichage compté, une seule fois par montage.
   *
   * Le serveur n'en retient qu'un par personne et par jour ; l'appel est
   * donc sans danger, et son échec ne doit rien empêcher — une annonce
   * s'affiche même si le comptage tombe.
   */
  useEffect(() => {
    for (const promo of promos) {
      void promotions.vue(promo.id).catch(() => {})
    }
  }, [promos])

  if (state.loading || promos.length === 0) return null

  return (
    <section className="stack stack--tight">
      <h2 className="section-title">À la une</h2>
      <div className="stack grid-cards">
        {promos.map((promo) => (
        <Card key={promo.id}>
          <div className="stack stack--tight">
            <strong className="small">{promo.title}</strong>
            <div className="muted small">
              {promo.institutionName}
              {promo.institutionCity ? ` · ${promo.institutionCity}` : ''}
            </div>
            {promo.message ? (
              <p className="muted small">{promo.message}</p>
            ) : null}
          </div>
        </Card>
        ))}
      </div>
    </section>
  )
}
