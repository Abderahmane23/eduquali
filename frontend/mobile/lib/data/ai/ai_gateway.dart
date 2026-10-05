import '../../domain/entities/course_models.dart';

/// Un cours enregistré, dans une version donnée.
class SavedCourse {
  const SavedCourse({
    required this.id,
    required this.courseId,
    required this.version,
    required this.title,
    required this.course,
    required this.createdAt,
    this.docxPath,
    this.xlsxPath,
  });

  final String id;

  /// Identique pour toutes les versions d'un même cours.
  final String courseId;
  final int version;
  final String title;
  final Course course;
  final DateTime createdAt;

  /// Le cours en Word : le format que le professeur rouvre et corrige.
  final String? docxPath;

  /// Le meme cours en Excel : exercices et calendrier en tableaux.
  final String? xlsxPath;
}

/// Refus de l'assistant, formulé pour être affiché tel quel.
class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Ce que l'application demande à l'assistant.
///
/// Une seule implémentation existe aujourd'hui, `DemoAiGateway`, qui ne
/// contacte aucun modèle. La vraie passera par le serveur : la clé Gemini ne
/// doit jamais se trouver dans l'APK, qui circule de téléphone à téléphone et
/// se décompile en quelques minutes (voir docs/AI_ASSISTANT.md, §3).
abstract interface class AiGateway {
  /// Vrai tant que les réponses sont fabriquées sur l'appareil.
  bool get isDemo;

  /// Plan du cours, avant de le construire.
  Future<CourseOutline> outline(CourseBrief brief);

  /// Construit le cours et écrit ses fichiers Word et Excel.
  Future<SavedCourse> buildCourse(CourseBrief brief, CourseOutline plan);

  /// Nouvelle version d'un cours existant.
  Future<SavedCourse> improveCourse(String courseId, String instruction);

  /// Dernière version de chaque cours, la plus récente en premier.
  Future<List<SavedCourse>> courses();

  /// Un message libre.
  Future<String> chat(String message);
}
