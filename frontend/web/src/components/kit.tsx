import type { ReactNode } from 'react'
import { Icon, type IconName } from './ui'

/*
 * Les formes de l'application, portées sur le site (11/10).
 *
 * `ui.tsx` tient les primitives communes aux deux — carte, bouton, champ,
 * pastille. Ce fichier-ci tient celles qui viennent des maquettes de
 * référence et des écrans Flutter : en-tête en dégradé, bandeau de chiffres,
 * tuile d'icône teintée, bascule segmentée, titre à deux tons.
 *
 * Pourquoi un second fichier plutôt que d'allonger le premier : `ui.tsx` est
 * importé par tous les écrans, y compris l'accueil, qui est le seul chargé
 * d'emblée. Ces composants-ci ne servent qu'aux écrans connectés, et le
 * découpage du bundle les laisse donc hors du premier téléchargement.
 */

/**
 * Un titre dont un seul mot est mis en avant.
 *
 * Le jaune ne sert qu'à cela : jamais un fond, jamais un statut. C'est le
 * seul procédé qui fasse lire un titre de trois lignes en entier, et il perd
 * tout son effet au deuxième emploi sur la même page.
 */
export function TwoToneTitle({
  before,
  accented,
  after,
  as: Tag = 'h1',
}: {
  before?: string
  accented: string
  after?: string
  as?: 'h1' | 'h2' | 'p'
}) {
  return (
    <Tag className="two-tone">
      {before}
      <em>{accented}</em>
      {after}
    </Tag>
  )
}

/**
 * Une bascule à deux ou trois segments.
 *
 * Elle n'est pas une liste déroulante : les options sont peu nombreuses et
 * s'excluent, et les voir toutes épargne un geste. `aria-pressed` plutôt
 * qu'un groupe de boutons radio — ce sont des boutons qui agissent
 * immédiatement, pas un champ qu'on valide.
 */
export function SegmentedToggle({
  labels,
  selected,
  onSelect,
  label,
}: {
  labels: string[]
  selected: number
  onSelect: (index: number) => void
  /** Ce que la bascule choisit, pour un lecteur d'écran. */
  label: string
}) {
  return (
    <div className="segmented" role="group" aria-label={label}>
      {labels.map((texte, index) => (
        <button
          key={texte}
          type="button"
          className="segmented__item"
          aria-pressed={index === selected}
          onClick={() => onSelect(index)}
        >
          {texte}
        </button>
      ))}
    </div>
  )
}

/** Un carré de couleur très claire portant une icône de la couleur pleine. */
export function Tile({
  icon,
  tone = 'accent',
  size = 22,
}: {
  icon: IconName
  tone?: 'accent' | 'success' | 'warning' | 'danger' | 'neutral'
  size?: number
}) {
  const suffixe = tone === 'accent' ? '' : ` tile--${tone}`
  return (
    <span className={`tile${suffixe}`} aria-hidden="true">
      <Icon name={icon} size={size} />
    </span>
  )
}

/** Une mesure du bandeau de chiffres. */
export interface Stat {
  value: ReactNode
  label: string
}

/**
 * Le bandeau de chiffres.
 *
 * Séparé par un filet et non découpé en cartes : des cartes feraient quatre
 * objets à comparer, alors qu'il s'agit d'une seule ligne de lecture.
 *
 * `plain` le pose sur du blanc au lieu du dégradé — même composant, parce que
 * deux façons de dessiner la même bande finiraient par diverger.
 */
export function StatStrip({
  stats,
  plain,
}: {
  stats: Stat[]
  plain?: boolean
}) {
  return (
    <div className={`statstrip${plain ? ' statstrip--plain' : ''}`}>
      {stats.map((stat) => (
        <div className="statstrip__cell" key={stat.label}>
          <span className="statstrip__value">{stat.value}</span>
          <span className="statstrip__label">{stat.label}</span>
        </div>
      ))}
    </div>
  )
}

/**
 * L'en-tête d'une page connectée : dégradé, titre, sous-titre, chiffres.
 *
 * Elle remplace `AppBar` sur les pages qui ont quelque chose à annoncer. Un
 * tableau de bord doit dire « voici où vous en êtes » avant « voici quoi
 * faire », et une barre de titre de 44 px n'a pas la place de le dire.
 */
