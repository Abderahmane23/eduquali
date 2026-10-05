import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import { api } from '../api'
import { useSession } from '../app/session'
import { AppGate } from '../components/AppGate'
import {
  AppBar,
  Banner,
  Button,
  Card,
  Field,
  Chip,
  EmptyState,
  Icon,
  Select,
  Skeleton,
  TextInput,
} from '../components/ui'
import { money } from '../lib/format'
import { useAsync } from '../lib/useAsync'
import type {
  CourseChapterPreview,
  PurchaseRequest,
  PurchaseState,
  VideoCourse,
  WalletMethod,
} from '../api/types'

/**
 * Les cours video en vente.
 *
 * **La vitrine est publique, la lecture non**, et ce n'est pas une
 * restriction arbitraire : un cours s'achete, et le fichier video vit dans
 * l'application, ou il se garde hors ligne. Ce que le web montre est ce qu'un
 * eleve veut savoir avant de payer — le programme, chapitre par chapitre.
 *
 * C'est aussi le meilleur argument qu'ait le site : on lit la table des
 * matieres entiere, puis il faut l'application pour regarder.
 */
export function Courses() {
  const [subjectId, setSubjectId] = useState('')

  const subjects = useAsync(() => api.subjects(), [])
  const courses = useAsync(
    () => api.videoCourses({ subjectId: subjectId || undefined }),
    [subjectId],
  )

  return (
    <>
      <AppBar title="Cours vidéo" />
      <div className="screen stack">
        <p className="muted small">
          Des cours enregistrés par des professeurs guinéens. Payés une fois,
          revus autant de fois qu’il faut.
        </p>

        <Select
          value={subjectId}
          onChange={(e) => setSubjectId(e.target.value)}
          aria-label="Filtrer par matière"
        >
          <option value="">Toutes les matières</option>
          {(subjects.data ?? []).map((subject) => (
            <option key={subject.id} value={subject.id}>
              {subject.name}
            </option>
          ))}
        </Select>

        {courses.loading ? (
          <Skeleton height={120} count={3} />
        ) : courses.error ? (
          <Banner tone="warning">{courses.error}</Banner>
        ) : (courses.data ?? []).length === 0 ? (
          <EmptyState
            title="Aucun cours ici"
            message="Changez de matière pour élargir la recherche."
          />
        ) : (
          <div className="stack grid-cards">
            {(courses.data ?? []).map((course) => (
            <Link
              key={course.id}
              to={`/cours/${course.id}`}
              className="card-link"
            >
              <Card>
                <div className="stack stack--tight">
                  <div className="row row--between">
                    <strong>{course.title}</strong>
                    <Chip tone="accent">{money(course.price)}</Chip>
                  </div>
                  <div className="muted small">{course.teacherName}</div>
                  <div
                    className="row"
                    style={{ gap: 'var(--s-2)', flexWrap: 'wrap' }}
                  >
                    {course.subject ? <Chip>{course.subject.name}</Chip> : null}
                    {course.levels.length > 0 ? (
                      <Chip>
                        {course.levels.map((l) => l.name).join(' · ')}
                      </Chip>
                    ) : null}
                  </div>
                  {/* Le volume dit ce qu'on achete mieux que le prix seul :
                      « 75 000 GNF » ne se compare a rien, « 3 chapitres,
                      6 videos » si. */}
                  <div className="row faint micro" style={{ gap: 'var(--s-2)' }}>
                    <Icon name="play" size={12} />
                    {volume(course.chapterCount, course.videoCount)}
                    {course.totalSeconds > 0
                      ? ` · ${duree(course.totalSeconds)}`
                      : ''}
                  </div>
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
 * Le programme d'un cours.
 *
 * Tout le sommaire, sans rien cacher : chapitres, titres des videos, durees,
 * ressources. Masquer la seconde moitie pour « donner envie » ferait douter
 * qu'il y ait une seconde moitie.
 */
export function CourseDetail() {
  const { id = '' } = useParams()
  const course = useAsync(() => api.videoCourse(id), [id])
  const programme = useAsync(() => api.courseProgramme(id), [id])

  if (course.loading) {
    return (
      <>
        <AppBar title="Cours" onBack />
        <div className="screen">
          <Skeleton height={40} count={5} />
        </div>
      </>
    )
  }

  if (course.error) {
    return (
      <>
        <AppBar title="Cours" onBack />
        <div className="screen">
          <Banner tone="warning">{course.error}</Banner>
        </div>
      </>
    )
  }

  if (!course.data) {
    return (
      <>
        <AppBar title="Cours" onBack />
        <EmptyState
          title="Cours introuvable"
          message="Ce cours n’est plus en vente."
        />
      </>
    )
  }

  const c = course.data
  const chapitres = programme.data ?? []

  return (
    <>
      <AppBar title={c.title} onBack />
      {/* Le programme a gauche, le prix et l'action a droite : sur un
          programme de dix chapitres, le prix doit rester sous les yeux. */}
      <div className="screen detail stack stack--loose">
        <aside className="detail__aside stack">
          <div className="stack stack--tight">
            <h1 className="page-title">{c.title}</h1>
            <p className="muted small">Par {c.teacherName}</p>
            <div className="row" style={{ gap: 'var(--s-2)', flexWrap: 'wrap' }}>
              <Chip tone="accent">{money(c.price)}</Chip>
              {c.subject ? <Chip>{c.subject.name}</Chip> : null}
              {c.levels.length > 0 ? (
                <Chip>{c.levels.map((l) => l.name).join(' · ')}</Chip>
              ) : null}
            </div>
          </div>

          {c.description ? (
            <p className="muted measure">{c.description}</p>
          ) : null}

          <BuyCourse course={c} />
        </aside>

        <section className="detail__main stack stack--tight">
          <h2 className="section-title">
            Programme
            <span className="faint micro" style={{ marginLeft: 'var(--s-2)' }}>
              {volume(c.chapterCount, c.videoCount)}
            </span>
          </h2>

          {programme.loading ? (
            <Skeleton height={64} count={3} />
          ) : chapitres.length === 0 ? (
            <p className="muted small">
              Le professeur n’a pas encore publié le programme de ce cours.
            </p>
          ) : (
            chapitres.map((chapitre) => (
              <Chapitre key={chapitre.id} chapitre={chapitre} />
            ))
          )}
        </section>
      </div>
    </>
  )
}

/** Un chapitre, deplie : on lit le programme, on ne le fouille pas. */
function Chapitre({ chapitre }: { chapitre: CourseChapterPreview }) {
  return (
    <Card>
      <div className="stack stack--tight">
        <strong className="small">
          {chapitre.position + 1}. {chapitre.title}
        </strong>
        {chapitre.description ? (
          <p className="muted small">{chapitre.description}</p>
        ) : null}

        {chapitre.items.map((item) => (
          <div className="row row--between small" key={item.id}>
            <span className="row" style={{ gap: 'var(--s-2)' }}>
              <Icon
                name={item.kind === 'VIDEO' ? 'play' : 'file'}
                size={14}
              />
              <span>{item.title}</span>
            </span>
            {item.durationSeconds ? (
              <span className="faint micro">{duree(item.durationSeconds)}</span>
            ) : null}
          </div>
        ))}
      </div>
    </Card>
  )
}

const volume = (chapitres: number, videos: number): string =>
  [
    `${chapitres} chapitre${chapitres > 1 ? 's' : ''}`,
    `${videos} vidéo${videos > 1 ? 's' : ''}`,
  ].join(' · ')

/** « 1 h 12 » ou « 12 min » — jamais « 72 min », qu'on doit convertir. */
function duree(secondes: number): string {
  const minutes = Math.round(secondes / 60)
  if (minutes < 60) return `${minutes} min`
  const heures = Math.floor(minutes / 60)
  const reste = minutes % 60
  return reste === 0 ? `${heures} h` : `${heures} h ${reste}`
}

/**
 * Acheter un cours.
 *
 * Le parcours suit ce que Djomy fait reellement pour Orange Money et MTN MoMo :
 * l'acheteur choisit son portefeuille, confirme le numero qui paie, et **le
 * telephone sonne**. Il valide sur son propre appareil ; nous attendons la
 * confirmation. Personne ne quitte la page, et aucune coordonnee de paiement ne
 * passe par nous.
 *
 * Le numero du compte est propose par defaut mais reste modifiable : on paie
 * souvent avec le portefeuille d'un parent, d'un oncle, d'un voisin. L'imposer
 * ferait echouer la moitie des paiements.
 *
 * **Rien ici ne decide qu'un cours est paye.** L'etat vient du serveur, qui le
 * tient d'un webhook signe. Cet ecran interroge et affiche ; il ne conclut pas.
 */
function BuyCourse({ course }: { course: VideoCourse }) {
  const { session } = useSession()
  const [method, setMethod] = useState<WalletMethod>()
  const [payerPhone, setPayerPhone] = useState('')
  const [demande, setDemande] = useState<PurchaseRequest>()
  const [etat, setEtat] = useState<PurchaseState>()
  const [erreur, setErreur] = useState<string>()
  const [envoi, setEnvoi] = useState(false)

  const peutAcheter = session?.parentId != null

  /**
   * Relit l'etat tant que la demande est en attente.
   *
   * Toutes les cinq secondes, trente fois au plus : au-dela de deux minutes et
   * demie, le payeur n'a pas confirme, et continuer a interroger ne sert plus
   * qu'a consommer ses donnees.
   */
  useEffect(() => {
    if (!demande || demande.payment !== 'awaiting_confirmation') return
    let tours = 0
    let vivant = true

    const minuterie = setInterval(async () => {
      tours += 1
      if (!vivant || tours > 30) {
        clearInterval(minuterie)
        return
      }
      try {
        const frais = await api.purchaseState(demande.id)
        if (!vivant) return
        setEtat(frais)
        if (frais.status !== 'PENDING') clearInterval(minuterie)
      } catch {
        // Une interrogation perdue n'est pas une erreur a montrer : la
        // suivante arrive dans cinq secondes.
      }
    }, 5000)

    return () => {
      vivant = false
      clearInterval(minuterie)
    }
  }, [demande])

  const payer = async (choisi: WalletMethod) => {
    setEnvoi(true)
    setErreur(undefined)
    setMethod(choisi)
    try {
      const resultat = await api.buyCourse(course.id, {
        method: choisi,
        payerPhone: payerPhone.trim() === '' ? undefined : payerPhone.trim(),
      })
      setDemande(resultat)
      // Portail ou carte : Djomy rend une adresse, on y envoie l'acheteur.
      if (resultat.payment === 'redirect' && resultat.redirectUrl) {
        window.location.assign(resultat.redirectUrl)
      }
    } catch (cause) {
      setErreur(
        cause instanceof Error
          ? cause.message
          : 'La demande n’a pas pu être enregistrée.',
      )
    } finally {
      setEnvoi(false)
    }
  }

  if (!peutAcheter) {
    return (
      <AppGate
        action="suivre ce cours"
        because="Les vidéos se téléchargent dans l’application et se regardent ensuite sans réseau — et sans recommencer à payer des données à chaque révision."
      />
    )
  }

  // --- Apres la demande --------------------------------------------------

  if (demande) {
    const statut = etat?.status ?? demande.status

    /**
     * Un paiement de test doit se voir, y compris quand il « reussit ».
     *
     * C'est la raison d'etre de ce bandeau : en bac a sable, Djomy confirme des
     * paiements ou aucun argent ne bouge. Sans mention, une demonstration passe
     * pour une vente — et on ne cherche l'argent que des semaines plus tard.
     */
    const bandeauTest = demande.sandbox ? (
      <Banner tone="warning">
        Paiement de test : aucun argent n’est prélevé ni reçu.
      </Banner>
    ) : null

    if (statut === 'PAID') {
      return (
        <div className="stack stack--tight">
          {bandeauTest}
          <Banner tone="accent">
            Paiement confirmé. Le cours est à vous : ouvrez l’application pour
            le regarder hors connexion.
          </Banner>
        </div>
      )
    }

    if (statut === 'FAILED' || statut === 'CANCELLED') {
      return (
        <div className="stack stack--tight">
          {bandeauTest}
          <Banner tone="warning">
            Le paiement n’a pas abouti. Rien n’a été débité.
          </Banner>
          <Button
            variant="ghost"
            block
            onClick={() => {
              setDemande(undefined)
              setEtat(undefined)
            }}
          >
            Réessayer
          </Button>
        </div>
      )
    }

    return (
      <div className="stack stack--tight">
        {bandeauTest}
        {demande.payment === 'awaiting_confirmation' ? (
          <>
            <Banner tone="accent">
              Validez le paiement de {money(demande.amount)} sur votre
              téléphone. {method === 'OM' ? 'Orange Money' : 'MTN MoMo'} vous a
              envoyé une demande de confirmation.
            </Banner>
            <p className="faint micro">
              Cette page se met à jour toute seule dès que la confirmation nous
              parvient. Vous pouvez aussi revenir plus tard : le cours
              s’ouvrira.
            </p>
          </>
        ) : (
          <>
            <Banner tone="accent">
              {demande.alreadyRequested
                ? 'Vous avez déjà demandé ce cours.'
                : 'Demande enregistrée.'}{' '}
              Il reste à régler {money(demande.amount)}.
            </Banner>
            {demande.paymentError ? (
              <p className="faint micro">{demande.paymentError}</p>
            ) : (
              <p className="faint micro">
                Le paiement mobile arrive — nous vous recontactons pour
                finaliser.
              </p>
            )}
          </>
        )}
      </div>
    )
  }

  // --- Avant la demande --------------------------------------------------

  return (
    <div className="stack stack--tight">
      {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

      <Field
        label="Numéro qui paie"
        hint="Celui de votre compte par défaut. Vous pouvez en mettre un autre."
      >
        <TextInput
          type="tel"
          inputMode="tel"
          autoComplete="tel"
          maxLength={14}
          placeholder={session?.displayName ? '620 00 01 01' : ''}
          value={payerPhone}
          onChange={(e) => setPayerPhone(e.target.value)}
        />
      </Field>

      {/* Deux boutons plutot qu'une liste deroulante : il n'y a que deux
          operateurs, et un choix a deux options ne se cache pas derriere un
          menu. */}
      <div className="row" style={{ gap: 'var(--s-2)' }}>
        <Button block disabled={envoi} onClick={() => payer('OM')}>
          {envoi && method === 'OM' ? 'Envoi…' : 'Orange Money'}
        </Button>
        <Button block disabled={envoi} onClick={() => payer('MOMO')}>
          {envoi && method === 'MOMO' ? 'Envoi…' : 'MTN MoMo'}
        </Button>
      </div>

      <p className="faint micro">
        {money(course.price)} — vous confirmerez sur votre téléphone. Rien
        n’est débité avant votre validation.
      </p>
    </div>
  )
}
