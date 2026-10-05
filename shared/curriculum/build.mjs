#!/usr/bin/env node
/**
 * Construit `shared/curriculum/guinea.json` depuis la recherche brute.
 *
 *   node shared/curriculum/build.mjs            # ecrit le fichier
 *   node shared/curriculum/build.mjs --check    # verifie qu'il est a jour
 *
 * --- Pourquoi un script et non un fichier ecrit a la main -----------------
 *
 * Les sources vivent dans `ressource_matières/` : un JSON de recherche
 * structure, et cinq fichiers texte dont les tableaux portent le detail reel des
 * programmes — chapitres, sous-chapitres, apprentissages attendus. Le JSON de
 * recherche, lui, marque toutes ses matieres `content_status: "partiel"` et se
 * contente souvent d'une ligne (« Chimie au college ») la ou le fichier texte en
 * donne onze parties.
 *
 * Recopier tout cela a la main aurait produit un fichier que personne ne
 * pourrait verifier, et qu'une mise a jour des sources rendrait faux sans que
 * rien ne le dise. Le script, lui, se rejoue : on remplace un fichier de
 * recherche, on relance, on lit le resume.
 *
 * --- Ce que ce fichier ne pretend pas -------------------------------------
 *
 * **Ce n'est pas le programme officiel.** Les sources le disent elles-memes :
 * il n'existe pas de publication ministerielle unique et accessible couvrant
 * toutes les matieres et toutes les classes. Les `quality_flags` et le
 * `content_status` de chaque entree sont recopies tels quels dans la sortie, et
 * les deux clients les affichent. Presenter cette compilation comme officielle
 * serait tromper un professeur sur ce qu'il prepare.
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ICI = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(ICI, '..', '..')
const SOURCES = join(ROOT, 'ressource_matières')
const SORTIE = join(ICI, 'guinea.json')

const verifier = process.argv.includes('--check')

// --- Outils de lecture -----------------------------------------------------

const lire = (nom) => readFileSync(join(SOURCES, nom), 'utf8').replace(/\r\n/g, '\n')

/** Retire les liens markdown `[texte](url)`, qui parasitent chaque titre. */
const sansLiens = (texte) =>
  texte.replace(/\[([^\]]*)\]\([^)]*\)/g, '').replace(/\s+/g, ' ').trim()

