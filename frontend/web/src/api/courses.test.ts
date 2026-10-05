import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

/**
 * La vitrine des cours video.
 *
 * Le programme est public — on doit savoir ce qu'on achete — et le fichier ne
 * l'est pas. Toute la valeur du cours tient dans cette ligne : si elle bouge,
 * le cours est gratuit pour qui sait interroger PostgREST avec la cle anonyme,
 * et la cle anonyme est dans le code du site.
 */
/**
 * Lit un fichier source **sans ses commentaires**, et avec des fins de ligne
 * normalisees.
 *
 * Les deux comptent. Sans le premier, ce test echouait sur sa propre
 * documentation : le commentaire de `courseProgramme` explique precisement que
 * `local_path` et `remote_url` ne doivent pas sortir, et la recherche trouvait
 * ces mots dans la phrase qui les interdit. Sans le second, un `toContain` qui
 * couvre deux lignes echoue sous Windows, ou les fichiers sont en CRLF.
 */
function code(chemin: string): string {
  return readFileSync(chemin, 'utf-8')
    .replace(/\r\n/g, '\n')
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^[ \t]*\/\/.*$/gm, '')
}

const supabase = code('src/api/supabase.ts')
const migration = readFileSync(
  '../../backend/supabase/migrations/0010_course_content.sql',
  'utf-8',
).replace(/\r\n/g, '\n')
const catalogue = JSON.parse(
  readFileSync('public/data/catalog.json', 'utf-8'),
) as {
  videoCourses?: {
    id: string
    teacherId: string
    status: string
    price: number
    chapters: { title: string; items: { kind: string; title: string }[] }[]
  }[]
  demoTeachers: { id: string }[]
}

describe('le sommaire public', () => {
  it('se lit dans la vue, jamais dans la table', () => {
    // `course_items` porte `local_path` et `remote_url`. La vue
    // `course_item_titles` n'expose que le titre, le genre et la duree.
    const bloc = supabase.slice(
      supabase.indexOf('async videoCourses'),
      supabase.indexOf('// --- Enseignants'),
    )
    expect(bloc).toContain('course_item_titles')
    expect(bloc).not.toMatch(/from\('course_items'\)/)
    expect(bloc).not.toMatch(/local_path/)
    expect(bloc).not.toMatch(/remote_url/)
  })

  it('la vue serveur ne rend pas le fichier', () => {
    const vue = migration.slice(
      migration.indexOf('create or replace view course_item_titles'),
      migration.indexOf('alter view course_item_titles'),
    )
    expect(vue).toContain('ci.title')
    expect(vue).toContain('ci.duration_seconds')
    expect(vue).not.toMatch(/local_path/)
    expect(vue).not.toMatch(/remote_url/)
    // Et seulement pour un cours en vente : un brouillon n'est pas une
    // vitrine.
    expect(vue).toContain("v.status = 'PUBLISHED'")
  })

  it('ne montre que les cours en vente', () => {
    const bloc = supabase.slice(
      supabase.indexOf('async videoCourses'),
      supabase.indexOf('async videoCourse('),
    )
    expect(bloc).toContain("eq('status', 'PUBLISHED')")
  })

  it('compte le sommaire en deux requêtes, pas une par cours', () => {
    // Une vitrine de vingt cours ferait vingt-et-un allers-retours sur une
    // connexion guinéenne.
    const bloc = supabase.slice(
      supabase.indexOf('async videoCourses'),
      supabase.indexOf('async videoCourse('),
    )
    // Deux `in(...)` : les chapitres de tous les cours, puis les elements de
    // tous les chapitres. Une boucle en ferait un par cours.
    expect(bloc.match(/\.in\(/g) ?? []).toHaveLength(2)
    expect(bloc).toContain("'course_id'")
    expect(bloc).toContain("'chapter_id'")
  })
})

describe('les cours de démonstration', () => {
  const cours = catalogue.videoCourses ?? []

  it('existent dans le référentiel partagé', () => {
    // Sans eux, la vitrine est vide sur le site de démonstration et l'onglet
    // « Cours vidéo » est vide sur un téléphone neuf : personne ne peut voir à
    // quoi ressemble le produit.
    expect(cours.length).toBeGreaterThanOrEqual(3)
  })

  it('appartiennent à des professeurs qui existent', () => {
    const enseignants = new Set(catalogue.demoTeachers.map((t) => t.id))
    for (const c of cours) {
      expect(enseignants.has(c.teacherId), `${c.id} sans professeur`).toBe(true)
    }
  })

  it('ont un programme et un prix', () => {
    for (const c of cours) {
      expect(c.status).toBe('PUBLISHED')
      expect(c.price, `${c.id} sans prix`).toBeGreaterThan(0)
      expect(c.chapters.length, `${c.id} sans chapitre`).toBeGreaterThan(0)
      for (const chapitre of c.chapters) {
        // Un chapitre vide s'afficherait comme une ligne sur laquelle on ne
        // peut pas cliquer.
        expect(chapitre.items.length, `${c.id} : chapitre vide`).toBeGreaterThan(
          0,
        )
      }
      // Au moins une vidéo : un « cours vidéo » sans vidéo ne vaut pas son nom.
      const videos = c.chapters.flatMap((ch) =>
        ch.items.filter((i) => i.kind === 'VIDEO'),
      )
      expect(videos.length, `${c.id} sans vidéo`).toBeGreaterThan(0)
    }
  })

  it('ne prétendent pas porter un fichier', () => {
    // Les vidéos de démonstration n'ont pas de fichier, et c'est assumé : un
    // fichier dans l'APK pèserait pour montrer une image noire. Y mettre une
    // adresse inventée ferait échouer la lecture au lieu de l'annoncer.
    const brut = JSON.stringify(cours)
    expect(brut).not.toContain('localPath')
    expect(brut).not.toContain('remoteUrl')
    expect(brut).not.toContain('.mp4')
  })
})
