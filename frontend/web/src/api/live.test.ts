import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * Les cours en direct — lot 1.
 *
 * Ce qui est vérifié ici est ce qui, en cas d'erreur, se voit tard et coûte
 * cher : les créneaux recopiés au lieu d'être lus, une place prise sans verrou,
 * un prix envoyé par le navigateur, et une inscription payée qui resterait
 * « en attente » jusqu'à ce que le cron la libère.
 */
const code = (chemin: string) =>
  readFileSync(chemin, 'utf-8')
    .replace(/\r\n/g, '\n')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^[ \t]*\/\/.*$/gm, '')

const sql = (nom: string) =>
  readFileSync(`../../backend/supabase/migrations/${nom}`, 'utf-8').replace(
    /\r\n/g,
    '\n',
  )

const worker = code('../../backend/api/[[...route]].ts')
const slots = JSON.parse(
  readFileSync('../../shared/scheduling/slots.json', 'utf-8'),
) as { sessionMinutes: number; slots: { id: string; start: string; end: string; days: string[] }[] }

describe('les créneaux', () => {
  it('sont une source unique, lue et non recopiée', () => {
    // Six créneaux recopiés dans le formulaire, la grille, le générateur et une
    // validation finissent par différer — et le défaut se voit au moment où un
    // professeur choisit un créneau que le générateur refuse, sans message.
    const serveur = code('../../backend/api/_lib/scheduling.ts')
    expect(serveur).toContain("shared/scheduling/slots.json")

    const client = code('src/lib/slots.ts')
    expect(client).toContain("'/data/scheduling/slots.json'")

    // Aucun horaire écrit en dur de part et d'autre.
    expect(serveur).not.toMatch(/'18:00'|'20:00'|'17:30'/)
    expect(client).not.toMatch(/'18:00'|'20:00'|'17:30'/)
  })

  it('font tous exactement une séance', () => {
    const minutes = (h: string) =>
      Number(h.slice(0, 2)) * 60 + Number(h.slice(3))
    for (const slot of slots.slots) {
      expect(
        minutes(slot.end) - minutes(slot.start),
        `${slot.id} ne dure pas ${slots.sessionMinutes} min`,
      ).toBe(slots.sessionMinutes)
    }
    expect(slots.sessionMinutes).toBe(90)
  })

  it('le script de synchronisation refuse un créneau trop court', () => {
    // C'est le seul endroit où la règle se vérifie mécaniquement.
    const sync = code('../../shared/onboarding/sync.mjs')
    expect(sync).toContain('il en faut')
    expect(sync).toContain('se chevauchent')
    // Et la vérification doit précéder la sortie, sinon elle ne s'exécute
    // jamais en mode `--check` — ce qui a été le cas pendant une heure.
    expect(sync.indexOf('sessionMinutes')).toBeLessThan(
      sync.indexOf("console.error('Parcours invalides"),
    )
  })
})

describe('les quinze places', () => {
  const migration = sql('0015_session_enrolments.sql')

  it('se prennent sous verrou, jamais par lecture puis écriture', () => {
    // Deux familles réservant la dernière place au même instant liraient toutes
    // deux 14, insèreraient toutes deux, et la séance en aurait 16.
    expect(migration).toContain('create or replace function claim_session_seat')
    expect(migration).toContain('seats_taken = s.seats_taken + 1')
    expect(migration).toContain('s.seats_taken < c.seats')
    expect(migration).toContain('get diagnostics')
  })

  it('ne descendent jamais sous zéro en se libérant', () => {
    // Un double appel — reprise manuelle, webhook rejoué — offrirait sinon une
    // place de plus que la salle n'en a.
    expect(migration).toContain('greatest(seats_taken - 1, 0)')
  })

  it('le serveur prend la place avant de lancer le paiement', () => {
    const bloc = worker.slice(
      worker.indexOf("app.post('/live/enrol'"),
      worker.indexOf('async function releaseExpiredSeats'),
    )
    expect(bloc.indexOf('claim_session_seat')).toBeLessThan(
      bloc.indexOf('startPayment'),
    )
    // Et il la rend si la suite échoue.
    expect(bloc).toContain('rendreLaPlace')
  })

  it('une place retenue sans paiement expire', () => {
    expect(migration).toContain('holds_until')
    expect(worker).toContain('SEAT_HOLD_MINUTES')
    expect(worker).toContain('releaseExpiredSeats')
  })
})

