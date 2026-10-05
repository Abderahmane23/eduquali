#!/usr/bin/env node
/**
 * Recopie les parcours d'inscription vers les deux clients.
 *
 * La source vit dans `shared/onboarding/`. Les copies sont generees : une
 * modification faite directement dans `public/data/` ou dans `assets/` sera
 * ecrasee au prochain passage, et c'est voulu — c'est la seule facon
 * d'empecher les deux clients de rediverger.
 *
 *   node shared/onboarding/sync.mjs          verifie et recopie
 *   node shared/onboarding/sync.mjs --check  verifie seulement (CI)
 */
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(HERE, '..', '..')

const TARGETS = [
  join(ROOT, 'frontend', 'web', 'public', 'data'),
  join(ROOT, 'frontend', 'mobile', 'assets', 'onboarding'),
]

/**
 * Ou vivent les illustrations referencees par les parcours.
 *
 * Le web les sert directement depuis `public/` ; l'application mobile les
 * embarque. La copie est faite ici pour la meme raison que les parcours :
 * deux jeux d'images finissent toujours par diverger.
 */
const IMAGE_DIR = join(ROOT, 'frontend', 'web', 'public', 'img')
const IMAGE_TARGET = join(ROOT, 'frontend', 'mobile', 'assets', 'img')

/**
 * Decoupage administratif, recopie comme les parcours.
 *
 * Les listes de prefectures ne vivent pas dans le JSON d'un parcours : elles
 * servent aux trois profils, et une liste recopiee trois fois finit par
 * differer.
 */
const GEO_SOURCE = join(ROOT, 'shared', 'geography', 'guinea.json')
const GEO_TARGETS = [
  join(ROOT, 'frontend', 'web', 'public', 'data', 'geography'),
  join(ROOT, 'frontend', 'mobile', 'assets', 'geography'),
]

/**
 * Referentiel et donnees de demonstration.
 *
 * Il vivait dans `frontend/mobile/assets/seed/`, et le web en gardait une
 * copie a la main dans `public/data/`. Les deux avaient deja divergé :
 * verifie le 02/10, le catalogue du web ne portait que 13 matieres sur 24 —
 * onze manquaient purement, dont la philosophie, l'EPS et toutes les
 * filieres techniques. Rien ne le signalait, parce qu'une liste plus courte
 * n'est pas une erreur.
 *
 * La source vit donc ici desormais, et les deux clients en recoivent une
 * copie. `backend/supabase/generate-seed.mjs` lit la meme.
 */
const SEED_SOURCE = join(ROOT, 'shared', 'seed')
const SEED_TARGETS = [
  join(ROOT, 'frontend', 'web', 'public', 'data'),
  join(ROOT, 'frontend', 'mobile', 'assets', 'seed'),
]

/**
 * Programme national : les trois profils du lycee.
 *
 * Meme raison que pour le decoupage administratif — c'est un fait fixe, pas
 * une donnee de back-office, et les deux clients doivent le connaitre sans
 * serveur.
 */
const CURRICULUM_SOURCE = join(ROOT, 'shared', 'curriculum', 'guinea.json')
const CURRICULUM_TARGETS = [
  join(ROOT, 'frontend', 'web', 'public', 'data', 'curriculum'),
  join(ROOT, 'frontend', 'mobile', 'assets', 'curriculum'),
]

// --- Creneaux des cours en direct ---------------------------------------
//
// Six creneaux de 90 minutes, lus par le serveur et par les deux clients.

const SLOTS_SOURCE = join(ROOT, 'shared', 'scheduling', 'slots.json')
const SLOTS_TARGETS = [
  join(ROOT, 'frontend', 'web', 'public', 'data', 'scheduling'),
  join(ROOT, 'frontend', 'mobile', 'assets', 'scheduling'),
]

/** Types connus des DEUX clients. Ajouter ici apres les avoir declares. */
const KNOWN_TYPES = new Set([
  'statement',
  'steps_preview',
  'carousel',
  'role_select',
  'form',
  'single_choice',
  'multi_choice',
  'boolean',
  'range',
  'plan_select',
  'upload',
  'day_hours',
])

