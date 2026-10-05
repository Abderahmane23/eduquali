import assert from 'node:assert/strict'
import { test } from 'node:test'

import {
  SESSION_MINUTES,
  SLOTS,
  isKnownSlot,
  occurrencesFor,
  slotById,
  slotMinutes,
} from './scheduling.ts'

/**
 * Les créneaux et la génération des séances.
 *
 * Deux choses sont testées ici, et ce sont les deux qui coûtent cher si elles
 * sont fausses : la grille elle-même — un créneau plus court qu'une séance
 * couperait un cours en plein milieu — et le calcul des dates, qui est
 * l'endroit classique des erreurs de bord.
 */

test('la grille tient la règle des 90 minutes', () => {
  assert.equal(SESSION_MINUTES, 90)
  assert.equal(SLOTS.length, 6)

  for (const slot of SLOTS) {
    assert.equal(
      slotMinutes(slot),
      SESSION_MINUTES,
      `${slot.id} ne dure pas ${SESSION_MINUTES} min`,
    )
  }
})

test('quatorze occurrences par semaine', () => {
  // 2 créneaux × 5 jours de semaine, plus 4 le samedi.
  const total = SLOTS.reduce((somme, slot) => somme + slot.days.length, 0)
  assert.equal(total, 14)
})

test('aucun chevauchement un même jour', () => {
  // Deux créneaux qui se croisent feraient deux cours au même moment dans la
  // même grille — et un professeur inscrit aux deux.
  for (const jour of ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']) {
    const duJour = SLOTS.filter((s) => s.days.includes(jour as never))
      .map((s) => ({
        id: s.id,
        debut: Number(s.start.slice(0, 2)) * 60 + Number(s.start.slice(3)),
        fin: Number(s.end.slice(0, 2)) * 60 + Number(s.end.slice(3)),
      }))
      .sort((a, b) => a.debut - b.debut)

    for (let i = 1; i < duJour.length; i++) {
      assert.ok(
        duJour[i].debut >= duJour[i - 1].fin,
        `${duJour[i - 1].id} et ${duJour[i].id} se chevauchent le ${jour}`,
      )
    }
  }
})

test('un créneau inconnu est refusé', () => {
  assert.equal(isKnownSlot('WD_18'), true)
  assert.equal(isKnownSlot('WD_17'), false)
  assert.equal(isKnownSlot(''), false)
  assert.equal(slotById('SAT_10')?.label, '10 h – 11 h 30')
  assert.equal(slotById('inventé'), undefined)
})

test('les séances tombent le bon jour, à la bonne heure', () => {
  // Jeudi 1er octobre 2026, 8 h UTC : avant tous les créneaux du jour.
  const depart = new Date('2026-10-01T08:00:00Z')
  const occurrences = occurrencesFor(['WD_18'], { from: depart, weeks: 1 })

  // Un créneau de semaine sur sept jours : jeudi, vendredi, lundi, mardi,
  // mercredi. Ni samedi ni dimanche.
  assert.equal(occurrences.length, 5)

  for (const o of occurrences) {
    assert.equal(o.slotId, 'WD_18')
    assert.equal(o.durationMinutes, 90)
    // La Guinée est à UTC+0 toute l'année : 18 h locales sont 18 h UTC.
    assert.equal(o.startsAt.getUTCHours(), 18)
    assert.equal(o.startsAt.getUTCMinutes(), 0)
    // Jamais le week-end pour ce créneau.
    assert.ok(o.startsAt.getUTCDay() >= 1 && o.startsAt.getUTCDay() <= 5)
  }

  // La première est le jeudi même, puisque 8 h précède 18 h.
  assert.equal(occurrences[0].startsAt.toISOString(), '2026-10-01T18:00:00.000Z')
})

test('une séance déjà commencée n’est pas créée', () => {
  // Jeudi 20 h : le créneau de 18 h du jour est passé. Regénérer ne doit pas
  // créer une séance qu'on ne pourrait ni annuler ni tenir.
  const depart = new Date('2026-10-01T20:00:00Z')
  const occurrences = occurrencesFor(['WD_18'], { from: depart, weeks: 1 })

  assert.ok(
    occurrences.every((o) => o.startsAt.getTime() > depart.getTime()),
    'une occurrence est dans le passé',
  )
  // Le jeudi est perdu, le vendredi devient le premier.
  assert.equal(occurrences[0].startsAt.toISOString(), '2026-10-02T18:00:00.000Z')
})

test('les créneaux du samedi ne tombent que le samedi', () => {
  const depart = new Date('2026-10-01T00:00:00Z')
  const occurrences = occurrencesFor(
    ['SAT_10', 'SAT_12', 'SAT_1730', 'SAT_19'],
    { from: depart, weeks: 2 },
  )

  // Quatre créneaux, deux samedis.
  assert.equal(occurrences.length, 8)
  for (const o of occurrences) {
    assert.equal(o.startsAt.getUTCDay(), 6, 'pas un samedi')
  }
})

test('les occurrences sortent triées', () => {
  // La grille se lit dans l'ordre du temps ; trier à l'affichage serait un
  // travail refait à chaque lecture.
  const occurrences = occurrencesFor(['SAT_19', 'WD_18', 'SAT_10'], {
    from: new Date('2026-10-01T00:00:00Z'),
    weeks: 2,
  })
  for (let i = 1; i < occurrences.length; i++) {
    assert.ok(
      occurrences[i].startsAt.getTime() >= occurrences[i - 1].startsAt.getTime(),
      'occurrences non triées',
    )
  }
})

test('quatre semaines d’un cours à deux créneaux', () => {
  // Le cas réel : un professeur choisit mardi et jeudi 18 h, le générateur
  // tourne pour quatre semaines.
  const occurrences = occurrencesFor(['WD_18', 'WD_20'], {
    from: new Date('2026-10-01T00:00:00Z'),
    weeks: 4,
  })
  // 2 créneaux × 5 jours ouvrés × 4 semaines = 40.
  assert.equal(occurrences.length, 40)
})

test('un créneau inconnu ne produit rien, et ne lève pas', () => {
  // Le générateur tourne sans personne pour lire une erreur : il ignore. C'est
  // l'écriture du cours qui doit refuser, avec `isKnownSlot`.
  const occurrences = occurrencesFor(['PAS_UN_CRENEAU'], {
    from: new Date('2026-10-01T00:00:00Z'),
    weeks: 4,
  })
  assert.equal(occurrences.length, 0)
})
