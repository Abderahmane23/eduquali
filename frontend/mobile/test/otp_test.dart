import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_constants.dart';
import 'package:veriprof/domain/usecases/otp_check.dart';

/// Vérification du code (§5.1).
///
/// Origine : en v1.4, chaque inscription finissait sur « Compte introuvable ».
/// Le code saisi était juste ; c'est l'identifiant du compte qui n'arrivait
/// pas jusqu'à l'écran du code. Et un compte déconnecté ne pouvait plus
/// revenir : il n'avait jamais eu de mot de passe.
void main() {
  final now = DateTime(2026, 9, 16, 10);
  const validity = Duration(minutes: 5);
  const offline = '123456';

  OtpOutcome check({
    String entered = '482913',
    String? expected = '482913',
    DateTime? issuedAt,
    bool offlineCodeEnabled = true,
    bool serverReachable = false,
  }) => checkOtp(
    entered: entered,
    expected: expected,
    issuedAt: issuedAt ?? now.subtract(const Duration(minutes: 1)),
    now: now,
    validity: validity,
    offlineCodeEnabled: offlineCodeEnabled,
    offlineCode: offline,
    serverReachable: serverReachable,
  );

  group('Code envoyé', () {
    test('le bon code ouvre la session', () {
      expect(check(), OtpOutcome.accepted);
      expect(check().opensSession, isTrue);
    });

    test('un mauvais code est refusé', () {
      expect(check(entered: '000001'), OtpOutcome.wrong);
      expect(check(entered: '000001').opensSession, isFalse);
    });

    test('les espaces autour du code ne comptent pas', () {
      expect(check(entered: ' 482913 '), OtpOutcome.accepted);
    });

    test('un code expiré est refusé', () {
      expect(
        check(issuedAt: now.subtract(const Duration(minutes: 6))),
        OtpOutcome.expired,
      );
    });

    test('sans code émis, rien ne passe', () {
      expect(
        check(expected: null, serverReachable: true),
        OtpOutcome.noPending,
      );
    });
  });

  group('Code unique hors ligne', () {
    test('passe quand le serveur ne répond pas', () {
      expect(check(entered: offline), OtpOutcome.acceptedOffline);
      expect(check(entered: offline).opensSession, isTrue);
    });

    test('passe même sans code émis — la situation qui bloquait', () {
      expect(
        check(entered: offline, expected: null),
        OtpOutcome.acceptedOffline,
      );
    });

    test('passe même quand le code émis a expiré', () {
      expect(
        check(
          entered: offline,
          issuedAt: now.subtract(const Duration(hours: 2)),
        ),
        OtpOutcome.acceptedOffline,
      );
    });

    test('ne passe JAMAIS quand le serveur répond', () {
      // La règle la plus sensible : sinon le code unique devient une porte
      // dérobée sur les vrais comptes dès que le serveur existe.
      expect(
        check(entered: offline, serverReachable: true),
        isNot(OtpOutcome.acceptedOffline),
      );
      expect(
        check(entered: offline, serverReachable: true).opensSession,
        isFalse,
      );
    });

    test('ne passe pas quand le drapeau est coupé', () {
      expect(
        check(entered: offline, offlineCodeEnabled: false),
        isNot(OtpOutcome.acceptedOffline),
      );
    });

    test('n’ouvre pas les autres codes hors ligne', () {
      // Hors ligne, un code faux reste faux : seul le code unique passe.
      expect(check(entered: '999999'), OtpOutcome.wrong);
    });
  });

  group('Constantes', () {
    test('le code unique a la longueur attendue par l’écran', () {
      expect(AppConstants.offlineOtpCode, hasLength(AppConstants.otpLength));
    });

    test('le code unique est composé de chiffres', () {
      expect(RegExp(r'^\d+$').hasMatch(AppConstants.offlineOtpCode), isTrue);
    });
  });

  group('Les deux bugs de la v1.4 ne reviennent pas', () {
    final router = File(
      'lib/presentation/router/app_router.dart',
    ).readAsStringSync();

    test('l’URL du code n’est plus écrite à la main', () {
      // `\$userId` : dollar échappé, donc le texte « $userId » au lieu de
      // l'identifiant. Le constructeur reste, même si plus aucun parcours
      // n'y mène depuis le 25/09 : il reviendra tel quel avec le SMS.
      expect(router.contains(r'userId=\$userId'), isFalse);
      expect(router.contains('static String otpFor'), isTrue);
    });

    test('otpFor transmet bien l’identifiant', () {
      final source = router.substring(router.indexOf('static String otpFor'));
      expect(source.contains("'userId': userId"), isTrue);
    });

    test('un numero seul n’ouvre plus aucune session', () {
      // Ce test surveillait l'inverse jusqu'au 02/10 : il exigeait qu'un champ
      // vide ouvre la session, parce que les comptes crees par l'inscription
      // n'avaient pas de mot de passe. C'etait la porte ouverte elle-meme —
      // connaitre un numero suffisait pour entrer dans le compte qui le porte.
      //
      // Le parcours demande desormais un mot de passe (etape `credentials`),
      // et les comptes anterieurs passent par « Mot de passe oublie ».
      final login = File(
        'lib/presentation/screens/auth/login_screen.dart',
      ).readAsStringSync();

      expect(
        login.contains('signInWithPhone'),
        isFalse,
        reason: 'la connexion sur le numero seul doit avoir disparu',
      );
      expect(login.contains('auth.login(_phone.text, _password.text)'), isTrue);
      expect(
        login.contains('Entrez votre mot de passe.'),
        isTrue,
        reason: 'un champ vide doit le dire, pas ouvrir la session',
      );
      // Le champ ne se dit plus facultatif : il ne l'est plus.
      expect(login.contains('Mot de passe (facultatif)'), isFalse);
      // La porte de secours reste : un compte d'avant le 02/10 n'a aucun mot
      // de passe, et sans ce lien il ne peut plus revenir.
      expect(login.contains('Mot de passe oublié'), isTrue);
    });

    test('le parcours demande un mot de passe aux quatre profils', () {
      // La regle vit dans le JSON partage : les deux clients la lisent, donc
      // ni l'un ni l'autre ne peut l'oublier de son cote.
      for (final profil in ['teacher', 'institution', 'parent', 'student']) {
        final parcours = File(
          'assets/onboarding/${profil}_onboarding.json',
        ).readAsStringSync();
        expect(
          parcours,
          contains('"id": "credentials"'),
          reason: '$profil : aucune etape de mot de passe',
        );
        expect(parcours, contains('"type": "password"'));
        expect(parcours, contains('"minLength": 8'));
      }
    });

    test('l’inscription enregistre le mot de passe choisi', () {
      final completion = File(
        'lib/presentation/screens/onboarding/signup_completion.dart',
      ).readAsStringSync();
      // Un secret local identique pour tout le monde a disparu.
      expect(completion.contains('_localSecret'), isFalse);
      // Les trois inscriptions transmettent ce qui a ete saisi.
      expect(
        "password: text('password')".allMatches(completion).length,
        3,
        reason: 'professeur, etablissement et famille',
      );

      final auth = File(
        'lib/data/repositories/auth_repository.dart',
      ).readAsStringSync();
      // La regle de longueur vit a un seul endroit, et les trois
      // inscriptions l'appellent.
      expect(auth.contains('static const minPasswordLength = 8'), isTrue);
      expect(
        '_checkPassword(password)'.allMatches(auth).length,
        greaterThanOrEqualTo(4),
        reason: 'les trois inscriptions, plus setPassword',
      );
      // Un compte parent n'avait aucune empreinte : il se creait et ne
      // pouvait plus jamais s'ouvrir.
      final parent = auth.substring(auth.indexOf('registerParent'));
      expect(
        parent.substring(0, parent.indexOf('_sync.enqueue')),
        contains('passwordHash'),
      );
    });

    test('les trois écrans de session partagent la même table d’accueil', () {
      for (final path in [
        'lib/presentation/screens/auth/splash_screen.dart',
        'lib/presentation/screens/auth/login_screen.dart',
        'lib/presentation/screens/auth/otp_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('isInstitution ? Routes.institutionHome'),
          isFalse,
          reason: '$path réécrit sa propre table et oublie le parent',
        );
      }
    });
  });
}