/** Listes dynamiques que les DEUX clients savent resoudre. */
const KNOWN_SOURCES = new Set([
  'subjects',
  'levels',
  /*
   * Les cinq paliers : PRIMAIRE, COLLEGE, LYCEE, SUPERIEUR, DIPLOME.
   *
   * Declares dans `shared/seed/catalog.json`, et non dans chaque parcours : le
   * parcours enseignant les avait recopies en dur a quatre valeurs (sans
   * « diplome »), et les parcours parent et etudiant listaient les seize classes
   * a plat — un parent d'eleve de CE2 faisait defiler jusqu'a « Master 2 ».
   *
   * L'identifiant d'un palier est la valeur de `cycle` d'un niveau, ce qui fait
   * que `optionsFilter` apparie les deux sans table de correspondance.
   */
  'stages',
  'cities',
  'countries',
  'regions',
  'prefectures',
  'filieres',
  'institutions',
  'institution_roles',
  'featured_teachers',
])

/// Un filtre porte soit un champ, soit plusieurs : les deux formes coexistent.
const filterFields = (filter) =>
  filter == null ? [] : filter.fields ?? [filter.field]

const KNOWN_FIELD_TYPES = new Set([
  'text',
  'phone',
  'dropdown',
  'combo',
  'month',
  // Saisi masque, avec un oeil pour reveler. Pose le 02/10 : sans SMS, le mot
  // de passe est la seule chose qui distingue le proprietaire d'un numero de
  // quelqu'un qui le connait.
  'password',
])

const checkOnly = process.argv.includes('--check')
const problems = []
const specs = []

