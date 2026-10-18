import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'

import { api } from '../api'
import { useSession } from '../app/session'
import { AppGate } from '../components/AppGate'
import { PageHead, SegmentedToggle } from '../components/kit'
import {
  AppBar,
  Banner,
  Button,
  Card,
  Chip,
  EmptyState,
  Field,
  Icon,
  Select,
  Skeleton,
  TextInput,
} from '../components/ui'
import { money } from '../lib/format'
import {
  groupByDay,
  loadSlots,
  longDayLabel,
  timeLabel,
  type SlotGrid,
} from '../lib/slots'
import { useAsync } from '../lib/useAsync'
import type {
  EnrolmentResult,
  LiveSession,
  MySession,
  WalletMethod,
} from '../api/types'

/**
 * La grille des cours en direct.
 *
 * **Publique.** On consulte un emploi du temps avant d'ouvrir un compte, comme
 * on consulte le programme d'un cours vidéo. Payer vient après avoir vu qu'il y
 * a un cours de maths le mardi à 18 h.
 *
 * Elle se lit **par journée** et non comme une liste de dates : « jeudi, deux
 * cours » se comprend d'un coup d'œil, une suite d'horodatages non.
 */
export function LiveGrid() {
  const [subjectId, setSubjectId] = useState('')
  const [grille, setGrille] = useState<SlotGrid>()

  const subjects = useAsync(() => api.subjects(), [])
  const seances = useAsync(
    () => api.liveSessions({ subjectId: subjectId || undefined }),
    [subjectId],
  )

  useEffect(() => {
    loadSlots()
      .then(setGrille)
      .catch(() => setGrille(undefined))
  }, [])

  const jours = groupByDay(seances.data ?? [], (s) => new Date(s.startsAt))

  return (
    <>
      <div className="screen stack stack--loose">
        {/*
          Le bandeau de la charte, et non une barre de navigation.

          `AppBar` porte un titre et un bouton retour. Sur un ecran de
          detail elle sert ; sur un onglet de premier rang il n'y a pas de
          retour a proposer, et l'onglet est deja surligne dans la barre du
          haut. Elle ne faisait donc que repeter le nom de la page, en
          remplacant le bandeau que la charte donne a chaque ecran.
        */}
        <PageHead
          title="Cours en direct"
          lede={
            'Quinze élèves au maximum, à heure fixe. Vous levez la main ' +
            'pour parler, et le professeur réexplique avant de continuer.'
          }
        />

        {/* Ses propres séances d'abord : quelqu'un qui a déjà payé vient
            pour retrouver son cours, pas pour en chercher un autre. */}
        <MesSeances grille={grille} />


        <Select
          value={subjectId}
          onChange={(e) => setSubjectId(e.target.value)}
          aria-label="Filtrer par matière"
        >
          <option value="">Toutes les matières</option>
          {(subjects.data ?? []).map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </Select>

        {seances.loading ? (
          <Skeleton height={96} count={3} />
        ) : seances.error ? (
          <Banner tone="warning">{seances.error}</Banner>
        ) : jours.length === 0 ? (
          <EmptyState
            title="Aucune séance programmée"
            message={
              subjectId
                ? 'Aucune séance dans cette matière pour les quatre prochaines semaines.'
                : 'Les professeurs n’ont pas encore ouvert de créneau. Revenez bientôt.'
            }
          />
        ) : (
          jours.map(({ day, items }) => (
            <section key={day.toISOString()} className="stack stack--tight">
              <h2 className="section-title">
                {grille ? longDayLabel(day, grille.weekdayLabels) : ''}
              </h2>
              <div className="stack grid-cards">
                {items.map((seance) => (
                  <SessionCard key={seance.id} seance={seance} />
                ))}
              </div>
            </section>
          ))
        )}
      </div>
    </>
  )
}

/**
 * Les séances que la famille a réservées.
 *
 * --- Pourquoi cette section n'est pas un écran à part --------------------
 *
 * Elle répond à la question qu'on se pose en arrivant sur « Cours en direct »
 * quand on en suit déjà un : *où est mon cours ?* Un onglet de plus demanderait
 * de savoir qu'il existe.
 *
 * Elle porte trois états, et chacun existe pour une raison précise :
 *
 *   * **à venir, payée** — le bouton d'entrée, quinze minutes avant ;
 *   * **à venir, non payée** — la réservation expire au bout de vingt minutes, et
 *     quelqu'un qui croit avoir payé se présenterait devant une porte fermée ;
 *   * **passée** — la rediffusion. Une coupure de courant est la première raison
 *     de rater un cours ici, et elle ne doit pas coûter la séance.
 *
 * Rien ne s'affiche pour un visiteur ni pour un professeur : la liste est vide, et
 * un titre au-dessus d'un vide se lit comme une panne.
 */
function MesSeances({ grille }: { grille?: SlotGrid }) {
  const { session } = useSession()
  const mien = useAsync(
    () => (session ? api.mySessions() : Promise.resolve([])),
    [session?.userId],
  )

  const seances = (mien.data ?? []).filter((s) => s.enrolmentStatus !== 'CANCELLED')
  if (!session || mien.loading || seances.length === 0) return null

  return (
    <section className="stack stack--tight">
      <div className="row row--between">
        <h2 className="section-title">Mes séances</h2>
        {/* Cette grille sert à réserver ; `/seances` sert à relire ce qu'on a
            payé. Le lien dit laquelle est laquelle. */}
        <Link className="card-link" to="/seances">
          Toutes mes séances
        </Link>
      </div>
      <div className="stack grid-cards">
        {seances.map((seance) => (
          <MaSeanceCard key={seance.enrolmentId} seance={seance} grille={grille} />
        ))}
      </div>
    </section>
  )
}

function MaSeanceCard({
  seance,
  grille,
}: {
  seance: MySession
  grille?: SlotGrid
}) {
  const debut = new Date(seance.startsAt)
  const fin = debut.getTime() + seance.durationMinutes * 60_000
  const maintenant = Date.now()

  // La même fenêtre que celle du serveur : il refusera un jeton en dehors, et
  // montrer un bouton qui échoue vaut moins que ne pas le montrer.
  const ouvrable =
    maintenant >= debut.getTime() - 15 * 60_000 && maintenant <= fin + 30 * 60_000
  const passee = maintenant > fin + 30 * 60_000
  const payee = seance.enrolmentStatus === 'CONFIRMED'

  return (
    <Card>
      <div className="stack stack--tight">
        <div className="row row--between">
          <strong>{seance.subject?.name ?? seance.title ?? 'Cours'}</strong>
          {seance.childName ? (
            <Chip>{seance.childName}</Chip>
          ) : null}
        </div>

        <div className="muted small">
          {grille ? longDayLabel(debut, grille.weekdayLabels) : ''}
          {' · '}
          {/*
            `timeLabel`, comme la grille juste en dessous.

            Deux defauts dans une seule expression : `toLocaleTimeString`
            lit l'heure du navigateur — la Guinee est a UTC toute l'annee et
            le reste du site lit en UTC — et il ecrit « 17:00 » la ou le
            francais ecrit « 17 h 00 ». La meme carte portait donc
            « samedi 17 octobre · 17:00 » sous une grille qui annonce
            « 18 h - 19 h 30 ».
          */}
          {timeLabel(debut)}
          {seance.level ? ` · ${seance.level.name}` : ''}
        </div>

        {!payee ? (
          <Banner tone="warning">
            Place réservée, paiement non confirmé. Elle sera relâchée si le
            paiement n’aboutit pas.
          </Banner>
        ) : null}

        {seance.status === 'CANCELLED' ? (
          <Banner tone="warning">Cette séance a été annulée.</Banner>
        ) : payee && ouvrable ? (
          <Link className="card-link" to={`/direct/${seance.sessionId}/salle`}>
            {seance.status === 'LIVE' ? 'Rejoindre maintenant' : 'Entrer dans la salle'}
          </Link>
        ) : null}

        {/* La preuve de présence, avant la rediffusion.
            C'est ce qu'une famille vient chercher après coup — « y était-il,
            et combien de temps ? ». L'écran existe depuis le 17/10 et rien
            n'y menait : la rediffusion était le seul lien d'une séance
            passée, et elle répond à une autre question. */}
        {passee && payee ? (
          <Link className="card-link" to={`/seances/${seance.sessionId}`}>
            La preuve de présence
          </Link>
        ) : null}

        {/* La rediffusion : proposée dès que la séance est passée, même si le
            transfert n'est pas fini — c'est l'écran de rediffusion qui sait
            dire « dans quelques minutes », et il le dit mieux qu'une absence de
            lien. */}
        {passee && payee ? (
          seance.replay === 'FAILED' ? (
            <p className="faint micro">
              L’enregistrement de cette séance n’a pas abouti.
            </p>
          ) : (
            <Link
              className="card-link"
              to={`/direct/${seance.sessionId}/rediffusion`}
            >
              {seance.replay === 'READY'
                ? 'Voir la rediffusion'
                : 'Rediffusion en préparation'}
            </Link>
          )
        ) : null}
      </div>
    </Card>
  )
}

/**
 * Les créneaux possibles, affichés une fois.
 *
 * Ils sont les mêmes chaque semaine : les montrer en tête permet de retenir
 * l'horaire plutôt que de le relire sur chaque carte.
 */
function SessionCard({ seance }: { seance: LiveSession }) {
  const { session } = useSession()
  const [ouvert, setOuvert] = useState(false)
  const complet = seance.seatsLeft === 0

  return (
    <Card>
      <div className="stack stack--tight">
        <div className="row row--between">
          <strong>{seance.title || seance.subject.name}</strong>
          <Chip tone="accent">{money(seance.price)}</Chip>
        </div>

        <div className="row" style={{ gap: 'var(--espace-2)', flexWrap: 'wrap' }}>
          <Chip>{seance.subject.name}</Chip>
          <Chip>{seance.level.name}</Chip>
        </div>

        <div className="row small faint" style={{ gap: 'var(--espace-3)' }}>
          <span className="row" style={{ gap: 'var(--espace-1)' }}>
            <Icon name="clock" size={14} />
            {timeLabel(new Date(seance.startsAt))}
          </span>
          <span>{seance.durationMinutes} min</span>
        </div>

        {seance.teacherName ? (
          <div className="muted small">{seance.teacherName}</div>
        ) : null}

        {/* La rareté est réelle : la dire est honnête, et c'est ce qui décide. */}
        <div className="row row--between small">
          <span className={complet ? 'faint' : 'muted'}>
            {complet
              ? 'Complet'
              : `${seance.seatsLeft} place${seance.seatsLeft > 1 ? 's' : ''} sur ${seance.seats}`}
          </span>
        </div>

        {complet ? null : session?.parentId == null ? (
          <AppGate action="réserver une place" />
        ) : ouvert ? (
          <EnrolForm seance={seance} />
        ) : (
          <Button block onClick={() => setOuvert(true)}>
            Réserver une place
          </Button>
        )}
      </div>
    </Card>
  )
}

/**
 * Réserver et payer.
 *
 * Même parcours que l'achat d'un cours vidéo : on choisit son portefeuille, on
 * confirme sur son téléphone. Inventer un second parcours de paiement pour le
 * même geste obligerait à l'apprendre deux fois.
 */
function EnrolForm({ seance }: { seance: LiveSession }) {
  const [payerPhone, setPayerPhone] = useState('')
  const [resultat, setResultat] = useState<EnrolmentResult>()
  const [erreur, setErreur] = useState<string>()
  const [envoi, setEnvoi] = useState(false)
  const [methode, setMethode] = useState<WalletMethod>()

  /*
   * Pour qui ?
   *
   * `POST /live/enrol` accepte un `childId` et le site ne l'envoyait jamais :
   * toute place prise ici partait avec `child_id = null`. Un parent de deux
   * enfants ne pouvait donc pas reserver deux places sur la meme seance — le
   * serveur rendait la premiere inscription comme « deja inscrit » — et la
   * preuve de presence disait « Vous etiez la » au lieu de nommer l'enfant.
   */
  const enfants = useAsync(() => api.children(), [])
  const liste = enfants.data ?? []
  const [pourQui, setPourQui] = useState(0)

  const reserver = async (choisie: WalletMethod) => {
    setEnvoi(true)
    setErreur(undefined)
    setMethode(choisie)
    try {
      const r = await api.enrolInSession(seance.id, {
        method: choisie,
        childId: liste[pourQui]?.id,
        payerPhone: payerPhone.trim() === '' ? undefined : payerPhone.trim(),
      })
      setResultat(r)
      if (r.payment === 'redirect' && r.redirectUrl) {
        window.location.assign(r.redirectUrl)
      }
    } catch (cause) {
      setErreur(
        cause instanceof Error ? cause.message : 'La réservation n’a pas abouti.',
      )
    } finally {
      setEnvoi(false)
    }
  }

  if (resultat) {
    return (
      <div className="stack stack--tight">
        {resultat.sandbox ? (
          <Banner tone="warning">
            Paiement de test : aucun argent n’est prélevé ni reçu.
          </Banner>
        ) : null}

        {resultat.payment === 'awaiting_confirmation' ? (
          <>
            <Banner tone="accent">
              Validez {money(resultat.amount)} sur votre téléphone.{' '}
              {methode === 'OM' ? 'Orange Money' : 'MTN MoMo'} vous a envoyé une
              demande.
            </Banner>
            {/* Le délai de rétention est l'information qui évite de revenir
                deux heures plus tard sur une place perdue. */}
            {resultat.holdsMinutes ? (
              <p className="faint micro">
                Votre place est gardée {resultat.holdsMinutes} minutes, le temps
                du paiement.
              </p>
            ) : null}
          </>
        ) : (
          <Banner tone="accent">
            {resultat.alreadyEnrolled
              ? 'Vous êtes déjà inscrit à cette séance.'
              : 'Place réservée.'}{' '}
            {resultat.paymentError ?? 'Il reste à régler ' + money(resultat.amount) + '.'}
          </Banner>
        )}
      </div>
    )
  }

  return (
    <div className="stack stack--tight">
      {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

      {/*
        Le choix n'apparait qu'a partir de deux enfants.
        Avec un seul, la question est deja repondue ; la poser quand meme
        ajouterait un geste a chaque reservation pour ne rien decider.
      */}
      {liste.length > 1 ? (
        <Field label="Pour qui ?">
          <SegmentedToggle
            label="L’enfant qui suivra la séance"
            labels={liste.map((enfant) => enfant.firstName)}
            selected={pourQui}
            onSelect={setPourQui}
          />
        </Field>
      ) : null}

      <Field
        label="Numéro qui paie"
        hint="Celui de votre compte par défaut."
      >
        <TextInput
          type="tel"
          inputMode="tel"
          maxLength={14}
          value={payerPhone}
          onChange={(e) => setPayerPhone(e.target.value)}
        />
      </Field>

      <div className="row" style={{ gap: 'var(--espace-2)' }}>
        <Button block disabled={envoi} onClick={() => reserver('OM')}>
          {envoi && methode === 'OM' ? 'Envoi…' : 'Orange Money'}
        </Button>
        <Button block disabled={envoi} onClick={() => reserver('MOMO')}>
          {envoi && methode === 'MOMO' ? 'Envoi…' : 'MTN MoMo'}
        </Button>
      </div>
      <p className="faint micro">
        {money(seance.price)} pour cette séance. Rien n’est débité avant votre
        validation.
      </p>
    </div>
  )
}

/**
 * Le professeur déclare un cours récurrent.
 *
 * Une fois, pas chaque semaine : il choisit sa matière, sa classe, son prix et
 * ses créneaux, et les séances sont générées pour un mois d'avance.
 */
export function LiveCourseForm() {
  const { session } = useSession()
  const navigate = useNavigate()

  const [subjectId, setSubjectId] = useState('')
  const [levelId, setLevelId] = useState('')
  const [title, setTitle] = useState('')
  const [price, setPrice] = useState('')
  const [slotIds, setSlotIds] = useState<string[]>([])
  const [grille, setGrille] = useState<SlotGrid>()
  const [erreur, setErreur] = useState<string>()
  const [envoi, setEnvoi] = useState(false)

  const subjects = useAsync(() => api.subjects(), [])
  const levels = useAsync(() => api.levels(), [])

  useEffect(() => {
    loadSlots().then(setGrille).catch(() => setGrille(undefined))
  }, [])

  const montant = Number.parseInt(price, 10) || 0

  /** Ce qui manque, en une phrase. `null` = publiable. */
  const bloquant = (): string | null => {
    if (!subjectId) return 'Choisissez une matière.'
    if (!levelId) return 'Choisissez une classe.'
    if (montant < 1000) return 'Indiquez le prix par élève et par séance.'
    if (slotIds.length === 0) return 'Choisissez au moins un créneau.'
    return null
  }

  const publier = async () => {
    setEnvoi(true)
    setErreur(undefined)
    try {
      await api.createLiveCourse({
        subjectId,
        levelId,
        title: title.trim() === '' ? undefined : title.trim(),
        price: montant,
        slotIds,
        publish: true,
      })
      navigate('/direct', { replace: true })
    } catch (cause) {
      setErreur(
        cause instanceof Error ? cause.message : 'Le cours n’a pas été créé.',
      )
    } finally {
      setEnvoi(false)
    }
  }

  if (session?.teacherId == null) {
    return (
      <>
        <AppBar title="Ouvrir un cours" onBack />
        <div className="screen">
          <EmptyState
            title="Réservé aux professeurs"
            message="Seul un compte enseignant peut ouvrir un cours en direct."
          />
        </div>
      </>
    )
  }

  const manque = bloquant()

  return (
    <>
      <AppBar title="Ouvrir un cours en direct" onBack />
      <div className="screen stack stack--loose">
        {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

        <Field label="Matière">
          <Select value={subjectId} onChange={(e) => setSubjectId(e.target.value)}>
            <option value="">Choisir…</option>
            {(subjects.data ?? []).map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </Select>
        </Field>

        <Field label="Classe">
          <Select value={levelId} onChange={(e) => setLevelId(e.target.value)}>
            <option value="">Choisir…</option>
            {(levels.data ?? []).map((l) => (
              <option key={l.id} value={l.id}>
                {l.name}
              </option>
            ))}
          </Select>
        </Field>

        <Field label="Titre du cours (facultatif)">
          <TextInput
            value={title}
            maxLength={120}
            placeholder="Les fonctions affines, de A à Z"
            onChange={(e) => setTitle(e.target.value)}
          />
        </Field>

        <Field
          label="Prix par élève et par séance"
          hint="Entre 40 000 et 50 000 GNF selon votre expérience et la matière."
        >
          <TextInput
            type="number"
            inputMode="numeric"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
          />
        </Field>

        {/* La part du professeur s'affiche avant la publication. Découvrir la
            retenue au premier virement est la meilleure façon de perdre
            quelqu'un. */}
        {montant > 0 ? (
          <Card>
            <div className="stack stack--tight">
              <strong className="small">
                Sur {money(montant)} par élève, il vous revient{' '}
                {money(Math.round(montant * 0.6))}.
              </strong>
              <span className="muted small">
                La plateforme retient 40 % — hébergement, visioconférence,
                encaissement Orange Money et MTN MoMo.
              </span>
              <span className="faint micro">
                Une séance pleine à 15 élèves vous rapporte{' '}
                {money(Math.round(montant * 0.6) * 15)}.
              </span>
            </div>
          </Card>
        ) : null}

        <section className="stack stack--tight">
          <h2 className="section-title">Vos créneaux</h2>
          <p className="muted small">
            Les mêmes heures chaque semaine. Les séances sont créées
            automatiquement pour un mois d’avance.
          </p>
          <div className="tags">
            {(grille?.slots ?? []).map((slot) => {
              const choisi = slotIds.includes(slot.id)
              return (
                <button
                  key={slot.id}
                  className="tag"
                  aria-pressed={choisi}
                  onClick={() =>
                    setSlotIds((actuels) =>
                      choisi
                        ? actuels.filter((id) => id !== slot.id)
                        : [...actuels, slot.id],
                    )
                  }
                >
                  {slot.days.length > 1
                    ? `Semaine ${slot.label}`
                    : `Samedi ${slot.label}`}
                </button>
              )
            })}
          </div>
          {slotIds.length > 0 ? (
            <span className="faint micro">
              {slotIds.reduce(
                (total, id) =>
                  total +
                  ((grille?.slots.find((s) => s.id === id)?.days.length) ?? 0),
                0,
              )}{' '}
              séances par semaine.
            </span>
          ) : null}
        </section>

        {manque ? <p className="faint micro">{manque}</p> : null}

        <Button block disabled={manque != null || envoi} onClick={publier}>
          {envoi ? 'Publication…' : 'Publier le cours'}
        </Button>
      </div>
    </>
  )
}
