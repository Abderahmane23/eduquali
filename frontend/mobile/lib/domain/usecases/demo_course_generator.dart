import '../entities/course_models.dart';

/// Génère un cours **sans appeler de modèle**.
///
/// Sert tant que le serveur et la clé Gemini n'existent pas : le professeur
/// peut parcourir tout le trajet — formulaire, plan, construction, fichier
/// Excel — sur un téléphone hors ligne. Le contenu est bâti à partir de ce
/// qu'il a saisi, il est donc plausible, mais ce n'est pas un vrai cours :
/// chaque écran et le fichier produit le disent.
///
/// Déterministe : deux appels sur la même demande donnent le même résultat.
/// C'est ce qui rend cette classe testable, et c'est aussi la propriété que
/// le vrai générateur n'aura pas.
abstract final class DemoCourseGenerator {
  /// Marque reprise dans l'application et dans le fichier Excel.
  static const demoNotice =
      'Contenu d’exemple, généré sans intelligence artificielle. '
      'Le vrai contenu arrivera avec la connexion au serveur.';

  static CourseOutline outline(CourseBrief brief) {
    final topics = _topics(brief);
    return CourseOutline(
      title: brief.title.trim().isEmpty ? 'Cours' : brief.title.trim(),
      audience: brief.audience,
      chapters: [
        for (var i = 0; i < topics.length; i++)
          ChapterSummary(
            title: 'Chapitre ${i + 1} — ${topics[i]}',
            summary: _summaryFor(topics[i], brief),
          ),
      ],
      recommendedExercises: brief.withExercises
          ? brief.exerciseCount
          : _recommendedExercises(topics.length),
      definitionCount: brief.withDefinitions ? topics.length * 3 : 0,
    );
  }

  static Course build(CourseBrief brief, CourseOutline plan) {
    final topics = [
      for (final c in plan.chapters) c.title.split('—').last.trim(),
    ];

    final chapters = [
      for (var i = 0; i < topics.length; i++)
        CourseChapter(
          number: i + 1,
          title: topics[i],
          content: _chapterContent(topics[i], brief),
          durationHours: 2,
        ),
    ];

    return Course(
      brief: brief,
      outline: plan,
      chapters: chapters,
      definitions: brief.withDefinitions ? _definitions(topics) : const [],
      exercises: brief.withExercises
          ? exercises(topics, brief.exerciseCount)
          : const [],
      schedule: brief.hasSchedule ? _schedule(brief, chapters) : const [],
    );
  }

  /// Exercices répartis sur les chapitres, en tournant.
  ///
  /// Exposé pour que l'amélioration d'un cours (« ajoute 5 exercices »)
  /// produise la même forme que la construction initiale.
  static List<CourseExercise> exercises(
    List<String> topics,
    int count, {
    int startAt = 1,
  }) => [
    for (var i = 0; i < count; i++)
      CourseExercise(
        number: startAt + i,
        chapter: topics.isEmpty ? 1 : (i % topics.length) + 1,
        statement:
            'Exercice ${startAt + i} — '
            '${topics.isEmpty ? "Application" : topics[i % topics.length]} : '
            'appliquer la notion vue en cours à un cas concret.',
        solution:
            'Corrigé attendu : rappeler la définition, poser les étapes, '
            'conclure par une phrase de réponse.',
        difficulty: (i % 3) + 1,
      ),
  ];

  // --- Construction du contenu -----------------------------------------

  /// Les thèmes viennent d'abord de ce que le professeur a écrit : une ligne,
  /// une puce ou un point-virgule par notion. À défaut, on découpe le titre.
  static List<String> _topics(CourseBrief brief) {
    final wanted = brief.withChapters ? brief.chapterCount : 1;
    final written = [
      for (final raw in brief.objectives.split(RegExp(r'[\n;•·]')))
        if (raw.trim().length > 2) _shorten(raw.trim()),
    ];

    if (written.length >= wanted) return written.take(wanted).toList();

    final title = brief.title.trim().isEmpty ? 'la notion' : brief.title.trim();
    return [
      ...written,
      for (var i = written.length; i < wanted; i++) _fallbackTopic(title, i),
    ];
  }

  static String _fallbackTopic(String title, int index) => switch (index) {
    0 => '$title : notions de base',
    1 => '$title : méthodes et propriétés',
    2 => '$title : applications',
    3 => '$title : synthèse et révisions',
    _ => '$title : approfondissement ${index - 2}',
  };

  static String _summaryFor(String topic, CourseBrief brief) =>
      'Ce que l’élève doit savoir faire à la fin : reconnaître, appliquer et '
      'justifier « ${_shorten(topic, 60)} » pour ${brief.levelNames.isEmpty ? "sa classe" : brief.levelNames.join(" et ")}.';

  static String _chapterContent(String topic, CourseBrief brief) =>
      '1. Introduction — situer « ${_shorten(topic, 60)} » dans le programme '
      'de ${brief.period.label.toLowerCase()}.\n'
      '2. Notions clés et vocabulaire.\n'
      '3. Méthode pas à pas, avec un exemple traité.\n'
      '4. Erreurs fréquentes et comment les éviter.\n'
      '5. Ce qu’il faut retenir.';

  static List<CourseDefinition> _definitions(List<String> topics) => [
    for (var i = 0; i < topics.length; i++)
      for (var j = 0; j < 3; j++)
        CourseDefinition(
          term: '${_shorten(topics[i], 40)} — terme ${j + 1}',
          definition:
              'Définition à compléter : énoncé court, une phrase, suivi d’un '
              'exemple tiré du chapitre ${i + 1}.',
          chapter: i + 1,
        ),
  ];

  /// Une séance par semaine, du début à la fin de la période.
  static List<CourseSession> _schedule(
    CourseBrief brief,
    List<CourseChapter> chapters,
  ) {
    final start = brief.startDate!;
    final end = brief.endDate!;
    final weeks = (end.difference(start).inDays / 7).floor() + 1;
    final count = weeks < chapters.length ? chapters.length : weeks;

    return [
      for (var i = 0; i < count; i++)
        CourseSession(
          date: start.add(Duration(days: 7 * i)),
          chapter: chapters.isEmpty ? 1 : (i % chapters.length) + 1,
          topic: chapters.isEmpty
              ? 'Séance ${i + 1}'
              : chapters[i % chapters.length].title,
        ),
    ];
  }

  static int _recommendedExercises(int chapters) => chapters * 4;

  static String _shorten(String value, [int max = 80]) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max - 1)}…';
  }
}
