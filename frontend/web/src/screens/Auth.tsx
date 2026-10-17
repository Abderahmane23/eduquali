import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Button, Field, TextInput } from '../components/ui'
import {
  Affiche,
  BigButton,
  RowItem,
  SegmentedToggle,
  Tile,
} from '../components/kit'
import { useSession } from '../app/session'

/**
 * Accueil non connecté (§55, écrans 1 à 3).
 *
 * --- Ce qui a changé le 11/10 --------------------------------------------
 *
 * La page était un bloc bleu posé dans une page blanche, suivi d'une boîte de
 * recherche, de deux portes et de trois liens. Trois défauts, dans l'ordre de
 * ce qu'ils coûtaient :
 *
 *   * **sur un téléphone**, le fond blanc reprenait sous le bloc bleu à une
 *     hauteur qui ne correspondait à rien, et la page se terminait sur un
 *     vide. L'écran du téléphone (`landing_screen.dart`) occupe tout l'écran
 *     d'un seul bleu, et c'est ce qui lui donne son assise ;
 *   * **sur un ordinateur**, la promesse et l'action étaient côte à côte mais
 *     le dégradé débordait d'un seul côté, ce qui faisait lire la page comme
 *     deux pages collées ;
 *   * **le premier geste n'était pas qualifié.** « Cherchez une matière »
 *     mélangeait deux besoins qui n'ont pas les mêmes résultats : une famille
 *     cherche quelqu'un qui se déplace le soir, une école cherche quelqu'un à
 *     recruter. La bascule du téléphone posait la question ; le site non.
 *
 * --- La promesse, et pourquoi elle est formulée ainsi --------------------
 *
 * Le titre s'arrête sur « pour » : la phrase se termine dans la boîte juste
 * en dessous, où l'on choisit entre « Cours à domicile » et « Embauche ». Le
 * premier geste devient la fin de la phrase, et il n'y a donc rien à lire
 * avant d'agir.
 *
 * La preuve porte sur le **mécanisme** — identité, diplôme et compétence
 * vérifiés un par un — et non sur une adjectivation (« les meilleurs
 * enseignants ») qu'un concurrent recopierait telle quelle. Les chiffres de
 * traction restent volontairement absents tant qu'ils ne sont pas mesurés :
 * une preuve inventée se retourne contre celui qui l'affiche.
 */
