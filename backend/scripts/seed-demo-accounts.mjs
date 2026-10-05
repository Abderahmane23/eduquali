/**
 * Cree les comptes de demonstration dans un projet Supabase.
 *
 * --- Pourquoi un script et non du SQL -------------------------------------
 *
 * `teachers.user_id` est `not null references profiles (id)`, et
 * `profiles.id` reference `auth.users (id)`. Une fiche de professeur ne peut
 * donc pas exister sans compte d'authentification, et un compte
 * d'authentification ne se cree pas en SQL : il passe par l'API
 * d'administration de Supabase. C'est la raison pour laquelle `seed.sql`
 * s'arrete au referentiel, aux etablissements et aux offres — tout ce qui ne
 * demande pas de compte.
 *
 * Sans ce script, un projet frais affiche un referentiel complet et **aucun
 * professeur** : ni fiche, ni cours a domicile, ni cours video. Le site a
 * l'air casse alors qu'il est seulement vide.
 *
 * --- Ce qu'il exige -------------------------------------------------------
 *
 * La cle `service_role`, qui passe outre RLS. Elle vit dans `backend/.env` et
 * **nulle part ailleurs** : jamais dans un bundle, jamais dans un APK, jamais
 * dans le depot. C'est la seule cle capable de creer un compte, et la seule
 * qu'une fuite rendrait catastrophique.
 *
 *   SUPABASE_URL=https://xxxx.supabase.co
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ...
 *
 * --- Ce qu'il cree --------------------------------------------------------
 *
 * Pour chaque professeur de demonstration : un compte, un profil, une fiche,
 * ses matieres, ses classes, ses certifications, son parcours, puis son offre
 * de cours a domicile. Ensuite les cours video avec leurs chapitres, et les
 * mises en avant des etablissements.
 *
 * Idempotent : un deuxieme appel retrouve les comptes par leur courriel et
 * met a jour les lignes au lieu de les empiler.
 *
 * --- A ne pas faire -------------------------------------------------------
 *
 * Ne pas lancer ce script sur la base qui portera de vrais comptes. Les
 * professeurs sont inventes et leurs parcours nomment des etablissements
 * reels ; les mises en avant annoncent des bourses que personne n'a decidees.
 * C'est acceptable sur une base de demonstration, pas ailleurs.
 *
 * Usage : node scripts/seed-demo-accounts.mjs
 */

