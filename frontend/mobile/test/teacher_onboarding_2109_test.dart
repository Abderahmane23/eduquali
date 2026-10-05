import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_constants.dart';
import 'package:veriprof/core/utils/validators.dart';
import 'package:veriprof/domain/entities/onboarding_spec.dart';

/// L'inscription professeur telle que la note manuscrite du 21/09 la demande.
///
/// Chaque test porte une demande de la feuille. Ils échoueront le jour où
/// quelqu'un remettra ce qui vient d'être retiré.
void main() {
  OnboardingFlowSpec load(String name) => OnboardingFlowSpec.fromJson(
    jsonDecode(File('assets/onboarding/$name.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  final teacher = load('teacher_onboarding');
  final steps = teacher.steps;
  OnboardingStep step(String id) => steps.firstWhere((s) => s.id == id);
  bool has(String id) => steps.any((s) => s.id == id);

  group('Ce que la note retire', () {
    test('la page « Kilomètres » a disparu', () {
      // Personne ne sait convertir son trajet en kilomètres : la zone se dit
      // en quartiers.
      expect(has('max_distance'), isFalse);
      expect(
        steps.any((s) => s.type == StepType.range),
        isFalse,
        reason: 'un curseur kilométrique est revenu',
      );
    });

    test('« Dernière expérience » a cédé la place au dépôt de documents', () {
      expect(has('past_experience'), isFalse);
      expect(has('documents'), isTrue);
      expect(step('documents').type, StepType.upload);
    });

    test('les deux étapes de disponibilité n’en font plus qu’une', () {
      expect(has('work_days'), isFalse);
      expect(has('work_hours'), isFalse);
      expect(step('availability').type, StepType.dayHours);
    });

    test('le choix du pays a disparu', () {
      // La Guinée est le seul pays servi : proposer le Sénégal laissait
      // croire qu'un numéro étranger passerait.
      final fields = [for (final s in steps) ...s.fields];
      expect(fields.any((f) => f.id == 'country'), isFalse);
      expect(fields.any((f) => f.optionsSource == 'countries'), isFalse);
    });
  });

  group('Ce que la note ajoute', () {
    test('« Sélectionnez vos services » arrive en deuxième', () {
      expect(steps[1].id, 'services');
      expect(
        steps[1].options.map((o) => o.value),
        containsAll(['HOME', 'FULL_TIME']),
      );
    });

    test('le dépôt attend un CV et un diplôme', () {
      final ids = step('documents').uploads.map((u) => u.id);
      expect(ids, containsAll(['cv_path', 'diploma_path']));
    });

    test('plusieurs matières restent possibles', () {
      expect(step('subjects').type, StepType.multiChoice);
      expect(step('subjects').minSelected, greaterThanOrEqualTo(1));
    });
  });

  group('« Passer » ne survit que sur le dépôt', () {
    test('le dépôt du CV et du diplôme se passe', () {
      // Un candidat n'a pas toujours son diplôme sous la main ; le lui
      // réclamer avant de l'inscrire le ferait abandonner.
      expect(step('documents').optional, isTrue);
    });

    test('aucune autre étape ne se passe', () {
      for (final s in steps) {
        if (s.id == 'documents') continue;
        expect(
          s.optional,
          isFalse,
          reason: '« ${s.title} » se passe encore, et finira vide',
        );
      }
    });
  });

  group('Le numéro est guinéen, et verrouillé', () {
    test('neuf chiffres, soit treize caractères avec l’indicatif', () {
      expect(AppConstants.phonePrefix, '+224');
      expect(Validators.normalizePhone('620000001').length, 13);
    });

    test('huit ou dix chiffres sont refusés', () {
      expect(Validators.phone('62000000'), isNotNull);
      expect(Validators.phone('6200000012'), isNotNull);
      expect(Validators.phone('620000001'), isNull);
    });

    test('la saisie est bornée à neuf chiffres', () {
      final source = File(
        'lib/presentation/screens/onboarding/onboarding_steps.dart',
      ).readAsStringSync();
      expect(source.contains('maxLength: 9'), isTrue);
      expect(source.contains('FilteringTextInputFormatter.digitsOnly'), isTrue);
      // L'indicatif n'est plus déduit d'un pays : il est fixe.
      expect(source.contains('_dialPrefix'), isFalse);
    });
  });
}
