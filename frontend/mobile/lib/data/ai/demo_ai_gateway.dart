import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/course_models.dart';
import '../../domain/usecases/demo_course_generator.dart';
import '../local/database/app_database.dart';
import 'ai_gateway.dart';
import 'course_docx.dart';
import 'course_xlsx.dart';

/// Assistant fonctionnant **sans serveur ni modèle**.
///
/// Tout se passe sur le téléphone : le cours fabriqué par
/// `DemoCourseGenerator`, les fichiers Word et Excel écrits dans le dossier
/// de l'application. C'est ce qui permet de parcourir le trajet complet sur
/// un APK partagé par Bluetooth, sans réseau.
///
/// Elle ne compte rien : l'accès à l'assistant est décidé par l'abonnement,
/// vérifié par l'écran avant tout appel. Quand le serveur existera, ce
/// contrôle se refera de son côté — seul endroit où un client ne peut pas
/// mentir.
class DemoAiGateway implements AiGateway {
  DemoAiGateway({
    required AppDatabase database,
    required String ownerId,
    required Future<Directory> Function() documentsDirectory,
    DateTime Function() now = DateTime.now,
  }) : _db = database,
       _documents = documentsDirectory,
       // ignore: prefer_initializing_formals
       _ownerId = ownerId,
       // ignore: prefer_initializing_formals
       _now = now;

  /// Compte propriétaire des cours produits.
  final String _ownerId;

  /// Horloge injectable : la date d'un cours se teste sans attendre demain.
  final DateTime Function() _now;

  final AppDatabase _db;
  final Future<Directory> Function() _documents;
  static const _uuid = Uuid();

  @override
  bool get isDemo => true;

  // --- Cours ------------------------------------------------------------

  @override
  Future<CourseOutline> outline(CourseBrief brief) async =>
      DemoCourseGenerator.outline(brief);

  @override
  Future<SavedCourse> buildCourse(CourseBrief brief, CourseOutline plan) async {
    final course = DemoCourseGenerator.build(brief, plan);
    return _save(course, courseId: _uuid.v4(), version: 1);
  }

  @override
  Future<SavedCourse> improveCourse(String courseId, String instruction) async {
    final previous = await _latest(courseId);
    if (previous == null) {
      throw const AiException('Ce cours est introuvable.');
    }

    final improved = _applyDemoImprovement(previous.course, instruction);
    return _save(improved, courseId: courseId, version: previous.version + 1);
  }

  @override
  Future<List<SavedCourse>> courses() async {
    final rows =
        await (_db.select(_db.aiCourses)
              ..where((t) => t.ownerId.equals(_ownerId))
              ..orderBy([
                // La version prime sur la date : deux versions enregistrées dans
                // la même seconde s'ordonnaient sinon au hasard, et la liste
                // pouvait montrer la v1 après une amélioration.
                (t) => OrderingTerm.desc(t.version),
                (t) => OrderingTerm.desc(t.createdAt),
              ]))
            .get();

    // Une seule entrée par cours : sa dernière version.
    final seen = <String>{};
    final latest = [
      for (final row in rows)
        if (seen.add(row.courseId)) _toSaved(row),
    ];
    // Puis le cours le plus récemment touché en premier.
    latest.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return latest;
  }

  @override
  Future<String> chat(String message) async {
    // La mention « mode démonstration » ne préfixe plus chaque réponse : elle
    // le disait à chaque message et transformait la conversation en
    // avertissement répété.
    //
    // Elle ne disparaît pas pour autant. Ce texte est écrit sur le téléphone,
    // sans modèle : le présenter comme une réponse d'assistant serait faire
    // passer du contenu fabriqué pour un résultat. La phrase reste, une fois,
    // à la fin — là où elle explique ce qu'on vient de lire.
    return 'Les réponses écrites arriveront avec la connexion au serveur. '
        'Ce qui fonctionne dès maintenant, c’est la construction d’un cours '
        '— touchez « Crée un cours complet ».';
  }

  // --- Mécanique --------------------------------------------------------

  Future<SavedCourse> _save(
    Course course, {
    required String courseId,
    required int version,
  }) async {
    final id = _uuid.v4();
    final directory = Directory(
      '${(await _documents()).path}${Platform.pathSeparator}cours',
    );
    await directory.create(recursive: true);

    // Les deux formats sont écrits d'un coup : le professeur choisit au
    // moment du téléchargement, pas au moment de la construction.
    final docx = File(
      '${directory.path}${Platform.pathSeparator}'
      '${CourseDocx.fileName(course, version)}',
    );
    await docx.writeAsBytes(CourseDocx.build(course));

    final xlsx = File(
      '${directory.path}${Platform.pathSeparator}'
      '${CourseXlsx.fileName(course, version)}',
    );
    await xlsx.writeAsBytes(CourseXlsx.build(course));

    await _db
        .into(_db.aiCourses)
        .insert(
          AiCoursesCompanion.insert(
            id: id,
            ownerId: _ownerId,
            courseId: courseId,
            version: version,
            title: course.title,
            courseJson: jsonEncode(course.toJson()),
            docxPath: Value(docx.path),
            xlsxPath: Value(xlsx.path),
            demo: const Value(true),
            createdAt: Value(_now()),
          ),
        );

    return SavedCourse(
      id: id,
      courseId: courseId,
      version: version,
      title: course.title,
      course: course,
      createdAt: _now(),
      docxPath: docx.path,
      xlsxPath: xlsx.path,
    );
  }

  /// Amélioration en mode démonstration.
  ///
  /// Reconnaît « ajoute N exercices » et « simplifie ». Toute autre demande
  /// ajoute une note de révision : mieux vaut un effet visible et honnête
  /// qu'un texte inventé qui ferait croire à une vraie compréhension.
  Course _applyDemoImprovement(Course course, String instruction) {
    final text = instruction.toLowerCase();
    final number = RegExp(r'\d+').firstMatch(text);

    if (text.contains('exercice')) {
      final extra = int.tryParse(number?.group(0) ?? '') ?? 5;
      return course.copyWith(
        exercises: [
          ...course.exercises,
          ...DemoCourseGenerator.exercises(
            [for (final c in course.chapters) c.title],
            extra,
            startAt: course.exercises.length + 1,
          ),
        ],
      );
    }

    if (text.contains('simplifi')) {
      return course.copyWith(
        definitions: [
          for (final d in course.definitions)
            CourseDefinition(
              term: d.term,
              definition: 'En une phrase : ${d.definition.split('.').first}.',
              chapter: d.chapter,
            ),
        ],
      );
    }

    return course.copyWith(
      chapters: [
        ...course.chapters,
        CourseChapter(
          number: course.chapters.length + 1,
          title: 'Révisions',
          content:
              'Demande du professeur : « $instruction ».\n'
              'À compléter — en mode démonstration, cette demande est '
              'enregistrée mais pas encore traitée.',
          durationHours: 1,
        ),
      ],
    );
  }

  Future<SavedCourse?> _latest(String courseId) async {
    final rows =
        await (_db.select(_db.aiCourses)
              ..where(
                (t) => t.ownerId.equals(_ownerId) & t.courseId.equals(courseId),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.version)])
              ..limit(1))
            .get();
    return rows.isEmpty ? null : _toSaved(rows.first);
  }

  SavedCourse _toSaved(AiCourseRow row) => SavedCourse(
    id: row.id,
    courseId: row.courseId,
    version: row.version,
    title: row.title,
    course: Course.fromJson(jsonDecode(row.courseJson) as Map<String, dynamic>),
    createdAt: row.createdAt,
    docxPath: row.docxPath,
    xlsxPath: row.xlsxPath,
  );
}
