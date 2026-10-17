import { useMemo } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { api } from '../api'
import type { MySession } from '../api/types'
import { useSession } from '../app/session'
import {
  BigButton,
  LigneDuTemps,
  PageHead,
  RowItem,
  Statut,
  gnf,
} from '../components/kit'
import { Banner, Button, Card, Chip, EmptyState, Skeleton } from '../components/ui'
import { timeLabel } from '../lib/slots'
import { useAsync } from '../lib/useAsync'

/*
 * L'espace d'une famille.
 *
 * --- Ce que ces deux écrans remplacent ----------------------------------
 *
 * Rien. Un parent ou un élève qui se connectait arrivait sur `/professeurs`,
 * un annuaire — la même page qu'un visiteur non inscrit. Ses séances
 * existaient bien, mais au bas de `/direct`, sous une grille d'une semaine
 * entière : il fallait savoir qu'elles étaient là.
 *
 * Deux écrans, et une seule question par écran :
 *
 *   `/tableau`  — qu'est-ce qui se passe aujourd'hui ?
 *   `/seances`  — qu'est-ce que j'ai payé, et mon enfant y était-il ?
 */

/** Une séance est-elle encore à venir ? */
function estAVenir(seance: MySession, maintenant: number): boolean {
  const fin =
    new Date(seance.startsAt).getTime() + seance.durationMinutes * 60_000
  return maintenant <= fin + 30 * 60_000
}

/**
 * La fenêtre d'entrée en salle.
 *
 * La même que celle du serveur : il refusera un jeton en dehors, et montrer
 * un bouton qui échoue vaut moins que ne pas le montrer.
 */
function ouvrable(seance: MySession, maintenant: number): boolean {
  const debut = new Date(seance.startsAt).getTime()
  const fin = debut + seance.durationMinutes * 60_000
  return maintenant >= debut - 15 * 60_000 && maintenant <= fin + 30 * 60_000
}

/**
 * « aujourd'hui à 17 h 00 », « mardi à 17 h 00 ».
 *
 * --- Pourquoi UTC et non l'heure du navigateur --------------------------
 *
 * `timeLabel` lit en UTC, parce que la Guinée y est toute l'année sans heure
 * d'été : c'est l'hypothèse de toute la grille des créneaux, écrite dans
 * `slots.ts`. Cette fonction employait `toLocaleTimeString`, donc l'heure du
 * navigateur. Sur un ordinateur réglé à Paris, l'accueil annonçait 19 h et la
 * grille 17 h pour la même séance — et c'est l'accueil qu'on croit.
 */
function quand(iso: string): string {
  const date = new Date(iso)
  const heure = timeLabel(date)

  // Le quantième en UTC, pour la même raison.
  const jourDe = (d: Date) =>
    Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate())
  const ecart = Math.round((jourDe(date) - jourDe(new Date())) / 86_400_000)

  if (ecart === 0) return `aujourd’hui à ${heure}`
  if (ecart === 1) return `demain à ${heure}`
  if (ecart === -1) return `hier à ${heure}`
  if (ecart > 1 && ecart < 7) return `${JOURS[date.getUTCDay()]} à ${heure}`
  return `le ${date.getUTCDate()} ${MOIS[date.getUTCMonth()]} à ${heure}`
}

const JOURS = [
  'dimanche',
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
]

const MOIS = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
]

/**
 * L'accueil d'une famille.
 *
 * --- Pourquoi la ligne du temps n'est pas toujours là -------------------
 *
 * Elle n'apparaît qu'à partir d'une séance réservée. Une ligne du temps vide
 * ne montre pas « zéro minute suivie » : elle montre un composant en panne.
 * Tant qu'aucune séance n'est prise, l'écran pose la seule question utile —
 * trouver un professeur.
 */
