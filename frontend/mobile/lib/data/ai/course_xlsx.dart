import 'dart:convert';

import 'package:archive/archive.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/course_models.dart';
import '../../domain/usecases/demo_course_generator.dart';

/// Une feuille : un nom et des lignes de cellules texte.
class _Sheet {
  _Sheet(this.name, this.rows);
  final String name;
  final List<List<String>> rows;
}

/// Fabrique le fichier Excel d'un cours.
///
/// Un `.xlsx` est une archive zip contenant quelques fichiers XML. On les
/// écrit directement : le paquet `excel` exigerait `archive` 3.x et `xml` < 7,
/// alors que le projet utilise déjà `archive` 4.x et `xml` 7 — l'ajouter
/// ferait reculer des dépendances dont d'autres fonctions dépendent.
///
/// Les valeurs partent en « chaîne littérale » (`inlineStr`), ce qui évite la
/// table de chaînes partagées : un fichier de plus à écrire, et une source
/// d'incohérence pour un gain nul à cette taille.
abstract final class CourseXlsx {
  static List<int> build(Course course) {
    final sheets = <_Sheet>[
      _cover(course),
      _chapters(course),
      if (course.definitions.isNotEmpty) _definitions(course),
      if (course.exercises.isNotEmpty) ...[
        _exercises(course),
        _solutions(course),
      ],
      if (course.schedule.isNotEmpty) _schedule(course),
    ];

    final archive = Archive();
    void add(String path, String content) {
      final bytes = utf8.encode(content);
      archive.add(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml', _contentTypes(sheets.length));
    add('_rels/.rels', _rootRels);
    add('xl/workbook.xml', _workbook(sheets));
    add('xl/_rels/workbook.xml.rels', _workbookRels(sheets.length));
    for (var i = 0; i < sheets.length; i++) {
      add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheets[i]));
    }

    return ZipEncoder().encode(archive);
  }

  /// Nom de fichier lisible et sans surprise pour le système.
  static String fileName(Course course, int version) {
    final slug = course.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'(^-|-$)'), '');
    return '${slug.isEmpty ? "cours" : slug}-v$version.xlsx';
  }

  // --- Feuilles ---------------------------------------------------------

  static _Sheet _cover(Course course) {
    final brief = course.brief;
    return _Sheet('Cours', [
      ['Titre', course.title],
      ['Classes', brief.levelNames.join(', ')],
      ['Période', brief.period.label],
      if (brief.hasSchedule)
        [
          'Dates',
          '${Fmt.date(brief.startDate!)} → ${Fmt.date(brief.endDate!)}',
        ],
      ['Chapitres', '${course.chapters.length}'],
      ['Définitions', '${course.definitions.length}'],
      ['Exercices', '${course.exercises.length}'],
      [],
      ['Objectifs', brief.objectives],
      [],
      ['Sommaire', ''],
      for (final c in course.chapters) ['${c.number}', c.title],
      [],
      if (course.demo) ['Avertissement', DemoCourseGenerator.demoNotice],
    ]);
  }

  static _Sheet _chapters(Course course) => _Sheet('Chapitres', [
    ['N°', 'Titre', 'Contenu', 'Durée conseillée'],
    for (final c in course.chapters)
      ['${c.number}', c.title, c.content, '${c.durationHours} h'],
  ]);

  static _Sheet _definitions(Course course) => _Sheet('Définitions', [
    ['Terme', 'Définition', 'Chapitre'],
    for (final d in course.definitions) [d.term, d.definition, '${d.chapter}'],
  ]);

  static _Sheet _exercises(Course course) => _Sheet('Exercices', [
    ['N°', 'Chapitre', 'Énoncé', 'Difficulté'],
    for (final e in course.exercises)
      ['${e.number}', '${e.chapter}', e.statement, e.difficultyLabel],
  ]);

  static _Sheet _solutions(Course course) => _Sheet('Corrigés', [
    ['N°', 'Corrigé'],
    for (final e in course.exercises) ['${e.number}', e.solution],
  ]);

  static _Sheet _schedule(Course course) => _Sheet('Calendrier', [
    ['Date', 'Chapitre', 'Séance'],
    for (final s in course.schedule)
      [Fmt.date(s.date), '${s.chapter}', s.topic],
  ]);

  // --- Parties XML ------------------------------------------------------

  static String _contentTypes(int sheetCount) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '${[for (var i = 1; i <= sheetCount; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
      '</Types>';

  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="xl/workbook.xml"/>'
      '</Relationships>';

  static String _workbook(List<_Sheet> sheets) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets>'
      '${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_attr(sheets[i].name)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
      '</sheets></workbook>';

  static String _workbookRels(int sheetCount) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${[for (var i = 1; i <= sheetCount; i++) '<Relationship Id="rId$i" '
            'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
            'Target="worksheets/sheet$i.xml"/>'].join()}'
      '</Relationships>';

  static String _sheetXml(_Sheet sheet) {
    final rows = StringBuffer();
    for (var r = 0; r < sheet.rows.length; r++) {
      final cells = sheet.rows[r];
      rows.write('<row r="${r + 1}">');
      for (var c = 0; c < cells.length; c++) {
        final value = cells[c];
        if (value.isEmpty) continue;
        rows.write(
          '<c r="${_ref(c, r)}" t="inlineStr"><is><t xml:space="preserve">'
          '${_text(value)}</t></is></c>',
        );
      }
      rows.write('</row>');
    }

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData>$rows</sheetData></worksheet>';
  }

  /// « A1 », « B2 »… puis « AA1 » au-delà de 26 colonnes.
  static String _ref(int column, int row) {
    var name = '';
    var n = column;
    while (true) {
      name = String.fromCharCode(65 + (n % 26)) + name;
      if (n < 26) break;
      n = (n ~/ 26) - 1;
    }
    return '$name${row + 1}';
  }

  /// Échappe le texte et retire les caractères de contrôle qu'Excel refuse.
  static String _text(String value) =>
      _attr(value.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), ''));

  static String _attr(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
