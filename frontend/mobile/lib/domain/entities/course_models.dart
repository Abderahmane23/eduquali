/// Période scolaire couverte par un cours.
enum CoursePeriod {
  trimester1('TRIM_1', 'Trimestre 1'),
  trimester2('TRIM_2', 'Trimestre 2'),
  trimester3('TRIM_3', 'Trimestre 3'),
  semester1('SEM_1', 'Semestre 1'),
  semester2('SEM_2', 'Semestre 2'),
  fullYear('YEAR', 'Toute l’année');

  const CoursePeriod(this.code, this.label);
  final String code;
  final String label;

  static CoursePeriod fromCode(String? code) => CoursePeriod.values.firstWhere(
    (p) => p.code == code,
    orElse: () => fullYear,
  );
}

/// Ce que le professeur a demandé.
class CourseBrief {
  const CourseBrief({
    required this.title,
    required this.levelNames,
    required this.period,
    required this.objectives,
    this.exerciseCount = 0,
    this.withDefinitions = true,
    this.chapterCount = 4,
    this.startDate,
    this.endDate,
  });

  final String title;
  final List<String> levelNames;
  final CoursePeriod period;

  /// Texte libre : notions, figures, types d'exercices attendus.
  final String objectives;

  /// 0 = pas d'exercices.
  final int exerciseCount;
  final bool withDefinitions;

  /// 0 = pas de découpage en chapitres.
  final int chapterCount;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get withExercises => exerciseCount > 0;
  bool get withChapters => chapterCount > 0;
  bool get hasSchedule => startDate != null && endDate != null;

  /// « 11e année · Terminale · Trimestre 1 »
  String get audience => [...levelNames, period.label].join(' · ');

  Map<String, dynamic> toJson() => {
    'title': title,
    'levelNames': levelNames,
    'period': period.code,
    'objectives': objectives,
    'exerciseCount': exerciseCount,
    'withDefinitions': withDefinitions,
    'chapterCount': chapterCount,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
  };

  factory CourseBrief.fromJson(Map<String, dynamic> json) => CourseBrief(
    title: json['title'] as String,
    levelNames: (json['levelNames'] as List<dynamic>).cast<String>(),
    period: CoursePeriod.fromCode(json['period'] as String?),
    objectives: json['objectives'] as String? ?? '',
    exerciseCount: json['exerciseCount'] as int? ?? 0,
    withDefinitions: json['withDefinitions'] as bool? ?? true,
    chapterCount: json['chapterCount'] as int? ?? 0,
    startDate: _date(json['startDate']),
    endDate: _date(json['endDate']),
  );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// Le plan proposé avant de construire : c'est ce que le professeur lit pour
/// décider s'il lance la construction.
class CourseOutline {
  const CourseOutline({
    required this.title,
    required this.audience,
    required this.chapters,
    required this.recommendedExercises,
    required this.definitionCount,
  });

  final String title;
  final String audience;
  final List<ChapterSummary> chapters;
  final int recommendedExercises;
  final int definitionCount;

  Map<String, dynamic> toJson() => {
    'title': title,
    'audience': audience,
    'chapters': [for (final c in chapters) c.toJson()],
    'recommendedExercises': recommendedExercises,
    'definitionCount': definitionCount,
  };

  factory CourseOutline.fromJson(Map<String, dynamic> json) => CourseOutline(
    title: json['title'] as String,
    audience: json['audience'] as String? ?? '',
    chapters: [
      for (final c in (json['chapters'] as List<dynamic>? ?? []))
        ChapterSummary.fromJson(c as Map<String, dynamic>),
    ],
    recommendedExercises: json['recommendedExercises'] as int? ?? 0,
    definitionCount: json['definitionCount'] as int? ?? 0,
  );
}

class ChapterSummary {
  const ChapterSummary({required this.title, required this.summary});

  final String title;
  final String summary;

  Map<String, dynamic> toJson() => {'title': title, 'summary': summary};

  factory ChapterSummary.fromJson(Map<String, dynamic> json) => ChapterSummary(
    title: json['title'] as String,
    summary: json['summary'] as String? ?? '',
  );
}

class CourseChapter {
  const CourseChapter({
    required this.number,
    required this.title,
    required this.content,
    this.durationHours = 2,
  });

  final int number;
  final String title;
  final String content;
  final int durationHours;

  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'content': content,
    'durationHours': durationHours,
  };