for (const name of readdirSync(HERE).filter((f) => f.endsWith('.json'))) {
  const path = join(HERE, name)
  let spec
  try {
    spec = JSON.parse(readFileSync(path, 'utf8'))
  } catch (error) {
    problems.push(`${name} : JSON invalide — ${error.message}`)
    continue
  }

  const steps = (spec.sections ?? []).flatMap((s) => s.steps ?? [])
  if (steps.length === 0) problems.push(`${name} : aucune etape`)

  // Champs que le parcours renseigne, plus ceux qu'il declare recevoir de
  // l'exterieur (`externalFields`) : une condition ne peut viser qu'eux.
  // Sans cette declaration, une faute de frappe dans un `showIf` passerait
  // inapercue et ferait disparaitre un ecran en silence.
  const produced = new Set(spec.externalFields ?? [])
  for (const step of steps) {
    if (step.fieldId) produced.add(step.fieldId)
    for (const f of step.fields ?? []) produced.add(f.id)
    for (const u of step.uploads ?? []) produced.add(u.id)
  }

  const ids = new Set()
  for (const step of steps) {
    if (ids.has(step.id)) problems.push(`${name} : etape "${step.id}" en double`)
    ids.add(step.id)

    if (!KNOWN_TYPES.has(step.type)) {
      problems.push(
        `${name} : etape "${step.id}" de type "${step.type}" inconnu des clients`,
      )
    }
    // Une etape `upload` sans fichier declare n'affiche rien du tout.
    if (step.type === 'upload' && (step.uploads ?? []).length === 0) {
      problems.push(`${name} : etape "${step.id}" de type upload sans fichier`)
    }
    for (const upload of step.uploads ?? []) {
      if (!upload.id || !upload.label) {
        problems.push(
          `${name} : un fichier de "${step.id}" n'a ni identifiant ni libelle`,
        )
      }
    }

    // Une etape qui collecte doit dire ou ranger la reponse.
    const collects = ![
      'statement',
      'steps_preview',
      'carousel',
      // `upload` range chaque fichier sous son propre identifiant.
      'upload',
    ].includes(step.type)
    if (collects && step.type !== 'form' && !step.fieldId) {
      problems.push(`${name} : etape "${step.id}" sans fieldId`)
    }
    if (step.showIf) {
      if (!step.showIf.field) {
        problems.push(`${name} : etape "${step.id}" a un showIf sans champ`)
      } else if (!produced.has(step.showIf.field)) {
        problems.push(
          `${name} : etape "${step.id}" depend de "${step.showIf.field}", ` +
            `qu'aucune etape ne renseigne et qui n'est pas declare dans ` +
            `externalFields`,
        )
      }
    }
    // Une source inconnue rend une liste vide, sans aucun message : l'ecran
    // s'affiche alors sans options et personne ne comprend pourquoi.
    for (const source of [step.optionsSource, step.itemsSource]) {
      if (source && !KNOWN_SOURCES.has(source)) {
        problems.push(
          `${name} : etape "${step.id}" lit la liste "${source}", inconnue ` +
            `des clients`,
        )
      }
    }
    for (const f of step.fields ?? []) {
      if (f.optionsSource && !KNOWN_SOURCES.has(f.optionsSource)) {
        problems.push(
          `${name} : champ "${f.id}" lit la liste "${f.optionsSource}", ` +
            `inconnue des clients`,
        )
      }
    }
    // Un filtre qui vise une question inexistante ne filtre rien.
    for (const champ of filterFields(step.optionsFilter)) {
      if (!produced.has(champ)) {
        problems.push(
          `${name} : etape "${step.id}" filtre sur ` +
            `"${champ}", qu'aucune etape ne renseigne`,
        )
      }
    }
    for (const field of step.fields ?? []) {
      if (!KNOWN_FIELD_TYPES.has(field.type)) {
        problems.push(
          `${name} : champ "${field.id}" de type "${field.type}" inconnu`,
        )
      }
      // Meme piege qu'au niveau de l'etape : un filtre en cascade qui vise
      // un champ inexistant laisse la liste entiere, et la commune de
      // Conakry apparait pour un professeur de Labe.
      for (const champ of filterFields(field.optionsFilter)) {
        if (!produced.has(champ)) {
          problems.push(
            `${name} : champ "${field.id}" filtre sur ` +
              `"${champ}", qu'aucune etape ne renseigne`,
          )
        }
      }
    }
    // Une illustration manquante ne casse rien : elle laisse un cadre vide
    // que personne ne remarque avant la mise en ligne.
    if (step.image) {
      if (!step.image.name) {
        problems.push(`${name} : etape "${step.id}" a une image sans nom`)
      } else {
        for (const density of ['', '@2x']) {
          const file = `${step.image.name}${density}.webp`
          if (!existsSync(join(IMAGE_DIR, file))) {
            problems.push(`${name} : etape "${step.id}" reference ${file}, absent`)
          }
        }
      }
      if (!step.image.alt) {
        // Une image sans alternative textuelle est invisible pour un lecteur
        // d'ecran (§7 du design_skill).
        problems.push(`${name} : etape "${step.id}" a une image sans alt`)
      }
    }
    for (const plan of step.plans ?? []) {
      if (!Number.isInteger(plan.price)) {
        // Le franc guineen n'a pas de subdivision en usage : un prix a
        // decimales signale une valeur restee en devise etrangere.
        problems.push(
          `${name} : formule "${plan.value}" a un prix non entier (${plan.price})`,
        )
      }
    }
  }

  specs.push({ name, path, raw: readFileSync(path, 'utf8') })
}

// --- Decoupage administratif ---------------------------------------------

let geoRaw = null
try {
  geoRaw = readFileSync(GEO_SOURCE, 'utf8')
  const geo = JSON.parse(geoRaw)
  const seen = new Set()
  let divisions = 0

  for (const region of geo.regions ?? []) {
    if (!region.code || !region.name) {
      problems.push('guinea.json : une region sans code ou sans nom')
      continue
    }
    if (seen.has(region.code)) {
      problems.push(`guinea.json : code "${region.code}" en double`)
    }
    seen.add(region.code)

    if ((region.divisions ?? []).length === 0) {
      // Une region sans division donne une liste vide a l'ecran suivant :
      // l'inscription se bloque sans rien expliquer.
      problems.push(`guinea.json : region "${region.name}" sans division`)
    }
    for (const division of region.divisions ?? []) {
      if (!division.code || !division.name) {
        problems.push(
          `guinea.json : division sans code ou sans nom dans "${region.name}"`,
        )
        continue
      }
      if (seen.has(division.code)) {
        problems.push(`guinea.json : code "${division.code}" en double`)
      }
      seen.add(division.code)
      divisions++
    }
  }
  if (!problems.length) {
    console.log(
      `${(geo.regions ?? []).length} regions, ${divisions} divisions.`,
    )
  }
} catch (error) {
  problems.push(`guinea.json : illisible — ${error.message}`)
}

