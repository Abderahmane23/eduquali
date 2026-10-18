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

    test('le parcours commence par une question, pas par une promesse', () {
      /*
       * Renversé deux fois, et l'histoire vaut d'être gardée.
       *
       * Le 24/09, les écrans de valeur sont passés AVANT la création du
       * compte : on demandait onze réponses à quelqu'un qui n'avait encore
       * rien vu du produit. C'était juste.
       *
       * Le 18/10, ils ont été retirés. Huit écrans vantaient le produit —
       * « Des profils vérifiés, pas des promesses », « Partout en Guinée,
       * même sans réseau » — à quelqu'un qui venait d'ouvrir le parcours
       * d'inscription, donc qui avait déjà décidé d'essayer. L'argument a
       * sa place avant, sur la page d'accueil, où il s'adresse à qui n'a
       * pas encore choisi.
       *
       * Ce que ce contrôle garde maintenant : qu'ils ne reviennent pas par
       * une resynchronisation du fichier partagé.
       */
      final spec = load('intro');
      final promesses = spec.steps
          .where((s) => s.type == StepType.statement)
          .map((s) => s.id)
          .toList();
      expect(
        promesses,
        isEmpty,
        reason: 'écrans de promesse revenus : ${promesses.join(', ')}',
      );
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

    test('chaque carte annoncée mène à un parcours', () {
      final spec = load('intro');
      final options = roleStepOf(spec).options;

      /*
       * Trois cartes depuis le 18/10, pour quatre profils.
       *
       * « Parent d'élève » et « Universitaire » étaient deux portes pour une
       * même famille : le parent d'un lycéen hésitait, et l'élève de
       * terminale qui s'inscrit seul ne se reconnaissait dans aucune. Elles
       * ont fusionné en « Élève ou étudiant », suivie de la question
       * « Êtes-vous parent ? ».
       *
       * `FAMILY` n'est donc pas un rôle : c'est une carte. Elle se traduit
       * en `PARENT` ou `STUDENT` avant que le parcours ne commence, et les
       * deux rôles restent distincts dans la base — ils le sont aussi dans
       * les politiques RLS, où un parent voit les séances de ses enfants.
       */
      expect(options.map((o) => o.value), [
        'TEACHER',
        'INSTITUTION',
        'FAMILY',
      ]);
      for (final option in options) {
        expect(
          OnboardingAudience.forRole(
            OnboardingAudience.roleReel({
              'role': option.value,
              'is_parent': 'no',
            }),
          ),
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
        /*
         * On compare le rôle RÉEL, pas la carte.
         *
         * `FAMILY` est une carte et n'existe pas dans `UserRole` : il n'est
         * écrit ni dans `profiles.role` ni dans les politiques RLS. Il ne
         * vit que le temps du choix.
         */
        final reel = OnboardingAudience.roleReel({
          'role': option.value,
          'is_parent': 'no',
        });
        expect(
          UserRole.values.map((r) => r.code),
          contains(reel),
          reason: '${option.value} donne « $reel », inconnu de UserRole',
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
      /*
       * « Diplômé » n'est dans aucune classe : poser la question obligerait à
       * inventer une réponse.
       *
       * Le primaire était dans le même cas jusqu'au 11/10, pour une autre
       * raison — le référentiel ne détaillait pas ses six années, donc la
       * question n'avait rien à proposer. Les six années existent maintenant
       * (1ère à 6ème, la numérotation guinéenne continue qui donne ensuite la
       * 7ème au collège), et la classe se demande comme ailleurs.
       */
      final spec = load('parent_onboarding');

      final diplome = spec
          .visibleSteps({'child_level_stage': 'DIPLOME'})
          .map((s) => s.id);
      expect(
        diplome,
        isNot(contains('child_level_class')),
        reason: 'un diplômé n’est dans aucune classe',
      );
      expect(diplome, contains('child_subjects'));

      final primaire = spec
          .visibleSteps({'child_level_stage': 'PRIMAIRE'})
          .map((s) => s.id);
      expect(
        primaire,
        contains('child_level_class'),
        reason:
            'le primaire a ses six années depuis le 11/10 : sans cette étape, '
            'un parent de CE2 ne pouvait pas dire la classe de son enfant',
      );
      expect(primaire, contains('child_subjects'));
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

      /*
       * Le compteur doit suivre ce qu'on voit, pas ce que le fichier contient :
       * annoncer « étape 4 sur 10 » à une famille qui n'en verra que 9 fait
       * douter d'avoir sauté quelque chose.
       *
       * Le repère a changé le 11/10. Le primaire comptait un écran de moins que
       * le collège, faute de classes au référentiel ; il en a six désormais, et
       * les deux branches comptent pareil. Ce qui les sépare encore est la
       * filière, demandée en 12ème et en Terminale seulement — donc le lycée
       * reste la branche la plus longue.
       */
      final lycee = OnboardingFlowState(
        spec: spec,
        answers: const {
          'child_level_stage': 'LYCEE',
          'child_level_id': 'lvl_terminale',
        },
      );

      // Aucune branche ne montre tous les écrans du fichier : c'est tout
      // l'intérêt des étapes conditionnelles.
      expect(primaire.total, lessThan(spec.steps.length));
      expect(college.total, lessThan(spec.steps.length));

      // Le primaire demande sa classe comme le collège.
      expect(primaire.total, college.total);
      expect(primaire.visible.map((s) => s.id), contains('child_level_class'));

      // Et la filière allonge la branche du lycée.
      expect(lycee.total, greaterThan(college.total));
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
