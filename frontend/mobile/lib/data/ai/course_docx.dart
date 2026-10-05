import 'dart:convert';

import 'package:archive/archive.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/course_models.dart';
import '../../domain/usecases/demo_course_generator.dart';

/// Fabrique le fichier Word d'un cours.
///
/// Word est le format que le professeur rouvre, corrige et réutilise —
/// l'Excel sert aux tableaux (exercices, calendrier), pas au cours lui-même.
///
/// Un `.docx` est, comme un `.xlsx`, une archive zip de fichiers XML. On les
/// écrit directement : les bibliothèques Word disponibles tirent des
/// dépendances incompatibles avec celles déjà utilisées ici.
abstract final class CourseDocx {
  static List<int> build(Course course) {
    final body = StringBuffer();

    _title(body, course.title);
    _line(body, course.brief.audience, style: 'Sous');
    if (course.brief.hasSchedule) {
      _line(
        body,
        'Du ${Fmt.date(course.brief.startDate!)} '
        'au ${Fmt.date(course.brief.endDate!)}',
        style: 'Sous',
      );
    }

    if (course.brief.objectives.trim().isNotEmpty) {
      _heading(body, 'Objectifs');
      for (final line in course.brief.objectives.split('\n')) {
        if (line.trim().isNotEmpty) _line(body, line.trim());
      }
    }

    _heading(body, 'Sommaire');
    for (final chapter in course.chapters) {
      _line(body, '${chapter.number}. ${chapter.title}');
    }

    for (final chapter in course.chapters) {
      _heading(body, 'Chapitre ${chapter.number} — ${chapter.title}');
      for (final line in chapter.content.split('\n')) {
        if (line.trim().isNotEmpty) _line(body, line.trim());
      }

      final definitions = course.definitions
          .where((d) => d.chapter == chapter.number)
          .toList();
      if (definitions.isNotEmpty) {
        _heading(body, 'Définitions', level: 3);
        for (final d in definitions) {
          _line(body, '${d.term} : ${d.definition}');
        }
      }

      final exercises = course.exercises
          .where((e) => e.chapter == chapter.number)
          .toList();
      if (exercises.isNotEmpty) {
        _heading(body, 'Exercices', level: 3);
        for (final e in exercises) {
          _line(body, '${e.statement}  (${e.difficultyLabel})');
        }
      }
    }

    if (course.exercises.isNotEmpty) {
      _heading(body, 'Corrigés');
      for (final e in course.exercises) {
        _line(body, 'Exercice ${e.number} — ${e.solution}');
      }
    }

    if (course.schedule.isNotEmpty) {
      _heading(body, 'Calendrier');
      for (final s in course.schedule) {
        _line(body, '${Fmt.date(s.date)} — ${s.topic}');
      }
    }

    if (course.demo) {
      _heading(body, 'Avertissement');
      _line(body, DemoCourseGenerator.demoNotice);
    }

    final archive = Archive();
    void add(String path, String content) {
      final bytes = utf8.encode(content);
      archive.add(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes);
    add('_rels/.rels', _rootRels);
    add('word/document.xml', _document(body.toString()));
    add('word/_rels/document.xml.rels', _documentRels);
    add('word/styles.xml', _styles);

    return ZipEncoder().encode(archive);
  }

  static String fileName(Course course, int version) {
    final slug = course.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'(^-|-$)'), '');
    return '${slug.isEmpty ? "cours" : slug}-v$version.docx';
  }

  // --- Blocs ------------------------------------------------------------

  static void _title(StringBuffer b, String text) => b.write(
    '<w:p><w:pPr><w:pStyle w:val="Titre"/></w:pPr>'
    '<w:r><w:t xml:space="preserve">${_escape(text)}</w:t></w:r></w:p>',
  );

  static void _heading(StringBuffer b, String text, {int level = 2}) => b.write(
    '<w:p><w:pPr><w:pStyle w:val="Titre$level"/></w:pPr>'
    '<w:r><w:t xml:space="preserve">${_escape(text)}</w:t></w:r></w:p>',
  );

  static void _line(StringBuffer b, String text, {String style = 'Normal'}) =>
      b.write(
        '<w:p><w:pPr><w:pStyle w:val="$style"/></w:pPr>'
        '<w:r><w:t xml:space="preserve">${_escape(text)}</w:t></w:r></w:p>',
      );

  // --- Parties XML ------------------------------------------------------

  static const _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '</Types>';

  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/>'
      '</Relationships>';

  static const _documentRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
      'Target="styles.xml"/>'
      '</Relationships>';

  static String _document(String body) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>$body</w:body></w:document>';

  /// Styles nommés plutôt que de la mise en forme répétée : le professeur
  /// peut changer l'apparence de tous les titres d'un coup dans Word.
  static const _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:style w:type="paragraph" w:styleId="Normal" w:default="1">'
      '<w:name w:val="Normal"/>'
      '<w:pPr><w:spacing w:after="120"/></w:pPr>'
      '<w:rPr><w:sz w:val="22"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="Titre">'
      '<w:name w:val="Title"/>'
      '<w:pPr><w:spacing w:after="240"/></w:pPr>'
      '<w:rPr><w:b/><w:sz w:val="48"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="Sous">'
      '<w:name w:val="Subtitle"/>'
      '<w:pPr><w:spacing w:after="160"/></w:pPr>'
      '<w:rPr><w:color w:val="55556A"/><w:sz w:val="24"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="Titre2">'
      '<w:name w:val="heading 2"/>'
      '<w:pPr><w:spacing w:before="320" w:after="160"/><w:outlineLvl w:val="1"/></w:pPr>'
      '<w:rPr><w:b/><w:sz w:val="32"/></w:rPr></w:style>'
      '<w:style w:type="paragraph" w:styleId="Titre3">'
      '<w:name w:val="heading 3"/>'
      '<w:pPr><w:spacing w:before="240" w:after="120"/><w:outlineLvl w:val="2"/></w:pPr>'
      '<w:rPr><w:b/><w:sz w:val="26"/></w:rPr></w:style>'
      '</w:styles>';

  static String _escape(String value) => value
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