// --- Programme national ---------------------------------------------------

let curriculumRaw = null
try {
  curriculumRaw = readFileSync(CURRICULUM_SOURCE, 'utf8')
  const { filieres = [] } = JSON.parse(curriculumRaw)
  if (filieres.length === 0) problems.push('curriculum : aucun profil')

  const seen = new Set()
  for (const f of filieres) {
    if (!f.id || !f.name) {
      problems.push('curriculum : un profil sans identifiant ou sans nom')
      continue
    }
    if (seen.has(f.id)) problems.push(`curriculum : "${f.id}" en double`)
    seen.add(f.id)

    if ((f.levelIds ?? []).length === 0) {
      // Un profil sans classe ne s'afficherait jamais : la question
      // disparaitrait en silence.
      problems.push(`curriculum : "${f.name}" ne vise aucune classe`)
    }
    if ((f.subjectIds ?? []).length === 0) {
      problems.push(`curriculum : "${f.name}" sans matiere`)
    }
    for (const major of f.majorSubjectIds ?? []) {
      if (!(f.subjectIds ?? []).includes(major)) {
        problems.push(
          `curriculum : "${f.name}" a pour majeure "${major}", absente de ` +
            `ses matieres`,
        )
      }
    }
  }
  /*
   * --- Le programme detaille, et les identifiants qu'il cite ---------------
   *
   * Depuis le 03/10, `guinea.json` ne porte plus seulement les trois profils :
   * il porte 15 matieres, 7 classes et plusieurs centaines de chapitres, extraits
   * des fichiers de `ressource_matières/` par `shared/curriculum/build.mjs`.
   *
   * Chaque chapitre cite une matiere et une classe par identifiant. **Ces
   * identifiants doivent exister dans `shared/seed/catalog.json`**, qui est le
   * referentiel dont la base est semee : une matiere inventee passerait toutes
   * les relectures et echouerait sur une cle etrangere au moment du semis, en
   * production, sur un fichier de 180 ko ou personne n'irait chercher.
   *
   * C'est un controle entre deux fichiers que personne ne lit ensemble. Il n'a
   * donc aucune autre place que celle-ci.
   */
  const programme = JSON.parse(curriculumRaw)
  const catalogue = JSON.parse(
    readFileSync(join(ROOT, 'shared', 'seed', 'catalog.json'), 'utf8'),
  )
  const matieresConnues = new Set((catalogue.subjects ?? []).map((m) => m.id))
  const classesConnues = new Set((catalogue.levels ?? []).map((n) => n.id))

  let chapitres = 0
  let sousChapitres = 0
  const inconnus = new Set()

  for (const matiere of programme.subjects ?? []) {
    if (!matieresConnues.has(matiere.id)) {
      inconnus.add(`matiere ${matiere.id}`)
    }
    for (const [classeId, liste] of Object.entries(
      matiere.chaptersByLevel ?? {},
    )) {
      if (!classesConnues.has(classeId)) inconnus.add(`classe ${classeId}`)
      for (const chapitre of liste) {
        chapitres += 1
        sousChapitres += (chapitre.subchapters ?? []).length
        if (!chapitre.title) {
          problems.push(
            `curriculum : un chapitre sans titre dans ${matiere.id}/${classeId}`,
          )
        }
      }
    }
  }

  for (const inconnu of inconnus) {
    problems.push(
      `curriculum : ${inconnu} absente de shared/seed/catalog.json — ` +
        'le semis echouera sur une cle etrangere',
    )
  }

  // Les profils citent aussi des matieres : les verifier evite qu'une question
  // d'inscription propose une matiere qui n'existe pas en base.
  for (const f of filieres) {
    for (const id of f.subjectIds ?? []) {
      if (!matieresConnues.has(id)) {
        problems.push(`curriculum : "${f.name}" cite la matiere inconnue ${id}`)
      }
    }
  }

  /*
   * L'avertissement doit survivre.
   *
   * Ce fichier est une compilation, pas une publication ministerielle — les
   * sources elles-memes le disent. Si quelqu'un retire l'avertissement, les deux
   * clients presenteraient la chose comme officielle a des professeurs qui
   * preparent leurs cours dessus.
   */
  if (!programme.disclaimer || programme.disclaimer.length < 40) {
    problems.push(
      'curriculum : l’avertissement « ce n’est pas une publication officielle » ' +
        'a disparu',
    )
  }
  if ((programme.qualityFlags ?? []).length === 0) {
    problems.push('curriculum : les reserves de qualite ont disparu')
  }

  if (!problems.length) {
    console.log(
      `${filieres.length} profils de lycee, ${(programme.subjects ?? []).length} ` +
        `matieres, ${chapitres} chapitres, ${sousChapitres} sous-chapitres.`,
    )
  }
} catch (error) {
  problems.push(`curriculum : illisible — ${error.message}`)
}

