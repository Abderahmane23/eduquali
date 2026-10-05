import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:veriprof/data/ai/ai_gateway.dart';
import 'package:veriprof/data/ai/demo_ai_gateway.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/domain/entities/course_models.dart';

/// L'assistant de démonstration, sur une vraie base et de vrais fichiers.
///
/// Le fichier vérifiait surtout des crédits jusqu'au 25/09 : solde de
/// bienvenue, débits, remboursements, packs, vidéos récompensées. Tout cela
/// a été supprimé avec le système de crédits — l'assistant est ouvert par
/// l'abonnement, et l'écran le vérifie avant d'appeler la passerelle
/// (`family_view_test`).
///
/// Ce qui reste est ce que la passerelle fait vraiment : produire un cours,
/// en écrire les deux fichiers, et le retrouver ensuite.
void main() {
  initializeDateFormatting('fr');

  late AppDatabase db;
  late Directory documents;
  late DateTime clock;
  late DemoAiGateway ai;

  final brief = CourseBrief(
    title: 'Les fonctions affines',
    levelNames: const ['Terminale'],
    period: CoursePeriod.trimester1,
    objectives: 'Définition\nGraphique\nVariations',
    exerciseCount: 6,
    chapterCount: 3,
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    documents = await Directory.systemTemp.createTemp('eduquali_test');
    clock = DateTime(2026, 9, 18, 10);
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u1',
            role: 'TEACHER',
            phone: '+224620000101',
          ),
        );
    ai = DemoAiGateway(
      database: db,
      ownerId: 'u1',
      documentsDirectory: () async => documents,
      now: () => clock,
    );
  });

  tearDown(() async {
    await db.close();
    if (documents.existsSync()) await documents.delete(recursive: true);
  });

  group('Plan du cours', () {
    test('se demande autant de fois qu’on veut', () async {
      // Plafonné à cinq par jour tant que le plan servait de porte d'entrée
      // gratuite vers un assistant facturé à l'acte. L'assistant se paie à
      // l'abonnement : un abonné qui refait son plan six fois de suite est
      // en train de travailler, pas de contourner un tarif.
      for (var i = 0; i < 8; i++) {
        expect(await ai.outline(brief), isA<CourseOutline>());
      }
    });

    test('suit le découpage demandé', () async {
      final plan = await ai.outline(brief);
      expect(plan.chapters, hasLength(brief.chapterCount));
    });
  });

  group('Construire un cours', () {
    test('écrit le cours et ses deux fichiers', () async {
      final saved = await ai.buildCourse(brief, await ai.outline(brief));

      expect(saved.version, 1);
      expect(saved.title, 'Les fonctions affines');
      expect(saved.course.exercises, hasLength(6));
      // Word est le format proposé en premier : il doit exister, sinon le
      // bouton principal de l'écran ne mène nulle part.
      expect(File(saved.docxPath!).existsSync(), isTrue);
      expect(File(saved.docxPath!).lengthSync(), greaterThan(1000));
      expect(File(saved.xlsxPath!).existsSync(), isTrue);
      expect(File(saved.xlsxPath!).lengthSync(), greaterThan(1000));
    });

    test('les deux fichiers se retrouvent après relecture en base', () async {
      await ai.buildCourse(brief, await ai.outline(brief));

      final reread = (await ai.courses()).single;
      expect(File(reread.docxPath!).existsSync(), isTrue);
      expect(File(reread.xlsxPath!).existsSync(), isTrue);
    });

    test('le cours se retrouve dans la liste', () async {
      await ai.buildCourse(brief, await ai.outline(brief));

      final courses = await ai.courses();
      expect(courses, hasLength(1));
      expect(courses.single.course.chapters, hasLength(3));
    });
  });

  group('Améliorer un cours', () {
    Future<SavedCourse> firstCourse() async =>
        ai.buildCourse(brief, await ai.outline(brief));

    test('« ajoute 4 exercices » crée une version 2', () async {
      final first = await firstCourse();

      final second = await ai.improveCourse(
        first.courseId,
        'Ajoute 4 exercices',
      );

      expect(second.version, 2);
      expect(second.course.exercises, hasLength(10));
    });

    test('la liste ne montre que la dernière version', () async {
      final first = await firstCourse();
      await ai.improveCourse(first.courseId, 'Ajoute 2 exercices');

      final courses = await ai.courses();
      expect(courses, hasLength(1));
      expect(courses.single.version, 2);
    });

    test('les fichiers des versions précédentes restent', () async {
      final first = await firstCourse();
      final second = await ai.improveCourse(
        first.courseId,
        'Ajoute 2 exercices',
      );

      expect(File(first.docxPath!).existsSync(), isTrue);
      expect(File(second.docxPath!).existsSync(), isTrue);
      expect(first.docxPath, isNot(second.docxPath));
      expect(File(first.xlsxPath!).existsSync(), isTrue);
      expect(File(second.xlsxPath!).existsSync(), isTrue);
      expect(first.xlsxPath, isNot(second.xlsxPath));
    });

    test('un cours inconnu est refusé', () async {
      expect(
        () => ai.improveCourse('inexistant', 'Ajoute 2 exercices'),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('Discussion', () {
    test('répond sans rien décompter, et dit ce qui marche vraiment', () async {
      final reply = await ai.chat('Bonjour');

      // Le mot « démonstration » ne préfixe plus chaque réponse — il le
      // disait à chaque message. Ce qui doit rester, c'est l'aveu que le
      // texte n'est pas produit par un modèle : le retirer ferait passer du
      // contenu fabriqué sur le téléphone pour une réponse d'assistant.
      expect(
        reply.toLowerCase(),
        contains('serveur'),
        reason: 'la réponse ne dit plus qu’aucun modèle ne l’a écrite',
      );
      expect(reply.toLowerCase(), isNot(startsWith('mode démonstration')));
    });
  });

  group('Le grand livre a disparu', () {
    test('la table des crédits n’existe plus en base', () async {
      // Supprimée par la migration v20. Un test qui la nommerait par sa
      // classe ne compilerait pas ; ici on interroge le schéma réel, qui
      // est ce qu'un téléphone déjà installé va migrer.
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'credit_ledger'",
          )
          .get();
      expect(rows, isEmpty);
    });

    test('une promotion ne porte plus de coût', () async {
      final columns = await db
          .customSelect('PRAGMA table_info(promotions)')
          .get();
      final noms = [for (final c in columns) c.read<String>('name')];
      expect(noms, isNot(contains('credit_cost')));
      // Et ce qui décide du chiffre montré au directeur est resté.
      expect(noms, contains('views'));
    });
  });
}
