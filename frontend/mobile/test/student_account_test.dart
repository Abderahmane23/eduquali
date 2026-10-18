import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_enums.dart';
import 'package:veriprof/domain/entities/onboarding_spec.dart';
import 'package:veriprof/presentation/controllers/onboarding_flow_controller.dart';
import 'package:veriprof/presentation/router/app_router.dart';

/// Le compte étudiant, demandé le 21/09.
///
/// Un majeur s'inscrit pour lui-même : il n'a personne à qui demander le
/// consentement. Le forcer à se déclarer « enfant » de quelqu'un serait faux,
/// et l'en empêcher le laisserait dehors.
void main() {
  OnboardingFlowSpec load(String name) => OnboardingFlowSpec.fromJson(
    jsonDecode(File('assets/onboarding/$name.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  group('Le profil existe', () {
    test('trois cartes se proposent, pour quatre profils', () {
      /*
       * « Parent d'eleve » et « Universitaire » ont fusionne le 18/10 en
       * une seule carte, « Eleve ou etudiant » : deux portes pour une meme
       * famille faisaient hesiter le parent d'un lyceen, et l'eleve de
       * terminale qui s'inscrit seul ne se reconnaissait dans aucune.
       *
       * Les deux ROLES restent distincts — ils le sont dans la base et dans
       * les politiques RLS, ou un parent voit les seances de ses enfants.
       * C'est la question « Etes-vous parent ? » qui les departage.
       */
      final roles = load('intro').steps
          .firstWhere((s) => s.id == 'role_select')
          .options
          .map((o) => o.value);
      expect(roles, ['TEACHER', 'INSTITUTION', 'FAMILY']);
    });

    test('le rôle porte son code et son âge minimum', () {
      expect(UserRole.fromCode('STUDENT'), UserRole.student);
      // Le libellé a changé le 03/10 ; le code, lui, ne doit jamais changer :
      // il est écrit dans SQLite, dans Postgres et dans les politiques RLS.
      // Les deux assertions tiennent ensemble, et c'est tout l'intérêt.
      expect(UserRole.student.label, 'Universitaire');
      expect(UserRole.student.code, 'STUDENT');
      expect(UserRole.studentMinAge, 18);
    });

    test('« STUDENT » ouvre bien un parcours', () {
      expect(OnboardingAudience.forRole('STUDENT'), OnboardingAudience.student);
    });
  });

  group('Son parcours', () {
    final spec = load('student_onboarding');

    test('l’âge n’a plus son écran, mais la règle tient toujours', () {
      // L'écran « Vous avez 18 ans ou plus ? » a été retiré le 23/09 : il
      // posait une question dont la réponse ne changeait rien au parcours
      // suivant — et l'ancien test passait à vide, `indexOf` rendant -1 une
      // fois l'étape disparue.
      //
      // La condition, elle, reste : sous 18 ans c'est un parent qui ouvre le
      // compte. Elle est écrite là où elle décide de quelque chose — au
      // moment de choisir son profil, avant d'avoir rempli quoi que ce soit.
      expect(spec.steps.map((s) => s.id), isNot(contains('age_check')));

      /*
       * La condition d'age a suivi la carte.
       *
       * Elle vivait sous « Universitaire », qui n'existe plus depuis la
       * fusion du 18/10. Elle est maintenant sous la reponse « Non, c'est
       * pour moi » de la question « Etes-vous parent ? » — c'est-a-dire
       * exactement la ou quelqu'un decide de s'inscrire seul, et donc la
       * ou elle decide de quelque chose.
       */
      final question = load(
        'intro',
      ).steps.firstWhere((s) => s.id == 'is_parent');
      final pourMoi = question.options.firstWhere((o) => o.value == 'no');
      expect(
        '${pourMoi.description}',
        contains('${UserRole.studentMinAge} ans'),
        reason: 'la condition d’âge a disparu du choix',
      );
    });

    test('il demande sa classe et ses matières, pour lui-même', () {
      final ids = spec.steps.map((s) => s.id);
      // `level` s'est scinde en deux le 03/10 : le palier (cinq choix) puis la
      // classe, qui ne se demande que pour les paliers qui en ont une. Et
      // `location` est devenu `school`, qui demande l'ecole, la commune et le
      // quartier des la deuxieme page.
      expect(
        ids,
        containsAll(['level_stage', 'level_class', 'subjects', 'school']),
      );
      // Aucune question sur un enfant : il n'en a pas.
      final fields = [
        for (final s in spec.steps) ...s.fields.map((f) => f.id),
        for (final s in spec.steps) s.fieldId,
      ];
      expect(fields.any((f) => (f ?? '').startsWith('child_')), isFalse);
    });

    test('il utilise la même cascade de localisation que les autres', () {
      final city = [
        for (final s in spec.steps) ...s.fields,
      ].firstWhere((f) => f.id == 'city');
      expect(city.optionsSource, 'prefectures');
      expect(city.optionsFilter?.field, 'region');
    });

    test('aucune étape ne se passe', () {
      for (final step in spec.steps) {
        expect(step.optional, isFalse, reason: step.id);
      }
    });
  });

  group('Il partage l’espace du parent', () {
    test('sa connexion l’emmène chez le parent', () {
      expect(Routes.homeFor(UserRole.student), Routes.homeFor(UserRole.parent));
    });

    test('le garde-fou le laisse entrer', () {
      expect(
        belongsToOtherSpace(path: '/parent', role: UserRole.student),
        isFalse,
      );
      expect(
        belongsToOtherSpace(path: '/parent/enfants', role: UserRole.student),
        isFalse,
      );
    });

    test('il reste dehors des deux autres espaces', () {
      expect(
        belongsToOtherSpace(path: '/teacher', role: UserRole.student),
        isTrue,
      );
      expect(
        belongsToOtherSpace(path: '/institution', role: UserRole.student),
        isTrue,
      );
    });

    test('un professeur n’entre toujours pas chez le parent', () {
      // Ouvrir l'espace parent à l'étudiant ne devait pas l'ouvrir à tous.
      expect(
        belongsToOtherSpace(path: '/parent', role: UserRole.teacher),
        isTrue,
      );
      expect(
        belongsToOtherSpace(path: '/parent', role: UserRole.institution),
        isTrue,
      );
    });
  });
}