/*
 * --- Un fichier copie dans assets/ doit etre declare dans pubspec.yaml ----
 *
 * Flutter n'embarque que les dossiers listes sous `assets:`. Un fichier ecrit
 * ailleurs existe sur le disque du developpeur, passe toutes les relectures, et
 * **manque dans l'APK** : la lecture leve a l'execution, chez l'usager, sur
 * l'ecran qui en depend.
 *
 * C'est exactement ce qui s'est passe avec `assets/scheduling/slots.json`,
 * recopie ici depuis le 02/10 et jamais declare. Rien ne l'a signale parce que
 * rien ne le lisait encore — le defaut attendait le premier ecran de cours en
 * direct.
 *
 * Ce controle est structurel : il relie deux fichiers que personne ne lit
 * ensemble.
 */
const PUBSPEC = join(ROOT, 'frontend', 'mobile', 'pubspec.yaml')
try {
  const pubspec = readFileSync(PUBSPEC, 'utf8')
  const declares = new Set(
    [...pubspec.matchAll(/^\s*-\s*(assets\/[\w./-]*)$/gm)].map((m) =>
      m[1].replace(/\/$/, ''),
    ),
  )

  for (const cible of SLOTS_TARGETS) {
    // Seules les cibles mobiles sont concernees : le site sert `public/`
    // directement, sans declaration.
    const normalise = cible.replace(/\\/g, '/')
    const marque = normalise.indexOf('/assets/')
    if (marque === -1) continue
    const chemin = normalise.slice(marque + 1)
    if (!declares.has(chemin.replace(/\/$/, ''))) {
      problems.push(
        `assets : « ${chemin}/ » recoit un fichier mais n'est pas declare dans ` +
          'frontend/mobile/pubspec.yaml — il ne sera pas embarque dans l\'APK',
      )
    }
  }
} catch (error) {
  problems.push(`assets : ${PUBSPEC} illisible (${error.message})`)
}

// --- Creneaux : la regle des 90 minutes se verifie ici ------------------
//
// C'est le seul endroit ou elle peut l'etre mecaniquement. Un creneau plus
// court qu'une seance ne se verrait sinon qu'au moment ou un cours serait
// coupe en plein milieu.