export function AccueilFamille() {
  const { session } = useSession()
  const navigate = useNavigate()
  const etat = useAsync(
    () => (session ? api.mySessions() : Promise.resolve([])),
    [session?.userId],
  )

  const maintenant = Date.now()
  const seances = useMemo(
    () =>
      (etat.data ?? [])
        .filter((s) => s.enrolmentStatus !== 'CANCELLED')
        .sort(
          (a, b) =>
            new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime(),
        ),
    [etat.data],
  )

  if (etat.loading) {
    return (
      <div className="screen">
        <Skeleton height={120} count={3} />
      </div>
    )
  }

  const aVenir = seances.filter((s) => estAVenir(s, maintenant))
  const passees = seances
    .filter((s) => !estAVenir(s, maintenant))
    .reverse()

  const prochaine = aVenir[0]
  const derniere = passees[0]

  /*
   * À rattraper.
   *
   * Une séance passée où il manque au moins cinq minutes et dont
   * l'enregistrement est prêt. En dessous de cinq minutes, c'est une entrée
   * un peu tardive, et en faire un rattrapage ferait d'un détail un problème.
   */
  const aRattraper = passees.filter(
    (s) =>
      s.replay === 'READY' &&
      s.minutesAttended != null &&
      s.durationMinutes - s.minutesAttended >= 5,
  )

  // La session porte un nom d'affichage, pas un prenom : on prend le
  // premier mot. « Bonjour Mariama Diallo. » sonne comme un guichet.
  const prenom = (session?.displayName ?? '').trim().split(/\s+/)[0] ?? ''

  // Aucune séance : l'écran ne montre ni ligne du temps ni bandeau vide.
  if (seances.length === 0) {
    return (
      <div className="screen stack stack--loose">
        <PageHead
          title={prenom === '' ? 'Bonjour.' : `Bonjour ${prenom}.`}
          lede="Il n’y a rien à suivre pour le moment."
        />
        <EmptyState
          icon="clock"
          title="Aucune séance réservée"
          message={
            'Un professeur guinéen, quinze élèves au plus, en direct et à ' +
            'heure fixe. Choisissez un créneau, et la séance apparaîtra ici.'
          }
        />
        <BigButton icon="search" onClick={() => navigate('/direct')}>
          Voir les cours en direct
        </BigButton>
      </div>
    )
  }

  return (
    <div className="screen stack stack--loose">
      <PageHead
        title={prenom === '' ? 'Bonjour.' : `Bonjour ${prenom}.`}
        lede={
          prochaine
            ? `Prochaine séance ${quand(prochaine.startsAt)}.`
            : 'Aucune séance à venir.'
        }
      />

      {etat.error ? <Banner tone="warning">{etat.error}</Banner> : null}

      {/*
        Deux colonnes à partir d'un écran large, une seule sur téléphone.

        À gauche ce qu'on lit — la séance qui vient, celle qui vient d'avoir
        lieu. À droite ce sur quoi on agit : rattraper, et tout voir. Sans
        cette structure, la ligne du temps d'une heure de cours s'étirait sur
        mille quatre cents points de large, et une barre aussi longue ne se
        lit plus comme une durée.

        La colonne principale est première dans le DOM ici : c'est aussi le
        bon ordre sur un téléphone — ce qui se passe aujourd'hui avant ce
        qu'on peut rattraper.
      */}
      <div className="pagegrid">
        <div className="pagegrid__main">
          {prochaine ? (
            <ProchaineSeance seance={prochaine} maintenant={maintenant} />
          ) : null}

          {/*
            La ligne du temps de la dernière séance.

            Elle répond à la question qu'un parent se pose le soir — « y
            était-il, et combien de temps ? » — sans qu'il ait à ouvrir quoi
            que ce soit. Elle n'apparaît que lorsque le serveur a compté des
            minutes : avant la séance, il n'y a rien à montrer.
          */}
          {derniere && derniere.minutesAttended != null ? (
            <DerniereSeance seance={derniere} />
          ) : null}
        </div>

        <aside className="pagegrid__aside">
          {aRattraper.length > 0 ? (
            <section className="stack stack--tight">
              <h2 className="section-title">À rattraper</h2>
              {/* Une absence se dit avec le moyen de la rattraper. */}
              {aRattraper.slice(0, 3).map((seance) => (
                <RowItem
                  key={seance.enrolmentId}
                  title={seance.subject?.name ?? seance.title ?? 'Cours'}
                  // « 8 minutes sont sur l'enregistrement » se coupait a
                  // « l'enregistrem… » sur un telephone. La ligne porte deja
                  // une icone de lecture : la phrase n'a pas a redire ou
                  // elles sont.
                  sub={`${
                    seance.durationMinutes - (seance.minutesAttended ?? 0)
                  } minutes à rattraper`}
                  icon="play"
                  onClick={() =>
                    navigate(`/direct/${seance.sessionId}/rediffusion`)
                  }
                />
              ))}
            </section>
          ) : null}

          <section className="stack stack--tight">
            <h2 className="section-title">Mes séances</h2>
            <p className="muted small">
              {aVenir.length} à venir · {passees.length} passée
              {passees.length > 1 ? 's' : ''}
            </p>
            <Link className="btn btn--ghost btn--block" to="/seances">
              Voir toutes mes séances
            </Link>
          </section>
        </aside>
      </div>
    </div>
  )
}

