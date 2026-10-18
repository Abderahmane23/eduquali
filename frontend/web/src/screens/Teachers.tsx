import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import { api } from '../api'
import { useSession } from '../app/session'
import { AppGate } from '../components/AppGate'
import { PageHead } from '../components/kit'
import {
  AppBar,
  Avatar,
  Banner,
  Card,
  Chip,
  EmptyState,
  Icon,
  Select,
  Skeleton,
} from '../components/ui'
import { availabilityLabel, experienceLabel, money } from '../lib/format'
import { useAsync } from '../lib/useAsync'

/**
 * Les professeurs.
 *
 * **Publique, comme sur le telephone.** On regarde avant d'ouvrir un compte,
 * et c'est ce que l'accueil promet deja : « le compte n'est reclame qu'au
 * moment de contacter quelqu'un ». Derriere une authentification, cette liste
 * demandait de s'inscrire pour savoir s'il y avait une raison de s'inscrire.
 *
 * Ce qui s'affiche est ce qu'un professeur publie de lui-meme. Le telephone et
 * le courriel n'y sont pas : ils ne circulent qu'apres mise en relation (§30),
 * et c'est RLS qui le garantit — pas cet ecran.
 *
 * La ville vient du compte quand il y en a un : un parent cherche quelqu'un
 * qui peut venir chez lui, et proposer un professeur de Kankan a une famille
 * de Conakry ne sert personne. Un visiteur, lui, choisit sa ville dans la
 * liste.
 */