/** Retire le gras, les italiques et le code des cellules. */
const propre = (cellule) =>
  sansLiens(cellule)
    .replace(/\*\*/g, '')
    .replace(/[*`]/g, '')
    // Les formules LaTeX des sources — \(D\) — ne servent a rien dans une liste
    // de chapitres et s'affichent mal partout.
    .replace(/\\\(([^)]*)\\\)/g, '$1')
    .trim()

/**
 * Les lignes d'un tableau markdown, decoupees en cellules.
 *
 * Ignore la ligne de separation (`|---|---|`) et l'en-tete, qu'on passe en
 * premier element pour que l'appelant puisse verifier ses colonnes.
 */
function tableaux(bloc) {
  const tables = []
  let courante = null
  for (const ligne of bloc.split('\n')) {
    const brute = ligne.trim()
    if (brute.startsWith('|') && brute.endsWith('|')) {
      const cellules = brute.slice(1, -1).split('|').map((c) => c.trim())
      if (cellules.every((c) => /^:?-{2,}:?$/.test(c))) continue
      if (!courante) {
        courante = { entete: cellules.map(propre), lignes: [] }
        tables.push(courante)
      } else {
        courante.lignes.push(cellules.map(propre))
      }
    } else if (brute === '') {
      // Une ligne vide ferme le tableau : deux tableaux colles seraient sinon
      // lus comme un seul, avec l'en-tete du second pris pour une donnee.
      courante = null
    }
  }
  return tables
}

/** Decoupe une cellule « a ; b ; c » en sous-chapitres. */
const sousChapitres = (cellule) =>
  propre(cellule)
    .split(/\s*;\s*|\s+•\s+/)
    .map((p) => p.replace(/^[,.\s]+|[,.\s]+$/g, ''))
    .filter((p) => p.length > 1)

/** « 7e année », « 7ÈME ANNÉE », « 10ème » -> `lvl_7`. */
function niveauDe(titre) {
  const t = sansLiens(titre).toLowerCase()
  if (/terminale/.test(t)) return 'lvl_terminale'
  const m = /(\d{1,2})\s*(?:e|è|ème|eme|ere|ère)?\b/.exec(t)
  if (!m) return null
  const n = Number(m[1])
  return n >= 7 && n <= 12 ? `lvl_${n}` : null
}

/** Decoupe un texte en sections par niveau de titre (`##` ou `###`). */
function sections(texte, niveau) {
  const marque = new RegExp(`^${'#'.repeat(niveau)}[^#]`, 'm')
  const lignes = texte.split('\n')
  const blocs = []
  let courant = null
  for (const ligne of lignes) {
    if (marque.test(ligne)) {
      // `propre` et non `sansLiens` : les titres du fichier de français
      // portent leur gras markdown (« **A. Grammaire** »), et le garder
      // empêchait aussi de reconnaître le préfixe de lettre juste en dessous.
      courant = { titre: propre(ligne.replace(/^#+\s*/, '')), corps: [] }
      blocs.push(courant)
    } else if (courant) {
      courant.corps.push(ligne)
    }
  }
  return blocs.map((b) => ({ titre: b.titre, corps: b.corps.join('\n') }))
}

// --- Les adaptateurs, un par fichier source -------------------------------
//
// Chacun connait la forme de SON fichier et rien d'autre. Un analyseur unique
// aurait du deviner, et aurait devine faux sur au moins un des cinq.

const chapitres = []  // { subjectId, levelId, title, summary, subchapters, outcome, source }

const ajouter = (entree) => {
  if (!entree.levelId || !entree.title) return
  chapitres.push({ summary: null, subchapters: [], outcome: null, ...entree })
}

/**
 * `math_physique.txt` — deux sections `## ... au college`, puis `### Ne annee`,
 * puis un tableau `| Domaine | Chapitres et sous-chapitres |`.
 */
function mathPhysique() {
  const texte = lire('math_physique.txt')
  for (const bloc of sections(texte, 2)) {
    const matiere = /math/i.test(bloc.titre)
      ? 'sub_math'
      : /physique/i.test(bloc.titre)
        ? 'sub_phys'
        : null
    if (!matiere) continue

    for (const annee of sections(bloc.corps, 3)) {
      const levelId = niveauDe(annee.titre)
      if (!levelId) continue
      for (const table of tableaux(annee.corps)) {
        if (table.lignes.length === 0) continue
        for (const [domaine, contenu] of table.lignes) {
          ajouter({
            subjectId: matiere,
            levelId,
            title: domaine,
            subchapters: sousChapitres(contenu ?? ''),
            source: 'math_physique.txt',
          })
        }
      }
    }
  }
}

/**
 * `chimie.txt` — `## Ne annee`, tableau
 * `| Partie | Lecons et sous-chapitres | Apprentissages attendus |`.
 *
 * La troisieme colonne est ce qu'aucune autre source ne donne : ce que l'eleve
 * doit savoir faire. Elle est conservee telle quelle.
 */
function chimie() {
  for (const bloc of sections(lire('chimie.txt'), 2)) {
    const levelId = niveauDe(bloc.titre)
    if (!levelId) continue
    for (const table of tableaux(bloc.corps)) {
      if (!/partie|th[eè]me/i.test(table.entete[0] ?? '')) continue
      for (const [partie, lecons, attendus] of table.lignes) {
        ajouter({
          subjectId: 'sub_chim',
          levelId,
          title: partie,
          subchapters: sousChapitres(lecons ?? ''),
          outcome: attendus ? propre(attendus) : null,
          source: 'chimie.txt',
        })
      }
    }
  }
}

/**
 * `anglais.txt` — deux formes dans le meme fichier :
 *
 *   * `## Ne annee — MOBEL n` avec `| Unite | Titre | Competences |` ;
 *   * `## 9e et 10e annees` avec `| Domaine | 9e: ... | 10e: ... |`, une colonne
 *     par classe. C'est le seul endroit du corpus ou un tableau porte deux
 *     niveaux a la fois, et l'ignorer aurait laisse 9e et 10e vides.
 */
function anglais() {
  for (const bloc of sections(lire('anglais.txt'), 2)) {
    const deuxNiveaux = /9e\s*et\s*10e/i.test(bloc.titre)

    for (const table of tableaux(bloc.corps)) {
      if (deuxNiveaux) {
        if (!/domaine/i.test(table.entete[0] ?? '')) continue
        for (const [domaine, neuf, dix] of table.lignes) {
          for (const [levelId, contenu] of [
            ['lvl_9', neuf],
            ['lvl_10', dix],
          ]) {
            ajouter({
              subjectId: 'sub_angl',
              levelId,
              title: domaine,
              subchapters: sousChapitres(contenu ?? ''),
              source: 'anglais.txt',
            })
          }
        }
        continue
      }

      const levelId = niveauDe(bloc.titre)
      if (!levelId || !/unit/i.test(table.entete[0] ?? '')) continue
      for (const [unite, titre, competences] of table.lignes) {
        ajouter({
          subjectId: 'sub_angl',
          levelId,
          // « Unité 3 — Shopping » : le numéro seul ne dit rien, le titre seul
          // ne se situe pas dans la progression. La colonne ne contient que le
          // chiffre, d'où le mot ajouté ici.
          title: [/^\d+$/.test(unite ?? '') ? `Unité ${unite}` : unite, titre]
            .filter(Boolean)
            .join(' — '),
          subchapters: sousChapitres(competences ?? ''),
          source: 'anglais.txt',
        })
      }
    }
  }
}

/**
 * `Français - lycée.txt` — malgre son nom, ce fichier porte le programme du
 * **college** (ses propres titres le disent). Forme :
 * `### NÈME ANNÉE (8h/semaine)` puis `#### A. Domaine` puis un tableau de deux
 * colonnes.
 *
 * Le domaine devient le chapitre, et chaque ligne du tableau un sous-chapitre :
 * « Grammaire » est le chapitre, « la phrase simple » en est une lecon.
 */
function francais() {
  const texte = lire('Français - lycée.txt')
  for (const annee of sections(texte, 3)) {
    const levelId = niveauDe(annee.titre)
    if (!levelId) continue
    for (const domaine of sections(annee.corps, 4)) {
      // « A. Grammaire » -> « Grammaire ».
      const titre = domaine.titre.replace(/^[A-Z]\.\s*/, '')
      const sous = []
      for (const table of tableaux(domaine.corps)) {
        for (const ligne of table.lignes) {
          const gauche = ligne[0] ?? ''
          const droite = ligne.slice(1).filter(Boolean).join(' ; ')
          if (gauche) sous.push(gauche)
          for (const p of sousChapitres(droite)) sous.push(p)
        }
      }
      /*
       * Hors tableau, trois formes coexistent dans ce fichier, et il faut les
       * trois : « G. Lecture » n'a ni tableau ni puces, et se perdait
       * entièrement.
       *
       *   - puce            « - La ponctuation »
       *   - liste numérotée « 1. Perception globale du texte »
       *   - étiquette grasse « **Lecture suivie** : découverte d'une œuvre »
       */
      for (const ligne of domaine.corps.split('\n')) {
        const puce = /^\s*[-*]\s+(.*)$/.exec(ligne)
        const numero = /^\s*\d+\.\s+(.*)$/.exec(ligne)
        const etiquette = /^\s*\*\*([^*]+)\*\*\s*(?::\s*(.*))?$/.exec(ligne)
        const brut = puce?.[1] ?? numero?.[1] ?? null
        if (brut) {
          const valeur = propre(brut)
          if (valeur.length > 1) sous.push(valeur)
        } else if (etiquette) {
          const nom = propre(etiquette[1])
          const detail = propre(etiquette[2] ?? '')
          const valeur = detail ? `${nom} : ${detail}` : nom
          if (nom.length > 1) sous.push(valeur)
        }
      }
      if (sous.length === 0) continue
      ajouter({
        subjectId: 'sub_fran',
        levelId,
        title: titre,
        subchapters: [...new Set(sous)],
        source: 'Français - lycée.txt',
      })
    }
  }
}

/**
 * `primaire-terminal.txt` — la vue d'ensemble du systeme 6+4+3.
 *
 * On n'en tire que ce que les autres fichiers ne donnent pas : le **primaire**,
 * absent partout ailleurs, et les **coefficients d'examen**. Le reste
 * (plans d'etude du college et du lycee) recoupe le JSON de recherche, et le
 * reprendre creerait des doublons de chapitres.
 */
function primaireEtCoefficients() {
  const texte = lire('primaire-terminal.txt')
  const resultat = { primarySubjects: [], examCoefficients: [] }

  for (const bloc of sections(texte, 3)) {
    if (/primaire/i.test(bloc.titre)) {
      for (const ligne of bloc.corps.split('\n')) {
        const m = /^\s*-\s+(.*)$/.exec(ligne)
        if (!m) continue
        const valeur = propre(m[1])
        if (valeur.length < 2) continue
        // « Français (Lecture, Dictée, ...) » -> nom + composantes.
        const detail = /^([^(]+)\(([^)]*)\)\s*$/.exec(valeur)
        resultat.primarySubjects.push({
          name: detail ? detail[1].trim() : valeur,
          components: detail
            ? detail[2].split(/\s*,\s*/).map((p) => p.trim()).filter(Boolean)
            : [],
        })
      }
    }
  }

  // Les coefficients : un tableau `| Matiere | Coefficient |`.
  for (const table of tableaux(texte)) {
    if (!/coefficient/i.test(table.entete[1] ?? '')) continue
    for (const [matiere, coef] of table.lignes) {
      const valeur = Number(String(coef).replace(',', '.'))
      if (!matiere || !Number.isFinite(valeur)) continue
      resultat.examCoefficients.push({ exam: 'CEP', subject: matiere, coefficient: valeur })
    }
  }

  return resultat
}

/**
 * `manuel_scolaire.txt` — les manuels par discipline.
 *
 * Donnee que rien d'autre ne porte, et la plus concrete pour un professeur : il
 * prepare avec un livre, pas avec un referentiel. La colonne « Statut a
 * retenir » est conservee parce qu'elle dit justement ce qui est une reference
 * et ce qui est un complement — la confondre ferait acheter le mauvais livre.
 */
function manuels() {
  const texte = lire('manuel_scolaire.txt')
  const livres = []
  for (const table of tableaux(texte)) {
    if (!/discipline/i.test(table.entete[0] ?? '')) continue
    for (const [discipline, titre, niveaux, statut] of table.lignes) {
      if (!discipline || !titre) continue
      livres.push({
        subject: discipline,
        title: titre,
        levels: niveaux ?? null,
        status: statut ?? null,
      })
    }
  }
  return livres
}

// --- Assemblage ------------------------------------------------------------

/**
 * Les identifiants du JSON de recherche qui designent une matiere deja nommee
 * autrement dans le referentiel.
 *
 * `sub_edphys` (« Education physique / activites pratiques ») et `sub_eps`
 * (« Education physique et sportive ») sont la meme matiere : memes sept
 * classes, meme contenu, deux entrees. Garder les deux donnerait deux matieres
 * identiques dans le catalogue, et les cours d'EPS se repartiraient au hasard
 * entre elles — une recherche sur l'une n'en trouverait que la moitie.
 *
 * Le controle croise de `sync.mjs` est ce qui a rendu ce doublon visible : il
 * compare les identifiants cites a `shared/seed/catalog.json`, et aucune
 * relecture d'un fichier de 180 ko ne l'aurait fait.
 */
const ALIAS_MATIERES = { sub_edphys: 'sub_eps' }

const recherche = JSON.parse(lire('programme_guineen_college_lycee.json'))

/*
 * Fusionne les alias avant tout traitement : la suite ne doit jamais voir
 * l'identifiant d'origine.
 */
recherche.subjects = recherche.subjects.reduce((liste, sujet) => {
  const cible = ALIAS_MATIERES[sujet.id]
  if (!cible) {
    liste.push(sujet)
    return liste
  }
  const existant = liste.find((s) => s.id === cible)
  if (!existant) {
    liste.push({ ...sujet, id: cible })
    return liste
  }
  // Le doublon n'apporte rien de plus ici (meme contenu), mais on fusionne
  // quand meme : si une future source enrichit l'un des deux, rien ne se perd.
  for (const [niveau, chaps] of Object.entries(sujet.chapters_by_level ?? {})) {
    const deja = existant.chapters_by_level?.[niveau] ?? []
    const titres = new Set(deja.map((c) => c.title))
    existant.chapters_by_level = existant.chapters_by_level ?? {}
    existant.chapters_by_level[niveau] = [
      ...deja,
      ...chaps.filter((c) => !titres.has(c.title)),
    ]
  }
  return liste
}, [])

mathPhysique()
chimie()
anglais()
francais()
const { primarySubjects, examCoefficients } = primaireEtCoefficients()
const textbooks = manuels()

/** Les chapitres extraits, groupes par matiere puis par niveau. */
function parMatiereEtNiveau() {
  const table = new Map()
  for (const ch of chapitres) {
    const cle = `${ch.subjectId}|${ch.levelId}`
    if (!table.has(cle)) table.set(cle, [])
    table.get(cle).push(ch)
  }
  return table
}

const extraits = parMatiereEtNiveau()

/** `7ème` -> `lvl_7`, pour relire les clefs du JSON de recherche. */
const idDeNomNiveau = (nom) => niveauDe(nom)

const sujets = recherche.subjects.map((sujet) => {
  const parNiveau = {}
  let remplaces = 0

  for (const [nomNiveau, chapsRecherche] of Object.entries(
    sujet.chapters_by_level ?? {},
  )) {
    const levelId = idDeNomNiveau(nomNiveau)
    const trouves = levelId ? extraits.get(`${sujet.id}|${levelId}`) : null

    if (trouves && trouves.length > 0) {
      /*
       * Le fichier texte gagne quand il est plus riche.
       *
       * Le JSON de recherche se contente parfois d'une ligne (« Chimie au
       * college ») la ou le fichier texte donne onze parties detaillees. Garder
       * les deux produirait un doublon ; garder le JSON perdrait le detail. On
       * compare donc le nombre de sous-chapitres, qui est la seule mesure
       * honnete de ce qu'une entree apporte.
       */
      const richesseTexte = trouves.reduce(
        (n, c) => n + c.subchapters.length,
        0,
      )
      const richesseJson = chapsRecherche.reduce(
        (n, c) => n + (c.subchapters?.length ?? 0),
        0,
      )
      if (richesseTexte >= richesseJson) {
        remplaces += 1
        parNiveau[levelId] = trouves.map((c, i) => ({
          order: i + 1,
          title: c.title,
          summary: c.summary,
          subchapters: c.subchapters,
          outcome: c.outcome,
          source: c.source,
        }))
        continue
      }
    }

    /*
     * Numerotation sequentielle, et non l'`order` du fichier source.
     *
     * Apres la fusion d'un alias (`sub_edphys` vers `sub_eps`), deux chapitres
     * venus de deux fichiers differents portent chacun `order: 1`. Or la cle de
     * `curriculum_chapters` est (matiere, niveau, position) et le semis fait
     * `on conflict do update` : le second ecrasait le premier sans bruit. Sept
     * chapitres d'EPS disparaissaient ainsi, et la base en service rendait 341
     * lignes la ou le fichier en declarait 348.
     *
     * Les deux autres branches numerotaient deja avec `i + 1` ; celle-ci
     * faisait exception, et c'est la seule que la fusion d'alias traverse.
     */
    parNiveau[levelId ?? nomNiveau] = [...chapsRecherche]
      .sort((a, b) => (a.order ?? 0) - (b.order ?? 0))
      .map((c, i) => ({
        order: i + 1,
        title: c.title,
        summary: c.summary ?? null,
        subchapters: c.subchapters ?? [],
        outcome: null,
        source: 'programme_guineen_college_lycee.json',
      }))
  }

  // Un niveau present dans les fichiers texte mais absent du JSON de recherche
  // ne doit pas disparaitre.
  for (const [cle, trouves] of extraits) {
    const [subjectId, levelId] = cle.split('|')
    if (subjectId !== sujet.id || parNiveau[levelId]) continue
    parNiveau[levelId] = trouves.map((c, i) => ({
      order: i + 1,
      title: c.title,
      summary: c.summary,
      subchapters: c.subchapters,
      outcome: c.outcome,
      source: c.source,
    }))
  }

  return {
    id: sujet.id,
    name: sujet.name,
    note: sujet.note ?? null,
    levelIds: Object.keys(parNiveau).sort(
      (a, b) => ordreNiveau(a) - ordreNiveau(b),
    ),
    profiles: sujet.profiles ?? [],
    weeklyHours: sujet.weekly_hours ?? null,
    contentStatus: sujet.content_status ?? 'partiel',
    enrichedFromText: remplaces > 0,
    chaptersByLevel: parNiveau,
    sourceIds: sujet.source_ids ?? [],
  }
})

function ordreNiveau(levelId) {
  if (levelId === 'lvl_terminale') return 13
  const m = /lvl_(\d+)/.exec(levelId)
  return m ? Number(m[1]) : 99
}

const sortie = {
  country: recherche.country ?? 'GN',
  countryName: recherche.country_name ?? 'République de Guinée',
  note: recherche.note,
  updated: new Date().toISOString().slice(0, 10),

  /*
   * ⚠ Ce fichier est une COMPILATION, pas le programme officiel.
   *
   * Les sources consultees ne contiennent pas de publication ministerielle
   * unique couvrant toutes les matieres et toutes les classes. Les deux clients
   * affichent cet avertissement : un professeur qui prepare un cours doit savoir
   * sur quoi il s'appuie.
   */
  disclaimer:
    'Compilation structurée à partir de sources guinéennes accessibles. ' +
    'Ce n’est pas une publication officielle du ministère : vérifiez auprès de ' +
    'votre établissement avant de vous en servir comme référence unique.',

  generatedBy: 'shared/curriculum/build.mjs',
  sourceFiles: [
    'programme_guineen_college_lycee.json',
    'math_physique.txt',
    'chimie.txt',
    'anglais.txt',
    'Français - lycée.txt',
    'primaire-terminal.txt',
    'manuel_scolaire.txt',
  ],

  scope: recherche.scope,
  methodology: recherche.methodology,
  qualityFlags: recherche.quality_flags ?? [],

  // Inchange : les deux clients et `sync.mjs` lisent deja cette liste.
  filieres: recherche.filieres,

  levels: recherche.levels,
  subjects: sujets,
  exams: recherche.exams,
  examCoefficients,
  primarySubjects,
  textbooks,
  sources: recherche.sources ?? [],
}

/* --- La cle du semis doit etre unique ici, pas decouverte en base ----------
 *
 * `curriculum_chapters` a pour cle (subject_id, level_id, position), et le semis
 * fait `on conflict do update` pour etre rejouable. Les deux ensemble ont une
 * consequence desagreable : deux chapitres de meme cle ne provoquent aucune
 * erreur, le second ecrase simplement le premier. Le fichier declare 348
 * chapitres, la base en contient 341, et rien ne le dit.
 *
 * C'est arrive. Le controle ci-dessous refuse donc de produire un fichier dont
 * le semis perdrait des lignes — mieux vaut un generateur qui s'arrete en
 * nommant les doublons qu'une base silencieusement incomplete.
 */
{
  const vues = new Map()
  const doublons = []
  for (const sujet of sujets) {
    for (const [levelId, chaps] of Object.entries(sujet.chaptersByLevel)) {
      for (const chap of chaps) {
        const cle = `${sujet.id}|${levelId}|${chap.order}`
        if (vues.has(cle)) doublons.push(`${cle}  « ${vues.get(cle)} » puis « ${chap.title} »`)
        else vues.set(cle, chap.title)
      }
    }
  }
  if (doublons.length > 0) {
    console.error('')
    console.error(
      `${doublons.length} chapitre(s) partagent une cle (matiere, niveau, position).`,
    )
    console.error('Le semis en perdrait autant, sans erreur :')
    for (const d of doublons) console.error(`  ${d}`)
    console.error('')
    process.exit(1)
  }
}

// --- Resume et ecriture ----------------------------------------------------

const totalChapitres = sujets.reduce(
  (n, s) => n + Object.values(s.chaptersByLevel).reduce((m, c) => m + c.length, 0),
  0,
)
const totalSous = sujets.reduce(
  (n, s) =>
    n +
    Object.values(s.chaptersByLevel).reduce(
      (m, chaps) => m + chaps.reduce((k, c) => k + c.subchapters.length, 0),
      0,
    ),
  0,
)
const avecAttendus = sujets.reduce(
  (n, s) =>
    n +
    Object.values(s.chaptersByLevel).reduce(
      (m, chaps) => m + chaps.filter((c) => c.outcome).length,
      0,
    ),
  0,
)

const texteSortie = `${JSON.stringify(sortie, null, 2)}\n`

console.log('')
console.log(`shared/curriculum/guinea.json`)
console.log(`  ${sujets.length} matières, ${sortie.levels.length} classes, ${sortie.filieres.length} profils`)
console.log(`  ${totalChapitres} chapitres, ${totalSous} sous-chapitres`)
console.log(`  ${avecAttendus} chapitres avec apprentissages attendus`)
console.log(`  ${textbooks.length} manuels, ${primarySubjects.length} matières du primaire`)
console.log(`  ${examCoefficients.length} coefficients d'examen, ${sortie.sources.length} sources`)
console.log(`  ${(texteSortie.length / 1024).toFixed(0)} ko`)
console.log('')
console.log('  Enrichies depuis les fichiers texte :')
for (const s of sujets.filter((s) => s.enrichedFromText)) {
  const n = Object.values(s.chaptersByLevel).reduce((m, c) => m + c.length, 0)
  console.log(`    ${s.name.padEnd(26)} ${n} chapitres`)
}

if (verifier) {
  const actuel = existsSync(SORTIE) ? readFileSync(SORTIE, 'utf8') : ''
  // La date de generation change a chaque execution : la comparer ferait
  // echouer le controle tous les jours sans qu'aucune donnee ait bouge.
  const sansDate = (t) => t.replace(/"updated": "[^"]*"/, '"updated": "—"')
  if (sansDate(actuel) !== sansDate(texteSortie)) {
    console.error(
      '\nguinea.json n’est pas à jour. Relancez :\n' +
        '  node shared/curriculum/build.mjs\n',
    )
    process.exit(1)
  }
  console.log('  À jour.\n')
} else {
  writeFileSync(SORTIE, texteSortie, 'utf8')
  console.log('  Écrit.\n')
}
