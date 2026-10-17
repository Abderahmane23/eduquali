import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { api } from '../api'
import { video } from '../api/server'
import type { CourseChapterPreview, CourseItemPreview } from '../api/types'
import {
  AppBar,
  Banner,
  Card,
  EmptyState,
  Icon,
  Skeleton,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'
import { clock } from '../lib/format'

/**
 * Lire un cours vidéo acheté.
 *
 * --- Ce que cet écran répare --------------------------------------------
 *
 * Un élève pouvait **acheter** un cours vidéo sur le site et n'avait aucun
 * moyen de le regarder. La route `/videos/:itemId/url` est servie depuis le
 * premier jour, et rien côté web ne l'appelait : on vendait quelque chose
 * qu'on ne livrait pas.
 *
 * --- Pourquoi le sommaire vient de la base, pas d'une route --------------
 *
 * `course_items` est fermée par RLS depuis la migration 0010 : seuls
 * l'auteur et ceux qui ont payé y accèdent. Une liste vide veut donc dire
 * « pas acheté », et c'est la base qui le dit. Une route serveur qui
 * revérifierait l'achat referait, sous la clé de service, ce que la base
 * fait déjà — et c'est là qu'on se trompe.
 *
 * --- Pourquoi un `iframe` et non notre lecteur ---------------------------
 *
 * La vidéo est servie en HLS. Safari le lit nativement, Chrome et Firefox
 * non : il leur faudrait `hls.js`, les niveaux de qualité, la reprise après
 * coupure. Sur une ligne guinéenne, c'est exactement le code qu'on écrit
 * mal. Le lecteur de Cloudflare Stream le fait déjà, depuis le même réseau
 * que la vidéo.
 */
export function CoursePlayer() {
  const { id = '' } = useParams()
  const cours = useAsync(() => api.videoCourse(id), [id])
  const sommaire = useAsync(() => api.courseLecture(id), [id])
  const [choisi, setChoisi] = useState<CourseItemPreview>()

  // Le premier élément lisible, dès que le sommaire arrive : un écran qui
  // ouvre sur un cadre vide se lit comme une panne.
  useEffect(() => {
    if (choisi || !sommaire.data) return
    for (const chapitre of sommaire.data) {
      const premier = chapitre.items.find((i) => i.kind === 'VIDEO')
      if (premier) {
        setChoisi(premier)
        return
      }
    }
  }, [sommaire.data, choisi])

  if (cours.loading || sommaire.loading) {
    return (
      <>
        <AppBar title="Cours" onBack />
        <div className="screen">
          <Skeleton height={200} count={2} />
        </div>
      </>
    )
  }

  const chapitres = sommaire.data ?? []

  if (chapitres.length === 0) {
    return (
      <>
        <AppBar title={cours.data?.title ?? 'Cours'} onBack />
        <div className="screen stack stack--loose">
          <EmptyState
            icon="play"
            title="Ce cours n’est pas encore à vous"
            message={
              'Les vidéos s’ouvrent une fois le cours payé. Si vous venez de ' +
              'payer, le serveur peut mettre une minute à le confirmer.'
            }
          />
        </div>
      </>
    )
  }

  return (
    <>
      {/*
        Un seul titre.

        L'ecran portait la barre de navigation **et** le bandeau de la
        charte, tous deux avec le nom du cours : le titre s'affichait deux
        fois a dix points d'intervalle. Sur un sous-ecran, c'est la barre qui
        reste — elle porte le retour, et le bandeau n'a rien a ajouter.
      */}
      <AppBar title={cours.data?.title ?? 'Cours'} onBack />
      <div className="screen stack stack--loose">
        {choisi ? <Lecteur item={choisi} /> : null}

        {/*
          Le professeur, seulement si on le connait.

          La phrase etait `Par ${teacherName}` sans garde : une fiche sans
          nom affichait « Par undefined ». Un champ vide se tait.
        */}
        {cours.data?.teacherName ? (
          <p className="muted small">
            Par {cours.data.teacherName}. Revu autant de fois qu’il faut.
          </p>
        ) : null}

        <section className="stack stack--tight">
          <h2 className="section-title">Le sommaire</h2>
          {chapitres.map((chapitre) => (
            <Chapitre
              key={chapitre.id}
              chapitre={chapitre}
              choisi={choisi}
              onChoisir={setChoisi}
            />
          ))}
        </section>
      </div>
    </>
  )
}

/** Le lecteur, et ce qu'il dit quand la vidéo n'est pas prête. */
function Lecteur({ item }: { item: CourseItemPreview }) {
  const adresse = useAsync(() => video.adresse(item.id), [item.id])

  if (adresse.loading) return <Skeleton height={220} count={1} />

  if (adresse.error || !adresse.data) {
    return (
      <Banner tone="warning">
        {/*
          Le message du serveur, pas un message générique : il distingue
          « pas encore déposée » de « en préparation », et ces deux-là
          n'appellent pas la même patience.
        */}
        {adresse.error ?? 'Cette vidéo n’est pas disponible.'}
      </Banner>
    )
  }

  return (
    <div className="stack stack--tight">
      <div className="replay">
        <iframe
          className="replay__cadre"
          src={adresse.data.iframe}
          title={item.title}
          allow="accelerometer; gyroscope; autoplay; encrypted-media; picture-in-picture;"
          allowFullScreen
        />
      </div>
      <strong>{item.title}</strong>
    </div>
  )
}

function Chapitre({
  chapitre,
  choisi,
  onChoisir,
}: {
  chapitre: CourseChapterPreview
  choisi?: CourseItemPreview
  onChoisir: (item: CourseItemPreview) => void
}) {
  return (
    <Card>
      <div className="stack stack--tight">
        <strong className="small">
          {chapitre.position + 1}. {chapitre.title}
        </strong>

        {chapitre.items.map((item) => {
          const actif = item.id === choisi?.id
          const lisible = item.kind === 'VIDEO'
          return (
            <button
              key={item.id}
              type="button"
              className="rowitem"
              // Un document ou un lien n'ouvre pas le lecteur : on ne
              // propose pas un geste qui ne fera rien.
              disabled={!lisible}
              aria-current={actif ? 'true' : undefined}
              onClick={() => lisible && onChoisir(item)}
            >
              <span className="rowitem__body">
                <span className="rowitem__title">
                  <Icon name={lisible ? 'play' : 'file'} size={14} />{' '}
                  {item.title}
                </span>
                {item.durationSeconds ? (
                  <span className="rowitem__sub">
                    {clock(item.durationSeconds)}
                  </span>
                ) : null}
              </span>
              <span className="rowitem__end">
                {actif ? <span className="faint micro">en cours</span> : null}
              </span>
            </button>
          )
        })}
      </div>
    </Card>
  )
}
