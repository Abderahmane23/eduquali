import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { digest, isAuditable, sanitize, toRow, writeEvent } from './audit.ts'

/**
 * Regle critique : « le journal prouve, mais ne divulgue pas ».
 *
 * Un journal d'audit qui recopie un mot de passe ou le corrige d'un test est
 * pire que pas de journal : il concentre en un seul endroit ce que le reste
 * du systeme protege.
 */

describe('sanitize — ce qui ne doit jamais atteindre le journal', () => {
  it('remplace les secrets, quelle que soit la casse', () => {
    const out = sanitize({
      phone: '620000101',
      password: 'hunter2',
      Token: 'eyJabc',
      OTP: '123456',
    }) as Record<string, unknown>

    assert.equal(out.phone, '620000101', 'une donnee utile reste lisible')
    assert.equal(out.password, '[redacted]')
    assert.equal(out.Token, '[redacted]')
    assert.equal(out.OTP, '[redacted]')
  })

  it('protege les reponses d’un test — les journaliser, c’est publier le corrige', () => {
    const out = sanitize({ answers: { q1: 'A', q2: 'B' } }) as Record<string, unknown>
    assert.equal(out.answers, '[redacted]')
  })

  it('descend dans les objets imbriques', () => {
    const out = sanitize({ user: { profile: { password: 'x' } } }) as any
    assert.equal(out.user.profile.password, '[redacted]')
  })

  it('tronque une chaine demesuree au lieu de la stocker', () => {
    const out = sanitize({ note: 'a'.repeat(5000) }) as Record<string, string>
    assert.ok(out.note.length < 600)
    assert.ok(out.note.includes('5000'), 'la taille reelle reste lisible')
  })

  it('borne un tableau long', () => {
    const out = sanitize({ ids: Array.from({ length: 100 }, (_, i) => i) }) as any
    assert.equal(out.ids.length, 21)
    assert.equal(out.ids[20], '…80 de plus')
  })

  it('s’arrete en profondeur au lieu de boucler', () => {
    let deep: any = 'fond'
    for (let i = 0; i < 20; i++) deep = { child: deep }
    assert.doesNotThrow(() => sanitize(deep))
    assert.ok(JSON.stringify(sanitize(deep)).includes('[profond]'))
  })

  it('laisse passer null et undefined tels quels', () => {
    assert.equal(sanitize(null), null)
    assert.equal(sanitize(undefined), undefined)
  })
})

describe('digest — empreinte de la charge assainie', () => {
  it('est stable pour une meme charge', () => {
    assert.equal(digest({ a: 1 }), digest({ a: 1 }))
  })

  it('change des que la charge change', () => {
    assert.notEqual(digest({ a: 1 }), digest({ a: 2 }))
  })
})

describe('toRow', () => {
  const base = {
    method: 'POST',
    path: '/applications',
    status: 201,
    durationMs: 42.6,
  }

  it('n’ecrit jamais un secret, ni dans la charge ni dans l’empreinte', () => {
    const avec = toRow({ ...base, payload: { jobId: 'j1', password: 'hunter2' } })
    const sans = toRow({ ...base, payload: { jobId: 'j1', password: 'autre' } })

    assert.equal(JSON.stringify(avec.payload).includes('hunter2'), false)
    // L'empreinte porte sur la charge ASSAINIE : sinon elle devient un
    // oracle permettant de tester un mot de passe candidat.
    assert.equal(avec.payload_sha256, sans.payload_sha256)
  })

  it('borne un user-agent declaratif', () => {
    const row = toRow({ ...base, userAgent: 'x'.repeat(2000) })
    assert.equal(row.user_agent?.length, 256)
  })

  it('arrondit la duree et accepte un appelant anonyme', () => {
    const row = toRow(base)
    assert.equal(row.duration_ms, 43)
    assert.equal(row.user_id, null)
    assert.equal(row.ip, null)
  })
})

describe('isAuditable — ce qui merite une ligne', () => {
  it('ignore la sonde de sante', () => {
    assert.equal(isAuditable('GET', '/health'), false)
  })

  it('retient toute mutation', () => {
    assert.equal(isAuditable('POST', '/applications'), true)
    assert.equal(isAuditable('PATCH', '/jobs/j1'), true)
  })

  it('retient la consultation de donnees personnelles', () => {
    assert.equal(isAuditable('GET', '/teachers'), true)
  })

  it('ignore la lecture du referentiel', () => {
    assert.equal(isAuditable('GET', '/subjects'), false)
  })
})

describe('writeEvent — le journal ne casse pas la production', () => {
  it('avale une panne d’ecriture', async () => {
    await assert.doesNotReject(
      writeEvent(
        async () => {
          throw new Error('base injoignable')
        },
        { method: 'POST', path: '/applications', status: 201, durationMs: 5 },
      ),
    )
  })

  it('transmet bien la ligne quand tout va bien', async () => {
    let recu: unknown
    await writeEvent(
      async (row) => {
        recu = row
      },
      { method: 'POST', path: '/applications', status: 201, durationMs: 5 },
    )
    assert.equal((recu as { path: string }).path, '/applications')
  })
})