let slotsRaw = null
try {
  slotsRaw = readFileSync(SLOTS_SOURCE, 'utf8')
  const { sessionMinutes, slots = [] } = JSON.parse(slotsRaw)

  if (typeof sessionMinutes !== 'number' || sessionMinutes <= 0) {
    problems.push('creneaux : sessionMinutes manquant ou invalide')
  }
  if (slots.length === 0) problems.push('creneaux : aucun creneau')

  /** « 18:30 » -> 1110 minutes depuis minuit. */
  const minutesOf = (heure) => {
    const m = /^(\d{1,2}):(\d{2})$/.exec(heure ?? '')
    return m ? Number(m[1]) * 60 + Number(m[2]) : null
  }

  const vus = new Set()
  const JOURS = new Set(['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'])
  let occurrences = 0

  for (const slot of slots) {
    const nom = slot.id ?? '(sans id)'
    if (!slot.id || vus.has(slot.id)) {
      problems.push(`creneaux : identifiant manquant ou en double (${nom})`)
    }
    vus.add(slot.id)

    const debut = minutesOf(slot.start)
    const fin = minutesOf(slot.end)
    if (debut == null || fin == null) {
      problems.push(`creneaux : ${nom} a une heure mal formee`)
      continue
    }
    const duree = fin - debut
    if (duree !== sessionMinutes) {
      problems.push(
        `creneaux : ${nom} dure ${duree} min, il en faut ${sessionMinutes}`,
      )
    }

    const jours = Array.isArray(slot.days) ? slot.days : []
    if (jours.length === 0) problems.push(`creneaux : ${nom} sans jour`)
    for (const jour of jours) {
      if (!JOURS.has(jour)) {
        problems.push(`creneaux : ${nom} porte un jour inconnu (${jour})`)
      }
    }
    occurrences += jours.length
  }

  // Deux creneaux qui se chevauchent le meme jour feraient deux cours au
  // meme moment dans la meme grille.
  for (const jour of JOURS) {
    const duJour = slots
      .filter((s) => (s.days ?? []).includes(jour))
      .map((s) => ({ id: s.id, debut: minutesOf(s.start), fin: minutesOf(s.end) }))
      .filter((s) => s.debut != null)
      .sort((a, b) => a.debut - b.debut)
    for (let i = 1; i < duJour.length; i++) {
      if (duJour[i].debut < duJour[i - 1].fin) {
        problems.push(
          `creneaux : ${duJour[i - 1].id} et ${duJour[i].id} se chevauchent ` +
            `le ${jour}`,
        )
      }
    }
  }

  if (!checkOnly) {
    console.log(
      `${slots.length} creneaux de ${sessionMinutes} min, ` +
        `${occurrences} occurrences par semaine`,
    )
  }
} catch (error) {
  problems.push(`creneaux : ${SLOTS_SOURCE} illisible (${error.message})`)
}

if (problems.length > 0) {
  console.error('Parcours invalides :')
  for (const p of problems) console.error('  - ' + p)
  process.exit(1)
}

if (checkOnly) {
  console.log(`${specs.length} parcours valides.`)
  process.exit(0)
}

for (const dir of GEO_TARGETS) {
  mkdirSync(dir, { recursive: true })
  writeFileSync(join(dir, 'guinea.json'), geoRaw, 'utf8')
  console.log(`decoupage administratif -> ${dir.replace(ROOT, '.')}`)
}

for (const dir of CURRICULUM_TARGETS) {
  mkdirSync(dir, { recursive: true })
  writeFileSync(join(dir, 'guinea.json'), curriculumRaw, 'utf8')
  console.log(`programme national -> ${dir.replace(ROOT, '.')}`)
}

for (const dir of SLOTS_TARGETS) {
  mkdirSync(dir, { recursive: true })
  writeFileSync(join(dir, 'slots.json'), slotsRaw, 'utf8')
  console.log(`creneaux -> ${dir.replace(ROOT, '.')}`)
}

for (const dir of TARGETS) {
  mkdirSync(dir, { recursive: true })
  for (const spec of specs) {
    writeFileSync(join(dir, spec.name), spec.raw, 'utf8')
  }
  console.log(`${specs.length} parcours -> ${dir.replace(ROOT, '.')}`)
}

for (const dir of SEED_TARGETS) {
  mkdirSync(dir, { recursive: true })
  let n = 0
  for (const file of readdirSync(SEED_SOURCE).filter((f) => f.endsWith('.json'))) {
    copyFileSync(join(SEED_SOURCE, file), join(dir, file))
    n++
  }
  console.log(`${n} fichiers de referentiel -> ${dir.replace(ROOT, '.')}`)
}

// Les illustrations suivent les parcours qui les citent.
mkdirSync(IMAGE_TARGET, { recursive: true })
let copied = 0
let bytes = 0
for (const file of readdirSync(IMAGE_DIR).filter((f) => f.endsWith('.webp'))) {
  copyFileSync(join(IMAGE_DIR, file), join(IMAGE_TARGET, file))
  bytes += statSync(join(IMAGE_DIR, file)).size
  copied++
}
console.log(
  `${copied} illustrations (${Math.round(bytes / 1024)} Ko) -> ${IMAGE_TARGET.replace(ROOT, '.')}`,
)