  factory CourseChapter.fromJson(Map<String, dynamic> json) => CourseChapter(
    number: json['number'] as int,
    title: json['title'] as String,
    content: json['content'] as String? ?? '',
    durationHours: json['durationHours'] as int? ?? 2,
  );
}

class CourseDefinition {
  const CourseDefinition({
    required this.term,
    required this.definition,
    required this.chapter,
  });

  final String term;
  final String definition;
  final int chapter;

  Map<String, dynamic> toJson() => {
    'term': term,
    'definition': definition,
    'chapter': chapter,
  };

  factory CourseDefinition.fromJson(Map<String, dynamic> json) =>
      CourseDefinition(
        term: json['term'] as String,
        definition: json['definition'] as String? ?? '',
        chapter: json['chapter'] as int? ?? 1,
      );
}

class CourseExercise {
  const CourseExercise({
    required this.number,
    required this.chapter,
    required this.statement,
    required this.solution,
    this.difficulty = 2,
  });

  final int number;
  final int chapter;
  final String statement;
  final String solution;

  /// 1 facile, 2 moyen, 3 difficile.
  final int difficulty;

  String get difficultyLabel => switch (difficulty) {
    1 => 'Facile',
    3 => 'Difficile',
    _ => 'Moyen',
  };

  Map<String, dynamic> toJson() => {
    'number': number,
    'chapter': chapter,
    'statement': statement,
    'solution': solution,
    'difficulty': difficulty,
  };

  factory CourseExercise.fromJson(Map<String, dynamic> json) => CourseExercise(
    number: json['number'] as int,
    chapter: json['chapter'] as int? ?? 1,
    statement: json['statement'] as String? ?? '',
    solution: json['solution'] as String? ?? '',
    difficulty: json['difficulty'] as int? ?? 2,
  );
}

class CourseSession {
  const CourseSession({
    required this.date,
    required this.chapter,
    required this.topic,
  });

  final DateTime date;
  final int chapter;
  final String topic;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'chapter': chapter,
    'topic': topic,
  };

  factory CourseSession.fromJson(Map<String, dynamic> json) => CourseSession(
    date: DateTime.parse(json['date'] as String),
    chapter: json['chapter'] as int? ?? 1,
    topic: json['topic'] as String? ?? '',
  );
}

/// Le cours complet. C'est ce JSON qui est conservé : le fichier Excel en est
/// refabriqué à chaque version.
class Course {
  const Course({
    required this.brief,
    required this.outline,
    required this.chapters,
    this.definitions = const [],
    this.exercises = const [],
    this.schedule = const [],
    this.demo = true,
  });

  final CourseBrief brief;
  final CourseOutline outline;
  final List<CourseChapter> chapters;
  final List<CourseDefinition> definitions;
  final List<CourseExercise> exercises;
  final List<CourseSession> schedule;

  /// Généré sans appel à un modèle : contenu d'exemple.
  final bool demo;

  String get title => outline.title;

  Course copyWith({
    List<CourseChapter>? chapters,
    List<CourseDefinition>? definitions,
    List<CourseExercise>? exercises,
  }) => Course(
    brief: brief,
    outline: outline,
    chapters: chapters ?? this.chapters,
    definitions: definitions ?? this.definitions,
    exercises: exercises ?? this.exercises,
    schedule: schedule,
    demo: demo,
  );

  Map<String, dynamic> toJson() => {
    'brief': brief.toJson(),
    'outline': outline.toJson(),
    'chapters': [for (final c in chapters) c.toJson()],
    'definitions': [for (final d in definitions) d.toJson()],
    'exercises': [for (final e in exercises) e.toJson()],
    'schedule': [for (final s in schedule) s.toJson()],
    'demo': demo,
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    brief: CourseBrief.fromJson(json['brief'] as Map<String, dynamic>),
    outline: CourseOutline.fromJson(json['outline'] as Map<String, dynamic>),
    chapters: [
      for (final c in (json['chapters'] as List<dynamic>? ?? []))
        CourseChapter.fromJson(c as Map<String, dynamic>),
    ],
    definitions: [
      for (final d in (json['definitions'] as List<dynamic>? ?? []))
        CourseDefinition.fromJson(d as Map<String, dynamic>),
    ],
    exercises: [
      for (final e in (json['exercises'] as List<dynamic>? ?? []))
        CourseExercise.fromJson(e as Map<String, dynamic>),
    ],
    schedule: [
      for (final s in (json['schedule'] as List<dynamic>? ?? []))
        CourseSession.fromJson(s as Map<String, dynamic>),
    ],
    demo: json['demo'] as bool? ?? true,
  );
}
