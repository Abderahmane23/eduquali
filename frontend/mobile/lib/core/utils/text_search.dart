/// Comparaison de texte pour la recherche.
///
/// Un clavier de téléphone guinéen tape « Nzerekore », « francais », « Bafata »
/// — sans accent, sans majuscule. Comparer les chaînes telles quelles fait
/// répondre « aucun résultat » sur une liste qui contient la réponse, et la
/// personne conclut que son école n'existe pas.
library;

/// Met une chaîne sous la forme utilisée pour comparer : minuscules, sans
/// accents, espaces réduits.
///
/// À n'utiliser que pour comparer. Ce qui est affiché reste la chaîne
/// d'origine : « Nzérékoré » s'écrit avec ses accents.
String foldText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[àâäá]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îïí]'), 'i')
    .replaceAll(RegExp('[ôöó]'), 'o')
    .replaceAll(RegExp('[ûüùú]'), 'u')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// [needle] apparaît-il dans [haystack], accents et casse ignorés ?
bool matchesSearch(String haystack, String needle) {
  final q = foldText(needle);
  return q.isEmpty || foldText(haystack).contains(q);
}
