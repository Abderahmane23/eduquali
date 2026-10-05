import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_enums.dart';
import 'package:veriprof/domain/entities/onboarding_spec.dart';
import 'package:veriprof/domain/usecases/subscription_rules.dart';
import 'package:veriprof/presentation/controllers/onboarding_flow_controller.dart';

/// Parcours d'inscription : découverte, choix du profil, étapes conditionnelles.
///
/// Ces règles décident ce qu'un utilisateur voit. Une condition mal évaluée
/// ne casse rien visiblement : elle fait disparaître un écran, et le profil
/// arrive incomplet à l'autre bout.
void main() {
  OnboardingFlowSpec load(String name) {
    final raw = File('assets/onboarding/$name.json').readAsStringSync();
    return OnboardingFlowSpec.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Le choix du profil : premiere etape de `intro.json`, et plus la seule
  /// depuis le 24/09 — trois ecrans de valeur et l'offre Pro la suivent.
  OnboardingStep roleStepOf(OnboardingFlowSpec spec) =>
      spec.steps.firstWhere((s) => s.type == StepType.roleSelect);

  group('Choix du profil', () {
    test('l’inscription commence par le choix du profil', () {
      final spec = load('intro');
      expect(spec.audience, 'ANY');
      expect(spec.steps.first.type, StepType.roleSelect);
    });

    test('chaque parcours annonce sa propre valeur', () {
      // Le même prix partout, mais pas le même argument : un professeur
      // achète de la visibilité, une famille achète de l'aide aux devoirs.
      final textes = {
        for (final p in [
          'teacher_onboarding',
          'parent_onboarding',
          'institution_onboarding',
        ])
          p: load(p).steps.last.plans.first.highlight,
      };
      expect(textes.values.toSet(), hasLength(textes.length));
    });

    test('la valeur est montrée avant qu’on pose des questions', () {
      // Renversé le 24/09. Les écrans de valeur passaient APRÈS la création
      // du compte : on demandait onze réponses à quelqu'un qui n'avait
      // encore rien vu du produit.
      final spec = load('intro');
      final apresLeRole = spec.steps
          .skipWhile((s) => s.type != StepType.roleSelect)
          .skip(1)
          .toList();

      final valeur = apresLeRole
          .where((s) => s.type == StepType.statement)
          .toList();
      expect(
        valeur.length,
        greaterThanOrEqualTo(3),
        reason: 'trois écrans de valeur au moins, avant les questions',
      );

      // Et ils ne demandent rien : ce sont des écrans qui expliquent.
      for (final s in valeur) {
        expect(s.fieldId, isNull, reason: '${s.id} demande une réponse');
      }
    });

    test('l’offre arrive en dernier, dans chaque parcours', () {
      // Déplacée le 24/09 : elle suivait les trois écrans de valeur, donc
      // avant la moindre question. On demande l'argent après l'effort, pas
      // avant — et un texte par profil suppose de la poser dans le parcours
      // du profil, pas dans l'introduction commune.
      expect(
        load('intro').steps.map((s) => s.type),
        isNot(contains(StepType.planSelect)),
      );

      for (final parcours in [
        'teacher_onboarding',
        'parent_onboarding',
        'student_onboarding',
        'institution_onboarding',
      ]) {
        final etapes = load(parcours).steps;
        expect(
          etapes.last.type,
          StepType.planSelect,
          reason: '$parcours ne finit pas par l’offre',
        );
      }
    });

    test('l’offre Pro se refuse', () {
      // Sans refus possible, aucun compte gratuit n'existerait — et la
      // demande d'abonnement au moment de contacter un professeur n'aurait
      // plus personne à qui s'adresser.
      final offre = load(
        'teacher_onboarding',
      ).steps.firstWhere((s) => s.type == StepType.planSelect);

      expect(offre.declineLabel, isNotNull);
      expect(offre.declineValue, isNotNull);

      // Les deux formules, aux prix du barème. Le parcours ne réécrit pas
      // les prix : il lit `subscription_rules.dart`, et ce test le vérifie.
      expect(offre.plans.map((p) => p.value), ['PRO', 'MASTER']);
      expect(offre.plans.map((p) => p.price.round()), [
        SubscriptionPlan.pro.monthlyPriceGnf,
        SubscriptionPlan.master.monthlyPriceGnf,
      ]);
      // Une seule formule mise en avant : deux ne mettent rien en avant.
      expect(offre.plans.where((p) => p.recommended), hasLength(1));
    });

    test('les écrans de présentation viennent après le compte', () {
      final spec = load('presentation');

      // Rien à saisir : ce sont des écrans qui expliquent, pas des questions.
      for (final step in spec.steps) {
        expect(
          step.type.collectsAnswer,
          isFalse,
          reason: '${step.id} ne devrait rien demander',
        );
      }

      // Un écran commun, puis trois variantes de chaque écran adapté au
      // profil : chacun n'en voit que trois.
      expect(spec.steps.length, 7);
      final visibleForTeacher = spec.visibleSteps({'role': 'TEACHER'});
      expect(visibleForTeacher, hasLength(3));
      expect(visibleForTeacher.first.id, 'social_proof');
    });

    test('chaque profil a sa version de la présentation', () {
      final spec = load('presentation');
      for (final role in ['TEACHER', 'INSTITUTION', 'PARENT']) {
        expect(
          spec.visibleSteps({'role': role}),
          hasLength(3),
          reason: '$role doit voir trois écrans',
        );
      }
    });

    test('le choix du profil est obligatoire', () {
      final spec = load('intro');
      final roleStep = roleStepOf(spec);

      expect(roleStep.required, isTrue);
      expect(roleStep.fieldId, 'role');

      final state = OnboardingFlowState(spec: spec);
      expect(
        state.canContinue,
        isFalse,
        reason: 'sans profil, le parcours suivant n’existe pas',
      );
    });

    test('les quatre profils annoncés mènent chacun à un parcours', () {
      final spec = load('intro');
      final options = roleStepOf(spec).options;

      expect(options.map((o) => o.value), [
        'TEACHER',
        'INSTITUTION',
        'PARENT',
        // Ajouté le 21/09 : un majeur s'inscrit pour lui-même.
        'STUDENT',
      ]);
      for (final option in options) {
        expect(
          OnboardingAudience.forRole(option.value),
          isNotNull,
          reason: '${option.value} sans parcours',
        );
        expect(
          option.description,
          isNotNull,
          reason: '${option.value} sans phrase d’explication',
        );
      }
    });

    test('chaque profil proposé existe dans le modèle de compte', () {
      // Le test lisait `steps.last.options` : depuis que des écrans de
      // valeur suivent le choix du profil, la dernière étape est un écran
      // sans options, la boucle ne tournait pas, et le test passait sur
      // une liste vide.
      final spec = load('intro');
      final options = roleStepOf(spec).options;
      expect(options, isNotEmpty);
      for (final option in options) {
        expect(
          UserRole.values.map((r) => r.code),
          contains(option.value),
          reason: '${option.value} inconnu de UserRole',
        );
      }
    });
  });

  group('Étapes conditionnelles', () {
    test('un palier avec classes montre l’étape de la classe', () {
      final spec = load('parent_onboarding');
      final ids = spec
          .visibleSteps({'child_level_stage': 'COLLEGE'})
          .map((s) => s.id);

      expect(ids, contains('child_level_class'));
      // Le profil ne s'ouvre qu'au lycée, à partir de la 12ème : au collège, il
      // ne filtrerait rien.
      expect(ids, isNot(contains('child_filiere')));
    });

    test('un palier sans classe masque l’étape de la classe', () {
      // Le primaire et « diplômé » n'ont pas de classe à choisir : le
      // référentiel ne détaille pas les six années du primaire, et un diplômé
      // n'est dans aucune classe. Poser la question obligerait à inventer une
      // réponse.
      final spec = load('parent_onboarding');
      for (final palier in ['PRIMAIRE', 'DIPLOME']) {
        final ids = spec
            .visibleSteps({'child_level_stage': palier})
            .map((s) => s.id);
        expect(
          ids,
          isNot(contains('child_level_class')),
          reason: 'le palier $palier n’a pas de classe à demander',
        );
        // Les matières, elles, se demandent toujours.
        expect(ids, contains('child_subjects'));
      }
    });

    test('une condition sans réponse masque l’étape', () {
      final spec = load('parent_onboarding');
      final ids = spec.visibleSteps(const {}).map((s) => s.id);

      expect(ids, isNot(contains('child_level_class')));
      expect(ids, isNot(contains('child_filiere')));
      // Les étapes inconditionnelles restent, elles.
      expect(ids, contains('identity'));
      expect(ids, contains('child_level_stage'));
      expect(ids, contains('child_school'));
    });

    test('la comparaison accepte un booléen comme une chaîne', () {
      // Le JSON écrit `"equals": true` ; le client stocke un vrai booléen,
      // et la comparaison se fait sur la forme texte des deux côtés.
      const condition = ShowIf(field: 'peu_importe', values: ['true']);
      expect(condition.matches(true), isTrue);
      expect(condition.matches('true'), isTrue);
      expect(condition.matches(false), isFalse);
      expect(condition.matches(null), isFalse);
    });

    test('une réponse multiple correspond dès qu’un élément correspond', () {
      // Le 26/09, « Vous donnez des cours à domicile ? » a été retirée : le
      // choix des services, deux écrans plus haut, le disait déjà. Les
      // disponibilités suivent donc une réponse multiple.
      //
      // Sans le `any`, la liste entière était comparée à « HOME » — jamais
      // égale — et l'écran des disponibilités disparaissait du parcours sans
      // que rien ne le signale.
      final spec = load('teacher_onboarding');

      final lesDeux = spec
          .visibleSteps({
            'service_types': ['HOME', 'FULL_TIME'],
          })
          .map((s) => s.id);
      expect(lesDeux, contains('home_availability'));
      expect(lesDeux, contains('availability'));

      final domicile = spec
          .visibleSteps({
            'service_types': ['HOME'],
          })
          .map((s) => s.id);
      expect(domicile, contains('home_availability'));
      expect(
        domicile,
        isNot(contains('availability')),
        reason: 'on ne demande pas ses horaires d’école à qui n’en veut pas',
      );

      final ecole = spec
          .visibleSteps({
            'service_types': ['FULL_TIME'],
          })
          .map((s) => s.id);
      expect(ecole, contains('availability'));
      expect(ecole, isNot(contains('home_availability')));
    });

    test('la question sur les cours à domicile a disparu', () {
      // Elle reposait la question à laquelle « Sélectionnez vos services »
      // venait de répondre.
      final ids = load('teacher_onboarding').steps.map((s) => s.id).toList();
      expect(ids, isNot(contains('home_courses')));
      expect(ids, contains('services'));
    });

    test('le compteur suit les étapes visibles, pas le fichier', () {
      final spec = load('parent_onboarding');
      final primaire = OnboardingFlowState(
        spec: spec,
        answers: const {'child_level_stage': 'PRIMAIRE'},
      );
      final college = OnboardingFlowState(
        spec: spec,
        answers: const {'child_level_stage': 'COLLEGE'},
      );

      // Les deux branches ne comptent pas le même nombre d'écrans : le primaire
      // n'a pas de classe à demander. Annoncer « étape 4 sur 10 » à une famille
      // qui n'en verra que 9 fait douter d'avoir sauté quelque chose.
      expect(primaire.total, lessThan(spec.steps.length));
      expect(college.total, greaterThan(primaire.total));
      expect(
        college.visible.map((s) => s.id),
        isNot(primaire.visible.map((s) => s.id)),
      );
    });

    test('un rang au-delà de la liste ne sort jamais du tableau', () {
      final spec = load('parent_onboarding');
      // Une reponse vient de retirer des etapes alors qu'on etait a la fin.
      final state = OnboardingFlowState(
        spec: spec,
        index: 99,
        answers: const {'child_status': 'ENROLLED'},
      );

      expect(state.position, state.total - 1);
      expect(() => state.step, returnsNormally);
      expect(state.isLast, isTrue);
    });

    test('toute condition vise un champ que le parcours renseigne', () {
      for (final name in [
        'intro',
        'teacher_onboarding',
        'institution_onboarding',
        'parent_onboarding',
      ]) {
        final spec = load(name);
        final produced = <String>{
          for (final step in spec.steps) ...[
            if (step.fieldId != null) step.fieldId!,
            for (final field in step.fields) field.id,
          ],
        };

        for (final step in spec.steps) {
          final condition = step.showIf;
          if (condition == null) continue;
          expect(
            produced,
            contains(condition.field),
            reason:
                '$name : "${step.id}" dépend de "${condition.field}", '
                'qu’aucune étape ne renseigne',
          );
        }
      }
    });
  });

  group('Illustrations', () {
    test('chaque illustration existe en deux densités', () {
      for (final name in [
        'intro',
        'teacher_onboarding',
        'institution_onboarding',
        'parent_onboarding',
      ]) {
        for (final step in load(name).steps) {
          final image = step.image;
          if (image == null) continue;
          for (final density in ['', '@2x']) {
            final file = File('assets/img/${image.name}$density.webp');
            expect(
              file.existsSync(),
              isTrue,
              reason: '$name : "${step.id}" référence ${file.path}, absent',
            );
          }
        }
      }
    });

    test('aucune illustration sans alternative textuelle', () {
      // Une image sans `alt` est invisible pour un lecteur d'écran.
      for (final name in [
        'intro',
        'teacher_onboarding',
        'institution_onboarding',
        'parent_onboarding',
      ]) {
        for (final step in load(name).steps) {
          final image = step.image;
          if (image == null) continue;
          expect(
            image.alt.trim(),
            isNotEmpty,
            reason: '$name : "${step.id}" a une image sans alt',
          );
        }
      }
    });
  });

  group('Prix', () {
    test('aucune formule ne reste libellée en devise étrangère', () {
      for (final name in [
        'teacher_onboarding',
        'institution_onboarding',
        'parent_onboarding',
      ]) {
        final spec = load(name);
        expect(spec.currency, 'GNF', reason: name);
        for (final step in spec.steps) {
          for (final plan in step.plans) {
            // Le franc guinéen n'a pas de subdivision en usage : un prix à
            // décimales signale une valeur restée en dollars.
            expect(
              plan.price,
              plan.price.roundToDouble(),
              reason: '$name : ${plan.value} a un prix à décimales',
            );
          }
        }
      }
    });
  });
}
