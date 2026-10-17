import { useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { api } from '../api'
import {
  domicile,
  serveurDisponible,
  type DemandeDomicile,
  type ModeDomicile,
  type MonOffreDomicile,
  type OffreDomicile,
} from '../api/server'
import { useSession } from '../app/session'
import {
  PageHead,
  SegmentedToggle,
  Tile,
  gnf,
} from '../components/kit'
import {
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
import { useAsync } from '../lib/useAsync'
import { formatDate } from '../lib/format'

/**
 * Les cours à domicile.
 *
 * --- Pourquoi c'est la page la plus rentable du site --------------------
 *
 * 500 000 à 900 000 GNF par mois et par élève, contre quelques milliers pour
 * une place en direct. Les tables existaient depuis la première migration et
 * **aucune route ne les servait**, sur aucun client : une offre à domicile ne
 * pouvait ni se publier ni se recevoir.
 *
 * --- Une page, deux lectures -------------------------------------------
 *
 * Un professeur vient publier son offre et répondre aux demandes ; une
 * famille vient chercher quelqu'un près de chez elle. Ce sont deux écrans
 * différents sous la même adresse, et c'est le rôle qui tranche — pas une
 * bascule, parce que personne n'est les deux à la fois.
 */
export function Tutoring() {
  const { session } = useSession()
  if (session?.role === 'TEACHER') return <CoteProfesseur />
  return <CoteFamille />
}

const MODES: Record<ModeDomicile, string> = {
  AT_STUDENT: 'chez l’élève',
  AT_TEACHER: 'chez le professeur',
  ONLINE: 'à distance',
}

/* =========================================================================
 * Côté famille : le catalogue
 * =========================================================================*/

function CoteFamille() {
  const { session } = useSession()
  const [params] = useSearchParams()

  // La ville du profil par defaut : la redemander alors qu'elle a ete donnee
  // a l'inscription est la redondance que l'audit du 04/10 reprochait au
  // parcours.
  const [ville, setVille] = useState(session?.city ?? '')

  // La matiere vient de l'accueil quand on y a tape quelque chose : poser la
  // question deux fois de suite est la facon la plus simple de perdre
  // quelqu'un entre deux ecrans.
  const [recherche, setRecherche] = useState(params.get('q') ?? '')

  const offres = useAsync(
    () => domicile.catalogue(ville ? { city: ville } : {}),
    [ville],
  )

  if (!serveurDisponible) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Cours à domicile</h1>
        <Banner tone="warning">
          Le catalogue passe par le serveur EduQuali, qui n’est pas relié à ce
          site.
        </Banner>
      </div>
    )
  }

  const liste = (offres.data?.offers ?? []).filter((offre) => {
    const q = recherche.trim().toLowerCase()
    if (!q) return true
    return (
      offre.subject.name.toLowerCase().includes(q)
      || offre.teacherName.toLowerCase().includes(q)
      || (offre.headline ?? '').toLowerCase().includes(q)
    )
  })

  return (
    <div className="screen stack stack--loose">
      <PageHead
        title="Un professeur chez vous"
        lede="Trois séances par semaine, à l’heure qui vous arrange. Les tarifs affichés sont un point de départ : on négocie toujours avec les parents."
      />

      {/* Les filtres a droite, les offres a gauche : la forme de toutes les
          places de marche, et pour une raison concrete — on affine en
          regardant les resultats changer, pas en remontant les chercher. */}
      <div className="pagegrid">
        <aside className="pagegrid__aside">
      <div className="card stack">
        <Field label="Quelle matière ?">
          <TextInput
            type="search"
            value={recherche}
            onChange={(e) => setRecherche(e.target.value)}
            placeholder="Maths, physique, anglais…"
          />
        </Field>
        <Field
          label="Dans quelle commune ?"
          hint="Laissez vide pour voir toute la Guinée."
        >
          <TextInput
            value={ville}
            onChange={(e) => setVille(e.target.value)}
            placeholder="Ratoma, Matam, Kaloum…"
          />
        </Field>
      </div>

        </aside>

        <div className="pagegrid__main">
      {offres.loading ? (
        <Skeleton height={120} count={3} />
      ) : offres.error ? (
        <Banner tone="warning">{offres.error}</Banner>
      ) : liste.length === 0 ? (
        <EmptyState
          icon="pin"
          title="Aucune offre ici pour l’instant"
          message="Élargissez la commune, ou regardez les cours en direct : ils se suivent depuis chez vous, à plusieurs, et coûtent beaucoup moins cher."
          action={
            <Link className="btn btn--ghost" to="/direct">
              Voir les cours en direct
            </Link>
          }
        />
      ) : (
        <div className="stack grid-cards">
          {liste.map((offre) => (
            <CarteOffre key={offre.id} offre={offre} />
          ))}
        </div>
      )}
        </div>
      </div>
    </div>
  )
}

