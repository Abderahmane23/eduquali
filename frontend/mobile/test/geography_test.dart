import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/domain/entities/guinea_geography.dart';
import 'package:veriprof/domain/entities/onboarding_spec.dart';

/// Le découpage administratif et la cascade qui le présente.
///
/// Le fichier vient de `shared/geography/guinea.json` ; la copie lue ici est
/// celle qu'embarque l'application, donc exactement ce que voit un testeur.
void main() {
  final raw = File(GuineaGeography.asset).readAsStringSync();
  final geography = GuineaGeography.fromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );

  group('Découpage administratif', () {
    test('les 10 régions sont là', () {
      expect(geography.regions, hasLength(10));
      final names = geography.regions.map((r) => r.name).toList();
      expect(
        names,
        containsAll([
          'Conakry',
          'Boké',
          'Kindia',
          'Mamou',
          'Labé',
          'Faranah',
          'Kankan',
          'Siguiri',
          'Nzérékoré',
          'Beyla',
        ]),
      );
    });

    test('aucune région n’est vide', () {
      // Une région sans subdivision bloque l'inscription sur un écran qui
      // n'explique rien.
      for (final region in geography.regions) {
        expect(region.divisions, isNotEmpty, reason: region.name);
      }
    });

    test('Conakry se découpe en 13 communes, pas en préfectures', () {
      final conakry = geography.region('CKY')!;
      expect(conakry.isSpecial, isTrue);
      expect(conakry.divisionLabel, 'Commune');
      expect(conakry.divisions, hasLength(13));
      expect(
        conakry.divisions.map((d) => d.name),
        containsAll(['Kaloum', 'Ratoma', 'Matoto', 'Dixinn', 'Matam']),
      );
    });

    test('les autres régions se découpent en préfectures', () {
      for (final region in geography.regions.where((r) => !r.isSpecial)) {
        expect(region.divisionLabel, 'Préfecture', reason: region.name);
      }
    });

    test('chaque code est unique', () {
      // Deux codes identiques feraient basculer une inscription dans la
      // mauvaise région, sans erreur visible.
      final codes = [
        for (final region in geography.regions) ...[
          region.code,
          for (final division in region.divisions) division.code,
        ],
      ];
      expect(codes.toSet(), hasLength(codes.length));
    });

    test('chaque subdivision connaît sa région', () {
      final known = geography.regions.map((r) => r.code).toSet();
      for (final division in geography.divisions) {
        expect(known, contains(division.regionCode), reason: division.name);
        expect(division.name.trim(), isNotEmpty);
      }
    });

    test('les préfectures récentes sont signalées', () {
      // Beaucoup de gens rattachent encore Kamsar à Boké et la cherchent
      // ailleurs : l'écran le dit au lieu de la laisser passer pour une
      // erreur.
      final kamsar = geography.divisions.firstWhere((d) => d.name == 'Kamsar');
      expect(kamsar.recent, isTrue);
      expect(kamsar.regionCode, 'BOK');

      final boke = geography.divisions.firstWhere(
        (d) => d.name == 'Boké' && d.regionCode == 'BOK',
      );
      expect(boke.recent, isFalse);
    });

    test('Siguiri et Beyla sont des régions, pas des préfectures', () {
      // Elles ont été détachées de Kankan et de Nzérékoré : les y laisser
      // ferait chercher Beyla dans la mauvaise liste.
      expect(geography.region('SIG'), isNotNull);
      expect(geography.region('BEY'), isNotNull);
      final kankan = geography.region('KAN')!.divisions.map((d) => d.name);
      expect(kankan, isNot(contains('Siguiri')));
      final nzerekore = geography.region('NZE')!.divisions.map((d) => d.name);
      expect(nzerekore, isNot(contains('Beyla')));
    });

    test('« Ratoma, Conakry » se lit d’un coup', () {
      expect(
        geography.describe(regionCode: 'CKY', divisionName: 'Ratoma'),
        'Ratoma, Conakry',
      );
      // La préfecture qui porte le nom de sa région ne se répète pas.
      expect(
        geography.describe(regionCode: 'KND', divisionName: 'Kindia'),
        'Kindia',
      );
      expect(geography.describe(), isNull);
    });
  });

  group('Cascade région → préfecture', () {
    // Les options telles que les fabrique `onboardingOptionsProvider`.
    final options = [
      for (final division in geography.divisions)
        OnboardingOption(
          value: division.name,
          label: division.name,
          groups: [division.regionCode],
        ),
    ];
    final filter = OptionsFilter.on('region');

    test('choisir Conakry ne laisse que ses communes', () {
      final shown = filter.apply(options, {'region': 'CKY'});
      expect(shown, hasLength(13));
      expect(shown.map((o) => o.value), contains('Ratoma'));
      expect(shown.map((o) => o.value), isNot(contains('Labé')));
    });

    test('choisir Labé ne laisse que ses préfectures', () {
      final shown = filter.apply(options, {'region': 'LAB'});
      expect(
        shown.map((o) => o.value),
        containsAll(['Labé', 'Koubia', 'Lélouma', 'Mali', 'Tougué']),
      );
      expect(shown.map((o) => o.value), isNot(contains('Ratoma')));
    });

    test('sans région répondue, le filtre ne filtre rien', () {
      // C'est pourquoi l'écran verrouille la liste au lieu de s'en remettre
      // au filtre : sans réponse, `apply` rend les 57 subdivisions.
      expect(filter.apply(options, const {}), hasLength(options.length));
    });

    test('les 57 subdivisions se répartissent sans reste', () {
      var total = 0;
      for (final region in geography.regions) {
        total += filter.apply(options, {'region': region.code}).length;
      }
      expect(total, options.length);
    });
  });

  group('Les parcours utilisent la cascade', () {
    OnboardingFlowSpec load(String name) => OnboardingFlowSpec.fromJson(
      jsonDecode(File('assets/onboarding/$name.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    for (final name in [
      'teacher_onboarding',
      'institution_onboarding',
      'parent_onboarding',
    ]) {
      test('$name demande la région avant la préfecture', () {
        final fields = [for (final step in load(name).steps) ...step.fields];
        final region = fields.where((f) => f.id == 'region').toList();
        final city = fields.where((f) => f.id == 'city').toList();

        expect(region, hasLength(1), reason: 'une seule question de région');
        expect(city, hasLength(1));
        expect(city.single.optionsSource, 'prefectures');
        expect(city.single.optionsFilter?.field, 'region');

        // L'ordre compte : la préfecture reste verrouillée tant que la
        // région n'est pas répondue.
        expect(
          fields.indexOf(region.single),
          lessThan(fields.indexOf(city.single)),
        );
      });
    }

    test('changer de région efface la préfecture déjà choisie', () {
      // Sans cela, un professeur qui corrige « Conakry » en « Labé » garde
      // « Ratoma » dans ses réponses : la liste ne l'affiche plus, mais
      // c'est bien elle qui partirait en base.
      final step = load(
        'teacher_onboarding',
      ).steps.firstWhere((s) => s.fields.any((f) => f.id == 'region'));
      expect(step.dependentFields('region'), contains('city'));

      // Le pays et le téléphone ne dépendent de rien : les effacer ferait
      // perdre une saisie sans raison.
      expect(step.dependentFields('region'), isNot(contains('phone')));
      expect(step.dependentFields('region'), isNot(contains('country')));
      expect(step.dependentFields('city'), isEmpty);
    });

    test('l’écran sait quoi demander d’abord', () {
      final step = load(
        'teacher_onboarding',
      ).steps.firstWhere((s) => s.fields.any((f) => f.id == 'region'));
      final city = step.fields.firstWhere((f) => f.id == 'city');
      expect(step.filterLabelFor(city), 'Région');
    });

    test('plus personne ne lit l’ancienne liste de villes', () {
      // `cities` listait les villes déjà présentes en base : au premier
      // démarrage elle est vide, et l'inscription se bloquait.
      for (final name in [
        'teacher_onboarding',
        'institution_onboarding',
        'parent_onboarding',
      ]) {
        final sources = [
          for (final step in load(name).steps)
            for (final field in step.fields) field.optionsSource,
        ];
        expect(sources, isNot(contains('cities')), reason: name);
      }
    });
  });
}
