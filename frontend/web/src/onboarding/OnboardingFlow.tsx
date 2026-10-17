import { useCallback, useMemo, useState } from 'react'
import { api } from '../api'
import {
  Button,
  Field,
  Icon,
  Progress,
  Skeleton,
  TextInput,
  type IconName,
} from '../components/ui'
import { useAsync } from '../lib/useAsync'
import { matchesSearch } from '../lib/textSearch'
import {
  canContinue,
  collectsAnswer,
  dependentFields,
  describeEstimate,
  filterOptions,
  loadFilieres,
  loadStages,
  loadFlow,
  loadGeography,
  visibleSteps,
  type Answers,
  type FlowName,
  type Option,
  type Step,
} from './spec'

/**
 * Rendu d'un parcours decrit en JSON.
 *
 * Le composant ne connait aucune question : il parcourt la description et
 * delegue au rendu correspondant au type d'ecran. C'est le pendant exact du
 * moteur Flutter — les deux consomment le meme fichier.
 */
export function OnboardingFlow({
  flow: name,
  initialAnswers,
  onDone,
  onBackOut,
}: {
  flow: FlowName
  /** Reponses deja collectees par un parcours precedent (l'intro). */
  initialAnswers?: Answers
  onDone: (answers: Answers) => void
  /** Appele quand l'utilisateur revient en arriere depuis le premier ecran. */
  onBackOut?: () => void
}) {
  const flow = useAsync(() => loadFlow(name), [name])
  const [index, setIndex] = useState(0)
  const [answers, setAnswers] = useState<Answers>(initialAnswers ?? {})

  // Les etapes conditionnelles entrent et sortent du parcours au fil des
  // reponses : le total affiche au compteur suit.
  const steps = useMemo(
    () => (flow.data ? visibleSteps(flow.data, answers) : []),
    [flow.data, answers],
  )

  const setAnswer = useCallback((key: string, value: unknown) => {
    setAnswers((prev) => ({ ...prev, [key]: value }))
  }, [])

  if (flow.loading) {
    return (
      <div className="screen">
        <Skeleton height={56} count={4} />
      </div>
    )
  }
  if (!flow.data || steps.length === 0) {
    return <div className="screen">Parcours indisponible.</div>
  }

  // Une reponse peut retirer des etapes : on ne sort jamais du tableau.
  const position = Math.min(index, steps.length - 1)
  const step = steps[position]
  const isLast = position === steps.length - 1
  const ready = canContinue(step, answers)

  const advance = () => {
    if (isLast) onDone(answers)
    else setIndex(position + 1)
  }

  return (
    <div className="flow">
      <div className="flow__head">
        {position > 0 || onBackOut ? (
          <button
            className="iconbtn"
            onClick={() =>
              position > 0 ? setIndex(position - 1) : onBackOut?.()
            }
            aria-label="Revenir à l’étape précédente"
          >
            <Icon name="back" />
          </button>
        ) : (
          <span style={{ width: 44 }} />
        )}
        <div style={{ flex: 1 }}>
          <Progress value={(position + 1) / steps.length} />
        </div>
        <span className="flow__counter">
          {position + 1}/{steps.length}
        </span>
      </div>

      <div className="flow__body">
        {/* L'illustration precede la question : elle pose la scene avant
            qu'on demande quoi que ce soit. */}
        {step.image ? <Illustration image={step.image} /> : null}
        <h1 className="flow__question">{step.title}</h1>
        {step.body ? <p className="flow__body-text">{step.body}</p> : null}
        <StepBody
          step={step}
          answers={answers}
          currency={flow.data.currency}
          setAnswer={setAnswer}
        />
      </div>

      {/* L'action principale reste toujours en bas a droite. */}
      <div className="flow__foot">
        {step.type === 'plan_select' ? (
          <Button
            variant="quiet"
            onClick={() => {
              setAnswer(step.fieldId!, step.declineValue)
              advance()
            }}
          >
            {step.declineLabel ?? 'Plus tard'}
          </Button>
        ) : step.optional && collectsAnswer(step.type) ? (
          <Button variant="quiet" onClick={advance}>
            Passer
          </Button>
        ) : null}

        <Button onClick={advance} disabled={!ready}>
          {step.cta ?? (isLast ? 'Terminer' : 'Continuer')}
          <Icon name="check" size={16} />
        </Button>
      </div>
    </div>
  )
}