function CarteOffre({ offre }: { offre: OffreDomicile }) {
  return (
    <Card>
      <div className="stack stack--tight">
        <div className="row row--between">
          <strong>{offre.subject.name}</strong>
          <Chip>{MODES[offre.mode]}</Chip>
        </div>

        <span className="muted small">
          {offre.teacherName}
          {offre.yearsExperience > 0
            ? ` · ${offre.yearsExperience} an${offre.yearsExperience > 1 ? 's' : ''} d’expérience`
            : ''}
        </span>

        {offre.headline ? (
          <span className="faint small">{offre.headline}</span>
        ) : null}

        {offre.city ? (
          <span className="row faint micro" style={{ gap: 'var(--espace-1)' }}>
            <Icon name="place" size={12} />
            {offre.city}
            {offre.districts.length > 0
              ? ` — ${offre.districts.join(', ')}`
              : ''}
          </span>
        ) : null}

        {offre.description ? (
          <p className="small">{offre.description}</p>
        ) : null}

        {offre.availabilityNote ? (
          <span className="faint micro">{offre.availabilityNote}</span>
        ) : null}

        <div className="row row--between">
          {/*
            Un tarif absent n'est pas un tarif de zéro : certains professeurs
            préfèrent discuter avant d'annoncer un chiffre, et afficher
            « 0 GNF » serait faux.
          */}
          <strong>
            {offre.hourlyRate
              ? `${gnf(offre.hourlyRate)} / heure`
              : 'Tarif à discuter'}
          </strong>
          <Link className="btn btn--primary" to={`/professeurs/${offre.teacherId}`}>
            Voir la fiche
          </Link>
        </div>
      </div>
    </Card>
  )
}

/* =========================================================================
 * Côté professeur : mes offres et mes demandes
 * =========================================================================*/

function CoteProfesseur() {
  const [onglet, setOnglet] = useState(0)
  const miennes = useAsync(() => domicile.miennes(), [])
  const demandes = useAsync(() => domicile.demandes(), [])

  if (!serveurDisponible) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Cours à domicile</h1>
        <Banner tone="warning">
          Cette page passe par le serveur EduQuali, qui n’est pas relié à ce
          site.
        </Banner>
      </div>
    )
  }

  const offres = miennes.data?.services ?? []
  const recues = demandes.data?.requests ?? []
  const aTraiter = recues.filter((d) => d.status === 'SENT').length

  return (
    <div className="screen stack stack--loose">
      <PageHead
        title="Mes cours à domicile"
        lede="La ligne la mieux payée du produit : de 500 000 à 900 000 GNF par mois et par élève, selon le niveau et le nombre de matières."
        stats={[
          { value: offres.filter((o) => o.active).length, label: 'offres en ligne' },
          { value: aTraiter, label: 'demandes à traiter' },
          { value: recues.filter((d) => d.status === 'ACCEPTED').length, label: 'acceptées' },
        ]}
      />

      <SegmentedToggle
        label="Ce que vous regardez"
        labels={[`Demandes${aTraiter > 0 ? ` (${aTraiter})` : ''}`, 'Mes offres']}
        selected={onglet}
        onSelect={setOnglet}
      />

      {onglet === 0 ? (
        <Demandes
          etat={demandes.loading}
          erreur={demandes.error}
          liste={recues}
          onChange={() => demandes.reload()}
        />
      ) : (
        <MesOffres
          etat={miennes.loading}
          erreur={miennes.error}
          liste={offres}
          onChange={() => miennes.reload()}
        />
      )}
    </div>
  )
}

const ETATS_DEMANDE: Record<
  string,
  { texte: string; ton?: 'success' | 'warning' | 'danger' }
> = {
  SENT: { texte: 'à traiter', ton: 'warning' },
  ACCEPTED: { texte: 'acceptée', ton: 'success' },
  DECLINED: { texte: 'refusée' },
}

