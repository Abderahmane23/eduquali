/**
 * Les créneaux des cours en direct.
 *
 * Lus dans `/data/scheduling/slots.json`, que `shared/onboarding/sync.mjs`
 * recopie depuis `shared/scheduling/slots.json` — la même source que le
 * serveur. Ce fichier ne redéfinit donc aucun horaire : il les charge.
 *
 * C'est délibéré. Six créneaux recopiés ici finiraient par différer de ceux du
 * serveur, et le défaut se verrait au moment où un professeur choisirait un
 * créneau que le générateur refuse — c'est-à-dire sans message et sans séance.
 */

export type Weekday = 'MON' | 'TUE' | 'WED' | 'THU' | 'FRI' | 'SAT' | 'SUN'

export interface Slot {
  id: string
  label: string
  days: Weekday[]
  start: string
  end: string
}

export interface SlotGrid {
  sessionMinutes: number
  slots: Slot[]
  weekdayLabels: Record<string, string>
}

let cache: SlotGrid | undefined

/** Charge la grille une fois, puis la rend depuis le cache. */
export async function loadSlots(): Promise<SlotGrid> {
  if (cache) return cache
  const reponse = await fetch('/data/scheduling/slots.json')
  if (!reponse.ok) throw new Error('Grille des créneaux introuvable.')
  cache = (await reponse.json()) as SlotGrid
  return cache
}

/** L'ordre des jours de la semaine, lundi d'abord. */
export const WEEK_ORDER: Weekday[] = [
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
  'SUN',
]

const JS_TO_CODE: Weekday[] = [
  'SUN',
  'MON',
  'TUE',
  'WED',
  'THU',
  'FRI',
  'SAT',
]

/**
 * Le jour d'une date, dans le code de la grille.
 *
 * Lu en UTC parce que la Guinée est à UTC+0 toute l'année, sans heure d'été :
 * c'est l'hypothèse qui permet de lire une heure locale sans bibliothèque de
 * fuseaux, et elle est écrite ici parce qu'elle cesserait d'être vraie le jour
 * d'une ouverture ailleurs.
 */
export function weekdayOf(date: Date): Weekday {
  return JS_TO_CODE[date.getUTCDay()]
}

/** « jeudi 9 octobre », pour un titre de groupe. */
export function longDayLabel(date: Date, labels: Record<string, string>): string {
  const jour = labels[weekdayOf(date)] ?? ''
  const mois = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ][date.getUTCMonth()]
  return `${jour.toLowerCase()} ${date.getUTCDate()} ${mois}`
}

/** « 18 h 00 », l'heure locale guinéenne. */
export function timeLabel(date: Date): string {
  const heures = date.getUTCHours()
  const minutes = String(date.getUTCMinutes()).padStart(2, '0')
  return `${heures} h ${minutes}`
}

/**
 * Regroupe des éléments datés par jour, dans l'ordre du temps.
 *
 * Une grille se lit par journée — « jeudi, deux cours » — et non comme une
 * liste de dates à décoder une par une.
 */
export function groupByDay<T>(
  items: T[],
  dateOf: (item: T) => Date,
): { day: Date; items: T[] }[] {
  const paquets = new Map<string, { day: Date; items: T[] }>()

  for (const item of items) {
    const date = dateOf(item)
    const cle = date.toISOString().slice(0, 10)
    const paquet = paquets.get(cle) ?? { day: date, items: [] }
    paquet.items.push(item)
    paquets.set(cle, paquet)
  }

  return [...paquets.values()].sort(
    (a, b) => a.day.getTime() - b.day.getTime(),
  )
}
