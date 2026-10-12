import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { api } from '../api'
import {
  prof,
  serveurDisponible,
  studio,
  type MonCoursVideo,
} from '../api/server'
import { PageHead, Steps, Tile, gnf } from '../components/kit'
import {
  AppBar,
  Banner,
  Button,
  Card,
  Chip,
  EmptyState,
  Field,
  Icon,
  Progress,
  Select,
  Skeleton,
  TextInput,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'

/**
 * La création d'un cours vidéo.
 *
 * --- Le vide que ceci remplit -------------------------------------------
 *
 * `sync.ts` refuse depuis toujours l'écriture directe de `video_courses`,
 * `course_chapters` et `course_items`, et chacun des trois refus renvoie vers
 * « une route dédiée ». Ces routes n'existaient pas. Un professeur ne pouvait
 * donc pas créer un cours vidéo, sur aucun des deux clients — la table était
 * remplie par le jeu de démonstration et par rien d'autre.
 *
 * --- Pourquoi un cours vidéo, et pas seulement du direct ---------------
 *
 * Un cours en direct se paie une fois par place et demande d'être là. Un
 * cours vidéo se vend sans vous, autant de fois qu'on l'achète : c'est le
 * seul revenu du produit qui ne soit pas proportionnel au temps passé.
 *
 * --- Le chemin d'une vidéo ---------------------------------------------
 *
 * Le serveur signe une adresse, le navigateur y envoie le fichier, puis
 * déclare le dépôt fini ; le serveur demande alors à Cloudflare Stream
 * d'ingérer depuis une adresse signée en lecture. Le fichier ne traverse
 * jamais le Worker — une vidéo de 300 Mo y serait refusée, et le temps de
 * calcul est facturé.
 */

/* =========================================================================
 * La liste : mes cours vidéo
 * =========================================================================*/

const ETATS: Record<
  MonCoursVideo['status'],
  { texte: string; ton?: 'success' | 'warning' }
> = {
  DRAFT: { texte: 'brouillon', ton: 'warning' },
  PUBLISHED: { texte: 'en vente', ton: 'success' },
  HIDDEN: { texte: 'retiré' },
}

export function MesCours() {
  const navigate = useNavigate()
  const mes = useAsync(() => prof.mesCoursVideo(), [])

  if (!serveurDisponible) {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Mes cours vidéo</h1>
        <Banner tone="warning">
          Cette page passe par le serveur Eduquali, qui n’est pas relié à ce
          site.
        </Banner>
      </div>
    )
  }

  const liste = mes.data?.courses ?? []
  const vendus = liste.reduce((total, cours) => total + cours.purchaseCount, 0)

  return (
    <div className="screen stack stack--loose">
      <PageHead
        title="Mes cours vidéo"
        lede="Un cours vidéo se vend sans vous, autant de fois qu’on l’achète. C’est le seul revenu qui ne dépend pas du temps que vous y passez."
        stats={[
          { value: liste.length, label: 'cours' },
          { value: liste.filter((c) => c.status === 'PUBLISHED').length, label: 'en vente' },
          { value: vendus, label: 'exemplaires vendus' },
        ]}
      />

      <Button block onClick={() => navigate('/cours/nouveau')}>
        <Icon name="plus" size={18} />
        Créer un cours
      </Button>

      {mes.loading ? (
        <Skeleton height={96} count={2} />
      ) : mes.error ? (
        <Banner tone="warning">{mes.error}</Banner>
      ) : liste.length === 0 ? (
        <EmptyState
          icon="play"
          title="Aucun cours vidéo"
          message="Un cours se compose d’un titre, d’un prix et de chapitres. Vous déposez les vidéos chapitre par chapitre, et vous publiez quand la première est prête."
        />
      ) : (
        <section className="stack">
          {liste.map((cours) => {
            const etat = ETATS[cours.status]
            return (
              <div className="rowitem" key={cours.id}>
                <Tile
                  icon="play"
                  tone={cours.status === 'PUBLISHED' ? 'success' : 'neutral'}
                />
                <span className="rowitem__body">
                  <span className="rowitem__title">{cours.title}</span>
                  <span className="rowitem__sub">
                    {cours.subject ?? 'Matière inconnue'} ·{' '}
                    {cours.price === 0 ? 'offert' : gnf(cours.price)} ·{' '}
                    {cours.chapters} chapitre{cours.chapters > 1 ? 's' : ''},{' '}
                    {cours.items} vidéo{cours.items > 1 ? 's' : ''}
                    {cours.purchaseCount > 0
                      ? ` · ${cours.purchaseCount} vendu${cours.purchaseCount > 1 ? 's' : ''}`
                      : ''}
                  </span>
                </span>
                <span className="rowitem__end">
                  <Chip tone={etat.ton}>{etat.texte}</Chip>
                  <Link className="btn btn--quiet" to={`/cours/${cours.id}/contenu`}>
                    Ouvrir
                  </Link>
                </span>
              </div>
            )
          })}
        </section>
      )}
    </div>
  )
}

