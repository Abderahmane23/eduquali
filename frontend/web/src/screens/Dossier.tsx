import { useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { api } from '../api'
import { dossier, serveurDisponible, type Piece, type TypePiece } from '../api/server'
import { useSession } from '../app/session'
import { Tile } from '../components/kit'
import {
  AppBar,
  Banner,
  Chip,
  Icon,
  Progress,
  Skeleton,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'

/**
 * Le dossier : les pièces qui font passer les pastilles au vert.
 *
 * --- Le défaut que cette page corrige -----------------------------------
 *
 * Sur le site, la fiche d'un professeur était en **lecture seule**. Les
 * quatre pastilles — identité, diplôme, compétence, expérience — ne pouvaient
 * passer au vert que depuis le téléphone, parce que c'était le seul endroit
 * d'où l'on pouvait déposer une pièce. Un professeur qui n'a pas
 * l'application restait non vérifié à vie.
 *
 * Et des professeurs vérifiés, c'est précisément ce que ce produit vend. Une
 * école qui compare deux candidats regarde ces pastilles ; un parent aussi.
 *
 * --- Ce que le dépôt ne fait pas ---------------------------------------
 *
 * Il ne vérifie rien. L'état passe à « reçu », pas à « vérifié » : la
 * vérification est un acte humain, et c'est elle qui allume la pastille.
 * L'écran le dit, parce qu'un professeur qui dépose son diplôme et voit
 * « reçu » se demanderait sinon ce qui manque encore.
 */

/** Ce qu'on demande, dans l'ordre où cela compte. */
const DEMANDES: {
  type: TypePiece
  titre: string
  pourquoi: string
  accept: string
}[] = [
  {
    type: 'DIPLOMA',
    titre: 'Votre diplôme',
    pourquoi:
      'C’est lui qui fait la différence quand un établissement compare deux candidats.',
    accept: 'application/pdf,image/jpeg,image/png,image/webp',
  },
  {
    type: 'ID_FRONT',
    titre: 'Pièce d’identité — recto',
    pourquoi:
      'Elle confirme que vous êtes bien la personne du profil. Elle n’est jamais montrée aux familles.',
    accept: 'image/jpeg,image/png,image/webp,application/pdf',
  },
  {
    type: 'ID_BACK',
    titre: 'Pièce d’identité — verso',
    pourquoi: 'Le verso porte la date de validité.',
    accept: 'image/jpeg,image/png,image/webp,application/pdf',
  },
  {
    type: 'SELFIE',
    titre: 'Une photo de vous',
    pourquoi:
      'Comparée à la pièce d’identité. C’est aussi celle qui s’affiche sur votre fiche.',
    accept: 'image/jpeg,image/png,image/webp',
  },
  {
    type: 'CV',
    titre: 'Votre CV',
    pourquoi:
      'Facultatif, mais il raconte un parcours que quatre pastilles ne disent pas.',
    accept: 'application/pdf,image/jpeg,image/png',
  },
]

const ETATS: Record<string, { texte: string; ton?: 'success' | 'warning' }> = {
  PENDING_UPLOAD: { texte: 'envoi interrompu', ton: 'warning' },
  UPLOADED: { texte: 'reçu, en attente de vérification' },
  VERIFIED: { texte: 'vérifié', ton: 'success' },
  REJECTED: { texte: 'refusé, à reprendre', ton: 'warning' },
}

export function Dossier() {
  const { session } = useSession()
  const pieces = useAsync(() => dossier.pieces(), [])
  const fiche = useAsync(
    () =>
      session?.teacherId
        ? api.teacher(session.teacherId)
        : Promise.resolve(null),
    [session?.teacherId],
  )

  const [deposees, setDeposees] = useState<Piece[]>([])
  const [erreur, setErreur] = useState<string>()
  const [enCours, setEnCours] = useState<TypePiece>()

  if (!serveurDisponible) {
    return (
      <>
        <AppBar title="Mon dossier" onBack />
        <div className="screen">
          <Banner tone="warning">
            Le dépôt de pièces passe par le serveur EduQuali, qui n’est pas
            relié à ce site.
          </Banner>
        </div>
      </>
    )
  }

  // Les pièces lues au chargement, plus celles déposées depuis : recharger la
  // liste entière après chaque dépôt ferait clignoter la page sur une
  // connexion lente.
  const toutes = [...(pieces.data?.documents ?? []), ...deposees]
  const derniere = (type: TypePiece) =>
    toutes.filter((p) => p.type === type).at(-1)

  const deposer = async (type: TypePiece, fichier: File) => {
    setEnCours(type)
    setErreur(undefined)
    try {
      const piece = await dossier.deposer(type, fichier)
      setDeposees((avant) => [...avant, piece])
    } catch (cause) {
      setErreur(
        cause instanceof Error
          ? cause.message
          : 'Le dépôt n’a pas abouti. Réessayez.',
      )
    } finally {
      setEnCours(undefined)
    }
  }

  const badges = fiche.data?.badges

  return (
    <>
      <AppBar title="Mon dossier" onBack />
      {/* La progression et les pastilles a droite, les pieces a gauche :
          on depose en regardant ce qui manque encore. Empilees, il fallait
          remonter apres chaque depot pour savoir ou l'on en etait. */}
      <div className="screen stack stack--loose">
        <div className="pagegrid">
        <aside className="pagegrid__aside">
        {fiche.data ? (
          <section className="card card--accent">
            <div className="stack stack--tight">
              <div className="row row--between">
                <strong>Profil complété à {fiche.data.completionRate} %</strong>
              </div>
              <Progress value={fiche.data.completionRate / 100} />
              <span className="small">
                {fiche.data.completionRate < 100
                  ? 'Un profil complet passe devant les autres dans les résultats, parce que les écoles filtrent sur ce qui est vérifié.'
                  : 'Votre dossier est complet. Il ne reste qu’à attendre la vérification.'}
              </span>
            </div>
          </section>
        ) : fiche.loading ? (
          <Skeleton height={96} count={1} />
        ) : null}

        {/*
          Ce que j'enseigne, et pourquoi c'est en tête du dossier.

          Une famille cherche par matière et par niveau. Sans cette
          déclaration, le professeur n'apparaît dans aucune recherche — il a
          beau avoir déposé son diplôme et passé le test, il est invisible.
          C'est donc la pièce la plus importante, et elle manquait.
        */}
        <section className="stack stack--tight">
          <h2 className="section-title">Ce que j’enseigne</h2>
          {fiche.data && fiche.data.subjects.length > 0 ? (
            <>
              <div className="row" style={{ flexWrap: 'wrap' }}>
                {fiche.data.subjects.map((matiere) => (
                  <Chip key={matiere.id}>{matiere.name}</Chip>
                ))}
              </div>
              <div className="row" style={{ flexWrap: 'wrap' }}>
                {fiche.data.levels.map((niveau) => (
                  <Chip key={niveau.id}>{niveau.name}</Chip>
                ))}
              </div>
            </>
          ) : (
            <Banner tone="warning">
              Vous n’apparaissez dans aucune recherche tant que vous n’avez
              pas déclaré vos matières et vos niveaux.
            </Banner>
          )}
          <Link className="btn btn--ghost btn--block" to="/profil/competences">
            {fiche.data && fiche.data.subjects.length > 0
              ? 'Modifier mes matières et niveaux'
              : 'Déclarer mes matières et niveaux'}
          </Link>
        </section>

        {badges ? (
          <section className="stack stack--tight">
            <h2 className="section-title">Ce qui est vérifié</h2>
            {(
              [
                ['Identité', badges.identity],
                ['Diplôme', badges.diploma],
                ['Compétence', badges.competency],
                ['Expérience', badges.experience],
              ] as [string, boolean][]
            ).map(([nom, acquis]) => (
              <div className="row small" key={nom}>
                <span
                  style={{
                    color: acquis ? 'var(--vert-fonce)' : 'var(--crayon)',
                  }}
                >
                  <Icon name={acquis ? 'check' : 'shield'} size={16} />
                </span>
                <span className={acquis ? '' : 'faint'}>{nom}</span>
              </div>
            ))}
            <p className="faint micro">
              La compétence s’obtient en passant un test, pas en déposant une
              pièce. L’expérience se vérifie auprès de l’établissement que vous
              avez déclaré.
            </p>
          </section>
        ) : null}

        </aside>

        <div className="pagegrid__main">
        {erreur ? <Banner tone="warning">{erreur}</Banner> : null}

        <section className="stack">
          <h2 className="section-title">Les pièces</h2>
          {pieces.loading ? (
            <Skeleton height={96} count={3} />
          ) : (
            DEMANDES.map((demande) => (
              <Depot
                key={demande.type}
                demande={demande}
                piece={derniere(demande.type)}
                occupe={enCours === demande.type}
                onFichier={(fichier) => deposer(demande.type, fichier)}
              />
            ))
          )}
        </section>

        <p className="faint micro measure">
          Vos pièces ne sont jamais visibles par les familles ni par les
          écoles. Elles servent uniquement à la vérification, et le dépôt est
          privé — c’est la règle posée pour toutes les pièces d’identité du
          produit.
        </p>
        </div>
        </div>
      </div>
    </>
  )
}

function Depot({
  demande,
  piece,
  occupe,
  onFichier,
}: {
  demande: { type: TypePiece; titre: string; pourquoi: string; accept: string }
  piece?: Piece
  occupe: boolean
  onFichier: (fichier: File) => void
}) {
  const champ = useRef<HTMLInputElement>(null)
  const etat = piece ? ETATS[piece.status] : undefined

  return (
    <div className="card">
      <div className="stack stack--tight">
        <div className="row">
          <Tile
            icon={demande.type === 'DIPLOMA' ? 'diploma' : 'file'}
            tone={piece?.status === 'VERIFIED' ? 'success' : 'neutral'}
          />
          <div className="rowitem__body">
            <strong>{demande.titre}</strong>
            <span className="rowitem__sub">{demande.pourquoi}</span>
          </div>
          {etat ? <Chip tone={etat.ton}>{etat.texte}</Chip> : null}
        </div>

        {/*
          Un `input[type=file]` caché derrière un bouton : le champ natif ne
          se met pas en forme, et son libellé « Choisir un fichier » est en
          anglais sur la moitié des navigateurs.
        */}
        <input
          ref={champ}
          type="file"
          accept={demande.accept}
          className="sr-only"
          onChange={(event) => {
            const fichier = event.target.files?.[0]
            if (fichier) onFichier(fichier)
            // Remis à zéro : sans cela, redéposer le même fichier après un
            // échec ne déclenche aucun événement.
            event.target.value = ''
          }}
        />

        <button
          type="button"
          className="dropzone"
          onClick={() => champ.current?.click()}
          disabled={occupe}
        >
          <Icon name="upload" size={22} />
          <span className="small">
            {occupe
              ? 'Envoi en cours…'
              : piece
                ? 'Remplacer le fichier'
                : 'Choisir un fichier'}
          </span>
          <span className="faint micro">
            PDF ou photo, 12 Mo au maximum
          </span>
        </button>
      </div>
    </div>
  )
}