function Demandes({
  etat,
  erreur,
  liste,
  onChange,
}: {
  etat: boolean
  erreur?: string
  liste: DemandeDomicile[]
  onChange: () => void
}) {
  const [occupe, setOccupe] = useState<string>()
  const [souci, setSouci] = useState<string>()

  const repondre = async (id: string, status: 'ACCEPTED' | 'DECLINED') => {
    setOccupe(id)
    setSouci(undefined)
    try {
      await domicile.repondre(id, status)
      onChange()
    } catch (cause) {
      setSouci(cause instanceof Error ? cause.message : 'Réponse impossible.')
    } finally {
      setOccupe(undefined)
    }
  }

  if (etat) return <Skeleton height={104} count={3} />
  if (erreur) return <Banner tone="warning">{erreur}</Banner>

  if (liste.length === 0) {
    return (
      <EmptyState
        icon="pin"
        title="Aucune demande pour l’instant"
        message="Les familles vous trouvent par la matière et par la commune. Une offre sans quartier précisé apparaît moins souvent : c’est le quartier qui décide des professeurs qui peuvent venir."
      />
    )
  }

  return (
    <div className="stack">
      {souci ? <Banner tone="warning">{souci}</Banner> : null}
      {liste.map((demande) => {
        const etatLu = ETATS_DEMANDE[demande.status] ?? { texte: demande.status }
        return (
          <Card key={demande.id}>
            <div className="stack stack--tight">
              <div className="row row--between">
                <strong>
                  {demande.subject ?? 'Cours'} — {demande.childName}
                </strong>
                <Chip tone={etatLu.ton}>{etatLu.texte}</Chip>
              </div>

              <span className="muted small">
                Reçue le {formatDate(demande.createdAt)}
                {demande.preferredStart
                  ? ` · souhaite commencer le ${formatDate(demande.preferredStart)}`
                  : ''}
              </span>

              {demande.message ? <p className="small">{demande.message}</p> : null}

              {demande.status === 'SENT' ? (
                <div className="row">
                  <Button
                    onClick={() => repondre(demande.id, 'ACCEPTED')}
                    disabled={occupe === demande.id}
                  >
                    Accepter
                  </Button>
                  <Button
                    variant="ghost"
                    onClick={() => repondre(demande.id, 'DECLINED')}
                    disabled={occupe === demande.id}
                  >
                    Refuser
                  </Button>
                </div>
              ) : demande.status === 'ACCEPTED' ? (
                /* Accepter ouvre le groupe de discussion : c'est le moment où
                   les deux personnes ont une raison de se parler, et c'est ce
                   passage qui transforme une annonce en relation. */
                <Link className="btn btn--ghost" to="/messages">
                  <Icon name="chat" size={18} />
                  Ouvrir la discussion
                </Link>
              ) : null}
            </div>
          </Card>
        )
      })}
    </div>
  )
}

function MesOffres({
  etat,
  erreur,
  liste,
  onChange,
}: {
  etat: boolean
  erreur?: string
  liste: MonOffreDomicile[]
  onChange: () => void
}) {
  const [ouvert, setOuvert] = useState(false)

  if (etat) return <Skeleton height={104} count={2} />
  if (erreur) return <Banner tone="warning">{erreur}</Banner>

  return (
    <div className="stack">
      {liste.map((offre) => (
        <div className="rowitem" key={offre.id}>
          <Tile icon="pin" tone={offre.active ? 'success' : 'neutral'} />
          <span className="rowitem__body">
            <span className="rowitem__title">{offre.subject.name}</span>
            <span className="rowitem__sub">
              {MODES[offre.mode]}
              {offre.hourlyRate ? ` · ${gnf(offre.hourlyRate)} / h` : ''}
              {offre.city ? ` · ${offre.city}` : ''}
            </span>
          </span>
          <span className="rowitem__end">
            <Button
              variant="quiet"
              onClick={async () => {
                await domicile.basculer(offre.id, !offre.active)
                onChange()
              }}
            >
              {offre.active ? 'Retirer' : 'Remettre'}
            </Button>
          </span>
        </div>
      ))}

      {liste.length === 0 && !ouvert ? (
        <EmptyState
          icon="plus"
          title="Aucune offre publiée"
          message="Une offre dit ce que vous enseignez, où vous pouvez vous déplacer et à quel tarif. Les familles cherchent par matière et par commune."
        />
      ) : null}

      {ouvert ? (
        <FormulaireOffre
          onDone={() => {
            setOuvert(false)
            onChange()
          }}
          onCancel={() => setOuvert(false)}
        />
      ) : (
        <Button block onClick={() => setOuvert(true)}>
          <Icon name="plus" size={18} />
          Publier une offre
        </Button>
      )}
    </div>
  )
}

