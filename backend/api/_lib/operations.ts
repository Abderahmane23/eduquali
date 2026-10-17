/**
 * Les règles de décision de l'exploitation.
 *
 * --- Pourquoi elles vivent ici ------------------------------------------
 *
 * Marquer un retrait payé est la seule opération du produit qu'on ne peut
 * pas annuler : l'argent part par Orange Money et ne revient pas. Les gardes
 * qui l'entourent ne doivent pas dépendre d'une base pour être vérifiées —
 * sinon elles ne le sont jamais.
 *
 * Elles sont donc des fonctions pures : on leur donne l'état lu et l'entrée
 * reçue, elles rendent un verdict. La route se contente de lire, d'appeler,
 * et d'écrire.
 */

/** Les états dans lesquels une demande de retrait attend encore. */
export const RETRAITS_OUVERTS = ['REQUESTED', 'APPROVED'] as const

/** Ce que la route a lu dans la table avant de décider. */
export interface DemandeRetrait {
  id: string
  amount: number
  status: string
}

/** Ce que l'opérateur a envoyé. */
export interface EntreeRetrait {
  decision: 'PAID' | 'REJECTED'
  note?: string
  amountConfirmed?: number
}

/**
 * Un verdict, et rien d'autre.
 *
 * `deja` n'est pas une erreur : c'est l'état attendu quand deux opérateurs
 * ouvrent la même file, ou quand on revient sur l'écran. Rendre un échec
 * ferait croire à une panne et inviterait à recommencer — sur un paiement,
 * recommencer est exactement ce qu'il ne faut pas faire.
 */
export type Verdict =
  | { ok: true; status: 'PAID' | 'REJECTED'; note: string | null }
  | { ok: false; deja: true; status: string }
  | { ok: false; deja?: false; code: number; message: string }

export function deciderRetrait(
  demande: DemandeRetrait,
  entree: EntreeRetrait,
): Verdict {
  if (!(RETRAITS_OUVERTS as readonly string[]).includes(demande.status)) {
    return { ok: false, deja: true, status: demande.status }
  }

  /*
   * Un refus sans motif se relit comme une panne, et se vit comme un vol.
   *
   * Le professeur voit la note telle quelle. « Refusé » tout seul ne lui dit
   * ni quoi corriger ni s'il peut redemander.
   */
  if (entree.decision === 'REJECTED') {
    if (!entree.note || entree.note.trim() === '') {
      return { ok: false, code: 400, message: 'Un refus demande un motif.' }
    }
    return { ok: true, status: 'REJECTED', note: entree.note.trim() }
  }

  /*
   * Le montant, retapé.
   *
   * Aucune vérification de permission ne protège de la ligne d'à côté : un
   * opérateur qui traite vingt demandes clique sur la dix-neuvième en
   * pensant à la vingtième. Retaper la somme est la garde la plus simple, et
   * la seule qui attrape cette erreur-là.
   */
  if (entree.amountConfirmed !== demande.amount) {
    return {
      ok: false,
      code: 409,
      message: 'Le montant retapé ne correspond pas à la demande.',
    }
  }

  return {
    ok: true,
    status: 'PAID',
    note: entree.note?.trim() ? entree.note.trim() : null,
  }
}

/** Ce que l'opérateur a envoyé pour un lot. */
export interface EntreeLot {
  decision: 'DELIVERED' | 'REFUSED'
  note?: string
}

/**
 * Un refus de lot demande un motif, une remise non.
 *
 * L'asymétrie est volontaire : une remise est une bonne nouvelle qui se
 * suffit, un refus reprend quelque chose que l'élève croyait avoir.
 */
export function deciderLot(
  entree: EntreeLot,
): { ok: true } | { ok: false; code: number; message: string } {
  if (entree.decision === 'REFUSED' && !entree.note?.trim()) {
    return { ok: false, code: 400, message: 'Un refus demande un motif.' }
  }
  return { ok: true }
}
