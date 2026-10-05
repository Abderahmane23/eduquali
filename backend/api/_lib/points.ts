/**
 * Les points de fidelite et le classement des concours — phase D1 et D4.
 *
 * --- Ce n'est pas le retour des credits ----------------------------------
 *
 * `credit_ledger` a ete supprime le 02/10 parce qu'il faisait payer l'usage de
 * l'IA a l'unite. Les points se **gagnent** : aucune fonction de ce fichier ne
 * prend un montant en francs, et aucune n'ouvre de moyen de paiement. Si une
 * signature se met un jour a ressembler a `buyPoints(amount)`, c'est l'ancien
 * systeme qui revient sous un nouveau nom.
 *
 * --- Pourquoi tout est pur ici -------------------------------------------
 *
 * Un bareme et un classement sont exactement le genre de regle qu'on croit
 * evidente et qu'on implemente de travers : les egalites, le dernier rang
 * recompense, le seuil de publication. Ecrites en fonctions pures, elles
 * s'eprouvent cas par cas sans Postgres — et c'est la seule facon de verifier
 * qu'un ex aequo recoit bien la meme chose que son co-classe.
 */

/** Ce que rapporte le simple fait d'avoir rendu sa copie. */
export const PARTICIPATION_POINTS = 5

/**
 * Nombre de copies rendues en dessous duquel le podium reste ferme.
 *
 * « Un classement national n'a de sens qu'avec assez de participants — ne pas
 * l'ouvrir a 30 inscrits » (plan D4). Annoncer un podium national a quatre
 * participants n'est pas une approximation, c'est une affirmation fausse sur le
 * pays. Le rang personnel, lui, reste toujours visible : il est honnete quel que
 * soit le nombre de participants.
 */
export const CLASSEMENT_MINIMUM = 10

/**
 * Le bareme : part decroissante de l'enjeu annonce.
 *
 * La table ne stocke que `points_prize`, le gain du premier. Les parts sont
 * calculees ici pour qu'un changement de bareme ne demande pas de reecrire les
 * concours deja crees.
 *
 * Les rangs au-dela du dixieme touchent la participation : un eleve qui finit
 * 200e a quand meme passe une heure sur les questions, et repartir les mains
 * vides est le meilleur moyen qu'il ne revienne pas la semaine suivante.
 */
export function awardForRank(prize: number, rank: number): number {
  if (!Number.isFinite(prize) || prize < 0 || rank < 1) return 0

  const part = (fraction: number) => Math.max(1, Math.round(prize * fraction))

  if (rank === 1) return Math.max(PARTICIPATION_POINTS, Math.round(prize))
  if (rank === 2) return Math.max(PARTICIPATION_POINTS, part(0.6))
  if (rank === 3) return Math.max(PARTICIPATION_POINTS, part(0.4))
  if (rank <= 10) return Math.max(PARTICIPATION_POINTS, part(0.1))
  return PARTICIPATION_POINTS
}

export interface ContestEntry {
  userId: string
  score: number | null
  startedAt: string
  submittedAt: string | null
}

export interface RankedEntry {
  userId: string
  score: number
  rank: number
  /** Duree de la copie, en secondes. */
  durationSeconds: number
}

const seconds = (from: string, to: string) =>
  Math.max(0, Math.round((Date.parse(to) - Date.parse(from)) / 1000))

/**
 * Le classement, calcule et jamais stocke.
 *
 * Deux decisions a defendre :
 *
 *   * **Les copies non rendues sont ecartees.** Une participation ouverte n'est
 *     pas un score de zero : l'eleve est peut-etre encore en train de repondre.
 *     La compter le classerait dernier avant meme d'avoir fini.
 *
 *   * **A score egal, la copie la plus rapide passe devant** — la duree, pas
 *     l'heure d'envoi. Departager sur l'heure favoriserait celui qui s'y met le
 *     lundi matin, ce qui ne mesure aucune competence ; la duree mesure au moins
 *     l'aisance. Et si les deux durees sont identiques, le rang est **partage** :
 *     inventer un ordre entre deux copies indiscernables serait arbitraire, et
 *     l'un des deux le verrait.
 */
export function ladder(entries: ContestEntry[]): RankedEntry[] {
  const rendues: RankedEntry[] = []
  for (const entry of entries) {
    if (entry.submittedAt == null || entry.score == null) continue
    rendues.push({
      userId: entry.userId,
      score: entry.score,
      rank: 0,
      durationSeconds: seconds(entry.startedAt, entry.submittedAt),
    })
  }

  rendues.sort(
    (a, b) => b.score - a.score || a.durationSeconds - b.durationSeconds,
  )

  // Classement « sportif » : deux deuxiemes, puis un quatrieme. Le rang dit
  // combien de copies font mieux, ce qui reste vrai avec des ex aequo.
  let rang = 0
  let vus = 0
  let precedent: RankedEntry | null = null
  for (const entry of rendues) {
    vus += 1
    const exAequo =
      precedent != null &&
      precedent.score === entry.score &&
      precedent.durationSeconds === entry.durationSeconds
    if (!exAequo) rang = vus
    entry.rank = rang
    precedent = entry
  }

  return rendues
}

export interface LeaderboardView {
  /** Faux tant que le seuil de [CLASSEMENT_MINIMUM] n'est pas atteint. */
  published: boolean
  participants: number
  /** Vide tant que le classement n'est pas publie. */
  podium: RankedEntry[]
  /** Toujours rendu, publie ou non : c'est ce que l'eleve vient chercher. */
  me: RankedEntry | null
  /** Combien de copies encore avant l'ouverture du podium. */
  missing: number
}

