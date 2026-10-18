import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { api } from '../api'
import { direct, prof, serveurDisponible, studio, type MonCoursVideo } from '../api/server'
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
          Cette page passe par le serveur EduQuali, qui n’est pas relié à ce
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
                  <ActionsCours cours={cours} onChange={mes.reload} />
                </span>
              </div>
            )
          })}
        </section>
      )}
    </div>
  )
}

/**
 * Corriger le titre d'un cours, ou le retirer.
 *
 * Les deux gestes manquaient : on pouvait creer, deposer, publier — jamais
 * revenir. Un titre fautif restait a l'ecran de tous ceux qui parcourent le
 * catalogue, et un cours rate ne se retirait pas.
 */
function ActionsCours({
  cours,
  onChange,
}: {
  cours: MonCoursVideo
  onChange: () => void
}) {
  const [mode, setMode] = useState<'repos' | 'titre' | 'confirme'>('repos')
  const [titre, setTitre] = useState(cours.title)
  const [occupe, setOccupe] = useState(false)
  const [souci, setSouci] = useState<string>()

  const renommer = async () => {
    const propre = titre.trim()
    if (propre.length < 3 || propre === cours.title) {
      setMode('repos')
      return
    }
    setOccupe(true)
    setSouci(undefined)
    try {
      await studio.modifier(cours.id, { title: propre })
      setMode('repos')
      onChange()
    } catch (cause) {
      setSouci(
        cause instanceof Error ? cause.message : 'Modification impossible.',
      )
    } finally {
      setOccupe(false)
    }
  }

  const supprimer = async () => {
    setOccupe(true)
    setSouci(undefined)
    try {
      await studio.supprimer(cours.id)
      onChange()
    } catch (cause) {
      /*
       * Le refus du serveur, mot pour mot.
       *
       * Il nomme le nombre d'achats et propose de masquer. Le remplacer par
       * « suppression impossible » laisserait chercher pourquoi, et la
       * reponse — « des familles ont paye » — est precisement celle qui fait
       * accepter le refus.
       */
      setSouci(
        cause instanceof Error ? cause.message : 'Suppression impossible.',
      )
      setMode('repos')
    } finally {
      setOccupe(false)
    }
  }

  if (mode === 'titre') {
    return (
      <span className="stack stack--tight">
        <TextInput
          value={titre}
          onChange={(e) => setTitre(e.target.value)}
          aria-label="Titre du cours"
          maxLength={120}
        />
        <span className="row" style={{ gap: 'var(--espace-2)' }}>
          <Button onClick={renommer} disabled={occupe}>
            {occupe ? 'Enregistrement…' : 'Enregistrer'}
          </Button>
          <Button
            variant="quiet"
            onClick={() => {
              setTitre(cours.title)
              setMode('repos')
            }}
          >
            Annuler
          </Button>
        </span>
        {souci ? <Banner tone="warning">{souci}</Banner> : null}
      </span>
    )
  }

  return (
    <span className="stack stack--tight">
      <span className="row" style={{ gap: 'var(--espace-2)' }}>
        <Button variant="quiet" onClick={() => setMode('titre')}>
          Renommer
        </Button>
        {/*
          La confirmation se fait sur place, en changeant le libelle.
          Une fenetre modale se ferme d'un geste reflexe — exactement le
          geste qu'on veut empecher avant un acte irreversible.
        */}
        <Button
          variant="quiet"
          disabled={occupe}
          onClick={() => (mode === 'confirme' ? supprimer() : setMode('confirme'))}
        >
          {mode === 'confirme' ? 'Confirmer la suppression' : 'Supprimer'}
        </Button>
      </span>
      {souci ? <Banner tone="warning">{souci}</Banner> : null}
    </span>
  )
}

/* =========================================================================
 * La création : titre, prix, chapitres
 * =========================================================================*/

