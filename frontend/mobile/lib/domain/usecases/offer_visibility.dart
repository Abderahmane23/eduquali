/// Quelles offres montrer à un professeur (§17).
///
/// Seulement celles de ses matières. Proposer une offre hors de son domaine
/// n'apporte rien et noie les offres pertinentes — c'est pourquoi l'onglet
/// Offres n'a plus ni recherche ni filtres : la sélection est faite d'office.
///
/// Fonction pure, générique sur l'identifiant de matière : elle se teste sans
/// base de données.
List<T> offersInSubjects<T>(
  Iterable<T> offers, {
  required Set<String> teacherSubjectIds,
  required String Function(T offer) subjectOf,
}) {
  // Sans matière déclarée, aucune offre n'est pertinente : l'écran invite
  // alors à ajouter ses matières plutôt que de tout montrer.
  if (teacherSubjectIds.isEmpty) return const [];
  return [
    for (final offer in offers)
      if (teacherSubjectIds.contains(subjectOf(offer))) offer,
  ];
}