/**
 * Illustration d'etape.
 *
 * Deux densites seulement : au-dela, le poids gagne ne compense plus la
 * requete supplementaire. Les fichiers sont generes a la hauteur d'affichage
 * (200 px, et 400 px pour les ecrans haute densite), largeur libre : les
 * illustrations n'ont pas toutes le meme cadrage et aucune n'est recadree.
 *
 * La hauteur est fixee par la feuille de style, donc la mise en page ne
 * saute pas pendant le chargement (CLS, §9 du design_skill).
 *
 * L'image porte son propre fond clair : les visuels sont dessines sur blanc
 * et flotteraient sur une surface sombre.
 */
function Illustration({ image }: { image: { name: string; alt: string } }) {
  return (
    <figure className="flow__illustration">
      <img
        src={`/img/${image.name}.webp`}
        srcSet={`/img/${image.name}.webp 1x, /img/${image.name}@2x.webp 2x`}
        alt={image.alt}
        loading="eager"
        decoding="async"
      />
    </figure>
  )
}

function StepBody({
  step,
  answers,
  currency,
  setAnswer,
}: {
  step: Step
  answers: Answers
  currency: string
  setAnswer: (key: string, value: unknown) => void
}) {
  switch (step.type) {
    case 'statement':
      return (
        <div>
          {(step.highlights ?? []).map((h) => (
            <div className="highlight" key={h.label}>
              {/* Le pictogramme accompagne le libelle, il ne le remplace
                  jamais : aucune information portee par la seule icone. */}
              {h.icon ? (
                <span className="highlight__icon">
                  <Icon name={h.icon as IconName} size={20} />
                </span>
              ) : null}
              <span className="highlight__value">{h.value}</span>
              <span className="highlight__label">{h.label}</span>
            </div>
          ))}
        </div>
      )

    case 'steps_preview':
      return (
        <div>
          {(step.items ?? []).map((item, i) => (
            <div className="numbered" key={item}>
              <span className="numbered__index">{i + 1}</span>
              <span>{item}</span>
            </div>
          ))}
        </div>
      )

    case 'carousel':
      return <FeaturedTeachers />

    /*
     * Choix du profil.
     *
     * Boutons empiles pleine largeur plutot qu'une liste d'etiquettes : c'est
     * la decision qui oriente tout le reste du parcours, elle merite la
     * hauteur d'un bouton et une phrase d'explication (§1 du design_skill —
     * une decision par ecran sur mobile).
     */
    case 'role_select':
      return (
        <div
          className="stack stack--tight"
          role="radiogroup"
          aria-label={step.title}
        >
          {(step.options ?? []).map((option) => {
            const selected = answers[step.fieldId!] === option.value
            return (
              <button
                key={option.value}
                type="button"
                className="rolebtn"
                role="radio"
                aria-checked={selected}
                onClick={() => setAnswer(step.fieldId!, option.value)}
              >
                <span className="rolebtn__label">{option.label}</span>
                {option.description ? (
                  <span className="rolebtn__hint">{option.description}</span>
                ) : null}
              </button>
            )
          })}
        </div>
      )

    case 'form':
      return (
        <div className="stack stack--loose">
          {(step.fields ?? []).map((field) => (
            <FormField
              key={field.id}
              field={field}
              value={answers[field.id]}
              answers={answers}
              // Le libelle du champ dont celui-ci depend : on dit quoi faire
              // plutot que de presenter une liste vide.
              filterLabel={
                (step.fields ?? []).find(
                  (f) => f.id === field.optionsFilter?.field,
                )?.label
              }
              onChange={(v) => {
                setAnswer(field.id, v)
                for (const id of dependentFields(field.id, step.fields ?? [])) {
                  setAnswer(id, undefined)
                }
              }}
            />
          ))}
        </div>
      )

    case 'single_choice':
      return <SingleChoice step={step} answers={answers} setAnswer={setAnswer} />

    case 'multi_choice':
      return (
        <MultiChoice step={step} answers={answers} setAnswer={setAnswer} />
      )

    case 'boolean':
      return (
        <div className="row" style={{ gap: 'var(--espace-3)' }}>
          {[true, false].map((option) => (
            <button
              key={String(option)}
              className="choice"
              aria-pressed={answers[step.fieldId!] === option}
              onClick={() => setAnswer(step.fieldId!, option)}
            >
              {option ? 'Oui' : 'Non'}
            </button>
          ))}
        </div>
      )

    case 'range': {
      const value =
        (answers[step.fieldId!] as number | undefined) ?? step.default ?? step.min ?? 0
      return (
        <div>
          <div className="row" style={{ alignItems: 'baseline' }}>
            <span
              style={{
                fontSize: '2.5rem',
                fontWeight: 700,
                color: 'var(--violette)',
                letterSpacing: '-0.02em',
              }}
            >
              {value}
            </span>
            <span className="muted">{step.unit}</span>
            <div className="spacer" />
            {step.estimate ? (
              <span className="faint small">
                {describeEstimate(step.estimate, value)}
              </span>
            ) : null}
          </div>
          <input
            type="range"
            min={step.min ?? 0}
            max={step.max ?? 100}
            step={step.step ?? 1}
            value={value}
            onChange={(e) => setAnswer(step.fieldId!, Number(e.target.value))}
            style={{ width: '100%', marginTop: 'var(--espace-4)' }}
            aria-label={step.title}
          />
        </div>
      )
    }

    case 'plan_select':
      return (
        <div className="stack stack--tight">
          {(step.plans ?? []).map((plan) => (
            <button
              key={plan.value}
              className="plan"
              aria-pressed={answers[step.fieldId!] === plan.value}
              onClick={() => setAnswer(step.fieldId!, plan.value)}
            >
              <span>
                <span className="row" style={{ gap: 'var(--espace-2)' }}>
                  <strong>{plan.name}</strong>
                  {plan.recommended ? <Chip>Conseillé</Chip> : null}
                </span>
                <span className="muted small">{plan.highlight}</span>
              </span>
              <span className="plan__price">
                {priceLabel(plan.price, currency)}
              </span>
            </button>
          ))}
        </div>
      )

    case 'upload':
      return <Uploads step={step} answers={answers} setAnswer={setAnswer} />

    case 'day_hours':
      return <DayHours step={step} answers={answers} setAnswer={setAnswer} />

    default:
      // Un type inconnu rendait `null` : l'ecran s'affichait vide et
      // « Continuer » passait. Il se voit desormais, et seulement en
      // developpement — en production, mieux vaut un ecran incomplet qu'un
      // parcours interrompu.
      if (import.meta.env.DEV) {
        throw new Error(
          `Type d’étape non rendu : « ${step.type} » (${step.id}). ` +
            'Ajouter son rendu ici et dans RENDERED_STEP_TYPES.',
        )
      }
      return null
  }
}

