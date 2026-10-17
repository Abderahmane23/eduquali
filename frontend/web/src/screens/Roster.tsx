import { useState } from 'react'
import { useParams } from 'react-router-dom'
import { prof, serveurDisponible } from '../api/server'
import { StatStrip, Tile } from '../components/kit'
import {
  AppBar,
  Banner,
  Button,
  Chip,
  EmptyState,
  Icon,
  Skeleton,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'

/**
 * Qui est attendu, et qui est là.
 *
 * --- Ce que cette page remplace -----------------------------------------
 *
 * Rien : un professeur sur le site entrait dans sa salle sans savoir combien
 * de personnes l'attendaient, ni si quelqu'un l'attendait. Les routes
 * existaient — `/roster`, `/notify` — et le téléphone les appelait déjà.
 *
 * --- Deux listes en une -------------------------------------------------
 *
 * Les places vendues et la présence constatée. Le professeur a besoin des
 * deux ensemble : « douze inscrits, sept présents » est la seule phrase qui
 * lui dise s'il doit attendre ou commencer.
 *
 * --- Ce qui ne s'affiche pas -------------------------------------------
 *
 * Le prénom de l'élève, et rien d'autre. Pas de téléphone, pas de courriel,
 * pas d'identifiant de compte : le professeur n'en a pas besoin pour faire
 * son cours, et le serveur ne les envoie pas.
 */
export function Roster() {
  const { id = '' } = useParams<{ id: string }>()
  const classe = useAsync(() => prof.inscrits(id), [id])

  const [envoi, setEnvoi] = useState<string>()
  const [fait, setFait] = useState<string>()
  const [erreur, setErreur] = useState<string>()

  const prevenir = async (
    cible: { enrolmentIds?: string[]; all?: boolean },
    marqueur: string,
    reussite: (n: number) => string,
  ) => {
    setEnvoi(marqueur)
    setErreur(undefined)
    setFait(undefined)
    try {
      const corps = await prof.prevenir(id, cible)
      setFait(reussite(corps.notified))
    } catch (cause) {
      setErreur(
        cause instanceof Error
          ? cause.message
          : 'L’envoi n’a pas abouti. Réessayez.',
      )
    } finally {
      setEnvoi(undefined)
    }
  }

  if (!serveurDisponible) {
    return (
      <>
        <AppBar title="Les inscrits" onBack />
        <div className="screen">
          <Banner tone="warning">
            Cette page lit la liste sur le serveur EduQuali, qui n’est pas
            relié à ce site.
          </Banner>
        </div>
      </>
    )
  }

  if (classe.loading) {
    return (
      <>
        <AppBar title="Les inscrits" onBack />
        <div className="screen">
          <Skeleton height={64} count={4} />
        </div>
      </>
    )
  }

  if (classe.error) {
    return (
      <>
        <AppBar title="Les inscrits" onBack />
        <div className="screen">
          <Banner tone="warning">{classe.error}</Banner>
        </div>
      </>
    )
  }

  const liste = classe.data?.roster ?? []
  const attendus = classe.data?.expected ?? 0
  const presents = classe.data?.present ?? 0

  return (
    <>
      <AppBar title="Les inscrits" onBack />
      <div className="screen screen--narrow stack stack--loose">
        <StatStrip
          plain
          stats={[
            { value: attendus, label: 'places vendues' },
            { value: presents, label: 'en salle' },
            { value: attendus - presents, label: 'pas encore là' },
          ]}
        />

        {attendus === 0 ? (
          <EmptyState
            icon="user"
            title="Personne d’inscrit"
            message="Les places se vendent jusqu’au début de la séance. Prévenez votre répertoire : ce sont les familles qui ont déjà suivi un de vos cours."
          />
        ) : (
          <>
            {/*
              Prévenir tout le monde d'abord : c'est le geste de la minute
              avant le cours, et aller le chercher au bout de douze lignes
              serait le geste le plus long de la page.

              Pas de SMS. Chaque message coûte, et un professeur qui prévient
              quinze personnes trois fois par semaine ferait une facture. Ce
              sont des notifications dans l'application.
            */}
            <div className="row" style={{ flexWrap: 'wrap' }}>
              <Button
                onClick={() =>
                  prevenir(
                    { all: true },
                    'tous',
                    (n) => `${n} personne${n > 1 ? 's' : ''} prévenue${n > 1 ? 's' : ''}.`,
                  )
                }
                disabled={envoi !== undefined}
              >
                <Icon name="bell" size={18} />
                {envoi === 'tous' ? 'Envoi…' : 'Prévenir tout le monde'}
              </Button>
              <span className="faint micro">
                Une notification dans l’application, pas un SMS.
              </span>
            </div>

            {fait ? <Banner>{fait}</Banner> : null}
            {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

            <section className="stack stack--tight">
              <h2 className="section-title">La classe</h2>
              {liste.map((inscrit) => (
                <div className="rowitem" key={inscrit.enrolmentId}>
                  <Tile
                    icon="user"
                    tone={inscrit.present ? 'success' : 'neutral'}
                  />
                  <span className="rowitem__body">
                    <span className="rowitem__title">{inscrit.name}</span>
                    <span className="rowitem__sub">
                      {inscrit.present
                        ? `en salle depuis ${inscrit.minutes} min`
                        : 'pas encore entré'}
                    </span>
                  </span>
                  <span className="rowitem__end">
                    {inscrit.present ? (
                      <Chip tone="success">Présent</Chip>
                    ) : (
                      <Button
                        variant="quiet"
                        onClick={() =>
                          prevenir(
                            { enrolmentIds: [inscrit.enrolmentId] },
                            inscrit.enrolmentId,
                            () => `${inscrit.name} a été prévenu.`,
                          )
                        }
                        disabled={envoi !== undefined}
                      >
                        {envoi === inscrit.enrolmentId ? 'Envoi…' : 'Prévenir'}
                      </Button>
                    )}
                  </span>
                </div>
              ))}
            </section>
          </>
        )}
      </div>
    </>
  )
}
