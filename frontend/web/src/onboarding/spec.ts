/**
 * Lecture de la description des parcours.
 *
 * Le fichier JSON est le meme que celui embarque par l'application mobile.
 * Ajouter une question se fait a un seul endroit et se repercute sur les deux
 * clients ; ces types ne font que refleter ce contrat.
 */

export type StepType =
  | 'statement'
  | 'steps_preview'
  | 'carousel'
  | 'role_select'
  | 'form'
  | 'single_choice'
  | 'multi_choice'
  | 'boolean'
  | 'range'
  | 'plan_select'
  | 'upload'
  | 'day_hours'

export type FieldType =
  | 'text'
  | 'phone'
  | 'dropdown'
  | 'combo'
  | 'month'
  /**
   * Saisi masque, avec un oeil pour reveler.
   *
   * Pose le 02/10. Sans SMS, le mot de passe est la seule chose qui distingue
   * le proprietaire d'un numero de quelqu'un qui le connait : jusque-la les
   * deux clients ouvraient les comptes avec un secret partage ecrit en clair
   * dans le code.
   */
  | 'password'

export interface Option {
  value: string
  label: string
  /** Ligne d'explication sous le libelle — utilisee par `role_select`. */
  description?: string
  /**
   * Familles auxquelles l'option appartient — pour un niveau ou une matiere,
   * les cycles : `PRIMAIRE`, `COLLEGE`, `LYCEE`, `SUPERIEUR`.
   *
   * Une matiere appartient souvent a plusieurs cycles (les mathematiques se
   * font partout), d'ou une liste et non une valeur unique. Liste vide =
   * l'option reste toujours visible.
   */
  groups?: string[]
}

/**
 * Restreint une liste dynamique selon une reponse precedente.
 *
 * Un professeur qui enseigne au college n'a rien a faire devant les matieres
 * du superieur : lui montrer toute la liste est une charge inutile et une
 * source d'erreur.
 *
 * Sans `map`, les valeurs de la reponse servent directement de familles
 * autorisees — le cas quand la question porte deja sur des cycles.
 */
export interface OptionsFilter {
  field: string
  map?: Record<string, string[]>
}

export interface Highlight {
  value: string
  label: string
  /** Pictogramme devant le chiffre cle. Voir `IconName`. */
  icon?: string
}

export interface Plan {
  value: string
  name: string
  price: number
  highlight: string
  recommended?: boolean
}

export interface Field {
  id: string
  type: FieldType
  label: string
  required?: boolean
  autofocus?: boolean
  allowCustom?: boolean
  optionsSource?: string
  /**
   * Restreint la liste en fonction d'une reponse deja donnee — c'est ce qui
   * fait la cascade region → prefecture : les communes de Conakry ne
   * s'affichent pas pour un professeur de Labe.
   */
  optionsFilter?: OptionsFilter
  dependsOn?: string
  prefixSource?: string
  default?: string
  nullableLabel?: string
  /** Ligne d'aide sous le champ. */
  hint?: string
  /**
   * Longueur minimale. Verifiee par `canContinue`, donc le bouton reste
   * desactive tant qu'elle n'est pas atteinte — plutot qu'un refus apres
   * l'envoi, quand le compte d'authentification est deja cree.
   */
  minLength?: number
}

export interface RangeEstimate {
  kind: string
  minutesPerUnit: number
}

/**
 * Illustration d'une etape.
 *
 * `name` designe un fichier de `/img` sans extension : le composant compose
 * lui-meme le `srcset`. Le mobile lit le meme nom dans ses assets — un seul
 * champ pour les deux clients.
 */
export interface Illustration {
  name: string
  /** Texte alternatif. Decrit la scene, jamais « illustration ». */
  alt: string
}

/**
 * Condition d'affichage d'une etape.
 *
 * « Montre cet ecran seulement si la reponse <field> vaut <equals> ». Sans
 * cela, un eleve deja scolarise devait repondre aux questions de celui qui
 * cherche un etablissement, et inversement.
 */
export interface ShowIf {
  field: string
  equals: string | string[]
}

/** Un fichier demande par une etape `upload`. */
export interface UploadSlot {
  id: string
  label: string
  /** « pdf,image » — ce que le selecteur accepte. */
  accept?: string
}

