/**
 * Ce qu'un compte a le droit de faire, et combien de fois.
 *
 * --- Ce qui change par rapport aux credits puis aux formules -------------
 *
 * Le modele precedent repondait par oui ou par non : une fonction etait
 * ouverte ou fermee selon la formule. Il ne savait pas dire « deux directs
 * par mois ». Or c'est exactement ce qui est vendu desormais, et une limite
 * qu'on ne sait pas compter est une limite qu'on n'applique pas.
 *
 * Ce module decrit donc des **quotas par periode**. Il ne compte rien
 * lui-meme : il dit ce qui est permis, et l'appelant fournit ce qui a deja
 * ete consomme. C'est ce qui le rend verifiable sans base de donnees.
 *
 * --- Les quatre etats ----------------------------------------------------
 *
 *   * **l'essai** — sept jours, tout ouvert sauf l'assistant, limite a trois
 *     questions par jour comme partout ailleurs ;
 *   * **le gratuit** — ce qui reste apres l'essai : trois questions par jour,
 *     un direct par quinzaine, un cours enregistre par mois ;
 *   * **Decouverte**, 50 000 GNF — quatre cours et deux directs par mois ;
 *   * **Illimite**, 200 000 GNF — cours et directs sans limite, assistant
 *     sans limite, questions pendant les directs, exercices corriges.
 *
 * L'essai n'est pas un quatrieme code de formule : c'est l'etat d'un compte
 * `FREE` de moins de sept jours. Ajouter un code aurait demande de migrer
 * les comptes existants et de tenir une valeur de plus dans la base, les
 * politiques RLS et les deux clients — pour une information que la date de
 * creation porte deja.
 *
 * --- Ce que ce module ne fait pas ---------------------------------------
 *
 * Il n'encaisse rien. Les prix sont ecrits ici parce qu'un ecran doit
 * pouvoir les afficher, mais aucun paiement n'est branche : `payments` n'est
 * pas configure sur le Worker. Une formule payante ne s'obtient donc pas
 * encore toute seule, et c'est volontaire — mieux vaut une porte fermee
 * qu'une porte qui prend l'argent sans rien ouvrir.
 */

/** Les codes ecrits dans `profiles.plan`. */
export type CodeFormule = 'FREE' | 'PRO' | 'MASTER'

/** Ce qu'on peut consommer, et sur quelle periode. */
export type Ressource = 'assistant' | 'direct' | 'cours'

/** La periode sur laquelle un quota se remet a zero. */
export type Periode = 'jour' | 'quinzaine' | 'mois' | 'jamais'

export interface Quota {
  /** `null` veut dire sans limite. */
  readonly max: number | null
  readonly periode: Periode
}

export interface Formule {
  readonly code: CodeFormule
  readonly nom: string
  /** Prix mensuel en francs guineens. */
  readonly prixGnf: number
  readonly quotas: Readonly<Record<Ressource, Quota>>
  /** Poser une question pendant un direct. */
  readonly questionsEnDirect: boolean
  /** Faire corriger ses exercices par le professeur. */
  readonly exercicesCorriges: boolean
}

/**
 * Trois questions par jour, pour tout le monde sauf Illimite.
 *
 * Le plafond ne protege pas la marge mais le budget : chaque question part
 * chez un fournisseur facture au jeton. Il est le meme pendant l'essai —
 * offrir un assistant sans limite pendant sept jours reviendrait a payer la
 * curiosite de qui ne restera pas.
 */
const ASSISTANT_PAR_JOUR = 3

const SANS_LIMITE: Quota = { max: null, periode: 'jamais' }

/** Sept jours, et ce que cela ouvre. */
export const JOURS_ESSAI = 7

export const FORMULES: Readonly<Record<CodeFormule, Formule>> = {
  FREE: {
    code: 'FREE',
    nom: 'Gratuit',
    prixGnf: 0,
    quotas: {
      assistant: { max: ASSISTANT_PAR_JOUR, periode: 'jour' },
      direct: { max: 1, periode: 'quinzaine' },
      cours: { max: 1, periode: 'mois' },
    },
    questionsEnDirect: false,
    exercicesCorriges: false,
  },
  PRO: {
    code: 'PRO',
    nom: 'Découverte',
    prixGnf: 50000,
    quotas: {
      assistant: { max: ASSISTANT_PAR_JOUR, periode: 'jour' },
      direct: { max: 2, periode: 'mois' },
      cours: { max: 4, periode: 'mois' },
    },
    questionsEnDirect: false,
    exercicesCorriges: false,
  },
  MASTER: {
    code: 'MASTER',
    nom: 'Illimité',
    prixGnf: 200000,
    quotas: {
      assistant: SANS_LIMITE,
      direct: SANS_LIMITE,
      cours: SANS_LIMITE,
    },
    questionsEnDirect: true,
    exercicesCorriges: true,
  },
}

/** L'essai : tout ouvert, sauf l'assistant qui garde son plafond. */
export const ESSAI: Formule = {
  code: 'FREE',
  nom: 'Essai',
  prixGnf: 0,
  quotas: {
    assistant: { max: ASSISTANT_PAR_JOUR, periode: 'jour' },
    direct: SANS_LIMITE,
    cours: SANS_LIMITE,
  },
  questionsEnDirect: false,
  exercicesCorriges: false,
}

export function formuleDe(code: string | null | undefined): Formule {
  const connue = FORMULES[(code ?? 'FREE') as CodeFormule]
  return connue ?? FORMULES.FREE
}

