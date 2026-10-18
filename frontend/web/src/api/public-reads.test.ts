import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * Ce que les pages publiques demandent au serveur.
 *
 * Les listes de professeurs, d'ecoles et d'offres sont devenues publiques le
 * 02/10 : on regarde avant d'ouvrir un compte, comme sur le telephone. La
 * frontiere qui compte n'est plus celle de l'ecran, c'est celle des colonnes.
 *
 * **RLS est la seule barriere** — la cle anonyme est dans le code du site. Ces
 * tests lisent le code du client et les migrations : ils ne remplacent pas une
 * verification contre une vraie base, ils ferment la porte qu'on ouvre par
 * commodite un soir de correction.
 */
const client = readFileSync('src/api/supabase.ts', 'utf-8')
const migration0009 = readFileSync(
  '../../backend/supabase/migrations/0009_public_teacher_read.sql',
  'utf-8',
)

describe('la lecture publique d’un enseignant', () => {
  it('ne demande jamais le téléphone ni le courriel', () => {
    // Le piège : une carte sans nom donne envie d'élargir la jointure sur
    // `profiles`, et `profiles` porte le téléphone. Les coordonnées ne
    // circulent qu'après mise en relation (§30).
    const colonnes = client.slice(
      client.indexOf('teacherColumns'),
      client.indexOf('async teacher('),
    )
    expect(colonnes).not.toMatch(/\bphone\b/)
    expect(colonnes).not.toMatch(/\bemail\b/)
    expect(colonnes).not.toMatch(/teacher_documents/)
  })

  it('passe par la vue publique pour le nom et la photo', () => {
    // « profil : lecture de soi » (0002) ferme `profiles` à tout le monde sauf
    // son propriétaire. Sans la vue, les cartes publiques s'affichent sans
    // nom — et c'est ce symptôme qui pousse à ouvrir `profiles`.
    expect(client).toContain('public_teacher_identities')

    // La vue ne doit exposer que ces quatre colonnes, et c'est la migration
    // qui le dit : si elle en gagne une, ce test le signale.
    const vue = migration0009.slice(
      migration0009.indexOf('create view public_teacher_identities'),
      migration0009.indexOf('alter view public_teacher_identities'),
    )
    expect(vue).toContain('first_name')
    expect(vue).toContain('last_name')
    expect(vue).toContain('photo_path')
    expect(vue).toContain('city')
    expect(vue).not.toMatch(/\bphone\b/)
    expect(vue).not.toMatch(/\bemail\b/)
  })

  it('ne fait pas échouer la liste quand la vue est muette', () => {
    // Un nom manquant est un défaut d'affichage ; une exception est une page
    // blanche. Une fiche sans nom reste utile : matière, ville, vérification.
    const bloc = client.slice(
      client.indexOf('private async withPublicIdentities'),
      client.indexOf('async searchTeachers'),
    )
    expect(bloc).toContain('if (error || !data) return profiles')
  })
})

describe('la frontière entre regarder et agir', () => {
  const app = readFileSync('src/App.tsx', 'utf-8')

  it('tout ce qui se regarde est public', () => {
    for (const route of [
      '"/professeurs"',
      '"/professeurs/:id"',
      '"/etablissements"',
      '"/etablissements/:id"',
      '"/offres"',
      '"/offres/:id"',
      '"/cours"',
      '"/cours/:id"',
      // Le catalogue des tests, pas le passage : un professeur doit pouvoir
      // voir qu'une certification existe dans sa matiere avant d'ouvrir un
      // compte.
      '"/tests"',
    ]) {
      const ligne = app
        .split('\n')
        .find((l) => l.includes(`path=${route}`))
      expect(ligne, `route ${route} absente`).toBeDefined()
      expect(ligne, `${route} est encore derrière <Guard>`).not.toContain(
        '<Guard>',
      )
    }
  })

  it('ce qui appartient à un compte le reste', () => {
    // Candidatures, passage d'un test et profil : ouvrir ces pages à un
    // visiteur n'afficherait rien d'utile et laisserait croire à une panne.
    for (const route of ['"/candidatures"', '"/tests/:id"', '"/profil"']) {
      const ligne = app
        .split('\n')
        .find((l) => l.includes(`path=${route}`))
      expect(ligne, `route ${route} absente`).toBeDefined()
      expect(ligne, `${route} doit rester gardée`).toContain('<Guard>')
    }
  })

  it('un test ne s’ouvre pas quand personne ne peut le corriger', () => {
    // En accès direct à Supabase, `submitTest` lève un 501 : corriger dans le
    // navigateur demanderait de lui livrer les bonnes réponses. Sans ce
    // garde-fou, on répondait à vingt questions avant d'apprendre que rien ne
    // serait enregistré.
    const index = readFileSync('src/api/index.ts', 'utf-8')
    expect(index).toContain('export const canGradeTests = !isSupabaseBackend')

    const tests = readFileSync('src/screens/Tests.tsx', 'utf-8')
    expect(tests).toContain('canGradeTests && session?.teacherId != null')
    // La carte ne mène nulle part tant que le test n'est pas passable.
    expect(tests).toContain('passable ? () => navigate(')
    expect(tests).toContain('AppGate')
  })

  it('aucune action engageante ne s’enfonce dans le vide', () => {
    // « Envoyer ma candidature » sortait sans rien faire quand le compte
    // n'avait pas de fiche enseignant — visiteur, parent ou établissement.
    const offres = readFileSync('src/screens/Offers.tsx', 'utf-8')
    expect(offres).toContain('AppGate')
    expect(offres).toContain('session?.teacherId ? (')

    /*
     * Le bouton n'est jamais masqué, il est remplacé : une action absente
     * se lit comme « ce professeur ne prend personne ».
     *
     * Cette épreuve exigeait aussi `because` — la phrase qui disait
     * pourquoi le geste vit dans l'application. Elle a été retirée le
     * 18/10 : la porte portait trois niveaux de texte pour une action
     * qu'on pousse, et on la lisait moins vite qu'on ne la franchissait.
     *
     * Ce que l'épreuve garde est la règle, pas sa formulation : la porte
     * nomme le geste empêché, et offre toujours une entrée. Si un jour
     * elle n'offrait plus rien, elle redeviendrait le cul-de-sac que ce
     * contrôle existe pour empêcher.
     */
    const gate = readFileSync('src/components/AppGate.tsx', 'utf-8')
    expect(gate).toContain('action')
    expect(gate).toContain('/inscription')
    expect(gate).toContain('/connexion')
  })
})