export interface Step {
  id: string
  type: StepType
  title: string
  /** Paragraphe d'explication sous le titre. */
  body?: string
  /** Etape conditionnelle : absente du parcours si la condition est fausse. */
  showIf?: ShowIf
  image?: Illustration
  fieldId?: string
  fields?: Field[]
  options?: Option[]
  highlights?: Highlight[]
  plans?: Plan[]
  items?: string[]
  /** Fichiers demandes par une etape `upload`. */
  uploads?: UploadSlot[]
  optionsSource?: string
  /** Restreint `optionsSource` selon une reponse deja donnee. */
  optionsFilter?: OptionsFilter
  itemsSource?: string
  allOption?: Option
  required?: boolean
  optional?: boolean
  /**
   * Liste longue : champ a taper plutot qu'un mur d'etiquettes.
   *
   * Pose le 24/09 sur les quatre etapes « matieres » — vingt-quatre
   * etiquettes ne se lisent pas, et on coche la premiere qui ressemble.
   */
  searchable?: boolean
  /** Texte d'invite du champ de recherche. */
  searchHint?: string
  minSelected?: number
  min?: number
  max?: number
  step?: number
  default?: number
  unit?: string
  estimate?: RangeEstimate
  cta?: string
  declineLabel?: string
  declineValue?: string
}

export interface Section {
  id: string
  label: string
  steps: Step[]
}

export interface FlowSpec {
  id: string
  audience: string
  currency: string
  sections: Section[]
}

export type Audience = 'teacher' | 'institution' | 'parent' | 'student'

/** `intro` precede le choix du profil ; les autres en decoulent. */
export type FlowName = 'intro' | Audience

const cache = new Map<FlowName, FlowSpec>()

export async function loadFlow(name: FlowName): Promise<FlowSpec> {
  const cached = cache.get(name)
  if (cached) return cached
  // `intro.json` n'a pas de suffixe : ce n'est pas le parcours d'un profil,
  // c'est ce qui sert a en choisir un.
  const file = name === 'intro' ? 'intro' : `${name}_onboarding`
  const response = await fetch(`/data/${file}.json`)
  if (!response.ok) throw new Error('Parcours introuvable')
  const spec = (await response.json()) as FlowSpec
  cache.set(name, spec)
  return spec
}

// --- Decoupage administratif ---------------------------------------------

export interface GeoDivision {
  code: string
  name: string
  /** Prefecture creee recemment — l'ecran le signale. */
  recent?: boolean
}

export interface GeoRegion {
  code: string
  name: string
  /** `REGION`, ou `SPECIALE` pour Conakry. */
  kind?: string
  /** `PREFECTURE`, ou `COMMUNE` pour Conakry. */
  divisionKind?: string
  divisions: GeoDivision[]
}

let geographyCache: Promise<GeoRegion[]> | null = null

/**
 * Les 10 regions de Guinee et leurs subdivisions.
 *
 * Le fichier vient de `shared/geography/guinea.json`, recopie par
 * `shared/onboarding/sync.mjs`. Il n'est pas ecrit dans le code : les
 * decoupages bougent, et deux copies finissent par diverger.
 */
export function loadGeography(): Promise<GeoRegion[]> {
  geographyCache ??= fetch('/data/geography/guinea.json')
    .then((response) => {
      if (!response.ok) throw new Error('Decoupage administratif introuvable')
      return response.json()
    })
    .then((data: { regions?: GeoRegion[] }) => data.regions ?? [])
    .catch((error) => {
      // Sans remise a zero, un echec reseau condamnerait la liste pour toute
      // la session.
      geographyCache = null
      throw error
    })
  return geographyCache
}

// --- Programme national ---------------------------------------------------

export interface Filiere {
  id: string
  name: string
  code: string
  /** Ce qui distingue le profil, en une phrase. */
  note?: string
  /** Classes concernees : le profil ne se choisit qu'a partir de la 12eme. */
  levelIds: string[]
  majorSubjectIds: string[]
  subjectIds: string[]
}

let curriculumCache: Promise<Filiere[]> | null = null

/**
 * Les trois profils du lycee guineen.
 *
 * Vient de `shared/curriculum/guinea.json`, recopie par
 * `shared/onboarding/sync.mjs` — meme source que l'application mobile.
 */
export function loadFilieres(): Promise<Filiere[]> {
  curriculumCache ??= fetch('/data/curriculum/guinea.json')
    .then((response) => {
      if (!response.ok) throw new Error('Programme national introuvable')
      return response.json()
    })
    .then((data: { filieres?: Filiere[] }) => data.filieres ?? [])
    .catch((error) => {
      curriculumCache = null
      throw error
    })
  return curriculumCache
}