/** Le compte est-il encore dans ses sept premiers jours ? */
export function dansLEssai(creeLe: Date, maintenant: Date): boolean {
  const fin = new Date(creeLe.getTime())
  fin.setUTCDate(fin.getUTCDate() + JOURS_ESSAI)
  return maintenant.getTime() < fin.getTime()
}

/** Ce qu'il reste d'essai, en jours entiers — 0 s'il est fini. */
export function joursDEssaiRestants(creeLe: Date, maintenant: Date): number {
  const fin = new Date(creeLe.getTime())
  fin.setUTCDate(fin.getUTCDate() + JOURS_ESSAI)
  const reste = fin.getTime() - maintenant.getTime()
  if (reste <= 0) return 0
  return Math.ceil(reste / 86_400_000)
}

/**
 * La formule qui s'applique vraiment.
 *
 * Une formule payante expiree ne retire rien de ce qui a ete cree : elle
 * referme seulement ce qui se paie. Et un compte qui vient d'etre cree
 * profite de l'essai, meme s'il a declare vouloir une formule payante a
 * l'inscription — l'intention n'est pas un paiement.
 */
export function formuleEffective(input: {
  plan: string | null | undefined
  renouvelleLe: Date | null | undefined
  creeLe: Date
  maintenant: Date
}): Formule {
  const { plan, renouvelleLe, creeLe, maintenant } = input
  const demandee = formuleDe(plan)

  if (demandee.code !== 'FREE') {
    // Le jour de l'echeance compte encore : couper a l'heure pres punirait
    // un decalage de fuseau ou un paiement enregistre avec un peu de retard.
    if (renouvelleLe) {
      const fin = new Date(renouvelleLe.getTime())
      fin.setUTCDate(fin.getUTCDate() + 1)
      if (maintenant.getTime() < fin.getTime()) return demandee
    }
  }

  return dansLEssai(creeLe, maintenant) ? ESSAI : FORMULES.FREE
}

/** Le debut de la periode courante pour un quota. */
export function debutDePeriode(periode: Periode, maintenant: Date): Date | null {
  const d = new Date(maintenant.getTime())
  switch (periode) {
    case 'jour':
      d.setUTCHours(0, 0, 0, 0)
      return d
    case 'mois':
      d.setUTCDate(1)
      d.setUTCHours(0, 0, 0, 0)
      return d
    case 'quinzaine': {
      /*
       * Une quinzaine glissante, et non « les quinze premiers jours du
       * mois ». Un decoupage fixe donnerait deux directs a qui s'inscrit le
       * 14 — un le 14, un le 16 — et un seul a qui s'inscrit le 2.
       */
      d.setUTCHours(0, 0, 0, 0)
      d.setUTCDate(d.getUTCDate() - 13)
      return d
    }
    case 'jamais':
      return null
  }
}

export interface Verdict {
  /** Le geste est-il permis maintenant ? */
  readonly permis: boolean
  /** Ce qu'il reste, ou `null` si sans limite. */
  readonly restant: number | null
  readonly max: number | null
  readonly periode: Periode
  /** Ce qu'on dit a la personne, quand c'est refuse. */
  readonly message?: string
}

const QUAND: Readonly<Record<Periode, string>> = {
  jour: 'aujourd’hui',
  quinzaine: 'ces quinze derniers jours',
  mois: 'ce mois-ci',
  jamais: '',
}

const CE_QUE_CEST: Readonly<Record<Ressource, string>> = {
  assistant: 'question à l’assistant',
  direct: 'cours en direct',
  cours: 'cours enregistré',
}

/**
 * Le geste est-il permis, au vu de ce qui a deja ete consomme ?
 *
 * `consomme` vient de l'appelant : c'est lui qui sait compter, et c'est ce
 * qui permet d'eprouver toutes les regles ici sans base de donnees.
 */
export function verdict(
  formule: Formule,
  ressource: Ressource,
  consomme: number,
): Verdict {
  const quota = formule.quotas[ressource]
  if (quota.max === null) {
    return { permis: true, restant: null, max: null, periode: quota.periode }
  }

  const restant = Math.max(0, quota.max - Math.max(0, consomme))
  if (restant > 0) {
    return {
      permis: true,
      restant,
      max: quota.max,
      periode: quota.periode,
    }
  }

  /*
   * Le refus dit le compte et la periode, puis ce qu'on peut faire.
   *
   * « Quota atteint » n'apprend rien. « Un cours en direct ces quinze
   * derniers jours, c'est la limite du compte gratuit » se verifie, et la
   * phrase suivante donne la sortie.
   */
  const quoi = CE_QUE_CEST[ressource]
  const quand = QUAND[quota.periode]
  const compte =
    quota.max === 1 ? `Un ${quoi}` : `${quota.max} ${quoi}s`

  return {
    permis: false,
    restant: 0,
    max: quota.max,
    periode: quota.periode,
    message:
      `${compte} ${quand}, c’est la limite de la formule ${formule.nom}. `
      + 'Changez de formule pour continuer.',
  }
}

/** La formule la moins chere qui ouvre ce geste. */
export function formuleMinimale(ressource: Ressource): Formule | null {
  const ordre: CodeFormule[] = ['FREE', 'PRO', 'MASTER']
  for (const code of ordre) {
    if (FORMULES[code].quotas[ressource].max === null) return FORMULES[code]
  }
  return null
}
