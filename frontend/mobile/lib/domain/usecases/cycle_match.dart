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
///   * **Professeur sans cycle déclaré** : on écarte, depuis le 11/10.
///
///     La règle disait l'inverse, et sa raison était juste : « le cacher le
///     priverait de toutes les familles sans que rien ne le lui dise ». Elle
///     tenait parce que l'inscription **jetait** les niveaux déclarés — un
///     professeur avait un profil vide sans y être pour rien, et le punir
///     aurait été injuste.
///
///     Ce n'est plus le cas : l'inscription enregistre les matières et les
///     niveaux, et `POST /teacher/competences` les pousse. Un profil vide
///     signifie désormais que le professeur a sauté l'étape, et la barre de
///     complétion de son profil le lui dit.
///
///     Le garder coûtait plus cher que l'écarter : un parent de CE2 voyait un
///     chargé de cours de L3 dans la première liste du produit.
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
      if (cyclesOf(teacher).contains(palier)) teacher,
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
