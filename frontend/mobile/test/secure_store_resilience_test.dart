import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Le magasin de clés ne doit jamais pouvoir empêcher l'application de
/// s'ouvrir.
///
/// Signalé le 25/09 : « l'apk ne se lance pas sur certains appareils, il
/// montre le logo ». Ce logo est celui du lanceur Android, retiré quand
/// Flutter dessine sa première image : il restait donc affiché parce que
/// `runApp` n'était jamais atteint.
///
/// `main()` attendait `secureStore.deviceId()` avant `runApp`, sans délai et
/// sans rattrapage. Or `EncryptedSharedPreferences` s'appuie sur le magasin
/// de clés d'Android, qui s'abîme pour des raisons extérieures à
/// l'application — restauration de sauvegarde, mise à jour du système, ROM
/// constructeur. Une fois abîmé, il lève à **chaque** lecture, pour
/// toujours. D'où des appareils qui marchent et d'autres non.
///
/// Deux protections, et il faut les deux : `resetOnError` répare la cause,
/// le rattrapage de `main()` couvre tout le reste — y compris les pannes
/// qu'on n'a pas encore rencontrées.
void main() {
  final store = File('lib/core/security/secure_store.dart').readAsStringSync();
  final entree = File('lib/main.dart').readAsStringSync();

  group('Le magasin de clés', () {
    test('repart à zéro plutôt que d’échouer indéfiniment', () {
      // Sans `resetOnError`, un magasin abîmé condamne le compte sur cet
      // appareil : chaque lecture lève, et rien ne le répare jamais.
      expect(
        store.contains('resetOnError: true'),
        isTrue,
        reason: 'un magasin abîmé doit se réinitialiser, pas condamner',
      );
      expect(store.contains('encryptedSharedPreferences: true'), isTrue);
    });
  });

  group('Le démarrage', () {
    test('n’attend jamais le magasin de clés sans filet', () {
      // La lecture reste sous `runStartupStep` : délai maximal, erreur
      // rattrapée, et le démarrage continue avec un identifiant de repli.
      final position = entree.indexOf('secureStore.deviceId()');
      expect(position, greaterThan(0));

      final avant = entree.substring(0, position);
      expect(
        avant.lastIndexOf('runStartupStep') > avant.lastIndexOf('runApp('),
        isTrue,
        reason: 'la lecture doit être enveloppée par une étape protégée',
      );
    });

    test('le magasin de clés n’est pas une étape indispensable', () {
      // Il ne porte qu'un identifiant d'appareil, qui sert à nommer
      // l'appareil dans la file d'envoi. Le marquer `fatal` transformerait
      // une gêne en écran d'erreur.
      final position = entree.indexOf("'stockage sécurisé'");
      expect(position, greaterThan(0));
      final bloc = entree.substring(position, position + 220);
      expect(bloc, contains('fatal: false'));
      expect(
        entree,
        contains('appareil-sans-cle'),
        reason: 'il faut un identifiant de repli, sinon la synchro part sans',
      );
    });

    test('rien n’est attendu sans délai avant runApp', () {
      // La règle générale, et la seule qui tienne : tout ce qui précède
      // `runApp` passe par l'étape protégée. Un `await` nu qui reviendrait
      // ici ramènerait le logo figé.
      final avantRunApp = entree.substring(0, entree.indexOf('runApp('));
      final attentes = RegExp(r'\n  await ').allMatches(avantRunApp).length;
      final protegees = 'runStartupStep'.allMatches(avantRunApp).length;
      expect(
        attentes,
        protegees,
        reason: 'chaque await du démarrage doit être une étape protégée',
      );
    });
  });
}
