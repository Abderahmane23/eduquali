import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:veriprof/data/ai/course_docx.dart';
import 'package:veriprof/data/ai/course_xlsx.dart';
import 'package:veriprof/domain/entities/course_models.dart';
import 'package:veriprof/domain/usecases/demo_course_generator.dart';

void main() {
  // Les dates du fichier Excel sont formatées en français, comme dans
  // l'application (`main.dart`).
  initializeDateFormatting('fr');

  final brief = CourseBrief(
    title: 'Les fonctions affines',
    levelNames: const ['11e année', 'Terminale'],
    period: CoursePeriod.trimester1,
    objectives:
        'Définition et vocabulaire\n'
        'Représentation graphique\n'
        'Sens de variation\n'
        'Problèmes concrets',
    exerciseCount: 15,
    chapterCount: 4,
    startDate: DateTime(2026, 10),
    endDate: DateTime(2026, 12, 15),
  );

  group('Plan du cours', () {
    test('autant de chapitres que demandé', () {
      expect(DemoCourseGenerator.outline(brief).chapters, hasLength(4));
    });

    test('les chapitres reprennent ce que le professeur a écrit', () {
      final titles = DemoCourseGenerator.outline(
        brief,
      ).chapters.map((c) => c.title).join(' ');
      expect(titles, contains('Représentation graphique'));
      expect(titles, contains('Sens de variation'));
    });

    test('complète quand le professeur en écrit moins que demandé', () {
      final vague = CourseBrief(
        title: 'Le théorème de Thalès',
        levelNames: const ['10e année'],
        period: CoursePeriod.fullYear,
        objectives: 'Comprendre le théorème',
        chapterCount: 4,
      );
      final plan = DemoCourseGenerator.outline(vague);
      expect(plan.chapters, hasLength(4));
      expect(plan.chapters.map((c) => c.title).toSet(), hasLength(4));
    });

    test('reprend le nombre d’exercices demandé', () {
      expect(DemoCourseGenerator.outline(brief).recommendedExercises, 15);
    });

    test('en propose un nombre si le professeur n’a rien dit', () {
      final sansExos = CourseBrief(
        title: 'Cours',
        levelNames: const ['11e année'],
        period: CoursePeriod.semester1,
        objectives: 'A\nB',
        chapterCount: 2,
      );
      expect(DemoCourseGenerator.outline(sansExos).recommendedExercises, 8);
    });

    test('deux appels donnent le même plan', () {
      final a = DemoCourseGenerator.outline(brief).toJson().toString();
      final b = DemoCourseGenerator.outline(brief).toJson().toString();
      expect(a, b);
    });
  });

  group('Cours construit', () {
    final course = DemoCourseGenerator.build(
      brief,
      DemoCourseGenerator.outline(brief),
    );

    test('respecte la demande', () {
      expect(course.chapters, hasLength(4));
      expect(course.exercises, hasLength(15));
      expect(course.definitions, hasLength(12));
      expect(course.demo, isTrue);
    });

    test('chaque exercice a un corrigé et vise un chapitre existant', () {
      for (final e in course.exercises) {
        expect(e.solution, isNotEmpty);
        expect(e.chapter, inInclusiveRange(1, course.chapters.length));
      }
    });

    test('le calendrier tient dans la période demandée', () {
      expect(course.schedule, isNotEmpty);
      for (final s in course.schedule) {
        expect(s.date.isBefore(brief.startDate!), isFalse);
      }
    });

    test('sans exercices ni définitions si le professeur n’en veut pas', () {
      final minimal = CourseBrief(
        title: 'Cours court',
        levelNames: const ['Terminale'],
        period: CoursePeriod.trimester2,
        objectives: 'Un seul point',
        exerciseCount: 0,
        withDefinitions: false,
        chapterCount: 1,
      );
      final built = DemoCourseGenerator.build(
        minimal,
        DemoCourseGenerator.outline(minimal),
      );
      expect(built.exercises, isEmpty);
      expect(built.definitions, isEmpty);
      expect(built.schedule, isEmpty);
    });

    test('se relit après enregistrement', () {
      final back = Course.fromJson(course.toJson());
      expect(back.title, course.title);
      expect(back.exercises.length, course.exercises.length);
      expect(back.schedule.first.date, course.schedule.first.date);
    });
  });

  group('Fichier Excel', () {
    final course = DemoCourseGenerator.build(
      brief,
      DemoCourseGenerator.outline(brief),
    );
    final bytes = CourseXlsx.build(course);
    final archive = ZipDecoder().decodeBytes(bytes);
    String part(String path) =>
        utf8.decode(archive.findFile(path)!.content as List<int>);

    test('contient les parties attendues d’un classeur', () {
      final names = archive.files.map((f) => f.name).toSet();
      expect(
        names,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'xl/workbook.xml',
          'xl/_rels/workbook.xml.rels',
          'xl/worksheets/sheet1.xml',
        ]),
      );
    });

    test('une feuille par partie du cours', () {
      final workbook = part('xl/workbook.xml');
      for (final name in [
        'Cours',
        'Chapitres',
        'Définitions',
        'Exercices',
        'Corrigés',
        'Calendrier',
      ]) {
        expect(workbook, contains('name="$name"'));
      }
    });

    test('le contenu du cours est dans les feuilles', () {
      expect(
        part('xl/worksheets/sheet1.xml'),
        contains('Les fonctions affines'),
      );
      expect(part('xl/worksheets/sheet2.xml'), contains('Sens de variation'));
    });

    test('l’avertissement « exemple » figure dans le fichier', () {
      // Un fichier qui circule doit dire lui-même ce qu'il vaut.
      expect(part('xl/worksheets/sheet1.xml'), contains('exemple'));
    });

    test('les caractères spéciaux sont échappés', () {
      final piege = CourseBrief(
        title: 'Fractions & « ratios » <avancé>',
        levelNames: const ['11e année'],
        period: CoursePeriod.fullYear,
        objectives: 'a < b & c > d',
        chapterCount: 1,
      );
      final xml = utf8.decode(
        ZipDecoder()
                .decodeBytes(
                  CourseXlsx.build(
                    DemoCourseGenerator.build(
                      piege,
                      DemoCourseGenerator.outline(piege),
                    ),
                  ),
                )
                .findFile('xl/worksheets/sheet1.xml')!
                .content
            as List<int>,
      );
      expect(xml, contains('&amp;'));
      expect(xml, contains('&lt;avanc'));
      expect(xml, isNot(contains('<avancé>')));
    });

    test('le nom de fichier est lisible et versionné', () {
      expect(CourseXlsx.fileName(course, 2), 'les-fonctions-affines-v2.xlsx');
    });

    test('écrit un fichier réel pour vérification externe', () async {
      final out = File('build/test_course.xlsx');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes);
      expect(await out.length(), greaterThan(1000));
    });
  });

  group('Fichier Word', () {
    final course = DemoCourseGenerator.build(
      brief,
      DemoCourseGenerator.outline(brief),
    );
    final bytes = CourseDocx.build(course);
    final archive = ZipDecoder().decodeBytes(bytes);
    String part(String path) =>
        utf8.decode(archive.findFile(path)!.content as List<int>);
    final document = part('word/document.xml');

    test('contient les parties attendues d’un document', () {
      final names = archive.files.map((f) => f.name).toSet();
      expect(
        names,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'word/document.xml',
          'word/_rels/document.xml.rels',
          'word/styles.xml',
        ]),
      );
    });

    test('le cours entier est dans le document', () {
      // Word est le format par défaut : rien ne doit rester dans l'Excel
      // seul, sinon le professeur croit avoir tout téléchargé.
      expect(document, contains('Les fonctions affines'));
      expect(document, contains('Sommaire'));
      expect(document, contains('Sens de variation'));
      expect(document, contains('Corrigés'));
      expect(document, contains('Calendrier'));
      expect(document, contains(course.definitions.first.term));
      expect(document, contains(course.exercises.first.statement));
      expect(document, contains(course.exercises.first.solution));
    });

    test('chaque chapitre a son titre de niveau 2', () {
      for (final chapter in course.chapters) {
        expect(document, contains('Chapitre ${chapter.number}'));
      }
      expect(
        'Titre2'.allMatches(document).length,
        greaterThanOrEqualTo(course.chapters.length),
      );
    });

    test('les titres passent par des styles nommés, pas par du gras posé '
        'à la main', () {
      // Le professeur peut alors changer l'apparence de tous les titres
      // d'un coup dans Word.
      expect(part('word/styles.xml'), contains('w:styleId="Titre2"'));
      expect(document, isNot(contains('<w:b/>')));
    });

    test('l’avertissement « exemple » figure dans le fichier', () {
      expect(document, contains('exemple'));
    });

    test('les caractères spéciaux sont échappés', () {
      final piege = CourseBrief(
        title: 'Fractions & « ratios » <avancé>',
        levelNames: const ['11e année'],
        period: CoursePeriod.fullYear,
        objectives: 'a < b & c > d',
        chapterCount: 1,
      );
      final xml = utf8.decode(
        ZipDecoder()
                .decodeBytes(
                  CourseDocx.build(
                    DemoCourseGenerator.build(
                      piege,
                      DemoCourseGenerator.outline(piege),
                    ),
                  ),
                )
                .findFile('word/document.xml')!
                .content
            as List<int>,
      );
      expect(xml, contains('&amp;'));
      expect(xml, contains('&lt;avanc'));
      expect(xml, isNot(contains('<avancé>')));
    });

    test('le nom de fichier est lisible et versionné', () {
      expect(CourseDocx.fileName(course, 2), 'les-fonctions-affines-v2.docx');
    });

    test('écrit un fichier réel pour vérification externe', () async {
      final out = File('build/test_course.docx');
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes);
      expect(await out.length(), greaterThan(1000));
    });
  });
}