/**
 * Depot du CV et des diplomes.
 *
 * Le fichier est garde tel quel dans les reponses : c'est l'objet `File` que
 * l'envoi vers Supabase Storage reprendra. Rien ne part pour l'instant — le
 * stockage n'existe pas encore (roadmap_web 1.2) — et l'ecran ne pretend donc
 * pas le contraire : il dit « joint », jamais « verifie ».
 */
function Uploads({
  step,
  answers,
  setAnswer,
}: {
  step: Step
  answers: Answers
  setAnswer: (key: string, value: unknown) => void
}) {
  /** 8 Mo, comme sur le telephone : c'est la meme connexion. */
  const MAX_BYTES = 8 * 1024 * 1024
  const [refus, setRefus] = useState<Record<string, string>>({})

  return (
    <div className="stack stack--loose">
      {(step.uploads ?? []).map((slot) => {
        const fichier = answers[slot.id] as File | undefined
        const accept = (slot.accept ?? 'pdf,image')
          .split(',')
          .map((part) => (part.trim() === 'image' ? 'image/*' : '.' + part.trim()))
          .join(',')

        return (
          <div className="stack stack--tight" key={slot.id}>
            <label className="field__label" htmlFor={`upload-${slot.id}`}>
              {slot.label}
            </label>
            <input
              id={`upload-${slot.id}`}
              type="file"
              accept={accept}
              onChange={(e) => {
                const choisi = e.target.files?.[0]
                if (!choisi) return
                if (choisi.size > MAX_BYTES) {
                  // Dire la limite au moment du choix, et non apres une
                  // tentative d'envoi qui n'aboutira jamais sur une
                  // connexion guineenne.
                  const mo = (choisi.size / (1024 * 1024)).toFixed(1)
                  setRefus((r) => ({
                    ...r,
                    [slot.id]: `Ce fichier pèse ${mo} Mo, au-delà de la limite de 8 Mo.`,
                  }))
                  e.target.value = ''
                  return
                }
                setRefus((r) => ({ ...r, [slot.id]: '' }))
                setAnswer(slot.id, choisi)
              }}
            />
            {refus[slot.id] ? (
              <span className="small" role="alert" style={{ color: 'var(--rouge)' }}>
                {refus[slot.id]}
              </span>
            ) : fichier ? (
              <span className="muted small">{fichier.name} — joint</span>
            ) : null}
          </div>
        )
      })}
    </div>
  )
}

/** Les sept jours et les trois moments de la journee, comme sur le mobile. */
const JOURS = [
  { code: 'MON', label: 'Lundi' },
  { code: 'TUE', label: 'Mardi' },
  { code: 'WED', label: 'Mercredi' },
  { code: 'THU', label: 'Jeudi' },
  { code: 'FRI', label: 'Vendredi' },
  { code: 'SAT', label: 'Samedi' },
  { code: 'SUN', label: 'Dimanche' },
] as const