/**
 * Ce qu'un ecran a le droit d'afficher.
 *
 * Le rang personnel vient **avant** le podium, dans cet objet comme a l'ecran :
 * « Afficher son propre rang avant le top 10 : c'est ce que l'eleve cherche »
 * (plan D4). Un podium ou l'on ne se trouve pas ne dit rien a celui qui le
 * regarde.
 */
export function leaderboardFor(
  entries: ContestEntry[],
  options: { me?: string; top?: number; minimum?: number } = {},
): LeaderboardView {
  const classes = ladder(entries)
  const minimum = options.minimum ?? CLASSEMENT_MINIMUM
  const top = options.top ?? 10
  const published = classes.length >= minimum

  return {
    published,
    participants: classes.length,
    podium: published ? classes.slice(0, top) : [],
    me: classes.find((e) => e.userId === options.me) ?? null,
    missing: Math.max(0, minimum - classes.length),
  }
}

export interface ShopItem {
  id: string
  pointsPrice: number
  stock: number
}

export interface ShopProgress {
  /** Ce qu'on peut echanger tout de suite. */
  affordable: string[]
  /** Le lot abordable suivant, et ce qu'il manque pour l'atteindre. */
  nextId: string | null
  missing: number
}

/**
 * Ou en est-on par rapport aux lots ?
 *
 * « Montrer la distance au lot suivant : "encore 140 points" » (plan D2). Un
 * solde seul ne dit pas si l'on progresse ; un ecart le dit.
 *
 * Le lot vise est **le moins cher parmi ceux qu'on ne peut pas encore
 * s'offrir**, et non le moins cher du catalogue : une fois le petit lot
 * atteint, l'ecran doit montrer la marche suivante, sinon il affiche
 * eternellement « encore 0 point ».
 *
 * Les lots epuises sont ignores : viser ce qu'on ne pourra pas recevoir est la
 * meilleure facon de faire abandonner.
 */
export function shopProgress(
  balance: number,
  items: ShopItem[],
): ShopProgress {
  const disponibles = items.filter((item) => item.stock > 0)
  const affordable = disponibles
    .filter((item) => item.pointsPrice <= balance)
    .map((item) => item.id)

  const suivant = disponibles
    .filter((item) => item.pointsPrice > balance)
    .sort((a, b) => a.pointsPrice - b.pointsPrice)[0]

  return {
    affordable,
    nextId: suivant?.id ?? null,
    missing: suivant ? suivant.pointsPrice - balance : 0,
  }
}

/**
 * La fenetre du concours de la semaine : lundi 00 h UTC au lundi suivant.
 *
 * Calculee et non stockee, pour une raison pratique : le cron qui ouvre les
 * concours tourne chaque nuit, et il doit pouvoir tourner **plusieurs fois dans
 * la meme semaine sans ouvrir plusieurs concours**. En derivant la fenetre de la
 * date, deux executions le mardi et le mercredi calculent le meme `opensAt` — il
 * suffit alors de regarder s'il existe deja, sans colonne « semaine » a tenir ni
 * curseur a reparer apres un echec.
 *
 * Lundi, parce que c'est le debut de semaine scolaire ; UTC, parce que Conakry
 * est a UTC+0 toute l'annee et qu'un decalage inventerait une difference qui
 * n'existe pas.
 */
export function weekWindow(now: Date = new Date()): {
  opensAt: string
  closesAt: string
} {
  const debut = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  )
  // `getUTCDay()` rend 0 pour dimanche : le ramener a 6 jours depuis lundi.
  const depuisLundi = (debut.getUTCDay() + 6) % 7
  debut.setUTCDate(debut.getUTCDate() - depuisLundi)

  const fin = new Date(debut)
  fin.setUTCDate(fin.getUTCDate() + 7)

  return { opensAt: debut.toISOString(), closesAt: fin.toISOString() }
}

/**
 * Le test retenu pour une semaine donnee.
 *
 * Rotation deterministe sur une liste ordonnee : la meme semaine donne toujours
 * le meme test. Tirer au hasard rendrait le cron non rejouable — deux executions
 * ouvriraient deux concours differents — et empecherait de repondre a « quel
 * concours la semaine prochaine ? » sans interroger la base.
 */
export function testForWeek(opensAt: string, testIds: string[]): string | null {
  if (testIds.length === 0) return null
  const semaines = Math.floor(Date.parse(opensAt) / (7 * 24 * 3600_000))
  // `%` peut rendre un negatif sur une date anterieure a 1970 ; le ramener.
  const index = ((semaines % testIds.length) + testIds.length) % testIds.length
  return testIds[index]
}

/**
 * Les ecritures de points a passer quand un concours ferme.
 *
 * Rendue comme une liste a inserer plutot qu'executee ici : la fonction reste
 * pure, donc le bareme s'eprouve sans base, et l'appelant garde la main sur la
 * transaction.
 *
 * La `reference` porte l'identifiant du concours, ce qui rend l'operation
 * **rejouable** : fermer deux fois le meme concours ne doit pas doubler les
 * gains, et l'appelant le verifie sur cette colonne.
 */
export function closingEntries(
  contestId: string,
  title: string,
  prize: number,
  entries: ContestEntry[],
): { owner_id: string; delta: number; reason: string; reference: string }[] {
  return ladder(entries).map((classe) => ({
    owner_id: classe.userId,
    delta: awardForRank(prize, classe.rank),
    // Dire POURQUOI : « un solde qui monte sans raison lisible ne motive pas ».
    // Le rang est dans la phrase, pas seulement dans une colonne technique.
    reason: `${title} — ${classe.rank}${classe.rank === 1 ? 're' : 'e'} place`,
    reference: `contest:${contestId}`,
  }))
}
