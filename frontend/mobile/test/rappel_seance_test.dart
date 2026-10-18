import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/notifications/rappel_seance.dart';

/// Le rappel d'une séance, une heure avant.
///
/// Ce qui est éprouvé ici ne demande ni téléphone ni plugin : l'identifiant
/// déduit de la séance, et le délai. Le reste — programmer réellement — ne se
/// vérifie que sur un appareil, et c'est précisément pour cela que ces deux
/// règles-là doivent être sûres.
void main() {
  test('une heure avant, et c’est la seule valeur', () {
    expect(RappelSeance.avance, const Duration(hours: 1));
  });

  group('L’identifiant du rappel', () {
    test('est déduit de la séance, pas tiré au hasard', () {
      // Reprogrammer le même rappel doit REMPLACER le précédent. Un
      // identifiant aléatoire en empilerait un second, et une famille qui
      // change d'avis deux fois recevrait trois rappels pour un cours.
      expect(RappelSeance.idPour('s-42'), RappelSeance.idPour('s-42'));
    });

    test('distingue deux séances', () {
      expect(
        RappelSeance.idPour('s-42'),
        isNot(RappelSeance.idPour('s-43')),
      );
    });

    test('reste un entier positif', () {
      // Android refuse un identifiant négatif, et `hashCode` en produit.
      for (final id in ['a', 'seance-longue-avec-des-tirets', 'ZZZ', '0']) {
        expect(RappelSeance.idPour(id), greaterThanOrEqualTo(0), reason: id);
      }
    });
  });

  group('Le moment du rappel', () {
    final debut = DateTime.utc(2026, 10, 20, 18);

    test('une heure avant le début', () {
      expect(debut.subtract(RappelSeance.avance), DateTime.utc(2026, 10, 20, 17));
    });

    test('rien n’est programmé dans le passé', () async {
      /*
       * Programmer dans le passe declenche immediatement sur certains
       * telephones. Recevoir « votre cours commence dans une heure » pour un
       * cours d'hier use la confiance qu'on met dans les rappels suivants —
       * et c'est cette confiance qui fait qu'on arrive a l'heure.
       */
      final rappel = RappelSeance(FlutterLocalNotificationsPlugin());
      final programme = await rappel.programmer(
        sessionId: 's-42',
        titre: 'Les fonctions affines',
        debut: debut,
        maintenant: DateTime.utc(2026, 10, 20, 17, 30),
      );
      expect(programme, isFalse);
    });
  });
}

/*
 * Le plugin reel, sans binding de plateforme.
 *
 * `preparer()` echoue alors — il n'y a pas de systeme a qui parler — et le
 * service rend `false` au lieu de lever. C'est exactement le comportement
 * qu'on veut sur un telephone sans services Google, ou quand quelqu'un a
 * refuse les notifications : une application qui ne peut pas programmer un
 * rappel doit quand meme s'ouvrir.
 */
