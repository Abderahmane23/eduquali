import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/domain/entities/onboarding_spec.dart';

/// Les trois profils du second cycle guinéen.
///
/// La 11ème année est commune ; le profil se choisit en 12ème et se garde en
/// Terminale. C'est lui qui décide des matières : l'économie ne se fait qu'en
/// sciences sociales, la géologie qu'en sciences expérimentales.
void main() {
  final catalog =
      jsonDecode(File('assets/seed/catalog.json').readAsStringSync())
          as Map<String, dynamic>;

  // Le programme national vient de `shared/curriculum/`, pas du seed :
  // les deux clients le lisent tel quel.
  final curriculum =
      jsonDecode(File('assets/curriculum/guinea.json').readAsStringSync())
          as Map<String, dynamic>;

  List<Map<String, dynamic>> rows(String key) =>
      (catalog[key] as List).cast<Map<String, dynamic>>();

  final filieres = (curriculum['filieres'] as List)
      .cast<Map<String, dynamic>>();
  final subjects = {for (final s in rows('subjects')) s['id'] as String: s};
  final levels = {for (final l in rows('levels')) l['id'] as String: l};

  Map<String, dynamic> filiere(String code) =>
      filieres.firstWhere((f) => f['code'] == code);

  Set<String> subjectNames(String code) => {
    for (final id in (filiere(code)['subjectIds'] as List))
      subjects[id]!['name'] as String,
  };

  group('Référentiel des profils', () {
    test('les trois profils du lycée sont là', () {
      expect(filieres, hasLength(3));
      expect(
        filieres.map((f) => f['name']),
        containsAll([
          'Sciences mathématiques',
          'Sciences expérimentales',
          'Sciences sociales',
        ]),
      );
    });

    test('le profil ne se choisit qu’à partir de la 12ème', () {
      // La 11eme annee est commune aux trois : la proposer reviendrait a
      // demander a une famille de trancher un an trop tot.
      for (final f in filieres) {
        expect(f['levelIds'], ['lvl_12', 'lvl_terminale'], reason: f['name']);
      }
    });

    test('chaque matière citée existe au référentiel', () {
      for (final f in filieres) {
        for (final id in [
          ...f['subjectIds'] as List,
          ...f['majorSubjectIds'] as List,
        ]) {
          expect(subjects, contains(id), reason: '${f['name']} → $id');
        }
      }
    });

    test('chaque classe citée existe au référentiel', () {
      for (final f in filieres) {
        for (final id in f['levelIds'] as List) {
          expect(levels, contains(id));
          expect(levels[id]!['cycle'], 'LYCEE');
        }
      }
    });

    test('la matière majeure fait partie du profil', () {
      for (final f in filieres) {
        for (final major in f['majorSubjectIds'] as List) {
          expect(f['subjectIds'], contains(major), reason: f['name']);
        }
      }
    });
  });

  group('Ce que chaque profil enseigne', () {
    test('sciences mathématiques : maths majeure, pas d’économie', () {
      final sm = subjectNames('SM');
      expect(sm, containsAll(['Mathematiques', 'Physique', 'Chimie']));
      expect(filiere('SM')['majorSubjectIds'], ['sub_math']);
      expect(sm, isNot(contains('Economie')));
      expect(sm, isNot(contains('Geologie')));
    });

    test('sciences expérimentales : biologie majeure, géologie comprise', () {
      final se = subjectNames('SE');
      expect(se, containsAll(['Biologie', 'Chimie', 'Physique', 'Geologie']));
      expect(filiere('SE')['majorSubjectIds'], ['sub_biol']);
      expect(se, isNot(contains('Economie')));
    });

    test('sciences sociales : histoire-géo majeures, économie comprise', () {
      final ss = subjectNames('SS');
      expect(ss, containsAll(['Histoire', 'Geographie', 'Economie']));
      expect(filiere('SS')['majorSubjectIds'], ['sub_hist', 'sub_geog']);
      // Ni physique ni chimie : ce n'est pas une filiere scientifique.
      expect(ss, isNot(contains('Physique')));
      expect(ss, isNot(contains('Chimie')));
    });

    test('le tronc commun est dans les trois', () {
      // Francais, anglais, philosophie et EPS se font quel que soit le
      // profil : les omettre priverait un eleve d'un soutien qu'il cherche.
      for (final code in ['SM', 'SE', 'SS']) {
        expect(
          subjectNames(code),
          containsAll([
            'Francais',
            'Anglais',
            'Philosophie',
            'Éducation physique et sportive',
          ]),
          reason: code,
        );
      }
    });
  });

  group('Filtrage des matières par profil', () {
    // Les options telles que les fabrique `onboardingOptionsProvider` : les
    // cycles ET les profils qui contiennent la matiere.
    final byFiliere = <String, Set<String>>{};
    for (final f in filieres) {
      for (final id in (f['subjectIds'] as List).cast<String>()) {
        byFiliere.putIfAbsent(id, () => {}).add(f['id'] as String);
      }
    }
    final options = [
      for (final s in rows('subjects'))
        OnboardingOption(
          value: s['id'] as String,
          label: s['name'] as String,
          groups: [
            ...(s['cycles'] as List).cast<String>(),
            ...?byFiliere[s['id']],
          ],
        ),
    ];

    Set<String> shown(OptionsFilter filter, Map<String, Object?> answers) =>
        filter.apply(options, answers).map((o) => o.label).toSet();

    test('choisir un profil réduit à ses matières', () {
      final filter = OptionsFilter.on('child_filiere_id');
      final soc = shown(filter, {'child_filiere_id': 'fil_soc'});
      expect(soc, contains('Economie'));
      expect(soc, isNot(contains('Physique')));
      expect(soc, isNot(contains('Droit')));
    });

    test('les deux filtres ne se marchent pas dessus', () {
      // Une matiere porte ses cycles et ses profils dans la meme liste :
      // filtrer sur « LYCEE » ne doit jamais retenir un profil, et filtrer
      // sur « fil_soc » ne doit jamais retenir un cycle.
      final parCycle = OptionsFilter.on('cycles');
      final parProfil = OptionsFilter.on('child_filiere_id');

      final lycee = shown(parCycle, {
        'cycles': ['LYCEE'],
      });
      expect(lycee, contains('Economie'));
      expect(lycee, contains('Informatique'));
      expect(lycee, isNot(contains('Médecine')));

      final math = shown(parProfil, {'child_filiere_id': 'fil_math'});
      expect(math, contains('Mathematiques'));
      // L'informatique est au lycee sans appartenir a un profil : elle ne
      // doit pas ressortir d'un filtre par profil.
      expect(math, isNot(contains('Informatique')));
    });
  });

  group('Le parcours parent demande le profil au bon moment', () {
    final spec = OnboardingFlowSpec.fromJson(
      jsonDecode(
            File('assets/onboarding/parent_onboarding.json').readAsStringSync(),
          )
          as Map<String, dynamic>,
    );

    test('la question n’apparaît qu’en 12ème et en Terminale', () {
      final step = spec.steps.firstWhere((s) => s.id == 'child_filiere');
      expect(step.showIf?.field, 'child_level_id');
      expect(step.showIf?.values, ['lvl_12', 'lvl_terminale']);

      expect(step.showIf!.matches('lvl_terminale'), isTrue);
      expect(step.showIf!.matches('lvl_11'), isFalse);
      expect(step.showIf!.matches(null), isFalse);
    });

    test('un enfant de 11ème ne voit pas la question', () {
      final visible = spec
          .visibleSteps({'child_level_id': 'lvl_11'})
          .map((s) => s.id);
      expect(visible, isNot(contains('child_filiere')));
    });

    test('un enfant de Terminale la voit, avant les matières', () {
      final visible = spec
          .visibleSteps({'child_level_id': 'lvl_terminale'})
          .map((s) => s.id)
          .toList();
      expect(visible, contains('child_filiere'));
      expect(
        visible.indexOf('child_filiere'),
        lessThan(visible.indexOf('child_subjects')),
      );
    });

    test('les matières de l’enfant suivent sa classe, puis son profil', () {
      // La classe d'abord : elle existe dès le collège. Le profil ensuite,
      // pour le lycée, où deux élèves de Terminale ne suivent pas le même
      // programme. Le profil seul ne filtrait rien avant la 12ᵉ.
      final step = spec.steps.firstWhere((s) => s.id == 'child_subjects');
      // Le palier vient en tete depuis le 03/10 : il est la seule reponse
      // disponible pour le primaire et pour un diplome, ou aucune classe n'est
      // demandee. Sans lui, les matieres de ces deux paliers ne seraient pas
      // filtrees du tout.
      expect(step.optionsFilter?.fields, [
        'child_level_stage',
        'child_level_id',
        'child_filiere_id',
      ]);
    });

    test('les matières ne sont demandées qu’une fois', () {
      // L'étape « Dans quelles matières ? » du répétiteur a été retirée le
      // 24/09 : elle reposait la question déjà posée pour l'enfant, deux
      // écrans plus haut, et les deux réponses pouvaient diverger sans que
      // rien ne tranche laquelle faisait foi.
      final ids = spec.steps.map((s) => s.id);
      expect(ids, contains('child_subjects'));
      expect(ids, isNot(contains('tutoring_subjects')));
    });
  });
}