const MOMENTS = [
  { code: 'MORNING', label: 'Matin', hours: '8 h – 12 h' },
  { code: 'AFTERNOON', label: 'Après-midi', hours: '12 h – 18 h' },
  { code: 'EVENING', label: 'Soirée', hours: '18 h – 21 h' },
] as const

/**
 * Disponibilites : jours x moments.
 *
 * Cocher un jour le prend en entier, puis on retire les moments qui ne
 * conviennent pas. L'inverse — cocher un jour puis devoir choisir une heure —
 * laissait des jours coches sans creneau, que le parcours refusait sans dire
 * pourquoi. C'est la regle retenue cote mobile, et la forme stockee est la
 * meme : `{ MON: ['MORNING', ...], ... }`.
 */
function DayHours({
  step,
  answers,
  setAnswer,
}: {
  step: Step
  answers: Answers
  setAnswer: (key: string, value: unknown) => void
}) {
  const field = step.fieldId!
  const saved = (answers[field] ?? {}) as Record<string, string[]>
  const [ouvert, setOuvert] = useState<string | null>(null)

  const momentsDe = (jour: string): string[] => saved[jour] ?? []

  const ecrire = (suivant: Record<string, string[]>) => setAnswer(field, suivant)

  const basculerJour = (jour: string) => {
    const suivant = { ...saved }
    if (momentsDe(jour).length === 0) {
      suivant[jour] = MOMENTS.map((m) => m.code)
      setOuvert(jour)
    } else {
      delete suivant[jour]
    }
    ecrire(suivant)
  }

  const basculerMoment = (jour: string, moment: string) => {
    const courant = momentsDe(jour)
    const suivant = { ...saved }
    const restant = courant.includes(moment)
      ? courant.filter((m) => m !== moment)
      : [...courant, moment]
    // Un jour sans moment ne veut rien dire : on le retire plutot que de
    // garder une liste vide qui compterait comme une disponibilite.
    if (restant.length === 0) delete suivant[jour]
    else suivant[jour] = restant
    ecrire(suivant)
  }

  const choisis = Object.values(saved).filter((m) => m.length > 0).length
  const manquants = (step.minSelected ?? 0) - choisis

  return (
    <div className="stack stack--tight">
      {/* Ce qu'il reste a faire, ecrit avant la liste : « Continuer »
          desactive sans explication laissait chercher. */}
      {manquants > 0 ? (
        <p className="muted small">
          {manquants === 1
            ? 'Encore un jour à cocher.'
            : `Encore ${manquants} jours à cocher.`}
        </p>
      ) : null}

      {JOURS.map((jour) => {
        const moments = momentsDe(jour.code)
        const actif = moments.length > 0
        return (
          <div key={jour.code}>
            <button
              className="choice"
              aria-pressed={actif}
              aria-expanded={ouvert === jour.code}
              onClick={() =>
                actif && ouvert !== jour.code
                  ? setOuvert(jour.code)
                  : basculerJour(jour.code)
              }
            >
              <span>{jour.label}</span>
              <span className="muted small">
                {actif
                  ? MOMENTS.filter((m) => moments.includes(m.code))
                      .map((m) => m.label)
                      .join(', ')
                  : 'Non disponible'}
              </span>
            </button>

            {actif && ouvert === jour.code ? (
              <div className="row" style={{ gap: 'var(--espace-2)', flexWrap: 'wrap' }}>
                {MOMENTS.map((moment) => (
                  <button
                    key={moment.code}
                    className="choice choice--compact"
                    aria-pressed={moments.includes(moment.code)}
                    onClick={() => basculerMoment(jour.code, moment.code)}
                  >
                    <span>{moment.label}</span>
                    <span className="muted small">{moment.hours}</span>
                  </button>
                ))}
              </div>
            ) : null}
          </div>
        )
      })}
    </div>
  )
}

function Chip({ children }: { children: React.ReactNode }) {
  return <span className="chip chip--accent">{children}</span>
}

/**
 * Montant local : espace comme separateur de milliers, aucune decimale, la
 * devise apres le nombre. Le franc guineen n'a pas de subdivision en usage —
 * afficher « 50 000,00 GNF » signale un formulaire qui n'a pas ete pense ici.
 */
const priceLabel = (value: number, currency: string): string =>
  `${new Intl.NumberFormat('fr-FR').format(Math.round(value))} ${currency}`

