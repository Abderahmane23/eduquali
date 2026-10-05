/**
 * Comparaison de texte pour la recherche.
 *
 * Un clavier de telephone guineen tape « Nzerekore », « francais », « Bafata »
 * — sans accent, sans majuscule. Comparer les chaines telles quelles fait
 * repondre « aucun resultat » sur une liste qui contient la reponse, et la
 * personne conclut que son ecole n'existe pas.
 *
 * Meme regle que `lib/core/utils/text_search.dart` cote mobile : les deux
 * clients lisent le meme referentiel, ils doivent y trouver les memes choses.
 */

/**
 * Met une chaine sous la forme utilisee pour comparer : minuscules, sans
 * accents, espaces reduits.
 *
 * A n'utiliser que pour comparer. Ce qui est affiche reste la chaine
 * d'origine : « Nzerekore » s'ecrit avec ses accents.
 */
export function foldText(value: string): string {
  return value
    .toLowerCase()
    .replace(/[àâäá]/g, 'a')
    .replace(/[éèêë]/g, 'e')
    .replace(/[îïí]/g, 'i')
    .replace(/[ôöó]/g, 'o')
    .replace(/[ûüùú]/g, 'u')
    .replace(/ç/g, 'c')
    .replace(/\s+/g, ' ')
    .trim()
}

/** `needle` apparait-il dans `haystack`, accents et casse ignores ? */
export function matchesSearch(haystack: string, needle: string): boolean {
  const q = foldText(needle)
  return q === '' || foldText(haystack).includes(q)
}