/** Un palier d'etudes : primaire, college, lycee, universite, diplome. */
export interface Stage {
  id: string
  name: string
  order: number
  hasClasses: boolean
  note?: string
}

let stagesCache: Promise<Stage[]> | null = null

/**
 * Les cinq paliers, depuis le referentiel partage.
 *
 * Jamais ecrits dans un parcours : le parcours enseignant les avait recopies en
 * dur a quatre valeurs et ignorait « diplome », tandis que les parcours parent
 * et etudiant listaient les seize classes a plat. Une seule source, et les trois
 * parcours disent la meme chose.
 */
export function loadStages(): Promise<Stage[]> {
  stagesCache ??= fetch('/data/catalog.json')
    .then((response) => {
      if (!response.ok) throw new Error('Referentiel introuvable')
      return response.json()
    })
    .then((data: { stages?: Stage[] }) =>
      [...(data.stages ?? [])].sort((a, b) => a.order - b.order),
    )
    .catch((error) => {
      stagesCache = null
      throw error
    })
  return stagesCache
}

/** Les ecrans, a plat, dans l'ordre de parcours. */
export const flatSteps = (spec: FlowSpec): Step[] =>
  spec.sections.flatMap((section) => section.steps)

/** Les options retenues pour cette etape, filtre applique. */
export function filterOptions(
  options: Option[],
  filter: OptionsFilter | undefined,
  answers: Answers,
): Option[] {
  if (!filter) return options

  const given = answers[filter.field]
  if (given == null) return options
  const values = (Array.isArray(given) ? given : [given]).map(String)
  if (values.length === 0) return options

  const allowed = filter.map
    ? values.flatMap((v) => filter.map![v] ?? [])
    : values
  // Reponse non listee : mieux vaut tout montrer que rien.
  if (allowed.length === 0) return options

  return options.filter(
    (o) => !o.groups?.length || o.groups.some((g) => allowed.includes(g)),
  )
}

/**
 * Les champs de [step] dont la liste depend de [fieldId], de proche en proche.
 *
 * Changer la region apres avoir choisi « Ratoma » doit effacer « Ratoma » :
 * la liste ne l'affiche plus, mais sans cela c'est bien elle qui partirait
 * en base.
 */
export function dependentFields(fieldId: string, fields: Field[]): string[] {
  const found = new Set<string>()
  let frontier = new Set<string>([fieldId])
  while (frontier.size > 0) {
    const next = new Set<string>()
    for (const field of fields) {
      const parent = field.optionsFilter?.field
      if (parent && frontier.has(parent) && !found.has(field.id)) {
        next.add(field.id)
      }
    }
    next.forEach((id) => found.add(id))
    frontier = next
  }
  return [...found]
}

/**
 * Vrai si l'etape doit apparaitre compte tenu des reponses deja donnees.
 *
 * Une reponse multiple correspond des qu'un de ses elements correspond. La
 * version precedente reduisait la reponse a `String(given)` : `['HOME',
 * 'FULL_TIME']` devenait `"HOME,FULL_TIME"`, qui n'egale jamais `"HOME"`.
 *
 * La consequence ne levait aucune erreur : depuis le retrait de « Vous donnez
 * des cours a domicile ? » le 26/09, les deux ecrans de disponibilite du
 * professeur ne s'affichaient plus jamais. Le parcours se terminait, le profil
 * partait incomplet, et rien ne le signalait.
 *
 * Meme regle que `ShowIf.matches` cote mobile
 * (`lib/domain/entities/onboarding_spec.dart`) : les deux clients lisent le
 * meme JSON, ils doivent en tirer les memes ecrans.
 */
export function stepApplies(step: Step, answers: Answers): boolean {
  if (!step.showIf) return true
  const given = answers[step.showIf.field]
  if (given == null) return false

  const expected = (
    Array.isArray(step.showIf.equals) ? step.showIf.equals : [step.showIf.equals]
  ).map((v) => String(v))

  const actual = Array.isArray(given) ? given.map((v) => String(v)) : [String(given)]
  return actual.some((v) => expected.includes(v))
}

/**
 * Le parcours reellement parcouru, conditions appliquees.
 *
 * Recalcule a chaque reponse : repondre « je cherche un etablissement » fait
 * apparaitre les ecrans correspondants sans rechargement.
 */
