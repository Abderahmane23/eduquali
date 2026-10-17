import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../api'
import { competences } from '../api/server'
import type { RefItem } from '../api/types'
import { useSession } from '../app/session'
import { PageHead, Statut } from '../components/kit'
import {
  AppBar,
  Banner,
  Button,
  Card,
  Chip,
  Skeleton,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'

/**
 * Ce qu'un professeur déclare enseigner.
 *
 * --- Ce que cet écran répare --------------------------------------------
 *
 * Une famille cherche par matière et par niveau. Un professeur qui n'a rien
 * déclaré n'apparaît dans aucune recherche : il s'est inscrit, il a passé le
 * test, il a déposé son diplôme — et il est invisible. La route
 * `/teacher/competences` existait depuis le premier jour et le site ne
 * l'appelait jamais.
 *
 * --- Pourquoi l'écran envoie tout à chaque fois -------------------------
 *
 * `remplacer_competences` écrit la déclaration entière en une instruction.
 * Ajouter et retirer ligne par ligne laisserait, le temps d'un réseau qui
 * coupe, un professeur déclaré sur une matière et plus aucun niveau — donc
 * introuvable, sans que rien ne l'ait signalé.
 *
 * --- Pourquoi une matière sans niveau ne part pas -----------------------
 *
 * Elle ne servirait à rien : la recherche croise les deux. L'écran le dit
 * au lieu d'enregistrer une déclaration qui ne ferait apparaître personne.
 */
export function Competences() {
  const { session } = useSession()
  const navigate = useNavigate()

  const matieres = useAsync(() => api.subjects(), [])
  const niveaux = useAsync(() => api.levels(), [])
  const fiche = useAsync(
    () =>
      session?.teacherId
        ? api.teacher(session.teacherId)
        : Promise.resolve(null),
    [session?.teacherId],
  )

  /** Matière choisie → niveaux choisis. */
  const [choix, setChoix] = useState<Map<string, Set<string>>>(new Map())
  const [charge, setCharge] = useState(false)
  const [envoi, setEnvoi] = useState(false)
  const [erreur, setErreur] = useState<string>()
  const [fait, setFait] = useState(false)

  /*
   * On part de ce qui est déjà déclaré.
   *
   * La fiche rend les matières et les niveaux à plat — elle ne dit pas quel
   * niveau va avec quelle matière. On coche donc tous les niveaux déclarés
   * sur chaque matière déclarée : c'est ce que la base contient dans
   * l'immense majorité des cas, et l'écran reste modifiable.
   */
  useEffect(() => {
    if (charge || !fiche.data) return
    const depart = new Map<string, Set<string>>()
    const tousNiveaux = new Set(fiche.data.levels.map((n) => n.id))
    for (const matiere of fiche.data.subjects) {
      depart.set(matiere.id, new Set(tousNiveaux))
    }
    setChoix(depart)
    setCharge(true)
  }, [fiche.data, charge])

  const parPalier = useMemo(() => {
    const paquets = new Map<string, RefItem[]>()
    for (const niveau of niveaux.data ?? []) {
      const palier = niveau.category ?? 'AUTRE'
      paquets.set(palier, [...(paquets.get(palier) ?? []), niveau])
    }
    return paquets
  }, [niveaux.data])

  if (session && session.role !== 'TEACHER') {
    return (
      <div className="screen stack stack--loose">
        <h1 className="page-title">Ce que j’enseigne</h1>
        <Banner tone="warning">
          Cet écran est réservé aux professeurs.
        </Banner>
      </div>
    )
  }

  if (matieres.loading || niveaux.loading || fiche.loading) {
    return (
      <>
        <AppBar title="Ce que j’enseigne" onBack />
        <div className="screen">
          <Skeleton height={80} count={5} />
        </div>
      </>
    )
  }

  const basculerMatiere = (id: string) => {
    const suivant = new Map(choix)
    if (suivant.has(id)) suivant.delete(id)
    else suivant.set(id, new Set())
    setChoix(suivant)
    setFait(false)
  }

  const basculerNiveau = (matiere: string, niveau: string) => {
    const suivant = new Map(choix)
    const liste = new Set(suivant.get(matiere) ?? [])
    if (liste.has(niveau)) liste.delete(niveau)
    else liste.add(niveau)
    suivant.set(matiere, liste)
    setChoix(suivant)
    setFait(false)
  }

  const sansNiveau = [...choix.entries()].filter(([, n]) => n.size === 0)
  const prete = choix.size > 0 && sansNiveau.length === 0

  const enregistrer = async () => {
    setEnvoi(true)
    setErreur(undefined)
    try {
      await competences.declarer(
        [...choix.entries()].map(([subjectId, levelIds]) => ({
          subjectId,
          levelIds: [...levelIds],
        })),
      )
      setFait(true)
    } catch (cause) {
      setErreur(
        cause instanceof Error
          ? cause.message
          : 'L’enregistrement n’a pas abouti.',
      )
    } finally {
      setEnvoi(false)
    }
  }

  return (
    <>
      <AppBar title="Ce que j’enseigne" onBack />
      <div className="screen stack stack--loose">
        <PageHead
          title="Ce que j’enseigne"
          lede={
            'Une famille cherche par matière et par niveau. Sans cette ' +
            'déclaration, vous n’apparaissez dans aucune recherche.'
          }
        />

        {erreur ? <Banner tone="warning">{erreur}</Banner> : null}
        {fait ? (
          <Banner>
            C’est enregistré. Vous apparaissez maintenant dans les recherches
            correspondantes.
          </Banner>
        ) : null}

        <section className="stack stack--tight">
          <h2 className="section-title">Les matières</h2>
          <div className="row" style={{ flexWrap: 'wrap' }}>
            {(matieres.data ?? []).map((matiere) => (
              <button
                key={matiere.id}
                type="button"
                className="rolebtn"
                aria-checked={choix.has(matiere.id)}
                role="checkbox"
                onClick={() => basculerMatiere(matiere.id)}
              >
                <span className="rolebtn__label">{matiere.name}</span>
              </button>
            ))}
          </div>
        </section>

        {[...choix.keys()].map((matiereId) => {
          const matiere = (matieres.data ?? []).find((m) => m.id === matiereId)
          const pris = choix.get(matiereId) ?? new Set<string>()
          return (
            <Card key={matiereId}>
              <div className="stack stack--tight">
                <div className="row row--between">
                  <strong>{matiere?.name ?? 'Matière'}</strong>
                  {pris.size === 0 ? (
                    /* Une matière sans niveau ne ferait apparaître personne :
                       on le dit avant d'enregistrer, pas après. */
                    <Statut ton="attente">Choisissez un niveau</Statut>
                  ) : (
                    <Chip tone="success">
                      {pris.size} niveau{pris.size > 1 ? 'x' : ''}
                    </Chip>
                  )}
                </div>

                {[...parPalier.entries()].map(([palier, liste]) => (
                  <div className="stack stack--tight" key={palier}>
                    <span className="etiquette">{nomDuPalier(palier)}</span>
                    <div className="row" style={{ flexWrap: 'wrap' }}>
                      {liste.map((niveau) => (
                        <button
                          key={niveau.id}
                          type="button"
                          className="rolebtn"
                          role="checkbox"
                          aria-checked={pris.has(niveau.id)}
                          onClick={() =>
                            basculerNiveau(matiereId, niveau.id)
                          }
                        >
                          <span className="rolebtn__label">{niveau.name}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </Card>
          )
        })}

        <div className="row row--actions">
          <Button disabled={envoi || !prete} onClick={enregistrer}>
            {envoi ? 'Enregistrement…' : 'Enregistrer'}
          </Button>
          <Button variant="ghost" onClick={() => navigate('/profil/dossier')}>
            Revenir au dossier
          </Button>
        </div>

        {choix.size === 0 ? (
          <p className="faint micro">
            Choisissez au moins une matière, puis les niveaux que vous y
            enseignez.
          </p>
        ) : null}
      </div>
    </>
  )
}

/** Le palier, dans les mots du système guinéen. */
function nomDuPalier(code: string): string {
  const noms: Record<string, string> = {
    PRIMARY: 'Primaire',
    SECONDARY: 'Collège et lycée',
    UNIVERSITY: 'Université',
    GRADUATE: 'Études supérieures',
  }
  return noms[code] ?? 'Autres niveaux'
}