/** La prochaine séance, en grand. */
function ProchaineSeance({
  seance,
  maintenant,
}: {
  seance: MySession
  maintenant: number
}) {
  const navigate = useNavigate()
  const payee = seance.enrolmentStatus === 'CONFIRMED'
  const peutEntrer = ouvrable(seance, maintenant) && payee

  return (
    <Card>
      <div className="stack">
        <div className="row row--between">
          <p className="etiquette">Prochaine séance</p>
          {seance.childName ? <Chip>{seance.childName}</Chip> : null}
        </div>

        {/*
          Pas de surlignage ici.

          Le signe marque « ce qu'il faut retenir », et ce n'est pas le nom de
          la matière — c'est l'heure, écrite juste dessous. Un surlignage posé
          sur chaque titre de carte cesse de vouloir dire quelque chose, et la
          charte n'en veut qu'un par écran.
        */}
        <h2 className="card-title">
          {seance.subject?.name ?? seance.title ?? 'Cours'}
        </h2>

        <p className="muted">
          {quand(seance.startsAt)} · {seance.durationMinutes} minutes
        </p>

        {/*
          Une réservation non payée n'est pas une place.

          Le serveur la tient le temps du paiement puis la relâche. L'écrire
          ici évite la seule mauvaise surprise possible : arriver à l'heure et
          trouver la place vendue.
        */}
        {payee ? null : (
          <Statut ton="attente" icon="clock">
            Paiement en attente — la place n’est pas encore gardée
          </Statut>
        )}

        {peutEntrer ? (
          <BigButton
            icon="play"
            onClick={() => navigate(`/direct/${seance.sessionId}/salle`)}
          >
            Entrer en classe
          </BigButton>
        ) : (
          <p className="muted small">
            {payee
              ? 'La salle ouvre un quart d’heure avant le début.'
              : `${gnf(seance.price)} à régler pour garder la place.`}
          </p>
        )}
      </div>
    </Card>
  )
}

/** La dernière séance suivie, et sa ligne du temps. */
function DerniereSeance({ seance }: { seance: MySession }) {
  const suivies = seance.minutesAttended ?? 0
  const qui = seance.childName ?? 'Vous'
  const verbe = seance.childName == null ? 'étiez là' : 'était là'

  return (
    <Card>
      <div className="stack">
        <p className="etiquette">La dernière séance</p>

        <p className="row row--baseline">
          <span className="chiffre">{suivies}</span>
          <strong>minutes sur {seance.durationMinutes}</strong>
        </p>

        <LigneDuTemps
          minutesSuivies={suivies}
          minutesTotales={seance.durationMinutes}
        />

        <p className="muted small">
          {suivies > 0
            ? `${qui} ${verbe} — ${quand(seance.startsAt)}.`
            : `Aucune minute comptée ${quand(seance.startsAt)}.`}
        </p>

        <Link className="btn btn--ghost" to={`/seances/${seance.sessionId}`}>
          Voir la preuve de présence
        </Link>
      </div>
    </Card>
  )
}

/**
 * Mes séances.
 *
 * --- Pourquoi une page à elle ------------------------------------------
 *
 * Cette liste vivait au bas de `/direct`, sous la grille d'une semaine
 * entière : la page publique qui sert à réserver portait aussi ce qu'on a
 * déjà payé. Deux questions sur un écran, et la seconde en bas.
 *
 * Elle montre les séances passées autant que celles à venir : sans elles,
 * une séance payée n'existe plus pour la famille dès que sa date est passée —
 * ni rediffusion, ni preuve, ni trace de l'achat.
 */
