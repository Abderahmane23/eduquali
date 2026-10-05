/**
 * Les créneaux, et la génération des séances.
 *
 * La liste des créneaux vit dans `shared/scheduling/slots.json` — une seule
 * source, copiée vers les deux clients par `shared/onboarding/sync.mjs`, qui
 * vérifie au passage que chaque créneau dure exactement une séance. Ce module
 * en est le lecteur côté serveur.
 *
 * Pourquoi un fichier et non six constantes ici : ces créneaux apparaissent
 * dans le formulaire du professeur, la grille de l'élève, ce générateur et une
 * validation d'inscription. Quatre copies finissent par diverger — ce dépôt a
 * déjà payé cette erreur sur le référentiel des matières, sur les seuils
 * d'affichage et sur le taux de commission.
 */

import slotsFile from '../../../shared/scheduling/slots.json' with { type: 'json' }

export type Weekday = 'MON' | 'TUE' | 'WED' | 'THU' | 'FRI' | 'SAT' | 'SUN'

export interface Slot {
  id: string
  label: string
  days: Weekday[]
  /** « 18:00 » */
  start: string
  /** « 19:30 » */
  end: string
}

/** Durée d'une séance, en minutes. */
export const SESSION_MINUTES: number = slotsFile.sessionMinutes

export const SLOTS: Slot[] = slotsFile.slots as Slot[]

export const WEEKDAY_LABELS: Record<string, string> = slotsFile.weekdayLabels

/** Un créneau par identifiant, ou `undefined` si inconnu. */
export function slotById(id: string): Slot | undefined {
  return SLOTS.find((s) => s.id === id)
}

/**
 * Les identifiants valides. Sert à refuser un créneau inventé côté client.
 *
 * La liste n'est pas recopiée en contrainte SQL : une contrainte à mettre à
 * jour à chaque changement d'horaire finirait par mentir, et c'est ici que le
 * refus doit se faire — au moment où une valeur entre.
 */
export function isKnownSlot(id: string): boolean {
  return SLOTS.some((s) => s.id === id)
}

/** Les jours de la semaine, dans l'ordre JavaScript (`Date.getUTCDay`). */
const ORDRE: Weekday[] = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']

/**
 * Le décalage horaire de la Guinée.
 *
 * **UTC+0, toute l'année, sans heure d'été.** C'est ce qui permet de composer
 * un instant à partir d'une heure locale sans bibliothèque de fuseaux : « 18 h
 * à Conakry » est « 18 h UTC ». Écrit ici parce que cette hypothèse est la
 * seule raison pour laquelle le calcul ci-dessous est juste, et qu'elle
 * cesserait de l'être le jour d'une ouverture en Côte d'Ivoire ou au Sénégal.
 */
export const GUINEA_UTC_OFFSET_HOURS = 0

/** « 18:30 » → `{ hours: 18, minutes: 30 }`, ou `null` si mal formé. */
function parseTime(value: string): { hours: number; minutes: number } | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(value)
  if (!m) return null
  const hours = Number(m[1])
  const minutes = Number(m[2])
  if (hours > 23 || minutes > 59) return null
  return { hours, minutes }
}

/** La durée d'un créneau, en minutes. */
export function slotMinutes(slot: Slot): number | null {
  const debut = parseTime(slot.start)
  const fin = parseTime(slot.end)
  if (!debut || !fin) return null
  return fin.hours * 60 + fin.minutes - (debut.hours * 60 + debut.minutes)
}

/** Une séance à créer : le moment, et le créneau dont elle vient. */
export interface PlannedOccurrence {
  slotId: string
  startsAt: Date
  durationMinutes: number
}

/**
 * Les occurrences d'un ensemble de créneaux, sur les `weeks` prochaines
 * semaines.
 *
 * Rendues triées, et **toujours dans le futur** : regénérer ne doit pas créer
 * des séances passées, qu'on ne pourrait ni annuler ni tenir.
 *
 * Un créneau inconnu est ignoré en silence ici — c'est l'écriture du cours qui
 * doit le refuser, pas le générateur, qui tourne sans personne pour lire son
 * erreur.
 */
export function occurrencesFor(
  slotIds: string[],
  options: { from?: Date; weeks?: number } = {},
): PlannedOccurrence[] {
  const depart = options.from ?? new Date()
  const semaines = options.weeks ?? 4
  const occurrences: PlannedOccurrence[] = []

  for (const slotId of slotIds) {
    const slot = slotById(slotId)
    if (!slot) continue
    const heure = parseTime(slot.start)
    const duree = slotMinutes(slot)
    if (!heure || duree == null) continue

    // On balaie jour par jour plutôt que de calculer le prochain lundi : un
    // calcul de « prochain jour J » est l'endroit classique des erreurs de
    // bord, et 7 × 4 itérations ne coûtent rien.
    for (let decalage = 0; decalage < semaines * 7; decalage++) {
      const jour = new Date(
        Date.UTC(
          depart.getUTCFullYear(),
          depart.getUTCMonth(),
          depart.getUTCDate() + decalage,
          heure.hours - GUINEA_UTC_OFFSET_HOURS,
          heure.minutes,
          0,
          0,
        ),
      )
      if (!slot.days.includes(ORDRE[jour.getUTCDay()])) continue
      // Une séance qui a déjà commencé ne se crée pas.
      if (jour.getTime() <= depart.getTime()) continue

      occurrences.push({
        slotId: slot.id,
        startsAt: jour,
        durationMinutes: duree,
      })
    }
  }

  return occurrences.sort(
    (a, b) => a.startsAt.getTime() - b.startsAt.getTime(),
  )
}
