import { useEffect, useState } from 'react'
import { Link, Navigate, useNavigate, useSearchParams } from 'react-router-dom'
import { api } from '../api'
import type { RankedCandidate } from '../api/types'
import { useSession } from '../app/session'
import { Avatar, Banner, Button, Chip, EmptyState, Skeleton } from '../components/ui'

/**
 * Les resultats de la recherche, avant tout compte.
 *
 * C'est la promesse de l'ecran d'entree : on regarde d'abord. La liste
 * montre ce qu'un professeur publie de lui-meme — nom, matieres, ville,
 * experience. Les coordonnees restent masquees, exactement comme pour un
 * etablissement qui n'a pas encore recrute (§30).
 *
 * Le compte n'est demande qu'au moment de contacter quelqu'un, parce que
 * c'est le premier geste qui engage une autre personne. Le meme decoupage
 * que sur l'application mobile : commencer ici, finir la-bas.
 */
export function Discover() {
  const [params] = useSearchParams()
  const navigate = useNavigate()
  const { session } = useSession()
  const query = (params.get('q') ?? '').trim()

  /*
   * Le mode, envoye par l'accueil.
   *
   * --- Le defaut que ceci corrige ---------------------------------------
   *
   * L'accueil du telephone demande depuis toujours « cours a domicile » ou
   * « embauche » avant de chercher, parce que les deux cherchent des
   * professeurs mais pas pour la meme chose : une famille cherche quelqu'un
   * qui se deplace le soir, une ecole cherche quelqu'un a recruter. Melanger
   * les deux listes donne des resultats que ni l'un ni l'autre ne peut
   * utiliser.
   *
   * Le site posait la question — depuis le 11/10 — et jetait la reponse :
   * `mode` arrivait dans l'adresse et cet ecran l'ignorait. Un parent qui
   * choisissait « cours a domicile » obtenait la liste des professeurs a
   * recruter, sans tarif, sans quartier et sans moyen de demander une
   * seance.
   */
  if (params.get('mode') === 'domicile') {
    return <Navigate to={`/domicile${query ? `?q=${encodeURIComponent(query)}` : ''}`} replace />
  }

  const [candidates, setCandidates] = useState<RankedCandidate[]>()
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    let alive = true
    setCandidates(undefined)
    setFailed(false)
    api
      .searchTeachers({})
      .then((found) => {
        if (alive) setCandidates(found)
      })
      .catch(() => {
        if (alive) setFailed(true)
      })
    return () => {
      alive = false
    }
  }, [])

  if (failed) {
    return (
      <div className="screen stack stack--loose">
        <Banner tone="warning">
          Recherche indisponible. Réessayez dans un instant.
        </Banner>
      </div>
    )
  }

  if (!candidates) {
    return (
      <div className="screen">
        <Skeleton count={4} />
      </div>
    )
  }

  const subjectsOf = (c: RankedCandidate) =>
    c.profile.subjects.map((s) => s.name).join(' · ')

  const needle = query.toLowerCase()
  const shown = needle
    ? candidates.filter(
        (c) =>
          c.profile.fullName.toLowerCase().includes(needle) ||
          (c.profile.city ?? '').toLowerCase().includes(needle) ||
          subjectsOf(c).toLowerCase().includes(needle),
      )
    : candidates

  return (
    <div className="screen stack stack--loose">
      <header className="hero">
        <h1 className="hero__title">{query || 'Professeurs'}</h1>
        <p className="hero__lede">
          {shown.length === 1
            ? '1 professeur disponible'
            : `${shown.length} professeurs disponibles`}
        </p>
      </header>

      {shown.length === 0 ? (
        <EmptyState
          title="Aucun résultat"
          message={
            query
              ? `Aucun professeur ne correspond à « ${query} ». Essayez une autre matière ou une autre ville.`
              : 'Aucun professeur disponible pour le moment.'
          }
        />
      ) : (
        <ul
          className="stack stack--tight grid-cards"
          style={{ listStyle: 'none', padding: 0 }}
        >
          {shown.map((c) => (
            <li key={c.profile.id}>
              {/*
                Chaque resultat mene a la fiche. Elle existe depuis le 02/10 et
                la recherche n'y renvoyait pas : on cherchait un professeur, on
                le trouvait, et on ne pouvait pas l'ouvrir.
              */}
              <Link to={`/professeurs/${c.profile.id}`} className="door">
                <Avatar first={c.profile.firstName} last={c.profile.lastName} />
                <span>
                  <span className="door__title">{c.profile.fullName}</span>
                  <br />
                  <span className="door__sub">{subjectsOf(c)}</span>
                  {c.profile.city ? (
                    <>
                      {' '}
                      <Chip>{c.profile.city}</Chip>
                    </>
                  ) : null}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}

      {/* Le compte n'est reclame qu'ici, et on dit pourquoi. */}
      {session ? null : (
        <div className="stack stack--tight">
          <p className="micro faint centered">
            Nécessaire pour contacter un professeur.
          </p>
          <Button block onClick={() => navigate('/inscription')}>
            Créer mon compte
          </Button>
          <p className="centered">
            <span className="faint">Vous avez déjà un compte ? </span>
            <Link to="/connexion">Se connecter</Link>
          </p>
        </div>
      )}
    </div>
  )
}