export function NouveauCours() {
  const navigate = useNavigate()
  const [etape, setEtape] = useState<'fiche' | 'choix'>('fiche')
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
            La création d’un cours passe par le serveur EduQuali, qui relit le
            prix. Il n’est pas relié à ce site.
          </Banner>
        </div>
      </>
    )
  }

  const propres = chapitres.map((c) => c.trim()).filter((c) => c !== '')
  const complet = titre.trim().length >= 3 && subjectId && choisis.length > 0 && propres.length > 0

  const montant = () => (prix ? Number(prix.replace(/\s/g, '')) : 0)

  /*
   * La fiche remplie ouvre le choix, elle ne cree rien.
   *
   * Un cours en direct et un cours enregistre sont deux objets differents
   * — `live_courses` d'un cote, `video_courses` de l'autre. Creer l'un puis
   * changer d'avis laisserait un brouillon mort dans le catalogue du
   * professeur. Le bouton choisi cree le bon objet, et lui seul.
   */
  const choisir = (event: React.FormEvent) => {
    event.preventDefault()
    if (!complet) {
      setErreur(
        'Il manque le titre, la matière, un niveau ou un premier chapitre.',
      )
      return
    }
    setErreur(undefined)
    setEtape('choix')
  }

  /** Ouvrir la salle tout de suite. */
  const demarrerLeDirect = async () => {
    setEnvoi(true)
    setErreur(undefined)
    try {
      const seance = await direct.immediat({
        subjectId,
        levelId: choisis[0],
        title: titre.trim(),
        description: description.trim() || undefined,
        price: montant(),
      })
      /*
       * La salle s'ouvre par la route qui tient deja la fenetre
       * d'ouverture, l'enregistrement et le jeton LiveKit. On ne la
       * reecrit pas ici : deux chemins vers une meme salle finissent par
       * diverger, et c'est la salle qui en patit.
       */
      await api.openRoom(seance.sessionId)
      navigate(`/direct/${seance.sessionId}/salle`, { replace: true })
    } catch (cause) {
      setErreur(
        cause instanceof Error
          ? cause.message
          : 'Le direct n’a pas pu s’ouvrir.',
      )
      setEnvoi(false)
    }
  }

  /** Deposer un cours deja enregistre. */
  const deposerUneRediffusion = async () => {
    setEnvoi(true)
    setErreur(undefined)
    try {
      const cree = await studio.creer({
        title: titre.trim(),
        description: description.trim() || undefined,
        subjectId,
        levelIds: choisis,
        price: montant(),
        chapters: propres.map((nom) => ({ title: nom })),
      })
      // Droit sur l'écran de dépôt : un cours sans vidéo n'est pas un cours,
      // et renvoyer vers la liste laisserait le professeur devant un
      // brouillon sans savoir ce qui manque.
      navigate(`/cours/${cree.id}/contenu`, { replace: true })
    } catch (cause) {
      setErreur(cause instanceof Error ? cause.message : 'Création impossible.')
      setEnvoi(false)
    }
  }

  if (etape === 'choix') {
    return (
      <>
        <AppBar title="Comment donnez-vous ce cours ?" onBack />
        <div className="screen screen--narrow stack stack--loose">
          <Steps labels={['La fiche', 'Le format', 'En ligne']} current={1} />

          <p className="muted measure">
            <strong>{titre.trim()}</strong>
            {montant() > 0 ? ` · ${montant().toLocaleString('fr-FR')} GNF` : null}
          </p>

          <Card>
            <div className="stack stack--tight">
              <strong>Démarrer le direct maintenant</strong>
              <p className="muted small">
                La salle s’ouvre tout de suite. Vous invitez vos élèves, et
                ceux qui ont installé l’application sont prévenus.
              </p>
              <Button block onClick={demarrerLeDirect} disabled={envoi}>
                {envoi ? 'Ouverture…' : 'Ouvrir la salle'}
              </Button>
            </div>
          </Card>

          <Card>
            <div className="stack stack--tight">
              <strong>Déposer une rediffusion</strong>
              <p className="muted small">
                Vous avez déjà filmé le cours. Il se vend autant de fois
                qu’il se regarde, sans que vous le redonniez.
              </p>
              <Button
                block
                variant="quiet"
                onClick={deposerUneRediffusion}
                disabled={envoi}
              >
                {envoi ? 'Création…' : 'Déposer les vidéos'}
              </Button>
            </div>
          </Card>

          {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

          <Button variant="quiet" block onClick={() => setEtape('fiche')}>
            Revenir à la fiche
          </Button>
        </div>
      </>
    )
  }

  return (
    <>
      <AppBar title="Créer un cours" onBack />
      <form
        className="screen screen--narrow stack stack--loose"
        onSubmit={choisir}
      >
        <Steps labels={['La fiche', 'Le format', 'En ligne']} current={0} />

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

        <Button type="submit" block disabled={!complet}>
          Continuer
        </Button>

        <p className="faint micro measure">
          Vous choisirez ensuite entre ouvrir le direct tout de suite, ou
          déposer un cours déjà filmé.
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
            Cette page passe par le serveur EduQuali, qui n’est pas relié à ce
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