import { createClient } from '@supabase/supabase-js'
import { readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const racine = join(here, '..', '..')

// --- Configuration --------------------------------------------------------

/** Lit `backend/.env` sans dependance : deux lignes suffisent. */
function lireEnv() {
  const valeurs = { ...process.env }
  try {
    const texte = readFileSync(join(here, '..', '.env'), 'utf8')
    for (const ligne of texte.split('\n')) {
      const m = ligne.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/)
      if (m) valeurs[m[1]] ??= m[2].replace(/^["']|["']$/g, '')
    }
  } catch {
    // Pas de fichier : les variables d'environnement suffisent.
  }
  return valeurs
}

const env = lireEnv()
const url = env.SUPABASE_URL
const serviceKey = env.SUPABASE_SERVICE_ROLE_KEY

if (!url || !serviceKey) {
  console.error(
    'Il manque SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY.\n' +
      'Les deux se trouvent dans Supabase > Project Settings > API.\n' +
      'A ecrire dans backend/.env, que .gitignore couvre.',
  )
  process.exit(1)
}

const db = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

/**
 * Le mot de passe des comptes de demonstration.
 *
 * Le meme que celui du client web (`transitionalSecret`), parce que c'est
 * ainsi qu'on pourra se connecter a un compte de demonstration depuis le site.
 * Ce n'est pas un secret : il est ecrit dans le bundle. Il ne tient que tant
 * que personne de reel n'a de compte.
 */
const MOT_DE_PASSE = 'eduquali-sans-sms-2026'

/** Le courriel deduit d'un numero, exactement comme le fait le site. */
const courrielDe = (telephone) =>
  `${telephone.replace(/\D/g, '')}@telephone.eduquali.gn`

// --- Donnees --------------------------------------------------------------

const catalogue = JSON.parse(
  readFileSync(join(racine, 'shared', 'seed', 'catalog.json'), 'utf8'),
)

// --- Outils ---------------------------------------------------------------

let echecs = 0

function echec(ou, erreur) {
  echecs++
  console.error(`  ! ${ou} : ${erreur.message ?? erreur}`)
}

/**
 * Retrouve ou cree le compte d'authentification d'un numero.
 *
 * `createUser` echoue si le courriel existe deja ; on liste alors pour
 * retrouver l'identifiant, plutot que de traiter l'echec comme une erreur.
 * Sans cela, un deuxieme appel du script s'arreterait au premier professeur.
 */
async function compteDe(telephone) {
  const email = courrielDe(telephone)
  const { data, error } = await db.auth.admin.createUser({
    email,
    password: MOT_DE_PASSE,
    // Sans cela le compte reste « non confirme » et la connexion est refusee.
    // Il n'y a pas de boite aux lettres derriere ce courriel : c'est un
    // identifiant deduit du numero, pas une adresse.
    email_confirm: true,
  })
  if (!error && data?.user) return data.user.id

  const { data: liste, error: erreurListe } =
    await db.auth.admin.listUsers({ page: 1, perPage: 1000 })
  if (erreurListe) throw erreurListe
  const existant = liste.users.find((u) => u.email === email)
  if (existant) return existant.id
  throw error ?? new Error(`compte introuvable pour ${email}`)
}

/** `upsert` sur une table, en signalant l'echec sans arreter le script. */
async function poser(table, lignes, conflit = 'id') {
  if (lignes.length === 0) return
  const { error } = await db.from(table).upsert(lignes, {
    onConflict: conflit,
  })
  if (error) echec(table, error)
}

// --- Professeurs ----------------------------------------------------------

console.log(`Projet : ${url}`)
console.log(`${catalogue.demoTeachers.length} professeurs de demonstration\n`)

for (const t of catalogue.demoTeachers) {
  const nom = `${t.firstName} ${t.lastName}`
  try {
    const userId = await compteDe(t.phone)

    await poser('profiles', [
      {
        id: userId,
        role: 'TEACHER',
        phone: t.phone,
        first_name: t.firstName,
        last_name: t.lastName,
        city: t.city ?? null,
        phone_verified: true,
      },
    ])

    await poser('teachers', [
      {
        id: t.id,
        user_id: userId,
        headline: t.headline ?? null,
        bio: t.bio ?? null,
        city: t.city ?? null,
        years_experience: t.yearsExperience ?? 0,
        availability: t.availability ?? 'AVAILABLE',
        identity_status: t.identityStatus ?? 'NONE',
        diploma_status: t.diplomaStatus ?? 'NONE',
        preferred_institution_types: (
          t.preferredInstitutionTypes ?? []
        ).join(','),
      },
    ])

    // Identifiants deduits plutot que tires au hasard : le script se rejoue,
    // et des identifiants neufs empileraient les lignes a chaque appel.
    await poser(
      'teacher_subjects',
      (t.subjects ?? []).map((subjectId) => ({
        id: `${t.id}_${subjectId}`,
        teacher_id: t.id,
        subject_id: subjectId,
      })),
    )

    await poser(
      'teacher_levels',
      (t.levels ?? []).map(([subjectId, levelId]) => ({
        id: `${t.id}_${subjectId}_${levelId}`,
        teacher_id: t.id,
        subject_id: subjectId,
        level_id: levelId,
      })),
    )

    await poser(
      'teacher_certifications',
      (t.certifications ?? []).map((c) => ({
        id: `${t.id}_cert_${c.subjectId}_${c.levelId}`,
        teacher_id: t.id,
        subject_id: c.subjectId,
        level_id: c.levelId,
        score: c.score,
      })),
    )

    await poser(
      'teacher_experiences',
      (t.experiences ?? []).map((x, i) => ({
        id: `${t.id}_xp${i + 1}`,
        teacher_id: t.id,
        institution_name: x.institutionName,
        position: x.position,
        city: x.city ?? null,
        start_date: `${x.startYear}-09-01`,
        end_date: x.endYear ? `${x.endYear}-06-30` : null,
        is_current: x.endYear == null,
        verification_status: x.verified ? 'VERIFIED' : 'PENDING',
      })),
    )

    console.log(`  ${nom}`)
  } catch (erreur) {
    echec(nom, erreur)
  }
}

// --- Cours a domicile -----------------------------------------------------

const offres = catalogue.tutoringServices ?? []
await poser(
  'tutoring_services',
  offres.map((o) => ({
    id: o.id,
    teacher_id: o.teacherId,
    subject_id: o.subjectId,
    // Colonnes `text[]` cote serveur, listes cote JSON : la correspondance est
    // directe, contrairement au telephone qui les aplatit en chaine.
    level_ids: o.levelIds ?? [],
    mode: o.mode ?? 'AT_STUDENT',
    hourly_rate: o.hourlyRate ?? null,
    city: o.city ?? null,
    districts: o.districts ?? [],
    availability_note: o.availabilityNote ?? null,
    description: o.description ?? null,
    active: true,
  })),
)
console.log(`\n${offres.length} offres de cours a domicile`)

// --- Cours video et leur sommaire ----------------------------------------

const cours = catalogue.videoCourses ?? []
await poser(
  'video_courses',
  cours.map((c) => ({
    id: c.id,
    teacher_id: c.teacherId,
    title: c.title,
    description: c.description ?? null,
    subject_id: c.subjectId ?? null,
    level_ids: (c.levelIds ?? []).join(','),
    price: c.price ?? 0,
    status: c.status ?? 'PUBLISHED',
  })),
)

const chapitres = []
const elements = []
for (const c of cours) {
  for (const [rang, chapitre] of (c.chapters ?? []).entries()) {
    // Les memes identifiants que le semis du telephone : les deux clients
    // designent le meme chapitre par le meme identifiant.
    const chapitreId = `${c.id}_ch${rang + 1}`
    chapitres.push({
      id: chapitreId,
      course_id: c.id,
      title: chapitre.title,
      description: chapitre.description ?? null,
      position: rang,
    })
    for (const [i, element] of (chapitre.items ?? []).entries()) {
      elements.push({
        id: `${chapitreId}_it${i + 1}`,
        chapter_id: chapitreId,
        kind: element.kind ?? 'VIDEO',
        title: element.title,
        duration_seconds: element.durationSeconds ?? null,
        position: i,
      })
    }
  }
}
await poser('course_chapters', chapitres)
await poser('course_items', elements)
console.log(
  `${cours.length} cours video, ${chapitres.length} chapitres, ` +
    `${elements.length} elements`,
)

// --- Mises en avant -------------------------------------------------------

const promotions = catalogue.promotions ?? []
await poser(
  'promotions',
  promotions.map((p) => ({
    id: p.id,
    institution_id: p.institutionId,
    title: p.title,
    message: p.message ?? null,
    status: p.status ?? 'ACTIVE',
  })),
)
console.log(`${promotions.length} mises en avant`)

// --- Bilan ----------------------------------------------------------------

console.log('')
if (echecs > 0) {
  console.error(
    `${echecs} echec(s). Les plus probables :\n` +
      '  - seed.sql n\'a pas ete charge : une matiere ou un etablissement\n' +
      '    reference n\'existe pas encore ;\n' +
      '  - le schema n\'est pas a jour : relancer eduquali_schema.sql.',
  )
  process.exit(1)
}
console.log('Comptes de demonstration en place.')
console.log('Connexion a un compte de demonstration :')
console.log('  numero       : un de ceux listes ci-dessus')
console.log(`  mot de passe : ${MOT_DE_PASSE}`)
console.log('')
console.log(
  'Depuis le 02/10 le mot de passe est obligatoire : il n’y a plus de ' +
    'connexion sur le numero seul, ni sur le site ni sur le telephone.',
)
