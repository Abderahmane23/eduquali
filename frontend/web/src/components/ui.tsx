import type { ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'

/** Primitives d'interface, alignees sur les composants du mobile. */

export function AppBar({
  title,
  onBack,
  action,
}: {
  title: string
  onBack?: boolean | (() => void)
  action?: ReactNode
}) {
  const navigate = useNavigate()
  const handleBack =
    typeof onBack === 'function' ? onBack : () => navigate(-1)

  return (
    <header className="appbar">
      {onBack ? (
        <button className="iconbtn" onClick={handleBack} aria-label="Retour">
          <Icon name="back" />
        </button>
      ) : null}
      <span className="appbar__title">{title}</span>
      <div className="spacer" />
      {action}
    </header>
  )
}

export function Card({
  children,
  onClick,
  accent,
}: {
  children: ReactNode
  onClick?: () => void
  accent?: boolean
}) {
  const className = `card${onClick ? ' card--tap' : ''}${accent ? ' card--accent' : ''}`
  return onClick ? (
    <button type="button" className={className} onClick={onClick}>
      {children}
    </button>
  ) : (
    <div className={className}>{children}</div>
  )
}

export function Button({
  children,
  onClick,
  variant = 'primary',
  block,
  disabled,
  type = 'button',
}: {
  children: ReactNode
  onClick?: () => void
  variant?: 'primary' | 'ghost' | 'quiet'
  block?: boolean
  disabled?: boolean
  type?: 'button' | 'submit'
}) {
  return (
    <button
      type={type}
      className={`btn btn--${variant}${block ? ' btn--block' : ''}`}
      onClick={onClick}
      disabled={disabled}
    >
      {children}
    </button>
  )
}

export function Chip({
  children,
  tone = 'neutral',
}: {
  children: ReactNode
  tone?: 'neutral' | 'success' | 'warning' | 'danger' | 'accent'
}) {
  return (
    <span className={`chip${tone === 'neutral' ? '' : ` chip--${tone}`}`}>
      {children}
    </span>
  )
}

export function Field({
  label,
  hint,
  error,
  children,
}: {
  label: string
  hint?: string
  error?: string
  children: ReactNode
}) {
  return (
    <label className="field">
      <span className="field__label">{label}</span>
      {children}
      {/* L'aide precede l'erreur : mieux vaut prevenir la saisie fautive.
          L'erreur est annoncee — une couleur seule ne porte pas
          l'information (§7 du design_skill). */}
      {error ? (
        <span className="field__error" role="alert">
          {error}
        </span>
      ) : hint ? (
        <span className="field__hint">{hint}</span>
      ) : null}
    </label>
  )
}

export function TextInput(
  props: React.InputHTMLAttributes<HTMLInputElement>,
) {
  return <input {...props} className="field__input" />
}

export function Select(
  props: React.SelectHTMLAttributes<HTMLSelectElement>,
) {
  return <select {...props} className="field__input" />
}

export function Progress({ value }: { value: number }) {
  const pct = Math.round(Math.min(1, Math.max(0, value)) * 100)
  return (
    <div
      className="progress"
      role="progressbar"
      aria-valuenow={pct}
      aria-valuemin={0}
      aria-valuemax={100}
    >
      <div className="progress__bar" style={{ width: `${pct}%` }} />
    </div>
  )
}

export function Avatar({
  first,
  last,
  src,
}: {
  first: string
  last: string
  src?: string
}) {
  if (src) return <img className="avatar" src={src} alt="" />
  const label = `${first.charAt(0)}${last.charAt(0)}`.toUpperCase()
  return (
    <span className="avatar" aria-hidden>
      {label}
    </span>
  )
}

export function EmptyState({
  icon = '—',
  title,
  message,
  action,
}: {
  icon?: string
  title: string
  message?: string
  action?: ReactNode
}) {
  return (
    <div className="empty stack">
      <div className="empty__icon" aria-hidden>
        {icon}
      </div>
      <h3>{title}</h3>
      {message ? <p className="muted small">{message}</p> : null}
      {action}
    </div>
  )
}

export function Banner({
  children,
  tone = 'neutral',
}: {
  children: ReactNode
  tone?: 'neutral' | 'accent' | 'warning'
}) {
  // Un avertissement est annonce au lecteur d'ecran : sans `role`, il
  // apparaissait a l'ecran sans jamais etre lu.
  const alerting = tone === 'warning'
  return (
    <div
      className={`banner${tone === 'neutral' ? '' : ` banner--${tone}`}`}
      role={alerting ? 'alert' : undefined}
      aria-live={alerting ? 'polite' : undefined}
    >
      {children}
    </div>
  )
}

export function Skeleton({ height = 72, count = 3 }: { height?: number; count?: number }) {
  return (
    <div className="stack" aria-hidden>
      {Array.from({ length: count }, (_, i) => (
        <div key={i} className="skeleton" style={{ height }} />
      ))}
    </div>
  )
}

/**
 * Icones : traits epais et silhouette pleine, reconnues plus vite que des
 * contours fins aux petites tailles.
 */
export function Icon({ name, size = 20 }: { name: IconName; size?: number }) {
  const paths: Record<IconName, ReactNode> = {
    back: <path d="M15 5l-7 7 7 7" />,
    search: (
      <>
        <circle cx="11" cy="11" r="7" />
        <path d="M20 20l-3.5-3.5" />
      </>
    ),
    home: <path d="M4 11l8-7 8 7v8a1 1 0 01-1 1h-4v-6h-6v6H5a1 1 0 01-1-1z" />,
    briefcase: (
      <>
        <rect x="3" y="8" width="18" height="12" rx="2" />
        <path d="M9 8V6a2 2 0 012-2h2a2 2 0 012 2v2" />
      </>
    ),
    user: (
      <>
        <circle cx="12" cy="8" r="4" />
        <path d="M4 20c0-4 3.6-6 8-6s8 2 8 6" />
      </>
    ),
    check: <path d="M5 12l5 5 9-10" />,
    clipboard: (
      <>
        <rect x="5" y="4" width="14" height="17" rx="2" />
        <path d="M9 4h6v3H9z" />
      </>
    ),
    place: (
      <>
        <path d="M12 21s7-6.3 7-11a7 7 0 10-14 0c0 4.7 7 11 7 11z" />
        <circle cx="12" cy="10" r="2.5" />
      </>
    ),
    clock: (
      <>
        <circle cx="12" cy="12" r="8" />
        <path d="M12 8v4l3 2" />
      </>
    ),
    shield: <path d="M12 3l7 3v6c0 4-3 7-7 9-4-2-7-5-7-9V6z" />,
    diploma: (
      <>
        <path d="M3 8l9-4 9 4-9 4-9-4z" />
        <path d="M7 10.2V15c0 1.7 2.2 3 5 3s5-1.3 5-3v-4.8" />
        <path d="M21 8v5" />
      </>
    ),
    play: (
      <>
        <circle cx="12" cy="12" r="9" />
        <path d="M10 8.5l6 3.5-6 3.5z" />
      </>
    ),
    file: (
      <>
        <path d="M14 3H7a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2V8z" />
        <path d="M14 3v5h5" />
      </>
    ),
  }

  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      {paths[name]}
    </svg>
  )
}

export type IconName =
  | 'back'
  | 'search'
  | 'home'
  | 'briefcase'
  | 'user'
  | 'check'
  | 'clipboard'
  | 'place'
  | 'clock'
  | 'shield'
  | 'diploma'
  | 'play'
  | 'file'
