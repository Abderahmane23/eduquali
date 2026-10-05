import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/domain/entities/onboarding_spec.dart';

/// Matières et classes proposées selon le cycle enseigné.
///
/// Demande du 19/09 : un professeur de collège ne doit pas voir la liste
/// entière. Le droit n'est pas enseigné au collège, la lecture ne l'est plus
/// au lycée — une liste de treize matières pour tout le monde est une charge
/// inutile et une source d'erreur.
void main() {
  final catalog =
      jsonDecode(File('assets/seed/catalog.json').readAsStringSync())
          as Map<String, dynamic>;

  List<OnboardingOption> optionsFrom(String key, String cycleField) => [
    for (final raw in (catalog[key] as List).cast<Map<String, dynamic>>())
      OnboardingOption(
        value: raw['id'] as String,
        label: raw['name'] as String,
        groups: raw[cycleField] is List
            ? [for (final c in raw[cycleField] as List) c.toString()]
            : [raw[cycleField].toString()],
      ),
  ];

  final subjects = optionsFrom('subjects', 'cycles');
  // Les en-tetes de cycle ne sont pas des classes : c'est la liste telle que
  // la rend `CatalogRepository.levels()`, groupings exclus.
  final levels = [
    for (final raw in (catalog['levels'] as List).cast<Map<String, dynamic>>())
      if (raw['grouping'] != true)
        OnboardingOption(
          value: raw['id'] as String,
          label: raw['name'] as String,
          groups: [raw['cycle'].toString()],
        ),
  ];
  final filter = OptionsFilter.on('cycles');

  Set<String> namesFor(List<OnboardingOption> options, List<String> cycles) =>
      filter.apply(options, {'cycles': cycles}).map((o) => o.label).toSet();

  group('Matières proposées', () {
    test('le collège ne voit pas le droit ni la géologie', () {
      final college = namesFor(subjects, ['COLLEGE']);
      expect(college, contains('Mathematiques'));
      expect(college, contains('Biologie'));
      expect(college, isNot(contains('Droit')));
      expect(college, isNot(contains('Geologie')));
      // La philosophie commence en Terminale, pas au college.
      expect(college, isNot(contains('Philosophie')));
      expect(college, isNot(contains('Médecine')));
    });

    test('le lycée voit la géologie, pas le droit', () {
      final lycee = namesFor(subjects, ['LYCEE']);
      expect(lycee, contains('Geologie'));
      expect(lycee, contains('Philosophie'));
      expect(lycee, isNot(contains('Droit')));
      expect(lycee, isNot(contains('Génie civil')));
    });

    test('le supérieur voit tout, droit compris', () {
      expect(namesFor(subjects, ['SUPERIEUR']), contains('Droit'));
    });

    test('deux cycles cochés réunissent les deux listes', () {
      final both = namesFor(subjects, ['COLLEGE', 'SUPERIEUR']);
      expect(both, contains('Biologie'));
      expect(both, contains('Droit'));
    });

    test('la liste raccourcit vraiment', () {
      // Sans filtre, vingt-cinq matieres : toute la scolarite guineenne, du
      // primaire aux facultes. C'est ce qu'on voulait eviter de montrer d'un
      // bloc.
      //
      // Vingt-quatre jusqu'au 03/10 : l'arabe manquait au referentiel alors que
      // le programme national le liste pour les sept classes du secondaire. Le
      // controle croise de `sync.mjs` l'a signale en comparant les identifiants
      // cites par le programme a ceux du catalogue.
      expect(subjects.length, 25);
      expect(namesFor(subjects, ['PRIMAIRE']).length, lessThan(8));
      expect(namesFor(subjects, ['COLLEGE']).length, lessThan(subjects.length));
    });

    test('sans cycle choisi, tout reste visible', () {
      // Mieux vaut trop montrer que bloquer quelqu'un devant une liste vide.
      expect(filter.apply(subjects, const {}), hasLength(subjects.length));
    });

    test('Biologie et Géologie sont au référentiel', () {
      final all = subjects.map((s) => s.label);
      expect(all, containsAll(['Biologie', 'Geologie']));
    });
  });

  group('Classes proposées', () {
    test('le collège montre ses quatre années, pas celles du lycée', () {
      // Le college guineen va de la 7eme a la 10eme annee, et se termine
      // par le BEPC.
      final college = namesFor(levels, ['COLLEGE']);
      expect(college, {
        '7ème année',
        '8ème année',
        '9ème année',
        '10ème année',
      });
      expect(college, isNot(contains('Terminale')));
    });

    test('le lycée montre ses trois classes, et rien d’autre', () {
      // Demande du 19/09 : « le professeur qui a choisi un cycle ne voit que
      // les classes correspondantes ». « Lycee » est un en-tete de cycle, il
      // n'a rien a faire a cote de « 11eme annee ».
      final lycee = namesFor(levels, ['LYCEE']);
      expect(lycee, {'11ème année', '12ème année', 'Terminale'});
      expect(lycee, isNot(contains('Lycée')));
      expect(lycee, isNot(contains('L1')));
    });

    test('aucun en-tête de cycle ne traîne dans les classes', () {
      final all = levels.map((l) => l.label).toSet();
      expect(all, isNot(contains('Primaire')));
      expect(all, isNot(contains('Collège')));
      expect(all, isNot(contains('Lycée')));
    });

    test('le supérieur ne voit que l’université', () {
      final sup = namesFor(levels, ['SUPERIEUR']);
      // Le systeme LMD : licence, master, doctorat.
      expect(sup, containsAll(['L1', 'L2', 'L3', 'Master 1', 'Master 2']));
      expect(sup, isNot(contains('Terminale')));
    });

    test('chaque classe porte un cycle', () {
      for (final level in levels) {
        expect(
          level.groups.single,
          isIn(['PRIMAIRE', 'COLLEGE', 'LYCEE', 'SUPERIEUR']),
          reason: '${level.label} sans cycle exploitable',
        );
      }
    });
  });
}
