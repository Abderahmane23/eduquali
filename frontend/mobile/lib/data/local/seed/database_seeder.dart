import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_enums.dart';
import '../database/app_database.dart';

/// Charge le referentiel et les données de démonstration dans la base locale.
///
/// Le referentiel (matières, niveaux, tests) proviendra du serveur via
/// `GET /api/v1/sync/pull` (§44) ; il est ici embarque en asset afin que
/// l'application soit pleinement utilisable des la première ouverture, y
/// compris sans connexion (§41).
class DatabaseSeeder {
  DatabaseSeeder(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();
  static const _seedFlag = 'seed_version';

  /// Version du jeu de donnees embarque.
  ///
  /// A incrementer des qu'un element du catalogue change : le seed ne
  /// repasse que si cette valeur differe de celle enregistree. Sans cela,
  /// une classe ajoutee n'apparait jamais sur une installation existante.
  ///
  /// v2 — Terminale, fiche detaillee des etablissements, Universite Nongo
  /// Conakry.
  /// v3 — offres de cours a domicile des professeurs de demonstration.
  /// v4 — cycles scolaires, Biologie et Geologie.
  /// v5 — programme guineen : classes accentuees, en-tetes de cycle retires
  /// de la liste des classes, matieres manquantes (philosophie, EPS,
  /// education civique, facultes universitaires) et les trois profils de
  /// lycee.
  /// v6 — cours video de demonstration, avec leurs chapitres.
  /// v7 — mises en avant d'etablissements.
  static const _seedVersion = '7';

  Future<void> seedIfNeeded() async {
    final current = await _db.readMeta(_seedFlag);
    if (current == _seedVersion) return;

    final catalog =
        jsonDecode(await rootBundle.loadString('assets/seed/catalog.json'))
            as Map<String, dynamic>;

    // Le programme national vient de `shared/curriculum/` : c'est un fait
    // fixe que les deux clients lisent, pas une donnee de back-office.
    final curriculum =
        jsonDecode(await rootBundle.loadString('assets/curriculum/guinea.json'))
            as Map<String, dynamic>;

    await _db.transaction(() async {
      await _seedSubjects(catalog['subjects'] as List<dynamic>);
      await _seedLevels(catalog['levels'] as List<dynamic>);
      await _seedFilieres(curriculum['filieres'] as List<dynamic>? ?? const []);
      await _seedTests(catalog['tests'] as List<dynamic>);
      await _seedInstitutions(catalog['institutions'] as List<dynamic>);
      await _seedJobs(catalog['jobs'] as List<dynamic>);
      await _seedDemoTeachers(catalog['demoTeachers'] as List<dynamic>);
      // Après les professeurs : une offre référence son professeur.
      await _seedTutoringServices(
        catalog['tutoringServices'] as List<dynamic>? ?? const [],
      );
      await _seedVideoCourses(
        catalog['videoCourses'] as List<dynamic>? ?? const [],
      );
      await _seedPromotions(
        catalog['promotions'] as List<dynamic>? ?? const [],
      );
    });

    await _db.writeMeta(_seedFlag, _seedVersion);
  }

  Future<void> _seedSubjects(List<dynamic> items) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.subjects, [
        for (final raw in items.cast<Map<String, dynamic>>())
          SubjectsCompanion.insert(
            id: raw['id'] as String,
            name: raw['name'] as String,
            code: raw['code'] as String,
            cycles: Value(
              (raw['cycles'] as List<dynamic>? ?? const []).cast<String>().join(
                ',',
              ),
            ),
            sortOrder: Value(raw['order'] as int),
          ),
      ]);
    });
  }

  Future<void> _seedLevels(List<dynamic> items) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.levels, [
        for (final raw in items.cast<Map<String, dynamic>>())
          LevelsCompanion.insert(
            id: raw['id'] as String,
            name: raw['name'] as String,
            code: raw['code'] as String,
            category: raw['category'] as String,
            cycle: Value(raw['cycle'] as String? ?? ''),
            grouping: Value(raw['grouping'] as bool? ?? false),
            sortOrder: Value(raw['order'] as int),
          ),
      ]);
    });
  }

  /// Les trois profils du second cycle.
  Future<void> _seedFilieres(List<dynamic> items) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.filieres, [
        for (final raw in items.cast<Map<String, dynamic>>())
          FilieresCompanion.insert(
            id: raw['id'] as String,
            name: raw['name'] as String,
            code: raw['code'] as String,
            note: Value(raw['note'] as String? ?? ''),
            cycle: Value(raw['cycle'] as String? ?? 'LYCEE'),
            levelIds: Value(_joined(raw['levelIds'])),
            majorSubjectIds: Value(_joined(raw['majorSubjectIds'])),
            subjectIds: Value(_joined(raw['subjectIds'])),
            sortOrder: Value(raw['order'] as int? ?? 0),
          ),
      ]);
    });
  }

  static String _joined(Object? value) =>
      (value as List<dynamic>? ?? const []).cast<String>().join(',');

  /// Charge chaque banque de questions et cree le test correspondant (§10.1).
  Future<void> _seedTests(List<dynamic> items) async {
    for (final raw in items.cast<Map<String, dynamic>>()) {
      final bankFile = raw['bank'] as String;
      final bank =
          jsonDecode(await rootBundle.loadString('assets/seed/$bankFile'))
              as Map<String, dynamic>;

      final questions = (bank['questions'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final testId = raw['id'] as String;

      await _db
          .into(_db.tests)
          .insertOnConflictUpdate(
            TestsCompanion.insert(
              id: testId,
              subjectId: raw['subjectId'] as String,
              levelId: raw['levelId'] as String,
              title: bank['title'] as String,
              // Le nombre annonce correspond au contenu reellement disponible.
              questionCount: questions.length,
              durationMinutes:
                  bank['durationMinutes'] as int? ??
                  AppConstants.testDurationMinutes,
              passingScore:
                  bank['passingScore'] as int? ?? AppConstants.testPassingScore,
              rules: Value(bank['rules'] as String?),
            ),
          );

      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.testQuestions, [
          for (var i = 0; i < questions.length; i++)
            _questionCompanion(testId, questions[i], i),
        ]);
      });
    }
  }

  TestQuestionsCompanion _questionCompanion(
    String testId,
    Map<String, dynamic> raw,
    int index,
  ) {
    final options = (raw['o'] as List<dynamic>).cast<String>();
    // Les options sont stockees avec leur cle d'affichage : A, B, C, D.
    final encoded = jsonEncode([
      for (var i = 0; i < options.length; i++)
        {'key': String.fromCharCode(65 + i), 'text': options[i]},
    ]);

    return TestQuestionsCompanion.insert(
      id: '${testId}_q${index + 1}',
      testId: testId,
      statement: raw['q'] as String,
      optionsJson: encoded,
      correctKey: raw['a'] as String,
      domain: raw['d'] as String,
      position: index,
      difficulty: Value(raw['x'] as int? ?? 2),
      explanation: Value(raw['e'] as String?),
    );
  }

  Future<void> _seedInstitutions(List<dynamic> items) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.institutions, [
        for (final raw in items.cast<Map<String, dynamic>>())
          InstitutionsCompanion.insert(
            id: raw['id'] as String,
            name: raw['name'] as String,
            type: raw['type'] as String,
            city: raw['city'] as String,
            address: Value(raw['address'] as String?),
            managerName: Value(raw['managerName'] as String?),
            description: Value(raw['description'] as String?),
            verificationStatus: Value(raw['verificationStatus'] as String),
            phone: Value(raw['phone'] as String?),
            phoneAlt: Value(raw['phoneAlt'] as String?),
            email: Value(raw['email'] as String?),
            website: Value(raw['website'] as String?),
            foundedYear: Value(raw['foundedYear'] as int?),
            ownership: Value(raw['ownership'] as String?),
            academicSystem: Value(raw['academicSystem'] as String?),
            degrees: Value(raw['degrees'] as String? ?? ''),
            specialties: Value(raw['specialties'] as String? ?? ''),
            facilities: Value(raw['facilities'] as String? ?? ''),
          ),
      ]);
    });
  }

  Future<void> _seedJobs(List<dynamic> items) async {
    final now = DateTime.now();
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.jobs, [
        for (final raw in items.cast<Map<String, dynamic>>())
          JobsCompanion.insert(
            id: raw['id'] as String,
            institutionId: raw['institutionId'] as String,
            title: raw['title'] as String,
            subjectId: raw['subjectId'] as String,
            levelIds: Value(
              (raw['levelIds'] as List<dynamic>).cast<String>().join(','),
            ),
            city: raw['city'] as String,
            contractType: raw['contractType'] as String,
            description: Value(raw['description'] as String?),
            salaryMin: Value(raw['salaryMin'] as int?),
            salaryMax: Value(raw['salaryMax'] as int?),
            salaryPublished: Value(raw['salaryPublished'] as bool? ?? false),
            minExperience: Value(raw['minExperience'] as int? ?? 0),
            requiresCertification: Value(
              raw['requiresCertification'] as bool? ?? false,
            ),
            status: const Value('PUBLISHED'),
            publishedAt: Value(
              now.subtract(
                Duration(days: raw['publishedDaysAgo'] as int? ?? 0),
              ),
            ),
          ),
      ]);
    });
  }

  /// Offres de cours à domicile des professeurs de démonstration.
  ///
  /// Sans elles, un parent qui installe l'application ne trouve aucun
  /// professeur à réserver et ne peut rien tester.
  Future<void> _seedTutoringServices(List<dynamic> items) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.tutoringServices, [
        for (final raw in items.cast<Map<String, dynamic>>())
          TutoringServicesCompanion.insert(
            id: raw['id'] as String,
            teacherId: raw['teacherId'] as String,
            subjectId: raw['subjectId'] as String,
            levelIds: Value(
              (raw['levelIds'] as List<dynamic>).cast<String>().join(','),
            ),
            mode: Value(raw['mode'] as String),
            hourlyRate: Value(raw['hourlyRate'] as int?),
            city: Value(raw['city'] as String?),
            districts: Value(
              (raw['districts'] as List<dynamic>? ?? const [])
                  .cast<String>()
                  .join(','),
            ),
            availabilityNote: Value(raw['availabilityNote'] as String?),
            description: Value(raw['description'] as String?),
          ),
      ]);
    });
  }

  /// Mises en avant d'établissements (02/10).
  ///
  /// C'est ce qu'un établissement achète avec la formule Master, et l'onglet
  /// Promotion n'avait rien à montrer sur une installation neuve : ni
  /// l'établissement ni la famille ne pouvaient voir à quoi ressemble la page
  /// qu'on leur vend.
  ///
  /// Aucun média : une image de démonstration pèserait dans l'APK sans rien
  /// apprendre. Le titre et le message sont ce qui porte l'annonce.
  Future<void> _seedPromotions(List<dynamic> items) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.promotions, [
        for (final raw in items.cast<Map<String, dynamic>>())
          PromotionsCompanion.insert(
            id: raw['id'] as String,
            institutionId: raw['institutionId'] as String,
            title: raw['title'] as String,
            message: Value(raw['message'] as String?),
            status: Value(raw['status'] as String? ?? 'ACTIVE'),
          ),
      ]);
    });
  }

  /// Cours vidéo de démonstration, avec leur sommaire (02/10).
  ///
  /// Sans eux, l'onglet « Cours vidéo » était vide sur une installation
  /// neuve : le lecteur écrit le 02/10 n'était atteignable qu'après qu'un
  /// professeur ait créé un cours, et personne ne pouvait voir à quoi
  /// ressemblait le produit.
  ///
  /// **Les vidéos n'ont pas de fichier.** Un fichier de démonstration
  /// pèserait dans l'APK pour montrer une image noire, et l'écran dit
  /// honnêtement « Bientôt disponible » sur une vidéo sans source. Ce qui est
  /// réel ici, c'est la structure : titres, chapitres, descriptions, durées,
  /// ressources — ce qu'un élève lit avant d'acheter.
  Future<void> _seedVideoCourses(List<dynamic> items) async {
    for (final raw in items.cast<Map<String, dynamic>>()) {
      final courseId = raw['id'] as String;

      await _db
          .into(_db.videoCourses)
          .insertOnConflictUpdate(
            VideoCoursesCompanion.insert(
              id: courseId,
              teacherId: raw['teacherId'] as String,
              title: raw['title'] as String,
              description: Value(raw['description'] as String?),
              subjectId: Value(raw['subjectId'] as String?),
              levelIds: Value(
                (raw['levelIds'] as List<dynamic>? ?? const [])
                    .cast<String>()
                    .join(','),
              ),
              price: Value(raw['price'] as int? ?? 0),
              status: Value(raw['status'] as String? ?? 'PUBLISHED'),
            ),
          );

      final chapitres = (raw['chapters'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      for (var rang = 0; rang < chapitres.length; rang++) {
        final chapitre = chapitres[rang];
        // Identifiant déduit du rang, et non tiré au hasard : le semis se
        // rejoue à chaque montée de version, et des identifiants neufs
        // empileraient les chapitres au lieu de les remplacer.
        final chapitreId = '${courseId}_ch${rang + 1}';

        await _db
            .into(_db.courseChapters)
            .insertOnConflictUpdate(
              CourseChaptersCompanion.insert(
                id: chapitreId,
                courseId: courseId,
                title: chapitre['title'] as String,
                description: Value(chapitre['description'] as String?),
                position: Value(rang),
              ),
            );

        final elements = (chapitre['items'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.courseItems, [
            for (var i = 0; i < elements.length; i++)
              CourseItemsCompanion.insert(
                id: '${chapitreId}_it${i + 1}',
                chapterId: chapitreId,
                kind: Value(elements[i]['kind'] as String? ?? 'VIDEO'),
                title: elements[i]['title'] as String,
                durationSeconds: Value(elements[i]['durationSeconds'] as int?),
                position: Value(i),
              ),
          ]);
        });
      }
    }
  }

  /// Enseignants de démonstration : ils alimentent la recherche cote
  /// établissement (§21) et le classement des candidats (§22).
  Future<void> _seedDemoTeachers(List<dynamic> items) async {
    final now = DateTime.now();

    for (final raw in items.cast<Map<String, dynamic>>()) {
      final teacherId = raw['id'] as String;
      final userId = 'user_$teacherId';

      await _db
          .into(_db.users)
          .insertOnConflictUpdate(
            UsersCompanion.insert(
              id: userId,
              role: UserRole.teacher.code,
              phone: raw['phone'] as String,
              firstName: Value(raw['firstName'] as String),
              lastName: Value(raw['lastName'] as String),
              city: Value(raw['city'] as String?),
              phoneVerified: const Value(true),
            ),
          );

      await _db
          .into(_db.teachers)
          .insertOnConflictUpdate(
            TeachersCompanion.insert(
              id: teacherId,
              userId: userId,
              headline: Value(raw['headline'] as String?),
              bio: Value(raw['bio'] as String?),
              city: Value(raw['city'] as String?),
              yearsExperience: Value(raw['yearsExperience'] as int? ?? 0),
              availability: Value(
                raw['availability'] as String? ?? 'AVAILABLE',
              ),
              identityStatus: Value(raw['identityStatus'] as String? ?? 'NONE'),
              diplomaStatus: Value(raw['diplomaStatus'] as String? ?? 'NONE'),
              preferredInstitutionTypes: Value(
                (raw['preferredInstitutionTypes'] as List<dynamic>? ?? [])
                    .cast<String>()
                    .join(','),
              ),
            ),
          );

      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.teacherSubjects, [
          for (final subjectId
              in (raw['subjects'] as List<dynamic>).cast<String>())
            TeacherSubjectsCompanion.insert(
              id: '${teacherId}_$subjectId',
              teacherId: teacherId,
              subjectId: subjectId,
            ),
        ]);

        batch.insertAllOnConflictUpdate(_db.teacherLevels, [
          for (final pair in (raw['levels'] as List<dynamic>))
            TeacherLevelsCompanion.insert(
              id: '${teacherId}_${(pair as List<dynamic>).join("_")}',
              teacherId: teacherId,
              subjectId: pair[0] as String,
              levelId: pair[1] as String,
            ),
        ]);

        batch.insertAllOnConflictUpdate(_db.teacherCertifications, [
          for (final cert
              in (raw['certifications'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>())
            TeacherCertificationsCompanion.insert(
              id: '${teacherId}_${cert["subjectId"]}_${cert["levelId"]}',
              teacherId: teacherId,
              subjectId: cert['subjectId'] as String,
              levelId: cert['levelId'] as String,
              score: cert['score'] as int,
              issuedAt: Value(now.subtract(const Duration(days: 90))),
            ),
        ]);

        batch.insertAllOnConflictUpdate(_db.teacherExperiences, [
          for (final exp
              in (raw['experiences'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>())
            TeacherExperiencesCompanion.insert(
              id: _uuid.v4(),
              teacherId: teacherId,
              institutionName: exp['institutionName'] as String,
              position: exp['position'] as String,
              city: Value(exp['city'] as String?),
              startDate: DateTime(exp['startYear'] as int, 9),
              endDate: Value(
                exp['endYear'] == null
                    ? null
                    : DateTime(exp['endYear'] as int, 7),
              ),
              current: Value(exp['endYear'] == null),
              verificationStatus: Value(
                (exp['verified'] as bool? ?? false) ? 'VERIFIED' : 'PENDING',
              ),
            ),
        ]);
      });
    }
  }
}
