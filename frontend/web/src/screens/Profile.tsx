import { Link, useNavigate } from 'react-router-dom'
import { api } from '../api'
import { droits, serveurDisponible } from '../api/server'
import { useSession } from '../app/session'
import {
  AppBar,
  Avatar,
  Banner,
  Button,
  Card,
  Chip,
  EmptyState,
  Icon,
  Progress,
  Skeleton,
} from '../components/ui'
import { applicationStatusLabel, availabilityLabel, duree, experienceLabel, institutionTypeLabel, relative } from '../lib/format'
import { useAsync } from '../lib/useAsync'

/** Profil public de l'enseignant (§15). */
/**
 * Profil, quel que soit le compte.
 *
 * L'ecran ne lisait que `session.teacherId` : un etablissement ou un parent
 * tombait donc sur « Profil indisponible », alors que son compte existait.
 * Chaque profil a maintenant sa vue, et toutes partagent la deconnexion.
 */
export function Profile() {
  const { session } = useSession()

  if (session?.role === 'INSTITUTION') return <InstitutionProfile />
  if (session?.role === 'PARENT') return <ParentProfile />
  return <TeacherProfileView />
}

/** Bouton de sortie, commun aux trois profils. */
function SignOut() {
  const { logout } = useSession()
  const navigate = useNavigate()

  return (
    <Button
      variant="ghost"
      block
      onClick={() => {
        // L'ordre compte : on quitte l'espace protege avant de vider la
        // session, sinon le garde de route renvoie vers la connexion et
        // efface la page d'accueil de l'historique.
        navigate('/', { replace: true })
        logout()
      }}
    >
      Se déconnecter
    </Button>
  )
}

function InstitutionProfile() {
  const { session } = useSession()
  const schools = useAsync(() => api.institutions(), [])
  const mine = (schools.data ?? []).find((s) => s.id === session?.institutionId)

  return (
    <>
      <AppBar title="Mon établissement" />
      <div className="screen stack stack--loose">
        {schools.loading ? (
          <Skeleton height={64} count={3} />
        ) : (
          <>
            <div>
              <strong>{mine?.name ?? session?.displayName}</strong>
              <div className="muted small">
                {mine ? institutionTypeLabel(mine.type) : 'Établissement'}
              </div>
              {mine ? (
                <div className="row faint micro" style={{ gap: 'var(--espace-1)' }}>
                  <Icon name="place" size={12} />
                  {mine.city}
                </div>
              ) : null}
            </div>

            {mine?.verified ? (
              <Chip tone="success">Établissement vérifié</Chip>
            ) : (
              <Banner tone="warning">
                Votre établissement est en cours de vérification. Vous pouvez
                déjà publier une offre.
              </Banner>
            )}

            {mine?.description ? (
              <p className="muted small">{mine.description}</p>
            ) : null}
          </>
        )}

        <SignOut />
      </div>
    </>
  )
}

function ParentProfile() {
  const { session } = useSession()

  return (
    <>
      <AppBar title="Mon profil" />
      <div className="screen stack stack--loose">
        <div>
          <strong>{session?.displayName}</strong>
          <div className="muted small">Parent d’élève</div>
        </div>

        <TempsDeCours />

        <section className="stack stack--tight">
          <h3 className="section-title">Mes enfants</h3>
          <EmptyState
            title="Aucun enfant enregistré"
            message="Ajoutez un enfant pour recevoir des propositions adaptées à sa classe."
          />
        </section>

        <SignOut />
      </div>
    </>
  )
}

/**
 * « Temps de cours cette semaine ».
 *
 * Le chiffre qui dit à un parent si l'abonnement sert. Il ne demande pas un
 * tableau de bord : il demande si son enfant travaille, et une réponse en une
 * ligne vaut mieux qu'un graphique qu'il n'ouvrira pas.
 *
 * Les minutes sont comptées par le serveur de visioconférence, jamais déclarées
 * par un client — un onglet fermé n'envoie pas de départ, et un élève qui
 * voudrait faire croire qu'il suit le cours n'aurait qu'à mentir une fois.
 *
 * Rien ne s'affiche tant qu'il n'y a rien à montrer : une semaine à zéro sur le
 * profil d'une famille qui vient de s'inscrire se lit comme un reproche.
 */
