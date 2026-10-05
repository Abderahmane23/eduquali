/// Quels cours vidéo parlent à l'apprenant qu'on suit.
///
/// --- Pourquoi un tri et non un filtre ------------------------------------
///
/// Le catalogue ne montrait rien de l'apprenant : `published()` ne filtre que
/// `status = 'PUBLISHED'`, et un universitaire qui venait de déclarer sa classe
/// et cinq matières voyait exactement le même catalogue qu'un élève de CE2.
///
/// La réponse n'est pas de cacher le reste. Un cours d'une autre classe sert
/// pour réviser l'année passée ou préparer la suivante, et un catalogue qui
/// rétrécit en silence fait croire qu'il n'y a que trois cours. On **remonte**
/// donc ce qui correspond, et on garde le reste accessible dessous — la même
/// règle que le filtre par palier des professeurs, qui s'annonce et se retire.
///
/// --- Ce que « correspondre » veut dire -----------------------------------
///
/// Deux signaux, le niveau et la matière, et ils ne pèsent pas pareil. Une
/// matière juste au mauvais niveau reste du même domaine ; un niveau juste
/// dans une autre matière ne sert à rien. La matière passe donc devant.
library;

/// Ce qu'on sait de l'apprenant au moment de classer.
class LearnerTaste {
  const LearnerTaste({this.levelId, this.subjectIds = const {}});

  final String? levelId;
  final Set<String> subjectIds;

  /// Rien de déclaré : il n'y a pas d'ordre à préférer.
  bool get isEmpty => levelId == null && subjectIds.isEmpty;
}

/// De 0 à 3 : combien ce cours parle à l'apprenant.
///
/// Rendu séparément du tri pour que l'écran puisse dire *pourquoi* un cours
/// est en tête — « votre matière », « votre classe ».
int courseAffinity({
  required LearnerTaste taste,
  required String? subjectId,
  required List<String> levelIds,
}) {
  if (taste.isEmpty) return 0;
  var score = 0;
  if (subjectId != null && taste.subjectIds.contains(subjectId)) score += 2;
  if (taste.levelId != null && levelIds.contains(taste.levelId)) score += 1;
  return score;
}

/// Les cours réordonnés : ce qui correspond d'abord, le reste ensuite.
///
/// Stable à l'intérieur de chaque score : l'ordre d'origine du catalogue est
/// déjà choisi (nouveautés, ventes), et le bousculer sans raison ferait sauter
/// les cartes d'une ouverture à l'autre.
List<T> coursesByAffinity<T>(
  Iterable<T> courses, {
  required LearnerTaste taste,
  required String? Function(T course) subjectOf,
  required List<String> Function(T course) levelsOf,
}) {
  final liste = [...courses];
  if (taste.isEmpty) return liste;

  final scores = <T, int>{
    for (final course in liste)
      course: courseAffinity(
        taste: taste,
        subjectId: subjectOf(course),
        levelIds: levelsOf(course),
      ),
  };

  // `sort` de Dart n'est pas stable ; on trie donc sur (score, position).
  final positions = <T, int>{
    for (var i = 0; i < liste.length; i++) liste[i]: i,
  };
  liste.sort((a, b) {
    final parScore = (scores[b] ?? 0).compareTo(scores[a] ?? 0);
    return parScore != 0
        ? parScore
        : (positions[a] ?? 0).compareTo(positions[b] ?? 0);
  });
  return liste;
}

/// Les cours à mettre en avant sur l'accueil, et seulement eux.
///
/// Vide quand rien ne correspond : une section « Pour votre niveau » remplie
/// de cours d'un autre niveau serait un mensonge, et il vaut mieux qu'elle
/// disparaisse — c'est la règle des autres sections de l'accueil.
List<T> recommendedCourses<T>(
  Iterable<T> courses, {
  required LearnerTaste taste,
  required String? Function(T course) subjectOf,
  required List<String> Function(T course) levelsOf,
  int max = 4,
}) {
  if (taste.isEmpty) return const [];
  final retenus = [
    for (final course in courses)
      if (courseAffinity(
            taste: taste,
            subjectId: subjectOf(course),
            levelIds: levelsOf(course),
          ) >
          0)
        course,
  ];
  return coursesByAffinity(
    retenus,
    taste: taste,
    subjectOf: subjectOf,
    levelsOf: levelsOf,
  ).take(max).toList();
}