export function PageHead({
  title,
  lede,
  stats,
  action,
}: {
  title: string
  lede?: string
  stats?: Stat[]
  action?: ReactNode
}) {
  // En deux colonnes dès qu'il y a des chiffres à poser à côté du titre.
  const split = stats && stats.length > 0 ? ' pagehead--split' : ''
  return (
    <header className={`pagehead${split}`}>
      <div className="stack stack--tight">
        <h1 className="pagehead__title">{title}</h1>
        {lede ? <p className="pagehead__lede">{lede}</p> : null}
        {action}
      </div>
      {stats && stats.length > 0 ? <StatStrip stats={stats} /> : null}
    </header>
  )
}

/**
 * Le bouton d'action majeur.
 *
 * Un seul par page : c'est ce qui lui donne son poids. Majuscules espacées et
 * pastille pleine, comme le « DÉMARRER UN COURS EN DIRECT » du téléphone.
 */
export function BigButton({
  children,
  onClick,
  icon,
  disabled,
  type = 'button',
}: {
  children: ReactNode
  onClick?: () => void
  icon?: IconName
  disabled?: boolean
  type?: 'button' | 'submit'
}) {
  return (
    <button
      type={type}
      className="bigbtn"
      onClick={onClick}
      disabled={disabled}
    >
      {icon ? <Icon name={icon} size={20} /> : null}
      {children}
    </button>
  )
}

/**
 * Une rangée : tuile, titre, sous-titre, et ce qui vient au bout.
 *
 * La forme de toutes les listes de l'application. Rendue comme un bouton
 * quand elle mène quelque part, comme une simple ligne sinon — un `div`
 * cliquable n'est pas atteignable au clavier.
 */
export function RowItem({
  icon,
  tone,
  title,
  sub,
  end,
  onClick,
}: {
  icon?: IconName
  tone?: 'accent' | 'success' | 'warning' | 'danger' | 'neutral'
  title: ReactNode
  sub?: ReactNode
  end?: ReactNode
  onClick?: () => void
}) {
  const contenu = (
    <>
      {icon ? <Tile icon={icon} tone={tone} /> : null}
      <span className="rowitem__body">
        <span className="rowitem__title">{title}</span>
        {sub ? <span className="rowitem__sub">{sub}</span> : null}
      </span>
      <span className="rowitem__end">
        {end}
        {onClick ? <Icon name="chevron" size={18} /> : null}
      </span>
    </>
  )

  return onClick ? (
    <button type="button" className="rowitem" onClick={onClick}>
      {contenu}
    </button>
  ) : (
    <div className="rowitem">{contenu}</div>
  )
}

/**
 * Un montant en francs guinéens.
 *
 * `fr-FR` sépare les milliers par une espace insécable fine, ce qui est la
 * convention en Guinée : « 1 200 000 GNF ». En chiffres de même chasse, pour
 * qu'un montant ne change pas de largeur en passant de 900 000 à 1 000 000.
 */
export function Money({ amount, unit = 'GNF' }: { amount: number; unit?: string }) {
  return (
    <span className="money">
      {amount.toLocaleString('fr-FR')}
      <span className="money__unit">{unit}</span>
    </span>
  )
}

/** Le même montant, en ligne dans une phrase. */
export function gnf(amount: number): string {
  return `${amount.toLocaleString('fr-FR')} GNF`
}

/**
 * Les étapes d'un formulaire long.
 *
 * Elles ne sont pas cliquables : on avance en remplissant. Les montrer sert à
 * dire combien il en reste — un formulaire de quatre écrans sans compteur se
 * lit comme un formulaire sans fin.
 */
export function Steps({
  labels,
  current,
}: {
  labels: string[]
  current: number
}) {
  return (
    <ol className="steps">
      {labels.map((texte, index) => (
        <li
          className="steps__item"
          key={texte}
          data-state={
            index === current ? 'current' : index < current ? 'done' : 'todo'
          }
          aria-current={index === current ? 'step' : undefined}
        >
          {index < current ? <Icon name="check" size={14} /> : null}
          {texte}
        </li>
      ))}
    </ol>
  )
}
