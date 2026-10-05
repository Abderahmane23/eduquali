import assert from 'node:assert/strict'
import { beforeEach, describe, it } from 'node:test'

import { RULES, hit, identify, reset, ruleFor } from './ratelimit.ts'

/**
 * Regle critique : « personne ne rejoue un test jusqu'a le reussir, et
 * personne n'enumere les profils ».
 */

describe('hit — fenetre fixe', () => {
  beforeEach(() => reset())

  it('laisse passer jusqu’a la limite, puis refuse', () => {
    const { limit } = RULES.auth
    for (let i = 1; i <= limit; i++) {
      assert.equal(hit('ip:1.2.3.4', 'auth').allowed, true, `appel ${i}`)
    }
    assert.equal(hit('ip:1.2.3.4', 'auth').allowed, false)
  })

  it('decompte ce qu’il reste, sans passer sous zero', () => {
    const { limit } = RULES.auth
    for (let i = 0; i < limit + 3; i++) hit('ip:5.6.7.8', 'auth')
    assert.equal(hit('ip:5.6.7.8', 'auth').remaining, 0)
  })

  it('compte chaque appelant separement', () => {
    for (let i = 0; i < RULES.auth.limit; i++) hit('ip:a', 'auth')
    assert.equal(hit('ip:a', 'auth').allowed, false)
    assert.equal(hit('ip:b', 'auth').allowed, true, 'un voisin ne doit pas etre puni')
  })

  it('compte chaque bareme separement', () => {
    for (let i = 0; i < RULES.auth.limit + 1; i++) hit('ip:c', 'auth')
    assert.equal(hit('ip:c', 'auth').allowed, false)
    assert.equal(hit('ip:c', 'read').allowed, true)
  })

  it('rouvre a la fenetre suivante', () => {
    const start = 1_000_000
    for (let i = 0; i < RULES.auth.limit + 1; i++) hit('ip:d', 'auth', start)
    assert.equal(hit('ip:d', 'auth', start).allowed, false)

    const apres = start + RULES.auth.windowSeconds * 1000 + 1
    assert.equal(hit('ip:d', 'auth', apres).allowed, true)
  })

  it('annonce un delai d’attente exploitable', () => {
    const start = 2_000_000
    for (let i = 0; i < RULES.auth.limit + 1; i++) hit('ip:e', 'auth', start)
    const refus = hit('ip:e', 'auth', start)
    assert.equal(refus.allowed, false)
    assert.ok(refus.retryAfter >= 1)
    assert.ok(refus.retryAfter <= RULES.auth.windowSeconds)
  })
})

describe('identify — qui est compte', () => {
  const headers = (values: Record<string, string>) => ({
    get: (name: string) => values[name.toLowerCase()] ?? null,
  })

  it('prefere le jeton a l’adresse IP', () => {
    // Derriere le CGNAT d'un operateur, des milliers d'abonnes partagent une
    // adresse : compter par IP ferait tomber toute une ville.
    const a = identify('jeton-a', headers({ 'x-forwarded-for': '41.0.0.1' }))
    const b = identify('jeton-b', headers({ 'x-forwarded-for': '41.0.0.1' }))
    assert.notEqual(a, b)
  })

  it('ne laisse jamais le jeton entier dans la cle', () => {
    const jeton = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.charge.signature'
    const cle = identify(jeton, headers({}))
    assert.ok(!cle.includes(jeton))
    assert.ok(!cle.includes('signature'))
  })

  it('retombe sur la premiere adresse de la chaine', () => {
    const cle = identify(undefined, headers({ 'x-forwarded-for': '41.0.0.9, 10.0.0.1' }))
    assert.equal(cle, 'ip:41.0.0.9')
  })

  it('reste defini sans en-tete', () => {
    assert.equal(identify(undefined, headers({})), 'ip:inconnu')
  })
})

describe('ruleFor — le bareme applique', () => {
  it('protege la correction d’un test', () => {
    assert.equal(ruleFor('POST', '/tests/t1/submit'), 'submit')
  })

  it('protege l’authentification', () => {
    assert.equal(ruleFor('POST', '/auth/login'), 'auth')
  })

  it('distingue lecture et ecriture', () => {
    assert.equal(ruleFor('GET', '/jobs'), 'read')
    assert.equal(ruleFor('POST', '/applications'), 'write')
  })

  it('est plus severe sur la soumission que sur la lecture', () => {
    assert.ok(RULES.submit.limit < RULES.read.limit)
    assert.ok(RULES.auth.limit < RULES.submit.limit)
  })
})