describe('le prix', () => {
  it('est relu en base, jamais envoyé par le client', () => {
    const schema = worker.slice(
      worker.indexOf('const enrolSchema'),
      worker.indexOf("app.post('/live/enrol'"),
    )
    expect(schema).toContain('sessionId')
    expect(schema).not.toMatch(/amount|price|montant/)

    const bloc = worker.slice(
      worker.indexOf("app.post('/live/enrol'"),
      worker.indexOf('async function releaseExpiredSeats'),
    )
    expect(bloc).toContain('Number(cours?.price')
  })

  it('un achat porte un cours OU une inscription, jamais les deux', () => {
    // Sans cette contrainte, un achat sans objet serait encaissé sans rien
    // donner en échange.
    const migration = sql('0015_session_enrolments.sql')
    expect(migration).toContain('course_purchases_target_check')
    expect(migration).toContain('alter column course_id drop not null')
  })
})

describe('une inscription payée se confirme', () => {
  it('le webhook la passe en CONFIRMED et retire l’expiration', () => {
    // Sans cela la place resterait « retenue » et le cron la libérerait au bout
    // de vingt minutes — alors qu'elle est payée.
    const bloc = worker.slice(worker.indexOf("app.post('/payments/djomy/webhook'"))
    expect(bloc).toContain('enrolment_id')
    expect(bloc).toContain("status: 'CONFIRMED'")
    expect(bloc).toContain('holds_until: null')
  })

  it('un échec rend la place, une seule fois', () => {
    const bloc = worker.slice(worker.indexOf("app.post('/payments/djomy/webhook'"))
    expect(bloc).toContain('release_session_seat')
    // La garde qui évite de rendre deux fois la même place.
    expect(bloc).toContain("avant.status !== 'CANCELLED'")
  })
})

describe('les séances sont générées, pas saisies', () => {
  const migration = sql('0014_live_courses.sql')

  it('aucun client ne peut créer une séance', () => {
    // Un client qui pourrait en créer poserait des séances hors créneau, hors
    // prix, hors planning.
    expect(migration).not.toMatch(/create policy[^;]*for insert[^;]*live_sessions/)
    expect(migration).toContain('Aucune politique `insert` ni `delete`')
  })

  it('le générateur est rejouable', () => {
    // Il tourne chaque nuit : relancer ne doit pas créer de doublons, et une
    // exécution manquée se rattrape au passage suivant.
    expect(migration).toContain('unique (live_course_id, starts_at)')
    expect(worker).toContain('ignoreDuplicates: true')
  })

  it('le cron est déclaré pour les deux cibles', () => {
    const wrangler = readFileSync('../../backend/wrangler.toml', 'utf-8')
    expect(wrangler.match(/crons = /g) ?? []).toHaveLength(2)
  })
})

describe('la grille publique', () => {
  it('se consulte sans compte', () => {
    const app = code('src/App.tsx')
    const ligne = app.split('\n').find((l) => l.includes('path="/direct"'))
    expect(ligne).toBeDefined()
    expect(ligne).not.toContain('<Guard>')
  })

  it('ouvrir un cours reste réservé à un professeur', () => {
    const ecran = code('src/screens/Live.tsx')
    expect(ecran).toContain('session?.teacherId == null')
    expect(ecran).toContain('Réservé aux professeurs')
  })

  it('le professeur voit sa part avant de publier', () => {
    // Découvrir la retenue au premier virement est la meilleure façon de perdre
    // quelqu'un.
    const ecran = code('src/screens/Live.tsx')
    expect(ecran).toContain('il vous revient')
    expect(ecran).toContain('montant * 0.6')
  })

  it('les places restantes sont affichées, jamais négatives', () => {
    const supabase = code('src/api/supabase.ts')
    expect(supabase).toContain('Math.max(places - prises, 0)')
    const ecran = code('src/screens/Live.tsx')
    expect(ecran).toContain('seatsLeft')
    expect(ecran).toContain('Complet')
  })
})