function TempsDeCours() {
  const resume = useAsync(() => api.studyMinutes(), [])

  if (resume.loading || !resume.data || resume.data.totalMinutes === 0) {
    return null
  }

  const { totalMinutes, sessions, perChild, perSubject } = resume.data

  return (
    <section className="stack stack--tight">
      <h3 className="section-title">Cette semaine</h3>
      <Card accent>
        <div className="stack stack--tight">
          <div>
            <strong className="chiffre">{duree(totalMinutes)}</strong>
            <div className="muted small">
              de cours en direct, sur {sessions} séance{sessions > 1 ? 's' : ''}
            </div>
          </div>

          {/* Par enfant d'abord : c'est la question posée. La matière vient
              ensuite, et répond à « sur quoi ? ». */}
          {perChild.length > 1 ? (
            <ul className="liste-nue small">
              {perChild.map((ligne) => (
                <li className="row row--between" key={ligne.childName}>
                  <span>{ligne.childName}</span>
                  <span className="muted">{duree(ligne.minutes)}</span>
                </li>
              ))}
            </ul>
          ) : null}

          {perSubject.length > 0 ? (
            <div className="row" style={{ gap: 'var(--espace-1)', flexWrap: 'wrap' }}>
              {perSubject.map((ligne) => (
                <Chip key={ligne.subjectName}>
                  {ligne.subjectName} · {duree(ligne.minutes)}
                </Chip>
              ))}
            </div>
          ) : null}
        </div>
      </Card>
    </section>
  )
}

/** « 45 min », « 3 h 30 ». */

function TeacherProfileView() {
  const { session } = useSession()
  const profile = useAsync(
    () => (session?.teacherId ? api.teacher(session.teacherId) : Promise.resolve(null)),
    [session?.teacherId],
  )

  if (profile.loading) {
    return (
      <>
        <AppBar title="Mon profil" />
        <div className="screen">
          <Skeleton height={64} count={4} />
        </div>
      </>
    )
  }

  const me = profile.data
  if (!me) {
    return (
      <>
        <AppBar title="Mon profil" />
        <div className="screen stack stack--loose">
          <EmptyState
            title="Profil incomplet"
            message="Votre fiche n’est pas encore créée. Reprenez l’inscription pour la compléter."
          />
          <SignOut />
        </div>
      </>
    )
  }

  const badges: [string, boolean][] = [
    ['Identité vérifiée', me.badges.identity],
    ['Diplôme vérifié', me.badges.diploma],
    ['Compétence certifiée', me.badges.competency],
    ['Expérience vérifiée', me.badges.experience],
  ]

  return (
    <>
      <AppBar title="Mon profil" />
      <div className="screen stack stack--loose">
        <RappelDossier badges={me.badges} />
        <div className="row">
          <Avatar first={me.firstName} last={me.lastName} src={me.photoUrl} />
          <div>
            <strong>{me.fullName}</strong>
            <div className="muted small">{me.headline}</div>
            <div className="row faint micro" style={{ gap: 'var(--espace-1)' }}>
              <Icon name="place" size={12} />
              {me.city}
            </div>
          </div>
        </div>

        {me.completionRate < 100 ? (
          <Card accent>
            <div className="stack stack--tight">
              <div className="row row--between">
                <strong>Profil complété a {me.completionRate} %</strong>
              </div>
              <Progress value={me.completionRate / 100} />
              <span className="small">
                Continuez pour etre visible par les établissements.
              </span>
            </div>
          </Card>
        ) : null}

        <section className="stack stack--tight">
          <h3 className="section-title">Verification</h3>
          {badges.map(([label, done]) => (
            <div className="row small" key={label}>
              <span style={{ color: done ? 'var(--vert-fonce)' : 'var(--crayon)' }}>
                <Icon name={done ? 'check' : 'shield'} size={16} />
              </span>
              <span className={done ? '' : 'faint'}>{label}</span>
            </div>
          ))}
        </section>

        {me.certifications.length > 0 ? (
          <section className="stack stack--tight">
            <h3 className="section-title">Certifications</h3>
            {me.certifications.map((cert) => (
              <Card key={cert.id}>
                <div className="row row--between">
                  <span>
                    <strong>{cert.subject.name}</strong>
                    <span className="muted"> — {cert.level.name}</span>
                  </span>
                  <Chip tone="success">{cert.score} %</Chip>
                </div>
              </Card>
            ))}
          </section>
        ) : null}

        <section className="stack stack--tight">
          <h3 className="section-title">Experience</h3>
          <span className="muted small">
            {experienceLabel(me.yearsExperience)} ·{' '}
            {availabilityLabel(me.availability)}
          </span>
          {me.experiences.map((exp) => (
            <Card key={exp.id}>
              <div className="stack stack--tight">
                <strong>{exp.position}</strong>
                <span className="muted small">{exp.institutionName}</span>
                <span className="faint micro">
                  {exp.startYear} – {exp.endYear ?? 'aujourd’hui'}
                  {exp.verified ? ' · vérifiée' : ''}
                </span>
              </div>
            </Card>
          ))}
        </section>

        <SignOut />
      </div>
    </>
  )
}