/**
 * Choix unique.
 *
 * Accepte une liste ecrite dans le JSON comme une liste du referentiel :
 * `single_choice` ignorait `optionsSource`, si bien qu'une etape comme
 * « Il est en quelle classe ? » n'affichait aucune option et bloquait le
 * parcours.
 */
function SingleChoice({
  step,
  answers,
  setAnswer,
}: {
  step: Step
  answers: Answers
  setAnswer: (key: string, value: unknown) => void
}) {
  const inline = step.options ?? []
  const dynamic = useAsync(
    () => resolveOptions(step.optionsSource),
    [step.optionsSource],
  )
  const options = filterOptions(
    inline.length > 0 ? inline : (dynamic.data ?? []),
    step.optionsFilter,
    answers,
  )

  if (inline.length === 0 && dynamic.loading) {
    return <Skeleton height={56} count={4} />
  }

  return (
    <div className="stack stack--tight">
      {options.map((option) => {
        const selected = answers[step.fieldId!] === option.value
        return (
          <button
            key={option.value}
            className="choice"
            aria-pressed={selected}
            onClick={() => setAnswer(step.fieldId!, option.value)}
          >
            {option.label}
            {selected ? (
              <span className="choice__check">
                <Icon name="check" size={18} />
              </span>
            ) : null}
          </button>
        )
      })}
    </div>
  )
}

function MultiChoice({
  step,
  answers,
  setAnswer,
}: {
  step: Step
  answers: Answers
  setAnswer: (key: string, value: unknown) => void
}) {
  const inline = step.options ?? []
  const dynamic = useAsync(
    () => resolveOptions(step.optionsSource),
    [step.optionsSource],
  )
  // Le filtre s'applique apres resolution : la liste vient du referentiel,
  // la restriction vient d'une reponse deja donnee.
  const options = filterOptions(
    inline.length > 0 ? inline : (dynamic.data ?? []),
    step.optionsFilter,
    answers,
  )
  const selected = (answers[step.fieldId!] as string[]) ?? []
  const allValue = step.allOption?.value

  const toggle = (value: string) => {
    let next = [...selected]
    // « Toutes les matières » et une selection nominative s'excluent.
    if (allValue && value === allValue) {
      setAnswer(step.fieldId!, next.includes(allValue) ? [] : [allValue])
      return
    }
    if (allValue) next = next.filter((v) => v !== allValue)
    next = next.includes(value)
      ? next.filter((v) => v !== value)
      : [...next, value]
    setAnswer(step.fieldId!, next)
  }

  if (inline.length === 0 && dynamic.loading) {
    return <Skeleton height={44} count={2} />
  }

  // Liste longue : un champ a taper. Vingt-quatre etiquettes ne se lisent pas,
  // et on coche la premiere qui ressemble.
  if (step.searchable) {
    // Les options ecartees par `optionsFilter` restent accessibles : un
    // professeur peut enseigner une matiere hors des classes qu'il a
    // declarees, et la faire disparaitre l'obligerait a revenir en arriere.
    const toutes = inline.length > 0 ? inline : (dynamic.data ?? [])
    const pertinentes = new Set(options.map((o) => o.value))
    return (
      <TypeAheadTags
        options={[
          ...options,
          ...toutes
            .filter((o) => !pertinentes.has(o.value))
            .map((o) => ({ ...o, description: 'Hors des classes choisies' })),
        ]}
        selected={selected}
        hint={step.searchHint ?? 'Tapez pour chercher…'}
        onToggle={toggle}
      />
    )
  }

  return (
    <div className="tags">
      {step.allOption ? (
        <button
          className="tag"
          aria-pressed={selected.includes(step.allOption.value)}
          onClick={() => toggle(step.allOption!.value)}
        >
          {step.allOption.label}
        </button>
      ) : null}
      {options.map((option) => (
        <button
          key={option.value}
          className="tag"
          aria-pressed={selected.includes(option.value)}
          onClick={() => toggle(option.value)}
        >
          {option.label}
        </button>
      ))}
    </div>
  )
}

/**
 * Champ a taper, suggestions dessous, etiquettes retenues en bas.
 *
 * Meme comportement que `TypeAheadTags` cote mobile : comparaison sans accent
 * ni casse, et ce qui est deja choisi ne se repropose pas — le reproposer fait
 * croire qu'on ne l'a pas pris.
 */
