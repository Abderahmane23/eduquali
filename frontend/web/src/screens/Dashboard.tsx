import { Link, useNavigate } from 'react-router-dom'
import { api } from '../api'
import { prof, revenus, serveurDisponible } from '../api/server'
import { useSession } from '../app/session'
import {
  BigButton,
  PageHead,
  RowItem,
  StatStrip,
  gnf,
  gnfCourt,
} from '../components/kit'
import { Banner, Card, Chip, EmptyState, Icon, Skeleton } from '../components/ui'
import { useAsync } from '../lib/useAsync'
import { longDayLabel, loadSlots, timeLabel } from '../lib/slots'

/**
 * Le tableau de bord du professeur.
 *
 * --- Le vide que cette page remplit -------------------------------------
 *
 * Un professeur connecté était redirigé vers `/offres` — un tableau d'offres
 * d'emploi. Il n'avait aucun écran qui lui montre ses propres cours : la
 * méthode `myLiveCourses` existait dans le contrat et dans les deux backends,
 * et **aucun écran ne l'appelait**. Il publiait un cours et ne le revoyait
 * jamais.
 *
 * Pire : il n'existait aucun lien vers sa propre salle. « Mes séances » lit
 * `mySessions()`, que le serveur remplit depuis `session_enrolments` — les
 * places achetées par les familles. Son commentaire le dit : « Un compte
 * enseignant n'a pas de fiche famille : liste vide, pas une erreur. » La
 * section était donc vide pour un professeur, qui devait taper
 * `/direct/<id>/salle` de mémoire pour entrer dans son propre cours.
 *
 * --- L'ordre de la page -------------------------------------------------
 *
 * Ce qui est urgent d'abord : la séance du jour, avec le bouton pour entrer.
 * Puis ce qui se décide : publier, déposer un cours, répondre. Puis ce qui
 * s'observe : les chiffres. Un tableau de bord qui commence par des chiffres
 * se lit comme un rapport, et personne n'ouvre un rapport pour faire cours.
 */
