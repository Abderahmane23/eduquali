import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_constants.dart';
import 'package:veriprof/data/remote/supabase_auth_api.dart';

/// Un seul compte, les deux clients.
///
/// Demande le 02/10 : il faut pouvoir creer un compte et s'y connecter depuis
/// le site comme depuis le telephone, pour acheter un cours d'un cote et le
/// retrouver de l'autre. Cela tient a une chose : **les deux cotes doivent
/// deduire le meme identifiant du meme numero**, et enregistrer le meme
/// `users.id`. Deux formules differentes feraient deux comptes pour la meme
/// personne, et le defaut ne se verrait que le jour du changement d'appareil.
void main() {
  group('L’identifiant deduit d’un numero', () {
    test('est le meme que celui du site', () {
      // La formule du client web, lue dans son source : si l'un des deux
      // change, ce test echoue au lieu de laisser deux comptes se creer.
      final web = File('../web/src/api/supabase.ts').readAsStringSync();
      expect(web, contains('@telephone.eduquali.gn'));
      expect(web, contains("phone.replace(/\\D/g, '')"));

      // Et le meme resultat, concretement.
      expect(
        SupabaseAuthApi.emailFor('+224 620 00 01 01'),
        '224620000101@telephone.eduquali.gn',
      );
      expect(
        SupabaseAuthApi.emailFor('224620000101'),
        '224620000101@telephone.eduquali.gn',
      );
    });

    test('ignore la mise en forme du numero', () {
      // Le meme numero tape de quatre facons doit ouvrir le meme compte.
      const attendu = '224620000101@telephone.eduquali.gn';
      for (final saisi in [
        '+224620000101',
        '+224 620 00 01 01',
        '224-620-000-101',
        '224 620 000 101',
      ]) {
        expect(SupabaseAuthApi.emailFor(saisi), attendu, reason: saisi);
      }
    });
  });

  group('La configuration', () {
    test('est vide par defaut, et l’application reste locale', () {
      // Sans `--dart-define`, aucun appel reseau n'est tente : l'application
      // fonctionne exactement comme avant, entierement sur la base locale.
      expect(AppConstants.supabaseUrl, isEmpty);
      expect(AppConstants.supabaseAnonKey, isEmpty);
      expect(SupabaseAuthApi.isConfigured, isFalse);
    });

    test('la cle anonyme est assumee dans l’APK, et dit pourquoi', () {
      // La regle « aucune cle dans l'APK » vise la cle Gemini et la cle
      // service_role. La cle anonyme est publique par construction — le site
      // l'envoie a chaque visiteur — et ce n'est pas elle qui protege les
      // donnees, c'est RLS. Sans cette explication ecrite, quelqu'un la
      // retirera au nom de la regle et cassera l'identite partagee.
      final constantes = File(
        'lib/core/constants/app_constants.dart',
      ).readAsStringSync();
      // Les marqueurs de commentaire et les retours a la ligne sont retires
      // avant de chercher : une phrase coupee par `dart format` n'est pas une
      // phrase absente, et un test qui s'en melerait echouerait au premier
      // reformatage.
      final prose = constantes
          .substring(0, constantes.indexOf('static const String supabaseUrl'))
          .replaceAll('///', ' ')
          .replaceAll(RegExp(r'\s+'), ' ');

      expect(prose, contains('publique par construction'));
      expect(prose, contains('service_role'));
      expect(prose, contains("c'est RLS"));
    });
  });

  group('Le depot d’authentification', () {
    final source = File(
      'lib/data/repositories/auth_repository.dart',
    ).readAsStringSync();

    test('prend l’identifiant du serveur quand il y en a un', () {
      // C'est ce qui fait que « le meme compte » n'est pas une facon de
      // parler : la base locale recopie l'identifiant du serveur.
      expect(source, contains('_reserveAccountId'));
      expect(
        source,
        isNot(contains('final userId = _uuid.v4();')),
        reason: 'un identifiant tire localement ferait un second compte',
      );
    });

    test('refuse d’ouvrir un compte hors ligne, et le dit', () {
      // On pourrait le creer en local et le rattacher plus tard, mais il
      // faudrait reconcilier deux identifiants pour la meme personne — et le
      // conflit se decouvrirait au changement d'appareil, au pire moment.
      expect(source, contains('Creer un compte demande une connexion'));
    });

    test('se replie sur l’empreinte locale quand le serveur se taît', () {
      // Sans ce repli, une coupure de reseau fermerait l'application a
      // quelqu'un qui s'est deja connecte sur cet appareil — absurde pour un
      // produit qui se revendique hors ligne.
      expect(source, contains('if (erreur.offline) return null;'));
      expect(source, contains('if (distant == null &&'));
    });

    test('la connexion sur le numero seul n’existe plus nulle part', () {
      // Elle ouvrait une session a qui presentait un numero existant.
      expect(source, isNot(contains('Future<AuthSession> signInWithPhone')));
    });
  });
}
