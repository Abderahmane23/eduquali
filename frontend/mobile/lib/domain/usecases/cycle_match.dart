/// Quels professeurs montrer selon le palier de l'apprenant.
///
/// « Pas de professeur d'université pour un élève de 7ème. » Un parent qui
/// cherche quelqu'un pour son collégien n'a rien à faire d'un chargé de cours
/// en L3 : il parcourt une liste dont une partie ne le concerne pas, et c'est
/// la première liste qu'il voit du produit.
///
/// Fonction pure et générique sur le type de candidat : elle se teste sans base
/// de données, et c'est ce qui permet d'éprouver les trois cas limites
/// ci-dessous un par un.
library;

/// Garde les professeurs qui enseignent au cycle de l'apprenant.
///
/// [learnerCycle] vaut `PRIMAIRE`, `COLLEGE`, `LYCEE`, `SUPERIEUR` ou
/// `DIPLOME` — l'identifiant d'un palier **est** la valeur de `cycle` d'un
/// niveau, et c'est ce qui permet d'apparier sans table de correspondance.
///
/// Trois décisions, et chacune a sa raison :
///
///   * **Palier inconnu** (`null` ou vide) : on ne filtre pas. Un apprenant sans
///     niveau enregistré verrait sinon une liste vide, et conclurait qu'il n'y a
///     aucun professeur dans sa ville. Ne rien savoir n'autorise pas à cacher.
///
///   * **Professeur sans cycle déclaré** : on garde. Son profil est incomplet,
///     pas inadapté — et le cacher le priverait de toutes les familles sans que
///     rien ne le lui dise. Un profil vide se corrige ; une disparition
///     silencieuse ne se remarque pas.
///
///   * **Cycles déclarés sans recouvrement** : on écarte. C'est le cas que la
///     règle vise, et le seul où l'on dispose vraiment de l'information.
List<T> teachersForCycle<T>(
  Iterable<T> teachers, {
  required String? learnerCycle,
  required Set<String> Function(T teacher) cyclesOf,
}) {
  final palier = (learnerCycle ?? '').trim();
  if (palier.isEmpty) return [...teachers];

  return [
    for (final teacher in teachers)
      if (cyclesOf(teacher) case final cycles
          when cycles.isEmpty || cycles.contains(palier))
        teacher,
  ];
}

/// Vrai quand le filtre retirerait au moins un professeur.
///
/// Sert à n'afficher l'indication « filtré sur le niveau » que lorsqu'elle dit
/// quelque chose. Annoncer un filtre qui n'écarte personne apprend à l'ignorer,
/// et la fois où il compte vraiment, il ne se lit plus.
bool cycleFilterBites<T>(
  Iterable<T> teachers, {
  required String? learnerCycle,
  required Set<String> Function(T teacher) cyclesOf,
}) =>
    teachersForCycle(
      teachers,
      learnerCycle: learnerCycle,
      cyclesOf: cyclesOf,
    ).length <
    teachers.length;
