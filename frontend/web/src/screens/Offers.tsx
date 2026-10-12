import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { api } from '../api'
import { useSession } from '../app/session'
import { AppGate } from '../components/AppGate'
import {
  AppBar,
  Banner,
  Button,
  Card,
  Chip,
  EmptyState,
  Icon,
  Skeleton,
} from '../components/ui'
import {
  contractLabel,
  experienceLabel,
  publishedOn,
  salaryRange,
} from '../lib/format'
import { useAsync } from '../lib/useAsync'
import type { JobOffer } from '../api/types'

/**
 * Liste des opportunites (§17).
 *
 * Par defaut, seules les offres correspondant aux matières declarees par
 * l'enseignant sont affichees : proposer des offres hors de son domaine
 * n'apporte rien et noie les offres pertinentes.
 */
/**
 * Offres d'emploi (§17).
 *
 * Un enseignant ne voit que les offres de ses matières. Pas de barre de
 * recherche ni de filtre : le profil dit déjà ce qu'il enseigne, redemander
 * la même chose à chaque visite est du travail rendu à l'utilisateur.
 *
 * Le filtrage se fait côté serveur dès que l'API réelle est branchée ; ici
 * la liste est réduite aux matières déclarées.
 */
export function Offers() {
  const { session } = useSession()
  const navigate = useNavigate()

  const profile = useAsync(
    () =>
      session?.teacherId ? api.teacher(session.teacherId) : Promise.resolve(null),
    [session?.teacherId],
  )
  const offers = useAsync(() => api.jobs(), [])

  const mySubjectIds = (profile.data?.subjects ?? []).map((s) => s.id)

  // Tant que le profil ne declare aucune matière, tout afficher vaut mieux
  // qu'une liste vide qui ressemble a une panne.
  const visible =
    mySubjectIds.length > 0
      ? (offers.data ?? []).filter((offer) =>
          mySubjectIds.includes(offer.subject.id),
        )
      : (offers.data ?? [])

  const loading = offers.loading || profile.loading

  return (
    <>
      <AppBar title="Offres d’emploi" />
      <div className="screen stack">
        {loading ? (
          <Skeleton height={120} />
        ) : offers.error ? (
          <Banner tone="warning">{offers.error}</Banner>
        ) : visible.length === 0 ? (
          <EmptyState
            title="Aucune offre pour l’instant"
            message={
              mySubjectIds.length > 0
                ? 'Rien dans vos matières aujourd’hui. De nouvelles offres arrivent chaque semaine.'
                : 'Ajoutez vos matières pour recevoir les offres qui vous correspondent.'
            }
            action={
              mySubjectIds.length === 0 ? (
                <Button variant="ghost" onClick={() => navigate('/profil')}>
                  Ajouter mes matières
                </Button>
              ) : undefined
            }
          />
        ) : (
          <div className="stack grid-cards">
            {visible.map((offer) => (
              <OfferCard
                key={offer.id}
                offer={offer}
                onOpen={() => navigate(`/offres/${offer.id}`)}
              />
            ))}
          </div>
        )}
      </div>
    </>
  )
}

function OfferCard({
  offer,
  onOpen,
}: {
  offer: JobOffer
  onOpen: () => void
}) {
  return (
    <Card onClick={onOpen}>
      <div className="stack stack--tight">
        <strong>{offer.title}</strong>
        <span className="muted small">{offer.institution.name}</span>
        <div className="row small faint" style={{ gap: 'var(--espace-2)' }}>
          <Icon name="place" size={14} />
          {offer.city}
        </div>
        <div className="row" style={{ gap: 'var(--espace-2)', flexWrap: 'wrap' }}>
          <Chip tone="accent">{offer.levels.map((l) => l.name).join(' · ')}</Chip>
          <Chip>{contractLabel(offer.contractType)}</Chip>
          {offer.requiresCertification ? (
            <Chip tone="success">Certification requise</Chip>
          ) : null}
        </div>
        <span className="micro faint">{publishedOn(offer.publishedAt)}</span>
      </div>
    </Card>
  )
}

/** Detail d'une offre et candidature (§18). */
export function OfferDetail() {
  const { id = '' } = useParams()
  const { session } = useSession()
  const navigate = useNavigate()
  const [applying, setApplying] = useState(false)
  const [applied, setApplied] = useState(false)
  const [error, setError] = useState<string>()

  const offer = useAsync(() => api.job(id), [id])

  const apply = async () => {
    if (!session?.teacherId) return
    setApplying(true)
    setError(undefined)
    try {
      await api.apply(session.teacherId, id)
      setApplied(true)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Votre candidature n’est pas partie. Réessayez.')
    } finally {
      setApplying(false)
    }
  }

  if (offer.loading) {
    return (
      <>
        <AppBar title="Offre" onBack />
        <div className="screen">
          <Skeleton height={40} count={5} />
        </div>
      </>
    )
  }

  if (!offer.data) {
    return (
      <>
        <AppBar title="Offre" onBack />
        <EmptyState title="Offre introuvable" />
      </>
    )
  }

  const job = offer.data
  const salary = salaryRange(job.salaryMin, job.salaryMax, job.salaryPublished)

  return (
    <>
      <AppBar title={job.institution.name} onBack />
      <div className="screen stack stack--loose">
        <div className="stack stack--tight">
          <h1 className="page-title">{job.title}</h1>
          <div className="row" style={{ gap: 'var(--espace-2)', flexWrap: 'wrap' }}>
            <Chip tone="accent">{job.subject.name}</Chip>
            <Chip>{job.levels.map((l) => l.name).join(' · ')}</Chip>
            <Chip>{contractLabel(job.contractType)}</Chip>
          </div>
        </div>

        <div className="stack stack--tight">
          <Row icon="place" label={job.city} />
          <Row icon="clock" label={publishedOn(job.publishedAt)} />
          {salary ? <Row icon="briefcase" label={salary} /> : null}
          {job.minExperience > 0 ? (
            <Row icon="user" label={experienceLabel(job.minExperience)} />
          ) : null}
        </div>

        {job.description ? <p className="muted">{job.description}</p> : null}

        {error ? <Banner tone="warning">{error}</Banner> : null}

        {applied ? (
          <Banner tone="accent">
            Candidature envoyée. Vous serez prévenu dès que l’établissement
            l’aura consultée.
          </Banner>
        ) : session?.teacherId ? (
          <Button block onClick={apply} disabled={applying}>
            {applying ? 'Envoi…' : 'Envoyer ma candidature'}
          </Button>
        ) : (
          // Sans fiche enseignant, `apply` sortait sans rien faire : le
          // bouton s'enfoncait et il ne se passait rien. C'etait vrai pour un
          // visiteur comme pour un compte parent ou etablissement.
          <AppGate
            action="postuler"
            because="Une candidature part avec votre CV et vos diplômes, qui se déposent depuis l’application."
          />
        )}

        {applied ? (
          <Button variant="ghost" block onClick={() => navigate('/candidatures')}>
            Voir mes candidatures
          </Button>
        ) : null}
      </div>
    </>
  )
}

function Row({ icon, label }: { icon: 'place' | 'clock' | 'briefcase' | 'user'; label: string }) {
  return (
    <div className="row muted small">
      <Icon name={icon} size={16} />
      <span>{label}</span>
    </div>
  )
}
