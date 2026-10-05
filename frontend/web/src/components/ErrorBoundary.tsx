import { Component, type ErrorInfo, type ReactNode } from 'react'

/**
 * Filet de securite autour des routes (§5 du code_skill).
 *
 * Sans lui, une exception dans un ecran laisse une page blanche : l'incident
 * devient invisible pour l'utilisateur et pour nous. Ici l'utilisateur garde
 * une issue, et la trace part dans la console — jamais a l'ecran, elle
 * revelerait la structure de l'application.
 */
interface Props {
  children: ReactNode
}

interface State {
  failed: boolean
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { failed: false }

  static getDerivedStateFromError(): State {
    return { failed: true }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    // Point unique de remontee : brancher ici le collecteur d'erreurs.
    console.error('[veriprof]', error, info.componentStack)
  }

  render() {
    if (!this.state.failed) return this.props.children

    return (
      <div className="screen stack stack--loose" role="alert">
        <h1 className="page-title">Cet écran n’a pas pu s’afficher</h1>
        <p className="page-lede">
          Rien n’est perdu : vos réponses et vos candidatures sont enregistrées.
          Rechargez la page pour reprendre où vous en étiez.
        </p>
        <button
          className="btn btn--primary btn--block"
          onClick={() => window.location.reload()}
        >
          Recharger la page
        </button>
        <a className="btn btn--ghost btn--block" href="/">
          Revenir à l’accueil
        </a>
      </div>
    )
  }
}