/* =========================================================================
 * La création : titre, prix, chapitres
 * =========================================================================*/

export function NouveauCours() {
  const navigate = useNavigate()
  const matieres = useAsync(() => api.subjects(), [])
  const niveaux = useAsync(() => api.levels(), [])

  const [titre, setTitre] = useState('')
  const [description, setDescription] = useState('')
  const [subjectId, setSubjectId] = useState('')
  const [choisis, setChoisis] = useState<string[]>([])
  const [prix, setPrix] = useState('')
  const [chapitres, setChapitres] = useState<string[]>([''])
  const [envoi, setEnvoi] = useState(false)
  const [erreur, setErreur] = useState<string>()

  if (!serveurDisponible) {
    return (
      <>
        <AppBar title="Créer un cours" onBack />
        <div className="screen">
          <Banner tone="warning">
            La création d’un cours passe par le serveur Eduquali, qui relit le
            prix. Il n’est pas relié à ce site.
          </Banner>
        </div>
      </>
    )
  }

  const propres = chapitres.map((c) => c.trim()).filter((c) => c !== '')
  const complet = titre.trim().length >= 3 && subjectId && choisis.length > 0 && propres.length > 0

  const creer = async (event: React.FormEvent) => {
    event.preventDefault()
    if (!complet) {
      setErreur(
        'Il manque le titre, la matière, un niveau ou un premier chapitre.',
      )
      return
    }

    setEnvoi(true)
    setErreur(undefined)
    try {
      const cree = await studio.creer({
        title: titre.trim(),
        description: description.trim() || undefined,
        subjectId,
        levelIds: choisis,
        price: prix ? Number(prix.replace(/\s/g, '')) : 0,
        chapters: propres.map((nom) => ({ title: nom })),
      })
      // Droit sur l'écran de dépôt : un cours sans vidéo n'est pas un cours,
      // et renvoyer vers la liste laisserait le professeur devant un
      // brouillon sans savoir ce qui manque.
      navigate(`/cours/${cree.id}/contenu`, { replace: true })
    } catch (cause) {
      setErreur(cause instanceof Error ? cause.message : 'Création impossible.')
    } finally {
      setEnvoi(false)
    }
  }

  return (
    <>
      <AppBar title="Créer un cours" onBack />
      <form className="screen screen--narrow stack stack--loose" onSubmit={creer}>
        <Steps labels={['La fiche', 'Les vidéos', 'En vente']} current={0} />

        <Field
          label="Le titre"
          hint="Ce que l’élève lit en premier. « Les limites en terminale » dit plus que « Cours de maths »."
        >
          <TextInput
            value={titre}
            onChange={(e) => setTitre(e.target.value)}
            maxLength={140}
            autoFocus
          />
        </Field>

        <Field label="Matière">
          <Select value={subjectId} onChange={(e) => setSubjectId(e.target.value)}>
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
                onClick={() =>
                  setChoisis((avant) =>
                    avant.includes(niveau.id)
                      ? avant.filter((v) => v !== niveau.id)
                      : [...avant, niveau.id],
                  )
                }
              >
                {niveau.name}
              </button>
            ))}
          </div>
        </Field>

        <Field
          label="Le prix"
          hint="Zéro est permis, et c’est un choix : un cours offert fait venir du monde sur les suivants."
        >
          <TextInput
            inputMode="numeric"
            value={prix}
            onChange={(e) => setPrix(e.target.value.replace(/[^0-9\s]/g, ''))}
            placeholder="25 000"
          />
        </Field>

        <Field label="De quoi parle ce cours ?">
          <TextInput
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            maxLength={4000}
            placeholder="Ce que l’élève saura faire à la fin."
          />
        </Field>

        <Field
          label="Les chapitres"
          hint="Un chapitre = une vidéo, en général. Vous pourrez en ajouter plus tard."
        >
          <div className="stack stack--tight">
            {chapitres.map((nom, index) => (
              <div className="row" key={index}>
                <TextInput
                  value={nom}
                  onChange={(e) =>
                    setChapitres((avant) =>
                      avant.map((v, i) => (i === index ? e.target.value : v)),
                    )
                  }
                  placeholder={`Chapitre ${index + 1}`}
                  maxLength={140}
                />
                {chapitres.length > 1 ? (
                  <button
                    type="button"
                    className="iconbtn"
                    aria-label={`Retirer le chapitre ${index + 1}`}
                    onClick={() =>
                      setChapitres((avant) => avant.filter((_, i) => i !== index))
                    }
                  >
                    <Icon name="back" size={18} />
                  </button>
                ) : null}
              </div>
            ))}
            {chapitres.length < 30 ? (
              <Button
                variant="quiet"
                onClick={() => setChapitres((avant) => [...avant, ''])}
              >
                <Icon name="plus" size={16} />
                Ajouter un chapitre
              </Button>
            ) : null}
          </div>
        </Field>

        {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

        <Button type="submit" block disabled={envoi || !complet}>
          {envoi ? 'Création…' : 'Créer et déposer les vidéos'}
        </Button>

        <p className="faint micro measure">
          Le cours est créé en brouillon : il n’apparaît au catalogue qu’une
          fois publié, et la publication exige au moins une vidéo prête. Un
          cours en vente sans rien à voir serait une promesse qu’on ne tient
          pas.
        </p>
      </form>
    </>
  )
}