export function Teachers() {
  const { session } = useSession()
  const [chosenCity, setChosenCity] = useState<string | null>(null)

  // La ville du compte sert de depart, pas de prison : on peut l'elargir.
  const city = chosenCity ?? session?.city ?? ''

  /*
   * Les cours a domicile d'abord, pour une famille.
   *
   * Un parent cherche quelqu'un qui vient a la maison : lui presenter d'abord
   * des offres a distance ou « chez l'enseignant » lui fait parcourir une liste
   * dont la moitie ne lui convient pas — et c'est la premiere liste qu'il voit
   * du produit.
   *
   * Un defaut, pas une prison : le bouton l'elargit, exactement comme la ville.
   */
  const familleOuEtudiant =
    session?.role === 'PARENT' || session?.role === 'STUDENT'
  const [domicileSeulement, setDomicileSeulement] = useState(familleOuEtudiant)

  const cities = useAsync(() => api.cities(), [])
  const state = useAsync(
    () =>
      api.searchTeachers({
        city: city || undefined,
        mode: domicileSeulement ? 'AT_STUDENT' : undefined,
      }),
    [city, domicileSeulement],
  )

  const available = (state.data ?? []).filter(
    ({ profile }) => profile.availability !== 'UNAVAILABLE',
  )

  return (
    <>
      <div className="screen stack stack--loose">
        <PageHead
          title="Professeurs"
          lede={
            'Chaque profil est vérifié pièce par pièce : identité, diplôme, ' +
            'puis un test sur le programme guinéen.'
          }
        />
        <Select
          value={city}
          onChange={(e) => setChosenCity(e.target.value)}
          aria-label="Filtrer par ville"
        >
          <option value="">Toutes les villes</option>
          {(cities.data ?? []).map((name) => (
            <option key={name} value={name}>
              {name}
            </option>
          ))}
        </Select>

        {/* Le defaut se voit et se desactive : une liste filtree en silence fait
            croire qu'il n'y a que trois professeurs dans la ville. */}
        {familleOuEtudiant ? (
          <label className="row" style={{ gap: 'var(--espace-2)' }}>
            <input
              type="checkbox"
              checked={domicileSeulement}
              onChange={(e) => setDomicileSeulement(e.target.checked)}
            />
            <span className="small">
              Seulement ceux qui se déplacent à domicile
            </span>
          </label>
        ) : null}

        {state.loading ? (
          <Skeleton height={88} count={3} />
        ) : state.error ? (
          <Banner tone="warning">{state.error}</Banner>
        ) : available.length === 0 ? (
          <EmptyState
            title="Aucun professeur disponible"
            message={
              city
                ? `Aucun professeur disponible à ${city} pour le moment.`
                : 'Aucun professeur disponible pour le moment.'
            }
          />
        ) : (
          <div className="stack grid-cards">
            {available.map(({ profile }) => (
            // La carte entiere mene a la fiche : sur un telephone, viser un
            // lien de la taille d'un mot fait manquer la cible.
            <Link
              key={profile.id}
              to={`/professeurs/${profile.id}`}
              className="card-link"
            >
              <Card>
                <div className="row">
                  <Avatar
                    first={profile.firstName}
                    last={profile.lastName}
                    src={profile.photoUrl}
                  />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <strong>{profile.fullName}</strong>
                    <div className="muted small">
                      {profile.subjects.map((s) => s.name).join(' · ') ||
                        profile.headline}
                    </div>
                    <div
                      className="row faint micro"
                      style={{ gap: 'var(--espace-1)' }}
                    >
                      <Icon name="place" size={12} />
                      {profile.city}
                    </div>
                  </div>
                  {profile.badges.identity ? (
                    <Chip tone="success">Vérifié</Chip>
                  ) : null}
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
 * La fiche publique d'un professeur.
 *
 * `api.teacher(id)` existait dans le contrat et aucune route ne l'appelait :
 * la liste affichait des noms sur lesquels on ne pouvait pas cliquer, ce qui
 * est le contraire d'un annuaire.
 *
 * Meme contenu que l'ecran du telephone, dans le meme ordre : qui, ce qu'il
 * enseigne, ce qui est verifie, son parcours. Le bouton « Contacter » est
 * remplace par [AppGate] et non masque.
 */
export function TeacherDetail() {
  const { id = '' } = useParams()
  const state = useAsync(() => api.teacher(id), [id])

  if (state.loading) {
    return (
      <>
        <AppBar title="Professeur" onBack />
        <div className="screen">
          <Skeleton height={40} count={5} />
        </div>
      </>
    )
  }

  if (state.error) {
    return (
      <>
        <AppBar title="Professeur" onBack />
        <div className="screen">
          <Banner tone="warning">{state.error}</Banner>
        </div>
      </>
    )
  }

  const profile = state.data
  if (!profile) {
    return (
      <>
        <AppBar title="Professeur" onBack />
        <EmptyState
          title="Profil introuvable"
          message="Ce professeur n’est plus référencé."
        />
      </>
    )
  }

  const verifies = [
    profile.badges.identity ? 'Identité vérifiée' : null,
    profile.badges.diploma ? 'Diplôme vérifié' : null,
    profile.badges.competency ? 'Certifié par un test' : null,
  ].filter((v): v is string => v != null)

  return (
    <>
      <AppBar title={profile.fullName} onBack />
      {/*
        Deux colonnes a partir de 1024 px : le parcours a gauche, l'identite et
        l'action a droite, cette derniere collee en haut. Sur un ordinateur,
        une fiche fait plusieurs ecrans de haut et le bouton « contacter »
        disparaissait en haut de page des le premier defilement.

        Sous 1024 px, `.detail` reste une pile et l'ordre du DOM s'applique :
        identite, action, puis le reste — ce qui est l'ordre voulu sur un
        telephone.
      */}
      <div className="screen detail stack stack--loose">
        <aside className="detail__aside stack">
          <Card>
            <div className="row">
              <Avatar
                first={profile.firstName}
                last={profile.lastName}
                src={profile.photoUrl}
              />
              <div style={{ flex: 1, minWidth: 0 }}>
                <strong>{profile.fullName}</strong>
                <div className="muted small">{profile.headline}</div>
                <div className="row faint micro" style={{ gap: 'var(--espace-1)' }}>
                  <Icon name="place" size={12} />
                  {profile.city ?? 'Ville non précisée'}
                </div>
              </div>
            </div>

            <div
              className="row"
              style={{
                gap: 'var(--espace-2)',
                flexWrap: 'wrap',
                marginTop: 'var(--espace-3)',
              }}
            >
              <Chip>{experienceLabel(profile.yearsExperience)}</Chip>
              <Chip>{availabilityLabel(profile.availability)}</Chip>
            </div>
          </Card>

          <AppGate action="contacter ce professeur" />
        </aside>

        <div className="detail__main stack stack--loose">
        <TutoringOffers teacherId={profile.id} />

        {verifies.length > 0 ? (
          <section className="stack stack--tight">
            <h2 className="section-title">Vérification</h2>
            {verifies.map((label) => (
              <div className="row" key={label} style={{ gap: 'var(--espace-2)' }}>
                <Icon name="check" size={16} />
                <span className="small">{label}</span>
              </div>
            ))}
          </section>
        ) : null}

        {profile.subjects.length > 0 || profile.levels.length > 0 ? (
          <section className="stack stack--tight">
            <h2 className="section-title">Compétences</h2>
            <div className="tags">
              {profile.subjects.map((s) => (
                <span className="tag" key={s.id}>
                  {s.name}
                </span>
              ))}
            </div>
            {profile.levels.length > 0 ? (
              <p className="muted small">
                Classes : {profile.levels.map((l) => l.name).join(', ')}
              </p>
            ) : null}
          </section>
        ) : null}

        {profile.bio ? (
          <section className="stack stack--tight">
            <h2 className="section-title">Présentation</h2>
            <p className="muted small">{profile.bio}</p>
          </section>
        ) : null}

        {profile.experiences.length > 0 ? (
          <section className="stack stack--tight">
            <h2 className="section-title">Parcours</h2>
            {profile.experiences.map((xp) => (
              <Card key={xp.id}>
                <div className="row row--between">
                  <strong className="small">{xp.position}</strong>
                  {/* Une experience verifiee n'a pas le meme poids qu'une
                      ligne saisie : la distinguer est tout l'interet. */}
                  {xp.verified ? <Chip tone="success">Vérifiée</Chip> : null}
                </div>
                <div className="muted small">
                  {xp.institutionName}
                  {xp.city ? ` · ${xp.city}` : ''}
                </div>
                <div className="faint micro">
                  {xp.startYear} – {xp.endYear ?? 'aujourd’hui'}
                </div>
              </Card>
            ))}
          </section>
        ) : null}

        {profile.certifications.length > 0 ? (
          <section className="stack stack--tight">
            <h2 className="section-title">Tests réussis</h2>
            {profile.certifications.map((cert) => (
              <div
                className="row row--between small"
                key={`${cert.subject.id}-${cert.level.id}`}
              >
                <span>
                  {cert.subject.name} — {cert.level.name}
                </span>
                <Chip tone="success">{cert.score} %</Chip>
              </div>
            ))}
          </section>
        ) : null}
        </div>
      </div>
    </>
  )
}

/**
 * Les cours a domicile proposes par ce professeur.
 *
 * C'est la premiere chose qu'une famille vient chercher, et c'etait absent de
 * la fiche : on voyait un professeur de mathematiques sans savoir s'il se
 * deplace, ou, ni a quel tarif. Les offres actives sont publiques cote serveur
 * depuis le debut (migration 0002) — la donnee etait la, l'ecran pour la lire
 * manquait.
 *
 * Le tarif s'affiche. Le cacher obligerait a ecrire pour le demander, ce qui
 * est exactement le geste qu'on ne veut pas imposer avant d'avoir choisi.
 *
 * Rien ne s'affiche quand il n'y a aucune offre : une section vide intitulee
 * « Cours a domicile » laisse croire que le professeur refuse de se deplacer.
 */
function TutoringOffers({ teacherId }: { teacherId: string }) {
  const state = useAsync(() => api.tutoringOffers(teacherId), [teacherId])
  const offres = state.data ?? []

  if (state.loading) return <Skeleton height={80} count={1} />
  if (offres.length === 0) return null

  return (
    <section className="stack stack--tight">
      <h2 className="section-title">Cours à domicile</h2>
      {offres.map((offre) => (
        <Card key={offre.id}>
          <div className="stack stack--tight">
            <div className="row row--between">
              <strong className="small">{offre.subject.name}</strong>
              {offre.hourlyRate ? (
                <Chip tone="accent">{money(offre.hourlyRate)} / h</Chip>
              ) : null}
            </div>

            <div className="row" style={{ gap: 'var(--espace-2)', flexWrap: 'wrap' }}>
              <Chip>{tutoringModeLabel(offre.mode)}</Chip>
              {offre.levels.length > 0 ? (
                <Chip>{offre.levels.map((l) => l.name).join(' · ')}</Chip>
              ) : null}
            </div>

            {/* Les quartiers decident si le professeur peut venir : c'est
                l'information la plus concrete de la fiche pour une famille de
                Conakry. */}
            {offre.districts.length > 0 ? (
              <div className="row small faint" style={{ gap: 'var(--espace-2)' }}>
                <Icon name="place" size={14} />
                {offre.districts.join(', ')}
              </div>
            ) : null}

            {offre.availabilityNote ? (
              <div className="row small faint" style={{ gap: 'var(--espace-2)' }}>
                <Icon name="clock" size={14} />
                {offre.availabilityNote}
              </div>
            ) : null}

            {offre.description ? (
              <p className="muted small">{offre.description}</p>
            ) : null}
          </div>
        </Card>
      ))}
    </section>
  )
}

const tutoringModeLabel = (mode: string): string =>
  ({
    AT_STUDENT: 'Se déplace chez l’élève',
    AT_TEACHER: 'Chez le professeur',
    ONLINE: 'En ligne',
  })[mode] ?? 'À convenir'