export function Dashboard() {
  const { session } = useSession()
  const navigate = useNavigate()

  const seances = useAsync(() => prof.seances(), [])
  const argent = useAsync(() => revenus.lire(), [])
  const grille = useAsync(() => loadSlots(), [])
  const fiche = useAsync(
    () => (session?.teacherId ? api.teacher(session.teacherId) : Promise.resolve(null)),
    [session?.teacherId],
  )

  if (!serveurDisponible) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Tableau de bord</h1>
        <Banner tone="warning">
          Cette page lit vos séances et vos revenus sur le serveur Eduquali,
          qui n’est pas relié à ce site. Les listes publiques restent
          consultables.
        </Banner>
      </div>
    )
  }

  const liste = seances.data?.sessions ?? []
  const maintenant = Date.now()

  /*
   * La séance qu'on peut ouvrir : la même fenêtre que celle du serveur, qui
   * refuse un jeton en dehors. Montrer un bouton qui échoue vaut moins que ne
   * pas le montrer.
   */
  const ouvrable = liste.find((seance) => {
    const debut = Date.parse(seance.startsAt)
    const fin = debut + seance.durationMinutes * 60_000
    return maintenant >= debut - 15 * 60_000 && maintenant <= fin + 30 * 60_000
  })

  const places = liste.reduce((total, s) => total + s.seatsTaken, 0)

  // Le prenom seul : « Bonjour Mariama Camara » se lit comme un courrier
  // administratif. `displayName` porte les deux.
  const prenom = session?.displayName?.trim().split(' ')[0]

  return (
    <div className="screen stack stack--loose">
      <PageHead
        title={prenom ? `Bonjour ${prenom}` : 'Votre tableau de bord'}
        lede={
          liste.length === 0
            ? 'Vous n’avez pas encore de séance programmée. Publiez un cours : les séances sont créées dans la minute.'
            : `${liste.length} séance${liste.length > 1 ? 's' : ''} à venir.`
        }
        stats={
          argent.data
            ? [
                { value: places, label: 'places vendues' },
                {
                  // Abrege : la cellule fait un tiers du bandeau, soit
                  // environ 74 px sur un telephone.
                  value: gnfCourt(argent.data.earned.total),
                  label: 'gagnés (GNF)',
                },
                {
                  value: fiche.data ? `${fiche.data.completionRate} %` : '—',
                  label: 'profil complété',
                },
              ]
            : undefined
        }
      />

      {/*
        Le gros bouton, en premier.

        C'est la forme du tableau de bord du téléphone : une action majeure et
        une seule, en haut, avant toute liste. Un professeur ouvre cette page
        pour faire cours ou pour en publier un — pas pour lire des chiffres.
      */}
      {ouvrable ? (
        <BigButton
          icon="play"
          onClick={() => navigate(`/direct/${ouvrable.id}/salle`)}
        >
          Entrer dans la salle
        </BigButton>
      ) : (
        <BigButton icon="plus" onClick={() => navigate('/direct/nouveau')}>
          Publier un cours en direct
        </BigButton>
      )}

      {/*
        --- Pourquoi deux colonnes a partir de 1 024 px -------------------

        Les seances se parcourent ; les quatre actions et les revenus se
        decident. Sur une seule colonne de 1 120 px, une rangee « Deposer un
        cours video » portait son chevron a mille pixels de son libelle, et il
        fallait defiler sous six cartes de seance pour atteindre la premiere
        action.

        L'ordre du DOM reste celui du telephone : les seances d'abord. Un
        professeur ouvre cette page pour faire cours.
      */}
      <div className="pagegrid">
        <div className="pagegrid__main">
      {seances.loading ? (
        <Skeleton height={88} count={2} />
      ) : seances.error ? (
        <Banner tone="warning">{seances.error}</Banner>
      ) : liste.length === 0 ? (
        <EmptyState
          title="Aucune séance programmée"
          message="Choisissez une matière, un niveau et un créneau : les séances des quatre prochaines semaines sont créées aussitôt, et votre cours apparaît dans la grille."
        />
      ) : (
        <section className="stack">
          <h2 className="section-title">Mes séances</h2>
          <div className="stack grid-cards">
            {liste.map((seance) => {
              const debut = new Date(seance.startsAt)
              const fin = debut.getTime() + seance.durationMinutes * 60_000
              const entrable =
                maintenant >= debut.getTime() - 15 * 60_000
                && maintenant <= fin + 30 * 60_000
              const complet = seance.seats > 0 && seance.seatsTaken >= seance.seats

              return (
                <Card key={seance.id}>
                  <div className="stack stack--tight">
                    <div className="row row--between">
                      <strong>{seance.subject ?? seance.title ?? 'Cours'}</strong>
                      <Chip tone={complet ? 'success' : undefined}>
                        {seance.seatsTaken} / {seance.seats}
                      </Chip>
                    </div>

                    <span className="muted small">
                      {grille.data
                        ? longDayLabel(debut, grille.data.weekdayLabels)
                        : debut.toLocaleDateString('fr-FR')}
                      {' · '}
                      {timeLabel(debut)}
                    </span>

                    {/*
                      Zéro inscrit n'est pas une erreur, et le dire évite
                      d'attendre dans une salle vide sans savoir pourquoi.
                    */}
                    {seance.seatsTaken === 0 ? (
                      <span className="faint micro">
                        Personne d’inscrit pour l’instant.
                      </span>
                    ) : null}

                    <div className="row" style={{ flexWrap: 'wrap' }}>
                      {entrable ? (
                        <Link
                          className="btn btn--primary"
                          to={`/direct/${seance.id}/salle`}
                        >
                          Entrer dans la salle
                        </Link>
                      ) : null}
                      <Link
                        className="btn btn--ghost"
                        to={`/direct/${seance.id}/inscrits`}
                      >
                        <Icon name="user" size={18} />
                        Les inscrits
                      </Link>
                    </div>
                  </div>
                </Card>
              )
            })}
          </div>
        </section>
      )}

        </div>

        <aside className="pagegrid__aside">
      {/* Ce qui se décide. Des rangées et non des cartes : six actions en
          cartes font six objets à comparer, alors qu'il s'agit d'une liste. */}
      <section className="stack">
        <h2 className="section-title">Développer mon activité</h2>
        <div className="rows">
        <RowItem
          icon="play"
          title="Déposer un cours vidéo"
          sub="Il se vend sans vous, autant de fois qu’on l’achète"
          onClick={() => navigate('/cours/nouveau')}
        />
        <RowItem
          icon="pin"
          tone="success"
          title="Proposer des cours à domicile"
          sub="La ligne la mieux payée : 500 000 à 900 000 GNF par mois"
          onClick={() => navigate('/domicile')}
        />
        <RowItem
          icon="sparkle"
          tone="warning"
          title="Préparer un cours avec l’assistant"
          sub="Plan, exercices et corrigés sur le programme guinéen"
          onClick={() => navigate('/assistant')}
        />
        <RowItem
          icon="diploma"
          tone="neutral"
          title="Compléter mon dossier"
          sub={
            fiche.data
              ? `Profil complété à ${fiche.data.completionRate} % — les pièces vérifiées font la différence`
              : 'Pièce d’identité, diplôme, CV'
          }
          onClick={() => navigate('/profil/dossier')}
        />
        </div>
      </section>

      {/* Les chiffres, en dernier : ils s'observent, ils ne se décident pas. */}
      {argent.data ? (
        <section className="stack">
          <h2 className="section-title">Mes revenus</h2>
          <StatStrip
            plain
            stats={[
              {
                value: gnfCourt(argent.data.earned.live),
                label: 'cours en direct',
              },
              {
                value: gnfCourt(argent.data.earned.videos),
                label: 'cours vidéo',
              },
              {
                value: gnfCourt(argent.data.available),
                label: 'à retirer',
              },
            ]}
          />
          {/* Le montant exact ici, en toutes lettres : le bandeau donne
              l'ordre de grandeur, cette ligne donne le chiffre. */}
          <span className="faint micro">
            {gnf(argent.data.earned.total)} gagnés en tout.
          </span>
          <Link className="block-link" to="/revenus">
            Voir le détail et demander un retrait
          </Link>
        </section>
      ) : null}
        </aside>
      </div>
    </div>
  )
}