/* =========================================================================
 * Le contenu : déposer les vidéos, puis publier
 * =========================================================================*/

const ETATS_VIDEO: Record<string, { texte: string; ton?: 'success' | 'warning' }> = {
  PENDING_UPLOAD: { texte: 'envoi interrompu', ton: 'warning' },
  TRANSFERRING: { texte: 'préparation en cours' },
  READY: { texte: 'prête', ton: 'success' },
  FAILED: { texte: 'échec, à reprendre', ton: 'warning' },
}

export function ContenuCours() {
  const { id = '' } = useParams<{ id: string }>()
  const contenu = useAsync(() => studio.contenu(id), [id])
  const [envoi, setEnvoi] = useState<string>()
  const [avancement, setAvancement] = useState(0)
  const [erreur, setErreur] = useState<string>()
  const [publication, setPublication] = useState(false)

  if (!serveurDisponible) {
    return (
      <>
        <AppBar title="Le contenu" onBack />
        <div className="screen">
          <Banner tone="warning">
            Cette page passe par le serveur Eduquali, qui n’est pas relié à ce
            site.
          </Banner>
        </div>
      </>
    )
  }

  if (contenu.loading) {
    return (
      <>
        <AppBar title="Le contenu" onBack />
        <div className="screen">
          <Skeleton height={96} count={3} />
        </div>
      </>
    )
  }

  if (contenu.error || !contenu.data) {
    return (
      <>
        <AppBar title="Le contenu" onBack />
        <div className="screen">
          <Banner tone="warning">
            {contenu.error ?? 'Cours introuvable.'}
          </Banner>
        </div>
      </>
    )
  }

  const cours = contenu.data
  const pretes = cours.chapters.reduce(
    (total, chapitre) =>
      total + chapitre.items.filter((item) => item.status === 'READY').length,
    0,
  )
  const enPreparation = cours.chapters.reduce(
    (total, chapitre) =>
      total
      + chapitre.items.filter((item) => item.status === 'TRANSFERRING').length,
    0,
  )

  const deposer = async (chapterId: string, titre: string, fichier: File) => {
    setEnvoi(chapterId)
    setAvancement(0)
    setErreur(undefined)
    try {
      await studio.deposerVideo(chapterId, titre, fichier, setAvancement)
      contenu.reload()
    } catch (cause) {
      setErreur(cause instanceof Error ? cause.message : 'Dépôt impossible.')
    } finally {
      setEnvoi(undefined)
    }
  }

  const publier = async () => {
    setPublication(true)
    setErreur(undefined)
    try {
      await studio.publier(
        cours.id,
        cours.status === 'PUBLISHED' ? 'HIDDEN' : 'PUBLISHED',
      )
      contenu.reload()
    } catch (cause) {
      setErreur(cause instanceof Error ? cause.message : 'Action impossible.')
    } finally {
      setPublication(false)
    }
  }

  return (
    <>
      <AppBar title={cours.title} onBack />
      <div className="screen screen--narrow stack stack--loose">
        <Steps
          labels={['La fiche', 'Les vidéos', 'En vente']}
          current={cours.status === 'PUBLISHED' ? 2 : pretes > 0 ? 2 : 1}
        />

        <div className="row row--between">
          <span className="muted small">
            {cours.price === 0 ? 'Offert' : gnf(cours.price)} ·{' '}
            {pretes} vidéo{pretes > 1 ? 's' : ''} prête{pretes > 1 ? 's' : ''}
            {enPreparation > 0 ? `, ${enPreparation} en préparation` : ''}
          </span>
          <Chip tone={cours.status === 'PUBLISHED' ? 'success' : 'warning'}>
            {ETATS[cours.status as MonCoursVideo['status']]?.texte
              ?? cours.status}
          </Chip>
        </div>

        {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

        {cours.chapters.map((chapitre) => (
          <Card key={chapitre.id}>
            <div className="stack stack--tight">
              <strong>{chapitre.title}</strong>
              {chapitre.description ? (
                <span className="faint small">{chapitre.description}</span>
              ) : null}

              {chapitre.items.map((item) => {
                const etat = item.status
                  ? ETATS_VIDEO[item.status]
                  : undefined
                return (
                  <div className="row row--between small" key={item.id}>
                    <span className="row" style={{ gap: 'var(--espace-2)' }}>
                      <Icon name="play" size={16} />
                      {item.title}
                    </span>
                    {etat ? <Chip tone={etat.ton}>{etat.texte}</Chip> : null}
                  </div>
                )
              })}

              {envoi === chapitre.id ? (
                <div className="stack stack--tight">
                  <Progress value={avancement / 100} />
                  <span className="faint micro">
                    Envoi : {avancement} %. Ne fermez pas cette page.
                  </span>
                </div>
              ) : (
                <DepotVideo
                  onFichier={(fichier) =>
                    deposer(chapitre.id, chapitre.title, fichier)
                  }
                  occupe={envoi !== undefined}
                />
              )}
            </div>
          </Card>
        ))}

        {/*
          Publier n'est proposé qu'avec une vidéo prête. Le serveur le refuse
          de toute façon, et un bouton qui échoue vaut moins qu'un bouton
          absent accompagné de la raison.
        */}
        {pretes > 0 ? (
          <Button block onClick={publier} disabled={publication}>
            {publication
              ? 'Enregistrement…'
              : cours.status === 'PUBLISHED'
                ? 'Retirer de la vente'
                : 'Mettre en vente'}
          </Button>
        ) : (
          <Banner>
            {enPreparation > 0
              ? 'Une vidéo est en préparation chez l’hébergeur. Cela prend quelques minutes ; revenez ensuite pour publier.'
              : 'Déposez au moins une vidéo pour pouvoir mettre ce cours en vente.'}
          </Banner>
        )}
      </div>
    </>
  )
}

function DepotVideo({
  onFichier,
  occupe,
}: {
  onFichier: (fichier: File) => void
  occupe: boolean
}) {
  const [cle, setCle] = useState(0)

  return (
    <label className="dropzone" style={{ cursor: occupe ? 'wait' : 'pointer' }}>
      <Icon name="upload" size={22} />
      <span className="small">Ajouter une vidéo</span>
      <span className="faint micro">MP4, MOV ou WEBM — 600 Mo au maximum</span>
      <input
        key={cle}
        type="file"
        accept="video/mp4,video/quicktime,video/webm"
        className="sr-only"
        disabled={occupe}
        onChange={(event) => {
          const fichier = event.target.files?.[0]
          if (fichier) onFichier(fichier)
          // Le champ est remonté : sans cela, redéposer le même fichier après
          // un échec ne déclenche aucun événement.
          setCle((n) => n + 1)
        }}
      />
    </label>
  )
}
