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
    // --- Ce que ces deux epreuves attendaient, et pourquoi cela a change ---
    //
    // Elles exigeaient que `+224 620 00 01 01` donne
    // `224620000101@telephone.eduquali.gn`. Les deux cotes etaient bien
    // d'accord — et tous les deux se trompaient de la meme facon.
    //
    // La formule ne gardait que les chiffres. Le MEME numero, tape avec son
    // indicatif ou sans, donnait donc deux adresses, donc deux comptes :
    //
    //     620000101      ->  620000101@telephone.eduquali.gn
    //     +224620000101  ->  224620000101@telephone.eduquali.gn
    //     0620000101     ->  0620000101@telephone.eduquali.gn
    //
    // Signale le 17/10 : « quand j'essaie de me connecter », 400 sur
    // /auth/v1/token. C'est exactement ce que rend Supabase quand on demande
    // un compte qui n'existe pas — et il n'existait pas, parce qu'il avait
    // ete cree sous une autre forme du meme numero.
    //
    // La forme retenue est **neuf chiffres, sans indicatif ni zero de tete** :
    // celle qu'un Guineen dicte, celle que le champ demande, et celle que le
    // prefixe « +224 » non modifiable rend non ambigue. L'histoire complete
    // est dans l'en-tete de `frontend/web/src/api/numero.ts`.
    //
    // Cette epreuve garde son role : verifier que les deux clients n'ont pas
    // diverge. Les formes elles-memes sont enumerees dans
    // `shared/identite/numeros.json`, que lisent les deux epreuves jumelles
    // (`test/numero_test.dart` ici, `src/api/numero.test.ts` sur le site).

    test('est le meme que celui du site', () {
      // On lit le source du site pour verifier qu'il passe par le module
      // partage. Avant, on y cherchait la formule elle-meme (« les chiffres
      // seulement ») : cela liait l'epreuve a une ligne de code plutot qu'a
      // une regle, et c'est ce qui a permis aux deux clients de se tromper
      // ensemble sans que rien ne proteste.
      final web = File('../web/src/api/supabase.ts').readAsStringSync();
      expect(web, contains("from './numero'"));
      expect(web, contains('adresseDuCompte(phone)'));

      final module = File('../web/src/api/numero.ts').readAsStringSync();
      expect(module, contains('@telephone.eduquali.gn'));

      // Et le meme resultat, concretement.
      expect(
        SupabaseAuthApi.emailFor('+224 620 00 01 01'),
        '620000101@telephone.eduquali.gn',
      );
      expect(
        SupabaseAuthApi.emailFor('620000101'),
        '620000101@telephone.eduquali.gn',
      );
    });

    test('ignore la mise en forme du numero', () {
      // Le meme numero tape de six facons doit ouvrir le meme compte —
      // indicatif compris, puisque c'est la qu'etait le defaut.
      const attendu = '620000101@telephone.eduquali.gn';
      for (final saisi in [
        '620000101',
        '620 00 01 01',
        '+224620000101',
        '+224 620 00 01 01',
        '224-620-000-101',
        '0620000101',
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