export const visibleSteps = (spec: FlowSpec, answers: Answers): Step[] =>
  flatSteps(spec).filter((step) => stepApplies(step, answers))

/** Un ecran informatif n'attend aucune réponse. */
export const collectsAnswer = (type: StepType): boolean =>
  !['statement', 'steps_preview', 'carousel'].includes(type)

/**
 * Les types d'etape que le rendu sait traiter.
 *
 * Existe pour une raison precise : `upload` et `day_hours` ont ete ajoutes au
 * JSON le 24/09 et le rendu tombait sur `default: return null`. L'ecran
 * s'affichait vide, « Continuer » fonctionnait, et un professeur inscrit sur
 * le web ne deposait jamais son CV ni ne declarait ses horaires. Aucune
 * erreur, aucune trace.
 *
 * Un type ajoute au JSON sans rendu correspondant doit maintenant se voir.
 */
export const RENDERED_STEP_TYPES: readonly StepType[] = [
  'statement',
  'steps_preview',
  'carousel',
  'role_select',
  'form',
  'single_choice',
  'multi_choice',
  'boolean',
  'range',
  'plan_select',
  'upload',
  'day_hours',
]

/** Profils proposes par `intro.json`. */
export type Role = 'TEACHER' | 'INSTITUTION' | 'PARENT' | 'STUDENT'

/**
 * Le parcours a charger pour chaque profil.
 *
 * `STUDENT` manquait alors que `intro.json` le propose et que
 * `student_onboarding.json` est bien copie dans `public/data/` : la requete
 * partait sur `/data/undefined_onboarding.json` et l'ecran affichait
 * « Parcours indisponible ». Un quatrieme profil choisissable qui ne menait
 * nulle part.
 */
export const AUDIENCE_BY_ROLE: Record<Role, Audience> = {
  TEACHER: 'teacher',
  INSTITUTION: 'institution',
  PARENT: 'parent',
  STUDENT: 'student',
}

/** « environ 20 min » pour 5 km. */
export function describeEstimate(
  estimate: RangeEstimate,
  value: number,
): string {
  const minutes = Math.round(value * estimate.minutesPerUnit)
  if (minutes <= 0) return 'sur place'
  if (minutes < 60) return `environ ${minutes} min`
  const hours = Math.floor(minutes / 60)
  const rest = minutes % 60
  return rest === 0
    ? `environ ${hours}h`
    : `environ ${hours}h${String(rest).padStart(2, '0')}`
}

export type Answers = Record<string, unknown>

/** La question courante est-elle satisfaite ? */
export function canContinue(step: Step, answers: Answers): boolean {
  if (!collectsAnswer(step.type) || step.optional) return true

  switch (step.type) {
    case 'form':
      return (step.fields ?? []).every((field) => {
        const value = answers[field.id]
        if (typeof value === 'string' && field.minLength != null) {
          // Verifie meme sur un champ facultatif : rempli a moitie, il serait
          // refuse par le serveur apres que le compte a ete cree.
          if (value.trim() !== '' && value.length < field.minLength) return false
        }
        if (!field.required) return true
        return typeof value === 'string' ? value.trim() !== '' : value != null
      })

    case 'multi_choice': {
      const selected = (answers[step.fieldId!] as string[]) ?? []
      const min = step.minSelected ?? (step.required ? 1 : 0)
      return selected.length >= min
    }

    case 'single_choice':
    case 'boolean':
    case 'role_select':
      return !step.required || answers[step.fieldId!] != null

    // Le curseur porte toujours une valeur, et une formule peut etre refusée.
    case 'range':
    case 'plan_select':
      return true

    case 'day_hours': {
      // Un jour sans creneau ne compte pas : il ne dit pas quand on est
      // libre, et une famille n'y trouverait rien.
      const saved = (answers[step.fieldId!] ?? {}) as Record<string, unknown>
      const jours = Object.values(saved).filter(
        (slots) => Array.isArray(slots) && slots.length > 0,
      ).length
      return jours >= (step.minSelected ?? (step.required ? 1 : 0))
    }

    case 'upload':
      // Une etape de depot non `optional` exige au moins un fichier. Celle du
      // professeur est `optional` : un candidat n'a pas toujours son diplome
      // sous la main, et le bouton « Passer » existe pour cela.
      return (step.uploads ?? []).some((slot) => answers[slot.id] != null)

    default:
      return true
  }
}
