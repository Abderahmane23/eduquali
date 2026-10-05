import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Button, Field, Icon, TextInput } from '../components/ui'
import { useSession } from '../app/session'

/**
 * Accueil non connecte (§55, ecrans 1 a 3).
 *
 * Une page = une promesse = une action principale. La promesse porte sur le
 * mecanisme — trois preuves controlees — et non sur une adjectivation
 * ("meilleurs enseignants") qu'un concurrent pourrait recopier telle quelle.
 *
 * Les chiffres de traction (nombre d'enseignants, d'établissements) sont
 * volontairement absents tant qu'ils ne sont pas mesurés : une preuve
 * inventée se retourne contre celui qui l'affiche.
 */
export function Landing() {
  const navigate = useNavigate()
  const [query, setQuery] = useState('')

  const search = (preset?: string) => {
    const q = (preset ?? query).trim()
    navigate(q ? `/recherche?q=${encodeURIComponent(q)}` : '/recherche')
  }

  return (
    // `landing` ne sert qu'au grand ecran : a partir de 1024 px, la promesse
    // et la boite de recherche se placent cote a cote. Le telephone ne voit
    // pas cette classe agir — tout ce qui s'y rattache vit dans une requete
    // `min-width`.
    <div className="screen landing">
      <header className="hero">
        <h1 className="hero__title">
          Trouvez le <span className="hero__accent">professeur</span>
          <br />
          qu’il vous faut
        </h1>
        <p className="hero__lede">
          Écoles, universités et cours à domicile, partout en Guinée.
        </p>
      </header>

      {/* La boite de premiere action. On cherche sans compte ; le compte
          n'est reclame qu'au moment de contacter quelqu'un, parce que c'est
          le premier geste qui engage une autre personne. */}
      <section className="action-card">
        <form
          className="stack stack--tight"
          onSubmit={(event) => {
            event.preventDefault()
            search()
          }}
        >
          <Field label="Quelle matière cherchez-vous ?">
            <TextInput
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Maths, physique, anglais…"
            />
          </Field>

          <div className="action-card__suggestions">
            {['Mathématiques', 'Physique', 'Anglais'].map((name) => (
              <button
                key={name}
                type="button"
                className="chip chip--action"
                onClick={() => search(name)}
              >
                {name}
              </button>
            ))}
          </div>

          <Button block type="submit">
            Chercher
          </Button>
          <p className="micro faint centered">
            Aucun compte nécessaire pour regarder.
          </p>
        </form>
      </section>

      <div className="doors">
        <button
          type="button"
          className="door"
          onClick={() => navigate('/inscription?role=TEACHER')}
        >
          <Icon name="user" />
          <span>
            <span className="door__title">Je suis professeur</span>
            <br />
            <span className="door__sub">
              Créez votre profil et recevez des offres
            </span>
          </span>
        </button>

        <button
          type="button"
          className="door"
          onClick={() => navigate('/inscription?role=INSTITUTION')}
        >
          <Icon name="briefcase" />
          <span>
            <span className="door__title">Je représente une école</span>
            <br />
            <span className="door__sub">
              Publiez un poste et recevez des candidatures
            </span>
          </span>
        </button>
      </div>

      {/* Les trois listes publiques, atteignables depuis l'accueil : « aucun
          compte necessaire pour regarder » doit se verifier d'un clic, pas
          seulement se lire. */}
      <nav className="row centered" style={{ gap: 'var(--s-4)', flexWrap: 'wrap' }}>
        <Link to="/cours">Cours vidéo</Link>
        <Link to="/etablissements">Écoles</Link>
        <Link to="/tests">Tests de certification</Link>
      </nav>

      <p className="centered" style={{ marginTop: 'var(--s-5)' }}>
        <span className="faint">Vous avez déjà un compte ? </span>
        <Link to="/connexion">Se connecter</Link>
      </p>

    </div>
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
