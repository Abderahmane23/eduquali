/**
 * Genere `seed.sql` a partir des fichiers de donnees partages.
 *
 * Le referentiel (matieres, niveaux, banques de questions) est deja decrit
 * dans `public/data`, qui alimente aussi l'application mobile. Le regenerer
 * plutot que de le retranscrire evite qu'une troisieme copie ne diverge.
 *
 * Usage : node supabase/generate-seed.mjs
 */

import { readFileSync, writeFileSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
// La source unique, partagee par les deux clients et par ce script.
//
// Elle a bouge deux fois : `backend/public/data` (disparu, le script
// echouait a chaque appel), puis les assets du mobile. Elle vit desormais
// dans `shared/seed/`, d'ou `shared/onboarding/sync.mjs` la recopie vers les
// deux clients — qui avaient diverge de onze matieres sans que rien ne le
// dise.
const dataDir = join(here, '..', '..', 'shared', 'seed')

const read = (name) => JSON.parse(readFileSync(join(dataDir, name), 'utf8'))

/** Echappement SQL : une apostrophe dans un enonce suffirait a tout casser. */
const q = (value) => {
  if (value === null || value === undefined) return 'null'
  if (typeof value === 'number') return String(value)
  if (typeof value === 'boolean') return value ? 'true' : 'false'
  return `'${String(value).replace(/'/g, "''")}'`
}

const arr = (values) =>
  values.length === 0
    ? "'{}'"
    : `array[${values.map((v) => q(v)).join(', ')}]::text[]`

const catalog = read('catalog.json')
const lines = []

lines.push(
  '-- Genere par supabase/generate-seed.mjs — ne pas modifier a la main.',
  '-- Referentiel et donnees de demonstration, identiques a ceux du mobile.',
  '',
  'begin;',
  '',
)

// --- Matieres et niveaux ---------------------------------------------------

lines.push('-- Matieres (§8)')
for (const s of catalog.subjects) {
  lines.push(
    `insert into subjects (id, name, code, sort_order) values (${q(s.id)}, ${q(s.name)}, ${q(s.code)}, ${s.order})`,
    '  on conflict (id) do update set name = excluded.name, sort_order = excluded.sort_order;',
  )
}
lines.push('')

/*
 * Niveaux (§9) — avec leur cycle et leur role de regroupement.
 *
 * `cycle` et `grouping` existent en base depuis la migration 0006 et **n'ont
 * jamais ete semes** : chaque niveau avait `cycle = ''` et `grouping = false`.
 * Le defaut etait invisible parce que les deux clients lisent ces champs depuis
 * `catalog.json`, pas depuis la base — mais toute requete serveur voulant
 * filtrer par palier (« pas de professeur d'universite pour un eleve de 9eme »)
 * n'avait rien sur quoi s'appuyer.
 *
 * Les cinq paliers de l'inscription s'appuient sur `cycle` : PRIMAIRE, COLLEGE,
 * LYCEE, SUPERIEUR, DIPLOME.
 */
lines.push('-- Niveaux (§9)')
for (const l of catalog.levels) {
  lines.push(
    `insert into levels (id, name, code, category, sort_order, cycle, grouping) values (${q(l.id)}, ${q(l.name)}, ${q(l.code)}, ${q(l.category)}, ${l.order}, ${q(l.cycle ?? '')}, ${q(Boolean(l.grouping))})`,
    '  on conflict (id) do update set name = excluded.name,',
    '    sort_order = excluded.sort_order, category = excluded.category,',
    '    cycle = excluded.cycle, grouping = excluded.grouping;',
  )
}
lines.push('')

// --- Tests et questions ----------------------------------------------------

lines.push('-- Tests et banques de questions (§10)')
for (const test of catalog.tests) {
  const bank = read(test.bank)
  lines.push(
    `insert into tests (id, subject_id, level_id, title, question_count, duration_minutes, passing_score, rules)`,
    `  values (${q(test.id)}, ${q(test.subjectId)}, ${q(test.levelId)}, ${q(bank.title)}, ${bank.questions.length}, ${bank.durationMinutes}, ${bank.passingScore}, ${q(bank.rules ?? null)})`,
    '  on conflict (id) do update set',
    '    title = excluded.title, question_count = excluded.question_count,',
    '    duration_minutes = excluded.duration_minutes, passing_score = excluded.passing_score;',
  )

  bank.questions.forEach((question, index) => {
    const options = question.o.map((text, i) => ({
      key: String.fromCharCode(65 + i),
      text,
    }))
    lines.push(
      `insert into test_questions (id, test_id, statement, options, correct_key, domain, position, difficulty, explanation)`,
      `  values (${q(`${test.id}_q${index + 1}`)}, ${q(test.id)}, ${q(question.q)}, ${q(JSON.stringify(options))}::jsonb, ${q(question.a)}, ${q(question.d)}, ${index}, ${question.x ?? 2}, ${q(question.e ?? null)})`,
      '  on conflict (id) do update set statement = excluded.statement, options = excluded.options,',
      '    correct_key = excluded.correct_key, explanation = excluded.explanation;',
    )
  })
  lines.push('')
}

// --- Etablissements et offres ----------------------------------------------

lines.push('-- Etablissements de demonstration')
for (const i of catalog.institutions) {
  lines.push(
    `insert into institutions (id, name, type, city, address, manager_name, description, verification_status,`,
    `                          phone, phone_alt, email, website, founded_year, ownership,`,
    `                          academic_system, degrees, specialties, facilities)`,
    `  values (${q(i.id)}, ${q(i.name)}, ${q(i.type)}, ${q(i.city)}, ${q(i.address ?? null)}, ${q(i.managerName ?? null)}, ${q(i.description ?? null)}, ${q(i.verificationStatus)},`,
    `          ${q(i.phone ?? null)}, ${q(i.phoneAlt ?? null)}, ${q(i.email ?? null)}, ${q(i.website ?? null)}, ${i.foundedYear ?? 'null'}, ${q(i.ownership ?? null)},`,
    `          ${q(i.academicSystem ?? null)}, ${q(i.degrees ?? '')}, ${q(i.specialties ?? '')}, ${q(i.facilities ?? '')})`,
    '  on conflict (id) do update set name = excluded.name, description = excluded.description,',
    '    phone = excluded.phone, phone_alt = excluded.phone_alt, email = excluded.email,',
    '    website = excluded.website, founded_year = excluded.founded_year,',
    '    ownership = excluded.ownership, academic_system = excluded.academic_system,',
    '    degrees = excluded.degrees, specialties = excluded.specialties,',
    '    facilities = excluded.facilities;',
  )
}
lines.push('')

lines.push('-- Offres publiees (§17)')
for (const j of catalog.jobs) {
  lines.push(
    `insert into jobs (id, institution_id, title, subject_id, level_ids, city, contract_type, description,`,
    `                  salary_min, salary_max, salary_published, min_experience, requires_certification,`,
    `                  visibility, status, published_at)`,
    `  values (${q(j.id)}, ${q(j.institutionId)}, ${q(j.title)}, ${q(j.subjectId)}, ${arr(j.levelIds)}, ${q(j.city)}, ${q(j.contractType)}, ${q(j.description ?? null)},`,
    `          ${q(j.salaryMin ?? null)}, ${q(j.salaryMax ?? null)}, ${q(j.salaryPublished ?? false)}, ${j.minExperience ?? 0}, ${q(j.requiresCertification ?? false)},`,
    `          'PUBLIC', 'PUBLISHED', now() - interval '${j.publishedDaysAgo ?? 0} days')`,
    '  on conflict (id) do update set title = excluded.title, description = excluded.description,',
    '    status = excluded.status, published_at = excluded.published_at;',
  )
}
lines.push('')

// --- Les lots de la boutique (D2) -----------------------------------------
//
// `stock` n'est PAS mis a jour par `on conflict` : rejouer le semis sur une base
// en service remettrait les compteurs a leur valeur d'origine, et un lot deja
// remis redeviendrait disponible. Le nom, le prix et l'image se corrigent ; ce
// qui reste en carton appartient a la base.
for (const l of catalog.shopItems ?? []) {
  // La date du tirage est relative au semis : une date fixe serait deja passee
  // a la premiere relecture du fichier, et le lot refuserait toute mise.
  const tirage =
    l.kind === 'RAFFLE' && l.drawsInDays
      ? `now() + interval '${l.drawsInDays} days'`
      : 'null'

  lines.push(
    `insert into shop_items (id, name, summary, image, points_price, value_gnf, stock, position, kind, draws_at)`,
    `  values (${q(l.id)}, ${q(l.name)}, ${q(l.summary ?? null)}, ${q(l.image)},`,
    `          ${l.pointsPrice}, ${l.valueGnf ?? 0}, ${l.stock ?? 0}, ${l.position ?? 0}, ${q(l.kind ?? 'DIRECT')}, ${tirage})`,
    '  on conflict (id) do update set name = excluded.name, summary = excluded.summary,',
    '    image = excluded.image, points_price = excluded.points_price,',
    '    value_gnf = excluded.value_gnf, position = excluded.position,',
    // `kind` se corrige, mais pas `draws_at` : rejouer le semis repousserait la
    // date d'un tirage deja annonce, et les gens l'attendent.
    '    kind = excluded.kind, updated_at = now();',
  )
}
lines.push('')

lines.push('commit;')
lines.push('')

// --- Enseignants de demonstration ------------------------------------------

// Ils dependent de comptes `auth.users`, qui ne peuvent pas etre crees par
// une simple insertion. Le fichier separe est applique apres inscription.
const demo = []
demo.push(
  '-- Enseignants de demonstration.',
  '--',
  '-- A appliquer APRES avoir cree les comptes correspondants via',
  '-- l’inscription par OTP : une fiche enseignant reference un compte',
  '-- `auth.users`, que seule l’authentification peut creer.',
  '--',
  '-- Renseignez ci-dessous l’identifiant du compte, puis executez.',
  '',
)

for (const t of catalog.demoTeachers) {
  demo.push(
    `-- ${t.firstName} ${t.lastName} — ${t.headline}`,
    `-- select seed_demo_teacher('<uuid du compte>', ${q(t.id)});`,
  )
}
demo.push('')
demo.push(
  'create or replace function seed_demo_teacher(account uuid, teacher text)',
  'returns void as $$',
  'begin',
  '  -- Laisse au deploiement le soin de rattacher la fiche au compte cree.',
  '  update teachers set user_id = account where id = teacher;',
  'end;',
  '$$ language plpgsql;',
)

writeFileSync(join(here, 'seed.sql'), lines.join('\n'), 'utf8')
writeFileSync(join(here, 'seed_demo_teachers.sql'), demo.join('\n'), 'utf8')

/*
 * --- Le programme scolaire -------------------------------------------------
 *
 * Dans SON fichier, et non dans `seed.sql`. Trois raisons, et la premiere est
 * la plus pratique :
 *
 *   * `seed.sql` se colle a la main dans l'editeur SQL de Supabase
 *     (documentation/DEPLOIEMENT.md). Y ajouter 348 chapitres le rendrait
 *     penible a manipuler pour un contenu qui n'a rien a voir avec les donnees
 *     de demonstration ;
 *   * le programme a son propre rythme : il se regenere quand les fichiers de
 *     `ressource_matières/` changent, pas quand on ajoute un etablissement de
 *     demonstration ;
 *   * il doit pouvoir etre rejoue seul, sur une base en service, sans toucher
 *     au reste. D'ou les `on conflict` ci-dessous.
 *
 * Le depot a deja ce decoupage (`seed_demo_teachers.sql`), pour la meme raison.
 */
const programme = JSON.parse(
  readFileSync(
    join(here, '..', '..', 'shared', 'curriculum', 'guinea.json'),
    'utf8',
  ),
)

const curriculum = [
  '-- Programme scolaire guineen — GENERE, ne pas modifier a la main.',
  '--',
  '-- Source : shared/curriculum/guinea.json, lui-meme construit par',
  '-- shared/curriculum/build.mjs depuis ressource_matières/.',
  '--',
  '-- ⚠ CE N EST PAS UNE PUBLICATION OFFICIELLE DU MINISTERE. Les sources',
  '-- consultees ne contiennent pas de programme ministeriel unique couvrant',
  '-- toutes les matieres et toutes les classes. Chaque ligne porte son',
  '-- content_status et sa source.',
  '--',
  '-- Rejouable : les `on conflict` mettent a jour au lieu d echouer, donc ce',
  '-- fichier se repasse sur une base en service quand le programme change.',
  '',
  'begin;',
  '',
]

// Les sources d'abord : les chapitres y font reference dans leurs commentaires.
curriculum.push('-- Provenance des donnees')
for (const source of programme.sources ?? []) {
  curriculum.push(
    'insert into curriculum_sources (id, kind, title, url, used_for) values (' +
      [
        q(source.id),
        q(source.type ?? 'web'),
        q(source.title),
        q(source.url ?? null),
        q(source.use ?? null),
      ].join(', ') +
      ')',
    '  on conflict (id) do update set title = excluded.title, ' +
      'url = excluded.url, used_for = excluded.used_for;',
  )
}
curriculum.push('')

// Les chapitres.
curriculum.push('-- Chapitres du programme')
let nbChapitres = 0
let nbSous = 0
for (const matiere of programme.subjects ?? []) {
  for (const [levelId, chapitres] of Object.entries(
    matiere.chaptersByLevel ?? {},
  )) {
    for (const chapitre of chapitres) {
      nbChapitres += 1
      nbSous += (chapitre.subchapters ?? []).length
      curriculum.push(
        'insert into curriculum_chapters (subject_id, level_id, position, ' +
          'title, summary, subchapters, outcome, content_status, source_ref) ' +
          'values (' +
          [
            q(matiere.id),
            q(levelId),
            chapitre.order,
            q(chapitre.title),
            q(chapitre.summary ?? null),
            arr(chapitre.subchapters ?? []),
            q(chapitre.outcome ?? null),
            q(matiere.contentStatus ?? 'partiel'),
            q(chapitre.source ?? null),
          ].join(', ') +
          ')',
        '  on conflict (subject_id, level_id, position) do update set',
        '    title = excluded.title, summary = excluded.summary,',
        '    subchapters = excluded.subchapters, outcome = excluded.outcome,',
        '    content_status = excluded.content_status,',
        '    source_ref = excluded.source_ref, updated_at = now();',
      )
    }
  }
}
curriculum.push('')

/*
 * Les manuels.
 *
 * `subject_id` est deduit du libelle quand il correspond a une matiere du
 * referentiel, et laisse nul sinon : « Sciences physiques et biologie » en
 * couvre deux, et en choisir une au hasard rattacherait le manuel a la mauvaise.
 */
const parNom = new Map(
  catalog.subjects.map((m) => [m.name.toLowerCase(), m.id]),
)
const alias = new Map([
  ['mathématiques', 'sub_math'],
  ['mathematiques', 'sub_math'],
  ['français', 'sub_fran'],
  ['francais', 'sub_fran'],
  ['anglais', 'sub_angl'],
  ['physique', 'sub_phys'],
  ['chimie', 'sub_chim'],
  ['biologie', 'sub_biol'],
  ['histoire', 'sub_hist'],
  ['géographie', 'sub_geog'],
  ['philosophie', 'sub_philo'],
  ['arabe', 'sub_arab'],
])

curriculum.push('-- Manuels de reference')
for (const livre of programme.textbooks ?? []) {
  const cle = (livre.subject ?? '').trim().toLowerCase()
  const subjectId = parNom.get(cle) ?? alias.get(cle) ?? null
  curriculum.push(
    'insert into curriculum_textbooks (subject_id, subject_label, title, ' +
      'levels_label, status_note) values (' +
      [
        q(subjectId),
        q(livre.subject),
        q(livre.title),
        q(livre.levels ?? null),
        q(livre.status ?? null),
      ].join(', ') +
      ')',
    '  on conflict (subject_label, title) do update set',
    '    subject_id = excluded.subject_id,',
    '    levels_label = excluded.levels_label,',
    '    status_note = excluded.status_note;',
  )
}

curriculum.push('', 'commit;', '')

writeFileSync(
  join(here, 'seed_curriculum.sql'),
  curriculum.join('\n'),
  'utf8',
)



const questionCount = catalog.tests.reduce(
  (sum, t) => sum + read(t.bank).questions.length,
  0,
)

console.log('seed.sql genere :')
console.log(`  ${catalog.subjects.length} matieres`)
console.log(`  ${catalog.levels.length} niveaux, ${(catalog.stages ?? []).length} paliers`)
console.log(`  ${catalog.tests.length} tests, ${questionCount} questions`)
console.log(`  ${catalog.institutions.length} etablissements`)
console.log(`  ${(catalog.shopItems ?? []).length} lots de la boutique`)
console.log(`  ${catalog.jobs.length} offres`)
console.log('seed_curriculum.sql genere :')
console.log(
  `  ${(programme.subjects ?? []).length} matieres, ${nbChapitres} chapitres, ` +
    `${nbSous} sous-chapitres`,
)
console.log(
  `  ${(programme.textbooks ?? []).length} manuels, ` +
    `${(programme.sources ?? []).length} sources`,
)
console.log(`  fichiers dans ${readdirSync(here).join(', ')}`)