export function Landing() {
  const navigate = useNavigate()
  const [query, setQuery] = useState('')

  /** 0 = cours à domicile, 1 = embauche. Le même ordre que sur le téléphone. */
  const [mode, setMode] = useState(0)

  const search = (preset?: string) => {
    const q = (preset ?? query).trim()
    const params = new URLSearchParams()
    if (q) params.set('q', q)
    params.set('mode', mode === 0 ? 'domicile' : 'embauche')
    navigate(`/recherche?${params.toString()}`)
  }

  return (
    <>
      {/* Le dégradé tient toute la page, téléphone comme ordinateur. */}
      <div className="hero-page">
        <div className="hero-page__inner">
          <div className="hero-page__top">
            <span className="hero-page__brand">EduQuali</span>
            {/*
              Une seule porte en haut, et c'est celle du professeur : la page
              entière parle à qui cherche un professeur, donc celui qui *est*
              professeur doit pouvoir sortir de ce discours tout de suite.

              Elle mène à la connexion, pas à l'inscription : un professeur
              qui clique ici a presque toujours déjà un compte, et celui qui
              n'en a pas trouve « Créer mon profil » sur l'écran d'arrivée.
            */}
            <Link className="pill-ghost" to="/connexion">
              Espace professeur
            </Link>
          </div>

          <div className="hero-page__middle">
            <div className="stack">
              {/*
                Le slogan, entier.

                Le titre s'arrêtait sur « pour », et la phrase devait se
                terminer dans la boîte juste en dessous — « Cours à domicile »
                ou « Embauche ». Le procédé est joli et il ne tient pas : sur
                un téléphone, la boîte est à cent quarante points plus bas,
                dans une carte blanche, et « pour » seul en fin de ligne se
                lit comme une phrase coupée.

                Un seul mot surligné, et c'est « professeur » : c'est lui que
                le produit promet.
              */}
              <Affiche
                before="Trouvez le "
                accented="professeur"
                after=" qu’il vous faut."
              />
              <p
                className="small"
                style={{ color: 'rgba(255, 255, 255, 0.82)', maxWidth: '44ch' }}
              >
                Chaque profil est vérifié pièce par pièce : identité, diplôme,
                puis un test de compétence sur le programme guinéen. Vous voyez
                ce qui a été contrôlé avant d’appeler qui que ce soit.
              </p>
            </div>

            {/* La boîte de première action : ce qu'on peut faire sans compte. */}
            <section className="sheet">
              <form
                className="stack"
                onSubmit={(event) => {
                  event.preventDefault()
                  search()
                }}
              >
                <SegmentedToggle
                  label="Ce que vous cherchez"
                  labels={['Cours à domicile', 'Embauche']}
                  selected={mode}
                  onSelect={setMode}
                />

                <Field
                  label={
                    mode === 0
                      ? 'Quelle matière pour votre enfant ?'
                      : 'Quelle matière enseignez-vous… ou cherchez-vous ?'
                  }
                >
                  <TextInput
                    type="search"
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder="Maths, physique, anglais…"
                  />
                </Field>

                <div className="action-card__suggestions">
                  {['Mathématiques', 'Physique', 'Anglais', 'Français'].map(
                    (name) => (
                      <button
                        key={name}
                        type="button"
                        className="chip chip--action"
                        onClick={() => search(name)}
                      >
                        {name}
                      </button>
                    ),
                  )}
                </div>

                <BigButton type="submit" icon="search">
                  Chercher
                </BigButton>

                <p className="micro faint centered">
                  Aucun compte nécessaire pour regarder.
                </p>
              </form>
            </section>
          </div>

          {/* Les deux portes du compte, en bas, décollées du bord : sur le
              bleu elles se lisent comme des boutons, pas comme du texte posé
              sur le fond. */}
          <div className="hero-page__bottom pill-row">
            <Link className="pill-solid" to="/inscription">
              Créer mon compte
            </Link>
            <Link className="pill-outline" to="/connexion">
              Me connecter
            </Link>
          </div>
        </div>
      </div>

      {/* Ce qui suit se lit en défilant, donc sur du blanc : trois paragraphes
          en blanc sur bleu demanderaient un contraste que le dégradé ne tient
          pas en corps de texte. */}
      <div className="screen stack stack--loose">
        <section className="stack">
          <h2>Ce que « vérifié » veut dire ici</h2>
          <div className="stack grid-cards">
            <div className="card">
              <div className="stack stack--tight">
                <Tile icon="shield" />
                <strong>Identité contrôlée</strong>
                <span className="muted small">
                  Pièce d’identité et photo, comparées l’une à l’autre. Un
                  profil sans ce contrôle le dit sur sa fiche.
                </span>
              </div>
            </div>
            <div className="card">
              <div className="stack stack--tight">
                <Tile icon="diploma" tone="success" />
                <strong>Diplôme vu et lu</strong>
                <span className="muted small">
                  Le document est déposé, puis relu par quelqu’un. Ce n’est pas
                  une case que le professeur coche lui-même.
                </span>
              </div>
            </div>
            <div className="card">
              <div className="stack stack--tight">
                <Tile icon="check" tone="warning" />
                <strong>Compétence testée</strong>
                <span className="muted small">
                  Un test sur le programme guinéen, matière par matière et
                  niveau par niveau. La note est sur la fiche.
                </span>
              </div>
            </div>
          </div>
        </section>

        <section className="stack">
          <h2>Vous venez pour autre chose ?</h2>
          <div className="stack grid-cards">
            <RowItem
              icon="user"
              title="Je suis professeur"
              sub="Créez votre profil, passez le test, recevez des offres"
              onClick={() => navigate('/inscription/enseignant')}
            />
            <RowItem
              icon="briefcase"
              tone="neutral"
              title="Je représente une école"
              sub="Publiez un poste et recevez des candidatures vérifiées"
              onClick={() => navigate('/inscription/etablissement')}
            />
            <RowItem
              icon="home"
              tone="neutral"
              title="Je suis parent ou élève"
              sub="Cours à domicile, cours en direct, cours vidéo"
              onClick={() => navigate('/inscription/parent')}
            />
          </div>
        </section>

        {/* Les listes publiques, atteignables depuis l'accueil : « aucun
            compte nécessaire pour regarder » doit se vérifier d'un clic, pas
            seulement se lire. */}
        <nav
          className="row centered"
          style={{ gap: 'var(--espace-4)', flexWrap: 'wrap' }}
          aria-label="Listes publiques"
        >
          <Link to="/professeurs">Professeurs</Link>
          <Link to="/direct">Cours en direct</Link>
          <Link to="/cours">Cours vidéo</Link>
          <Link to="/etablissements">Écoles</Link>
          <Link to="/tests">Tests de certification</Link>
        </nav>
      </div>
    </>
  )
}

export function Login() {
  const { login } = useSession()
  const navigate = useNavigate()
  // Aucun identifiant pre-rempli : les valeurs de demonstration partaient
  // jusqu'ici dans le bundle de production.
  const [phone, setPhone] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string>()
  const [busy, setBusy] = useState(false)

  const submit = async (event: React.FormEvent) => {
    event.preventDefault()
    setBusy(true)
    setError(undefined)
    try {
      await login(phone, password)
      navigate('/offres', { replace: true })
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : 'Numéro ou mot de passe incorrect. Réessayez.',
      )
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="screen stack stack--loose" onSubmit={submit}>
      <h1 className="page-title">Connexion</h1>

      <Field
        label="Numéro de téléphone"
        hint="9 chiffres, sans l’indicatif. Exemple : 620 00 01 01"
      >
        <TextInput
          type="tel"
          inputMode="tel"
          autoComplete="tel-national"
          maxLength={14}
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
        />
      </Field>

      <Field label="Mot de passe" error={error}>
        <TextInput
          type="password"
          autoComplete="current-password"
          maxLength={128}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
      </Field>

      <Button type="submit" block disabled={busy}>
        {busy ? 'Connexion…' : 'Me connecter'}
      </Button>

      <p className="muted small centered">
        Pas encore de compte ?{' '}
        <Link to="/inscription">Créer mon profil vérifié</Link>
      </p>
    </form>
  )
}