export function MesSeances() {
  const { session } = useSession()
  const etat = useAsync(
    () => (session ? api.mySessions() : Promise.resolve([])),
    [session?.userId],
  )

  if (etat.loading) {
    return (
      <div className="screen">
        <Skeleton height={96} count={4} />
      </div>
    )
  }

  const maintenant = Date.now()
  const seances = (etat.data ?? []).filter(
    (s) => s.enrolmentStatus !== 'CANCELLED',
  )
  const aVenir = seances
    .filter((s) => estAVenir(s, maintenant))
    .sort(
      (a, b) =>
        new Date(a.startsAt).getTime() - new Date(b.startsAt).getTime(),
    )
  const passees = seances
    .filter((s) => !estAVenir(s, maintenant))
    .sort(
      (a, b) =>
        new Date(b.startsAt).getTime() - new Date(a.startsAt).getTime(),
    )

  return (
    <div className="screen stack stack--loose">
      <PageHead
        title="Mes séances"
        lede="Ce qui vient, et ce qui a eu lieu."
      />

      {etat.error ? <Banner tone="warning">{etat.error}</Banner> : null}

      {seances.length === 0 ? (
        <EmptyState
          icon="clock"
          title="Aucune séance"
          message={
            'Les séances réservées apparaissent ici, avec les minutes ' +
            'suivies une fois le cours terminé.'
          }
        />
      ) : null}

      {aVenir.length > 0 ? (
        <section className="stack stack--tight">
          <h2 className="section-title">À venir</h2>
          {aVenir.map((seance) => (
            <CarteSeance
              key={seance.enrolmentId}
              seance={seance}
              maintenant={maintenant}
            />
          ))}
        </section>
      ) : null}

      {passees.length > 0 ? (
        <section className="stack stack--tight">
          <h2 className="section-title">Passées</h2>
          {passees.map((seance) => (
            <CarteSeance
              key={seance.enrolmentId}
              seance={seance}
              maintenant={maintenant}
            />
          ))}
        </section>
      ) : null}
    </div>
  )
}

function CarteSeance({
  seance,
  maintenant,
}: {
  seance: MySession
  maintenant: number
}) {
  const navigate = useNavigate()
  const aVenir = estAVenir(seance, maintenant)
  const payee = seance.enrolmentStatus === 'CONFIRMED'
  const suivies = seance.minutesAttended

  return (
    <Card>
      <div className="stack stack--tight">
        <div className="row row--between">
          <strong>{seance.subject?.name ?? seance.title ?? 'Cours'}</strong>
          {seance.childName ? <Chip>{seance.childName}</Chip> : null}
        </div>

        <p className="muted small">
          {quand(seance.startsAt)} · {seance.durationMinutes} minutes
        </p>

        {/*
          Les minutes suivies, sur une séance passée.

          Un total sans la barre serait un bulletin ; la barre dit quand. Et
          le chiffre ne vient avec aucun commentaire : ni « assidu », ni
          « insuffisant ».
        */}
        {!aVenir && suivies != null ? (
          <div className="stack stack--tight">
            <p className="row row--baseline">
              <span className="chiffre chiffre--petit">{suivies}</span>
              <span className="muted">
                minutes sur {seance.durationMinutes}
              </span>
            </p>
            <LigneDuTemps
              minutesSuivies={suivies}
              minutesTotales={seance.durationMinutes}
            />
          </div>
        ) : null}

        {/*
          Un seul bouton par carte.

          « La preuve de présence » et « Revoir » côte à côte ne tenaient pas
          sur une largeur de téléphone : le premier passait sur deux lignes et
          le second flottait à côté. L'écran de preuve propose déjà la
          rediffusion en second bouton — la garder ici la faisait exister deux
          fois, et c'est elle qui sautait en premier à l'œil alors qu'elle
          répond à une autre question.
        */}
        <div className="row">
          {aVenir ? (
            ouvrable(seance, maintenant) && payee ? (
              <Button
                onClick={() => navigate(`/direct/${seance.sessionId}/salle`)}
              >
                Entrer en classe
              </Button>
            ) : (
              <Statut ton={payee ? 'ok' : 'attente'} icon="clock">
                {payee ? 'Place gardée' : 'Paiement en attente'}
              </Statut>
            )
          ) : (
            <Button
              block
              variant="ghost"
              onClick={() => navigate(`/seances/${seance.sessionId}`)}
            >
              La preuve de présence
            </Button>
          )}
        </div>
      </div>
    </Card>
  )
}