function TypeAheadTags({
  options,
  selected,
  hint,
  onToggle,
  maxVisible = 6,
}: {
  options: Option[]
  selected: string[]
  hint: string
  onToggle: (value: string) => void
  maxVisible?: number
}) {
  const [saisie, setSaisie] = useState('')

  const suggestions = options
    .filter((o) => !selected.includes(o.value))
    .filter((o) => matchesSearch(o.label, saisie))
    .slice(0, maxVisible)

  const retenues = selected
    .map((value) => options.find((o) => o.value === value))
    .filter((o): o is Option => o != null)

  return (
    <div className="stack stack--tight">
      <label className="field">
        <span className="field__label">{hint}</span>
        <input
          type="text"
          value={saisie}
          placeholder={hint}
          onChange={(e) => setSaisie(e.target.value)}
          aria-label={hint}
        />
      </label>

      {saisie.trim() !== '' && suggestions.length === 0 ? (
        <p className="muted small">Aucune matière ne correspond</p>
      ) : null}

      {suggestions.length > 0 ? (
        <div className="stack stack--tight">
          {suggestions.map((option) => (
            <button
              key={option.value}
              className="choice"
              onClick={() => {
                onToggle(option.value)
                // Le champ se vide apres un choix : sinon la deuxieme matiere
                // se cherche a travers le texte de la premiere.
                setSaisie('')
              }}
            >
              <span>{option.label}</span>
              {option.description ? (
                <span className="muted small">{option.description}</span>
              ) : null}
            </button>
          ))}
        </div>
      ) : null}

      {retenues.length > 0 ? (
        <div className="tags">
          {retenues.map((option) => (
            <button
              key={option.value}
              className="tag"
              aria-pressed
              onClick={() => onToggle(option.value)}
              aria-label={`Retirer ${option.label}`}
            >
              {option.label} ×
            </button>
          ))}
        </div>
      ) : null}
    </div>
  )
}

/**
 * Mot de passe, avec un oeil pour reveler.
 *
 * Un seul champ et pas de confirmation : « retapez votre mot de passe » double
 * la saisie sur un clavier de telephone et fait echouer une inscription sur
 * deux. Pouvoir relire ce qu'on a tape rend le meme service pour un geste.
 *
 * La longueur manquante s'affiche pendant la saisie, et non apres l'envoi : a
 * ce moment-la le compte d'authentification existe deja, et le refus laisse un
 * numero pris sans compte utilisable.
 */
function PasswordField({
  field,
  value,
  onChange,
}: {
  field: import('./spec').Field
  value: string
  onChange: (value: string) => void
}) {
  const [visible, setVisible] = useState(false)
  const minimum = field.minLength ?? 8
  const manque = value !== '' && value.length < minimum

  return (
    <Field
      label={field.label}
      hint={manque ? undefined : field.hint}
      error={manque ? `Encore ${minimum - value.length} caractère(s).` : undefined}
    >
      <div className="row" style={{ gap: 'var(--espace-2)' }}>
        <TextInput
          type={visible ? 'text' : 'password'}
          // `new-password` dit au gestionnaire du navigateur d'en proposer un
          // plutot que de recopier un mot de passe existant.
          autoComplete="new-password"
          autoFocus={field.autofocus}
          maxLength={128}
          value={value}
          onChange={(e) => onChange(e.target.value)}
        />
        <button
          type="button"
          className="btn btn--ghost"
          aria-pressed={visible}
          onClick={() => setVisible((v) => !v)}
        >
          {visible ? 'Masquer' : 'Afficher'}
        </button>
      </div>
    </Field>
  )
}