/** Suivi des candidatures (§18). */
/**
 * « Il vous manque votre piece d'identite. »
 *
 * Une carte, et non une fenetre modale : une modale se ferme d'un geste, et
 * au troisieme passage on apprend ou est la croix sans plus rien lire.
 * Celle-ci reste tant que le dossier est incomplet, et n'empeche pas de
 * faire autre chose.
 */
function RappelDossier({
  badges,
}: {
  badges: { identity: boolean; diploma: boolean }
}) {
  /*
   * L'etat de l'essai vient du serveur, et son absence ne fait pas taire le
   * rappel.
   *
   * `/entitlements` lit des colonnes posees par la migration 0034. Tant
   * qu'elle n'est pas appliquee, l'appel echoue — et un dossier incomplet
   * reste un dossier incomplet. On affiche alors la forme douce.
   */
  const etat = useAsync(
    () => (serveurDisponible ? droits.lire() : Promise.resolve(undefined)),
    [],
  )

  const manque: string[] = []
  if (!badges.identity) manque.push('votre pièce d’identité')
  if (!badges.diploma) manque.push('votre diplôme')
  if (manque.length === 0) return null

  const enEssai = etat.data?.essai.enCours ?? true
  const restants = etat.data?.essai.joursRestants

  return (
    <Card>
      <div className="stack stack--tight">
        <strong>
          {enEssai
            ? 'Terminez votre inscription'
            : 'Votre fiche ne remonte pas encore'}
        </strong>
        <p className="muted small">
          {enEssai ? (
            <>
              Il manque {manque.join(' et ')}. Une fiche vérifiée passe
              devant les autres dans les recherches
              {typeof restants === 'number' && restants > 0
                ? `, et votre essai se termine dans ${restants} jour${
                    restants > 1 ? 's' : ''
                  }`
                : null}
              .
            </>
          ) : (
            <>
              Il manque {manque.join(' et ')}. Tant qu’elles ne sont pas
              déposées, votre fiche reste derrière celles qui le sont — c’est
              la raison la plus fréquente d’un profil que personne n’appelle.
            </>
          )}
        </p>
        <Link className="btn btn--primary btn--block" to="/profil/dossier">
          Déposer mes pièces
        </Link>
      </div>
    </Card>
  )
}

export function Applications() {
  const { session } = useSession()
  const navigate = useNavigate()
  const state = useAsync(
    () =>
      session?.teacherId
        ? api.applications(session.teacherId)
        : Promise.resolve([]),
    [session?.teacherId],
  )

  return (
    <>
      <AppBar title="Mes candidatures" />
      <div className="screen stack">
        {state.loading ? (
          <Skeleton height={96} />
        ) : state.error ? (
          <Banner tone="warning">{state.error}</Banner>
        ) : (state.data ?? []).length === 0 ? (
          <EmptyState
            title="Aucune candidature"
            message="Vos candidatures apparaîtront ici avec leur statut."
            action={
              <Button variant="ghost" onClick={() => navigate('/offres')}>
                Parcourir les offres
              </Button>
            }
          />
        ) : (
          <div className="stack grid-cards">
            {(state.data ?? []).map((application) => (
            <Card
              key={application.id}
              onClick={() => navigate(`/offres/${application.job.id}`)}
            >
              <div className="stack stack--tight">
                <div className="row row--between">
                  <strong>{application.job.title}</strong>
                  {application.matchScore != null ? (
                    <Chip tone="accent">{application.matchScore} %</Chip>
                  ) : null}
                </div>
                <span className="muted small">
                  {application.job.institution.name}
                </span>
                <div className="row" style={{ gap: 'var(--espace-2)' }}>
                  <Chip>{applicationStatusLabel(application.status)}</Chip>
                  <span className="faint micro">
                    {relative(application.appliedAt)}
                  </span>
                </div>
              </div>
            </Card>
            ))}
          </div>
        )}
      </div>
    </>
  )
}
