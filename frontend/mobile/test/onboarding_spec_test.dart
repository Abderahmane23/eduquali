import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/domain/entities/onboarding_spec.dart';

/// Le JSON des parcours est un contrat partage avec le futur front React.
/// Ces tests verifient qu'il reste lisible par les deux clients.
void main() {
  OnboardingFlowSpec load(String name) {
    final raw = File('assets/onboarding/$name.json').readAsStringSync();
    return OnboardingFlowSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  group('Référentiel des niveaux', () {
    List<Map<String, dynamic>> levels() {
      final raw = File('assets/seed/catalog.json').readAsStringSync();
      return (jsonDecode(raw) as Map<String, dynamic>)['levels']
          .cast<Map<String, dynamic>>();
    }

    test('le lycée va jusqu’en Terminale', () {
      // En Guinee, le lycee se termine en Terminale : sans elle, un
      // professeur de lycee ne peut pas declarer la classe qu'il enseigne
      // le plus souvent.
      final names = levels().map((l) => l['name']);
      expect(names, contains('Terminale'));
    });

    test('Terminale est un niveau scolaire, pas universitaire', () {
      final terminale = levels().firstWhere((l) => l['name'] == 'Terminale');
      expect(terminale['category'], 'SECONDARY');
    });

    test('chaque niveau porte un rang d’affichage unique', () {
      final orders = [for (final l in levels()) l['order'] as int];
      expect(orders.toSet(), hasLength(orders.length));
      // Le rang doit suivre l'ordre du fichier, sinon l'affichage depend de
      // l'ordre d'insertion en base.
      final sorted = [...orders]..sort();
      expect(orders, sorted);
    });

    test('Terminale se place après la 12e et avant l’universitaire', () {
      final items = levels();
      int rank(String id) =>
          items.firstWhere((l) => l['id'] == id)['order'] as int;
      expect(rank('lvl_terminale'), greaterThan(rank('lvl_12')));
      expect(rank('lvl_terminale'), lessThan(rank('lvl_l1')));
    });
  });

  group('Description des parcours', () {
    test('aucune question d’etat civil', () {
      // « Etes-vous marie(e) ? » et « Avez-vous des enfants ? » : sans
      // rapport avec la competence, et c'est le type de donnee qui fonde une
      // discrimination a l'embauche. Retirees, elles ne doivent pas revenir.
      final ids = load('teacher_onboarding').steps.map((s) => s.id).toList();
      expect(ids, isNot(contains('married')));
      expect(ids, isNot(contains('children')));

      final fields = load(
        'teacher_onboarding',
      ).steps.map((s) => s.fieldId).whereType<String>();
      expect(fields, isNot(contains('married')));
      expect(fields, isNot(contains('has_children')));
    });

    test('le parcours enseignant ne pose que des questions', () {
      final spec = load('teacher_onboarding');

      expect(spec.audience, 'TEACHER');
      // Les ecrans de presentation sont passes apres la creation du compte
      // (presentation.json) : l'inscription ne contient plus que des
      // questions, et va donc droit au but.
      for (final step in spec.steps) {
        expect(
          step.type.collectsAnswer,
          isTrue,
          reason: '${step.id} n’est pas une question',
        );
      }
      expect(spec.steps.length, greaterThan(8));
    });

    test('le parcours etablissement commence par qui inscrit', () {
      final spec = load('institution_onboarding');

      expect(spec.audience, 'INSTITUTION');
      expect(spec.steps.first.type, StepType.form);
      // La fonction de la personne engage une responsabilite : elle est
      // obligatoire.
      final role = spec.steps.first.fields.firstWhere(
        (f) => f.id == 'manager_role',
      );
      expect(role.required, isTrue);
      expect(role.optionsSource, 'institution_roles');
    });

    test('chaque etape de saisie porte une cle de reponse', () {
      for (final name in ['teacher_onboarding', 'institution_onboarding']) {
        final spec = load(name);
        for (final step in spec.steps) {
          if (!step.type.collectsAnswer) continue;
          if (step.type == StepType.form) {
            expect(
              step.fields,
              isNotEmpty,
              reason: '${step.id} est un formulaire sans champ',
            );
            continue;
          }
          // Une etape de depot range chaque fichier sous son propre
          // identifiant : un `fieldId` unique ne suffirait pas a distinguer
          // le CV du diplome.
          if (step.type == StepType.upload) {
            expect(
              step.uploads,
              isNotEmpty,
              reason: '${step.id} est un depot sans fichier declare',
            );
            for (final upload in step.uploads) {
              expect(upload.id, isNotEmpty);
              expect(upload.label, isNotEmpty);
            }
            continue;
          }
          expect(
            step.fieldId,
            isNotNull,
            reason: '${step.id} ne sait pas ou ranger sa reponse',
          );
        }
      }
    });

    test('les cles de reponse sont uniques dans un parcours', () {
      for (final name in ['teacher_onboarding', 'institution_onboarding']) {
        final spec = load(name);
        final keys = <String>[];
        for (final step in spec.steps) {
          if (step.fieldId != null) keys.add(step.fieldId!);
          keys.addAll(step.fields.map((f) => f.id));
        }
        expect(
          keys.toSet().length,
          keys.length,
          reason:
              'cle dupliquee dans $name : une reponse en ecraserait '
              'une autre',
        );
      }
    });

    test('une liste dynamique reference le referentiel, jamais une copie', () {
      final spec = load('teacher_onboarding');
      final subjects = spec.steps.firstWhere((s) => s.id == 'subjects');

      // Les matieres viennent du back-office (§8) : les figer dans le JSON
      // ferait diverger les deux clients au premier ajout.
      expect(subjects.optionsSource, 'subjects');
      expect(subjects.options, isEmpty);
    });

    test('l’offre arrive en dernier, et ne bloque personne', () {
      // Renversé le 24/09 : l'offre est désormais dans le parcours, mais à
      // la toute fin — on demande l'argent après l'effort, jamais avant.
      //
      // Ce qui protège n'est donc plus son absence, c'est son refus : sans
      // « Commencer sans abonnement », aucun compte gratuit n'existerait, et
      // l'inscription deviendrait un péage.
      for (final name in [
        'teacher_onboarding',
        'institution_onboarding',
        'parent_onboarding',
        'student_onboarding',
      ]) {
        final etapes = load(name).steps;
        final offres = [
          for (var i = 0; i < etapes.length; i++)
            if (etapes[i].type == StepType.planSelect) i,
        ];

        expect(offres, hasLength(1), reason: '$name : une seule offre');
        expect(
          offres.single,
          etapes.length - 1,
          reason: '$name : l’offre n’est pas la dernière étape',
        );
        expect(
          etapes.last.declineLabel,
          isNotNull,
          reason: '$name : l’offre ne se refuse pas',
        );
      }
    });

    test('les classes suivent le cycle, les matieres suivent les classes', () {
      // Le cycle suffit pour les classes. Pour les matieres il ne suffit
      // plus : « LYCEE » proposait la philosophie a un professeur de 11eme,
      // ou elle ne s'enseigne pas encore.
      final spec = load('teacher_onboarding');
      expect(
        spec.steps.firstWhere((s) => s.id == 'levels').optionsFilter?.field,
        'cycles',
      );
      expect(
        spec.steps.firstWhere((s) => s.id == 'subjects').optionsFilter?.field,
        'level_ids',
      );
    });

    test('la section se deduit de l’indice de l’etape', () {
      final spec = load('teacher_onboarding');

      expect(spec.sectionOf(0).id, spec.sections.first.id);
      expect(spec.sectionOf(spec.steps.length - 1).id, spec.sections.last.id);
    });
  });

  group('Estimation de trajet', () {
    test('convertit une distance en duree lisible', () {
      const estimate = RangeEstimate(kind: 'travel_time', minutesPerUnit: 4);

      expect(estimate.describe(0), 'sur place');
      expect(estimate.describe(5), 'environ 20 min');
      expect(estimate.describe(15), 'environ 1h');
      expect(estimate.describe(20), 'environ 1h20');
    });
  });
}