function FormulaireOffre({
  onDone,
  onCancel,
}: {
  onDone: () => void
  onCancel: () => void
}) {
  const matieres = useAsync(() => api.subjects(), [])
  const niveaux = useAsync(() => api.levels(), [])

  const [subjectId, setSubjectId] = useState('')
  const [choisis, setChoisis] = useState<string[]>([])
  const [mode, setMode] = useState<ModeDomicile>('AT_STUDENT')
  const [tarif, setTarif] = useState('')
  const [quartiers, setQuartiers] = useState('')
  const [dispo, setDispo] = useState('')
  const [description, setDescription] = useState('')
  const [envoi, setEnvoi] = useState(false)
  const [erreur, setErreur] = useState<string>()

  const basculer = (id: string) =>
    setChoisis((avant) =>
      avant.includes(id) ? avant.filter((v) => v !== id) : [...avant, id],
    )

  const publier = async (event: React.FormEvent) => {
    event.preventDefault()
    if (!subjectId || choisis.length === 0) {
      setErreur('Choisissez une matière et au moins un niveau.')
      return
    }

    setEnvoi(true)
    setErreur(undefined)
    try {
      await domicile.publier({
        subjectId,
        levelIds: choisis,
        mode,
        hourlyRate: tarif ? Number(tarif.replace(/\s/g, '')) : undefined,
        districts: quartiers
          .split(',')
          .map((q) => q.trim())
          .filter((q) => q !== ''),
        availabilityNote: dispo || undefined,
        description: description || undefined,
      })
      onDone()
    } catch (cause) {
      setErreur(
        cause instanceof Error ? cause.message : 'Publication impossible.',
      )
    } finally {
      setEnvoi(false)
    }
  }

  return (
    <form className="card stack form-col" onSubmit={publier}>
      <h3>Nouvelle offre</h3>

      <Field label="Matière">
        <Select
          value={subjectId}
          onChange={(e) => setSubjectId(e.target.value)}
        >
          <option value="">Choisir…</option>
          {(matieres.data ?? []).map((matiere) => (
            <option key={matiere.id} value={matiere.id}>
              {matiere.name}
            </option>
          ))}
        </Select>
      </Field>

      <Field label="Pour quels niveaux ?">
        <div className="tags">
          {(niveaux.data ?? []).map((niveau) => (
            <button
              key={niveau.id}
              type="button"
              className="tag"
              aria-pressed={choisis.includes(niveau.id)}
              onClick={() => basculer(niveau.id)}
            >
              {niveau.name}
            </button>
          ))}
        </div>
      </Field>

      <Field label="Où ?">
        <Select
          value={mode}
          onChange={(e) => setMode(e.target.value as ModeDomicile)}
        >
          <option value="AT_STUDENT">Je me déplace chez l’élève</option>
          <option value="AT_TEACHER">L’élève vient chez moi</option>
          <option value="ONLINE">À distance</option>
        </Select>
      </Field>

      <Field
        label="Votre tarif horaire (facultatif)"
        hint="Un point de départ, pas un prix fixe : on négocie toujours avec les parents. Laissez vide pour en discuter de vive voix."
      >
        <TextInput
          inputMode="numeric"
          value={tarif}
          onChange={(e) => setTarif(e.target.value.replace(/[^0-9\s]/g, ''))}
          placeholder="50 000"
        />
      </Field>

      <Field
        label="Quels quartiers ?"
        hint="Séparés par des virgules. C’est le quartier qui décide des familles qui vous trouvent."
      >
        <TextInput
          value={quartiers}
          onChange={(e) => setQuartiers(e.target.value)}
          placeholder="Nongo, Kipé, Taouyah"
        />
      </Field>

      <Field label="Vos disponibilités (facultatif)">
        <TextInput
          value={dispo}
          onChange={(e) => setDispo(e.target.value)}
          placeholder="Lundi, mercredi et vendredi à partir de 17 h"
          maxLength={400}
        />
      </Field>

      <Field label="Quelques mots sur votre façon de travailler">
        <TextInput
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          placeholder="Je reprends les bases avant d’avancer, avec des exercices du manuel guinéen."
          maxLength={1500}
        />
      </Field>

      {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

      <div className="row">
        <Button type="submit" disabled={envoi}>
          {envoi ? 'Publication…' : 'Publier'}
        </Button>
        <Button variant="ghost" onClick={onCancel}>
          Annuler
        </Button>
      </div>
    </form>
  )
}
