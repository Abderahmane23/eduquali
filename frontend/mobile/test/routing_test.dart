import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le parcours d'inscription doit rester **atteignable**.
///
/// Origine : la v1.3 embarquait le nouveau parcours au complet — écrans de
/// découverte, choix du profil, illustrations — mais le splash pointait
/// toujours vers l'ancien écran. Tout était livré, rien n'était accessible,
/// et l'application semblait inchangée.
///
/// Ces vérifications lisent la source plutôt que de monter l'application :
/// elles répondent à « quelqu'un envoie-t-il l'utilisateur ici ? », question
/// qu'un test de widget sur un seul écran ne pose jamais.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final splash = read('lib/presentation/screens/auth/splash_screen.dart');
  final login = read('lib/presentation/screens/auth/login_screen.dart');
  final router = read('lib/presentation/router/app_router.dart');

  group('L’action est le premier écran, pas la connexion', () {
    // Renversé le 24/09. Le splash envoyait sur la connexion, donc la
    // première chose demandée à quelqu'un qui ne connaît pas encore
    // l'application était son numéro de téléphone. Il vient voir s'il
    // existe un professeur de maths près de chez lui : c'est cette
    // réponse-là qui vaut la peine d'un compte.
    test('le splash envoie un visiteur sans session vers la recherche', () {
      expect(
        splash.contains('Routes.landing'),
        isTrue,
        reason: 'un visiteur sans session doit arriver sur l’écran d’action',
      );
      expect(
        splash.contains('Routes.login'),
        isFalse,
        reason: 'la connexion n’est plus la porte d’entrée',
      );
    });

    test('l’écran d’action mène à la recherche, au compte et à la '
        'connexion', () {
      final landing = File(
        'lib/presentation/screens/auth/landing_screen.dart',
      ).readAsStringSync();
      // Les trois sorties : chercher sans compte, en créer un, revenir.
      expect(landing.contains('Routes.discoverFor'), isTrue);
      expect(landing.contains('Routes.signup'), isTrue);
      expect(landing.contains('Routes.login'), isTrue);
    });
  });

  group('Le parcours d’inscription est atteignable', () {
    test('la connexion y renvoie pour créer un compte', () {
      expect(login.contains('Routes.signup'), isTrue);
    });

    test('la route existe dans le routeur', () {
      expect(router.contains('path: Routes.signup'), isTrue);
    });

    test('elle est ouverte sans être connecté', () {
      // Sinon le visiteur est renvoyé vers la connexion, qu'il ne peut pas
      // passer puisqu'il n'a pas encore de compte.
      final guard = router.substring(router.indexOf('Routes.login'));
      expect(guard.contains('Routes.signup'), isTrue);
    });
  });

  group('La présentation vient après la création du compte', () {
    final otp = read('lib/presentation/screens/auth/otp_screen.dart');
    final presentation = read(
      'lib/presentation/screens/onboarding/presentation_screen.dart',
    );

    test('l’écran du code y mène', () {
      expect(otp.contains('Routes.presentation'), isTrue);
    });

    test('elle n’est montrée qu’une fois', () {
      expect(otp.contains('alreadySeen'), isTrue);
      expect(presentation.contains('writeMeta'), isTrue);
    });

    test('elle est passable', () {
      expect(presentation.contains('Passer'), isTrue);
    });

    test('le choix du profil précède le compte, la présentation le suit', () {
      final intro = File('assets/onboarding/intro.json').readAsStringSync();
      // `intro.json` ne contient plus que le choix du profil : les écrans de
      // découverte sont passés dans `presentation.json`, après le compte.
      expect(intro.contains('role_select'), isTrue);
      expect(intro.contains('steps_preview'), isFalse);
      expect(File('assets/onboarding/presentation.json').existsSync(), isTrue);
    });
  });

  group('L’ancien parcours ne revient pas', () {
    test('aucune référence aux écrans supprimés', () {
      // Identifiant entier : `TeacherOnboardingScreen` contient
      // « OnboardingScreen » et reste, lui, parfaitement légitime.
      for (final gone in [
        'OnboardingScreen',
        'RegisterScreen',
        'RegisterInstitutionScreen',
      ]) {
        final whole = RegExp('(?<![A-Za-z])$gone(?![A-Za-z])');
        expect(
          whole.hasMatch(router),
          isFalse,
          reason: '\$gone est remplacé par le parcours unique',
        );
      }
    });

    test('les fichiers supprimés ne réapparaissent pas', () {
      for (final gone in [
        'lib/presentation/screens/auth/onboarding_screen.dart',
        'lib/presentation/screens/auth/register_screen.dart',
        'lib/presentation/screens/auth/register_institution_screen.dart',
      ]) {
        expect(
          File(gone).existsSync(),
          isFalse,
          reason: '$gone doit rester supprimé',
        );
      }
    });
  });

  group('Chaque profil a son accueil', () {
    // La table vit dans `Routes.homeFor` : le splash, la connexion et
    // l'écran du code la partagent au lieu de la réécrire chacun — deux sur
    // trois oubliaient le parent.
    final start = router.indexOf('static String homeFor');
    final homeFor = router.substring(start, router.indexOf('};', start));

    test('la table d’accueil oriente les quatre rôles', () {
      expect(
        homeFor.contains('UserRole.institution => institutionHome'),
        isTrue,
        reason: 'un établissement tomberait dans l’espace d’un autre profil',
      );
      // Le parent et l'étudiant majeur partagent le même espace : même
      // scolarité suivie, mêmes contrats, même calendrier.
      expect(
        homeFor.contains('UserRole.parent || UserRole.student => parentHome'),
        isTrue,
        reason: 'l’étudiant tomberait dans l’espace enseignant',
      );
      expect(homeFor.contains('_ => teacherHome'), isTrue);
    });

    test('le splash s’en sert', () {
      expect(splash.contains('Routes.homeFor('), isTrue);
    });
  });
}
