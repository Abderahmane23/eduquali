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
 * Le surlignage : deux ou trois mots, ceux qu'il faut retenir.
 *
 * --- Le premier signe de la marque -------------------------------------
 *
 * « Dans un cahier, on surligne ce qu'il faut retenir. » Pour le parent, ce
 * sont les minutes où son enfant était là ; pour l'élève, sa place ; pour le
 * professeur, sa part.
 *
 * **Un seul passage par phrase, un seul par écran.** Ne pas surligner un
 * bouton, un titre entier, un paragraphe, un prix : un surlignage partout ne
 * dit plus rien. C'est la règle qui fait tenir le signe, et c'est aussi la
 * plus facile à enfreindre sans le voir.
 */
export function Surlignage({
  children,
  anime,
}: {
  children: ReactNode
  /** Se trace de gauche à droite en 300 ms, quand une preuve s'ouvre. */
  anime?: boolean
}) {
  return (
    <span className={`surlignage${anime ? ' surlignage--anime' : ''}`}>
      {children}
    </span>
  )
}

/**
 * Une affiche : une phrase courte dont un mot est surligné.
 *
 * Remplace l'ancien titre à deux tons, qui posait un mot en jaune sur un
 * dégradé. Même intention — faire lire un titre de trois lignes en entier —
 * et le geste de la marque à la place de l'effet.
 */
export function Affiche({
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
    <Tag className="affiche">
      {before}
      <Surlignage>{accented}</Surlignage>
      {after}
    </Tag>
  )
}

/**
 * L'annotation du cahier : un mot ou deux.
 *
 * « Présent ! », « Vu », « Bravo ». Jamais une phrase, jamais un bouton, une
 * seule fois par écran. C'est la troisième police, et elle ne sert qu'à ça.
 */
export function Annotation({
  children,
  rouge,
}: {
  children: ReactNode
  rouge?: boolean
}) {
  return (
    <span className={`annotation${rouge ? ' annotation--rouge' : ''}`}>
      {children}
    </span>
  )
}

/**
 * La classe de quinze.
 *
 * Quinze places, trois rangs de cinq. Jamais plus, jamais moins — c'est le
 * nombre que le produit promet, et le dessin le dit avant la phrase.
 *
 * `label` n'est pas facultatif : la charte exige une phrase à côté, et un
 * carré de couleur seul ne dit pas combien de places restent. Elle sert aussi
 * de description pour qui n'voit pas l'image.
 */
export function Quinze({
  prises,
  mienne,
  label,
  mini,
}: {
  /** Combien de places sont prises, de 0 à 15. */
  prises: number
  /** Le rang de votre place, de 1 à 15, si vous en avez une. */
  mienne?: number
  label: string
  mini?: boolean
}) {
  // Borné : une séance de seize places n'existe pas, et un tableau de seize
  // carrés casserait les trois rangs de cinq.
  const n = Math.max(0, Math.min(15, Math.round(prises)))

  return (
    <div
      className={`quinze${mini ? ' quinze--mini' : ''}`}
      role="img"
      aria-label={label}
    >
      {Array.from({ length: 15 }, (_, i) => {
        const rang = i + 1
        const classe =
          rang === mienne ? 'mienne' : rang <= n ? 'prise' : ''
        return <i key={rang} className={classe} />
      })}
    </div>
  )
}

/**
 * Une pastille de statut : une couleur, une forme et **un mot**.
 *
 * La couleur seule ne suffit jamais. C'est la règle de la charte, et c'est
 * aussi celle de l'accessibilité : un écran en plein soleil, un daltonien, un
 * téléphone en noir et blanc pour économiser la batterie.
 */
export function Statut({
  children,
  ton = 'attente',
  icon,
}: {
  children: ReactNode
  ton?: 'ok' | 'ko' | 'attente' | 'point'
  icon?: IconName
}) {
  return (
    <span className={`statut statut--${ton}`}>
      {icon ? <Icon name={icon} size={18} /> : null}
      {children}
    </span>
  )
}

/**
 * « En direct ».
 *
 * Le seul emploi de `rouge` en aplat. S'il est à l'écran, la caméra tourne —
 * il ne décore jamais.
 */
export function EnDirect() {
  return <span className="en-direct">En direct</span>
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
 * Le même montant, en abrégé : « 1,2 M », « 45 k ».
 *
 * --- Pourquoi deux formats ----------------------------------------------
 *
 * Une cellule de bandeau fait un tiers de sa largeur. Sur un écran de
 * 360 px, cela laisse environ 74 px de texte utile — et « 1 200 000 GNF » en
 * Poppins 22 gras en demande 140. Le chiffre débordait de sa cellule ou se
 * cassait sur trois lignes.
 *
 * Abréger n'est pas une concession à la petite taille : une cellule de
 * bandeau porte un ordre de grandeur, qu'on lit d'un coup d'œil pour savoir
 * où l'on en est. Le montant exact a sa place dans `.money`, qui a toute la
 * largeur, et dans les lignes d'historique, où il doit être vérifiable.
 *
 * Une virgule décimale, et une seule : « 1,25 M » demande de compter les
 * chiffres pour savoir ce qu'on lit.
 */
export function gnfCourt(amount: number): string {
  if (amount >= 1_000_000) {
    const millions = amount / 1_000_000
    // Pas de « 1,0 M » : au-dessus de dix millions la décimale n'apporte
    // plus rien, et en dessous un zéro décimal est du bruit.
    const texte =
      millions >= 10 || Number.isInteger(millions)
        ? String(Math.round(millions))
        : millions.toFixed(1).replace('.', ',')
    return `${texte} M`
  }
  if (amount >= 10_000) return `${Math.round(amount / 1000)} k`
  return amount.toLocaleString('fr-FR')
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