function FormField({
  field,
  value,
  answers,
  filterLabel,
  onChange,
}: {
  field: import('./spec').Field
  value: unknown
  answers?: Answers
  filterLabel?: string
  onChange: (value: unknown) => void
}) {
  const dynamic = useAsync(
    () => resolveOptions(field.optionsSource),
    [field.optionsSource],
  )

  if (field.type === 'password') {
    return (
      <PasswordField
        field={field}
        value={typeof value === 'string' ? value : ''}
        onChange={onChange}
      />
    )
  }

  /*
   * Un `combo` se tape, un `dropdown` se choisit.
   *
   * Les deux etaient rendus par le meme `<select>` : `allowCustom` etait
   * ignore, et une famille dont l'ecole manquait de la liste n'avait aucun
   * recours — elle ne pouvait ni la taper, ni passer a l'etape suivante
   * avec le bon nom.
   *
   * Un `<input>` avec sa `<datalist>` fait les deux a la fois : on tape ce
   * qu'on veut, et le navigateur propose ce qu'il connait au fil de la
   * frappe. C'est natif, cela tient sur le Chrome d'un Android d'entree de
   * gamme, et cela ne coute aucune bibliotheque.
   */
  if (field.type === 'combo' && field.allowCustom) {
    const parent = field.optionsFilter?.field
    const waiting = parent != null && answers?.[parent] == null
    const options = waiting
      ? []
      : filterOptions(dynamic.data ?? [], field.optionsFilter, answers ?? {})
    const listeId = `liste-${field.id}`

    return (
      <label className="field">
        <span className="field__label">{field.label}</span>
        <input
          className="field__input"
          type="text"
          list={listeId}
          value={(value as string) ?? ''}
          placeholder="Tapez le nom, ou choisissez dans la liste"
          maxLength={160}
          autoComplete="off"
          onChange={(e) => onChange(e.target.value)}
        />
        <datalist id={listeId}>
          {options.map((option) => (
            <option key={option.value} value={option.label} />
          ))}
        </datalist>
        {field.hint ? (
          <span className="field__hint">{field.hint}</span>
        ) : null}
      </label>
    )
  }

  if (field.type === 'dropdown' || field.type === 'combo') {
    // Cascade : tant que la reponse dont ce champ depend manque, la liste
    // complete n'a aucun sens — les 13 communes de Conakry n'ont rien a
    // faire devant un professeur de Labe.
    const parent = field.optionsFilter?.field
    const waiting = parent != null && answers?.[parent] == null
    const options = waiting
      ? []
      : filterOptions(dynamic.data ?? [], field.optionsFilter, answers ?? {})

    return (
      <label className="field">
        <span className="field__label">{field.label}</span>
        <select
          className="field__input"
          value={(value as string) ?? ''}
          disabled={waiting}
          onChange={(e) => onChange(e.target.value)}
        >
          <option value="">Choisir…</option>
          {options.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </select>
        {waiting ? (
          <span className="field__hint">
            Choisissez d’abord : {filterLabel ?? 'la réponse précédente'}
          </span>
        ) : null}
      </label>
    )
  }

  if (field.type === 'month') {
    const now = new Date().getFullYear()
    return (
      <label className="field">
        <span className="field__label">{field.label}</span>
        <select
          className="field__input"
          value={(value as string) ?? ''}
          onChange={(e) => onChange(e.target.value || null)}
        >
          <option value="">{field.nullableLabel ?? 'Choisir…'}</option>
          {Array.from({ length: 40 }, (_, i) => now - i).map((year) => (
            <option key={year} value={String(year)}>
              {year}
            </option>
          ))}
        </select>
      </label>
    )
  }

  /*
   * L'indicatif guineen, visible et non modifiable.
   *
   * Le site se contentait d'un indice sous le champ (« 9 chiffres, sans
   * l'indicatif »), que personne ne lit avant de taper. L'application mobile,
   * elle, affiche « +224 » dans le champ depuis le debut (`prefixText`) : les
   * deux clients demandaient la meme chose de deux facons, et seule l'une des
   * deux se comprend sans explication.
   *
   * Non modifiable parce qu'il n'y a pas de choix a faire : la plateforme est
   * guineenne, et un champ editable inviterait a coller un numero complet, qu'il
   * faudrait ensuite deviner et nettoyer.
   */
  return (
    <label className="field">
      <span className="field__label">{field.label}</span>
      {field.type === 'phone' ? (
        <span className="field__phone">
          <span className="field__prefix" aria-hidden="true">
            +224
          </span>
          <input
            className="field__input"
            type="tel"
            inputMode="tel"
            autoComplete="tel-national"
            maxLength={12}
            aria-label={`${field.label} (indicatif +224)`}
            autoFocus={field.autofocus}
            value={(value as string) ?? ''}
            onChange={(e) => onChange(e.target.value)}
          />
        </span>
      ) : (
        <input
          className="field__input"
          type="text"
          autoFocus={field.autofocus}
          value={(value as string) ?? ''}
          onChange={(e) => onChange(e.target.value)}
        />
      )}
      {field.type === 'phone' ? (
        <span className="field__hint">9 chiffres : 6XX XX XX XX</span>
      ) : null}
    </label>
  )
}

/** Les listes evolutives viennent du referentiel, jamais du JSON (§8, §9). */
async function resolveOptions(source?: string): Promise<Option[]> {
  switch (source) {
    case 'subjects':
      return (await api.subjects()).map((s) => ({ value: s.id, label: s.name }))
    case 'levels':
      return (await api.levels()).map((l) => ({
        value: l.id,
        label: l.name,
        /*
         * `groups` au PLURIEL, et le cycle.
         *
         * Deux defauts se cumulaient ici, et le resultat etait un filtre qui ne
         * filtrait rien :
         *
         *   1. `filterOptions` ne lit que `groups`, et traite une option sans
         *      `groups` comme toujours acceptable. Le `group` au singulier pose
         *      ici n'etait donc lu par personne ;
         *   2. `category` ne distingue pas college de lycee — les deux valent
         *      « SECONDARY » — alors que le filtre compare a un cycle
         *      (« COLLEGE », « LYCEE »). Meme lu, il n'aurait rien apparie.
         *
         * Conséquence visible : « Vous enseignez a quel niveau ? » n'avait aucun
         * effet sur « Quelles classes ? ». Un professeur de primaire se voyait
         * proposer « Master 2 ». L'application mobile, elle, posait bien
         * `groups: l.cycles` depuis le debut : les deux clients avaient diverge.
         */
        groups: l.cycle ? [l.cycle] : [],
      }))
    case 'stages': {
      // L'identifiant d'un palier EST la valeur de `cycle` d'un niveau : le
      // filtre de l'etape suivante apparie donc sans table de correspondance.
      const stages = await loadStages()
      return stages.map((s) => ({
        value: s.id,
        label: s.name,
        description: s.note,
      }))
    }
    case 'institution_roles':
      return [
        { value: 'DIRECTOR', label: 'Directeur / Directrice' },
        { value: 'FOUNDER', label: 'Fondateur / Fondatrice' },
        { value: 'PEDAGOGY', label: 'Responsable pédagogique' },
        { value: 'ADMIN', label: 'Responsable administratif' },
        { value: 'HR', label: 'Responsable des ressources humaines' },
        { value: 'OTHER', label: 'Autre fonction' },
      ]
    case 'filieres': {
      // `groups` porte les classes concernees, pour ne proposer le profil
      // qu'a partir de la 12eme annee.
      const filieres = await loadFilieres()
      return filieres.map((f) => ({
        value: f.id,
        label: f.name,
        description: f.note,
        groups: f.levelIds,
      }))
    }
    case 'regions': {
      // La valeur enregistree est le code : les noms bougent moins que les
      // decoupages, mais un code ne bouge pas du tout.
      const regions = await loadGeography()
      return regions.map((r) => ({
        value: r.code,
        label: r.name,
        description:
          r.kind === 'SPECIALE'
            ? 'Region speciale, decoupee en communes'
            : undefined,
      }))
    }
    case 'prefectures': {
      // `groups` porte le code de la region : c'est lui que `optionsFilter`
      // compare a la reponse precedente.
      const regions = await loadGeography()
      return regions.flatMap((r) =>
        r.divisions.map((d) => ({
          value: d.name,
          label: d.name,
          description: d.recent ? 'Prefecture recente' : undefined,
          groups: [r.code],
        })),
      )
    }
    case 'cities':
      return (await api.cities()).map((c) => ({ value: c, label: c }))
    case 'countries':
      return [
        { value: 'GN', label: 'Guinee' },
        { value: 'SN', label: 'Senegal' },
        { value: 'ML', label: 'Mali' },
        { value: 'CI', label: 'Cote d’Ivoire' },
      ]
    case 'institutions': {
      /*
       * Les ecoles, et non les anciens employeurs des professeurs.
       *
       * Cette branche lisait `teacher_experiences` : elle ne proposait donc
       * que les ecoles ou un professeur **deja inscrit** avait travaille.
       * Dans un pays ou la plupart des ecoles n'ont pas encore de compte,
       * c'est une liste qui ne contient presque jamais celle qu'on cherche.
       *
       * La vue `ecoles_connues` rassemble les trois endroits ou un nom
       * existe : les comptes d'etablissement, les noms tapes par les
       * familles, et les experiences des professeurs. Un nom tape par une
       * famille apparait donc pour la suivante.
       */
      return api.ecolesConnues()
    }
    default:
      return []
  }
}

function FeaturedTeachers() {
  const state = useAsync(() => api.searchTeachers({}), [])
  if (state.loading) return <Skeleton height={88} count={3} />

  /*
   * Profils empiles, pas un carrousel.
   *
   * Le defilement horizontal cachait les profils suivants derriere un geste
   * que rien n'annonce, et le score en pourcentage promettait une precision
   * que ces profils de demonstration n'ont pas. Trois cartes visibles d'un
   * coup disent la meme chose sans rien cacher.
   */
  return (
    <div className="stack stack--tight">
      {(state.data ?? []).slice(0, 3).map(({ profile }) => (
        <div className="card card--compact" key={profile.id}>
          <div className="row">
            <span className="avatar">
              {profile.firstName.charAt(0)}
              {profile.lastName.charAt(0)}
            </span>
            <span>
              <strong>{profile.fullName}</strong>
              <br />
              <span className="muted small">
                {profile.certifications[0]
                  ? profile.certifications[0].subject.name
                  : profile.headline}
              </span>
            </span>
          </div>
        </div>
      ))}
    </div>
  )
}
