import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/network/api_client.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/core/security/secure_store.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/local/seed/database_seeder.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/domain/usecases/cycle_match.dart';
import 'package:veriprof/presentation/providers/core_providers.dart';
import 'package:veriprof/presentation/providers/feature_providers.dart';

/// Ce qu'une famille voit d'un professeur, et ce qu'elle peut en faire.
///
/// Demandé le 26/09 : une famille ne contacte pas, elle réserve. Deux portes
/// pour le même geste envoyaient des « bonjour » dans un fil de discussion
/// pendant que le professeur attendait une demande datée, avec une matière
/// et une classe — et personne ne savait plus ce qui avait été convenu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await DatabaseSeeder(db).seedIfNeeded();
  });

  tearDown(() => db.close());

  ProviderContainer container() {
    final network = NetworkStatusService();
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        secureStoreProvider.overrideWithValue(SecureStore()),
        networkServiceProvider.overrideWithValue(network),
        syncEngineProvider.overrideWithValue(
          SyncEngine(
            database: db,
            network: network,
            api: SyncApi(buildApiClient(() async => null)),
            deviceId: 'test',
          ),
        ),
      ],
    );
  }

  group('Les professeurs proposés à une famille', () {
    test('ont tous une offre de cours à domicile en ligne', () async {
      final c = container();
      addTearDown(c.dispose);

      final domicile = await c.read(homeTeachersProvider(null).future);
      final offres = await c.read(allTutoringOffersProvider.future);
      final proposent = {for (final offer in offres) offer.teacherId};

      expect(domicile, isNotEmpty, reason: 'le seed en contient');
      expect(
        [for (final t in domicile) t.profile.teacherId],
        everyElement(isIn(proposent)),
        reason: 'un professeur sans offre ouvre une fiche sans rien à réserver',
      );
    });

    test('excluent celui qui ne se déplace pas', () async {
      // Le test reposait sur le seed : il contenait des professeurs sans
      // offre de cours à domicile, et l'écart suffisait à prouver que le
      // filtre filtrait. Depuis le 02/10 les trente en proposent tous, donc
      // l'écart a disparu — et un test qui s'appuie sur la forme des données
      // de démonstration meurt dès qu'on les étoffe.
      //
      // On fabrique donc le cas ici : un professeur disponible, sans offre.
      // Le test porte alors sur la règle, et plus sur le jeu de données.
      final c = container();
      addTearDown(c.dispose);

      final avant = await c.read(homeTeachersProvider(null).future);
      final modele = (await db.select(db.teachers).get()).first;
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: 'u_sans_offre',
              role: 'TEACHER',
              phone: '+224629999999',
              firstName: const Value('Sans'),
              lastName: const Value('Domicile'),
            ),
          );
      await db
          .into(db.teachers)
          .insert(
            TeachersCompanion.insert(
              id: 't_sans_offre',
              userId: 'u_sans_offre',
              city: Value(modele.city),
              availability: const Value('AVAILABLE'),
            ),
          );

      c.invalidate(availableTeachersProvider);
      c.invalidate(homeTeachersProvider);
      final tous = await c.read(availableTeachersProvider(null).future);
      final domicile = await c.read(homeTeachersProvider(null).future);

      expect(
        tous.map((t) => t.profile.teacherId),
        contains('t_sans_offre'),
        reason: 'il est disponible, donc il figure dans la liste large',
      );
      expect(
        domicile.map((t) => t.profile.teacherId),
        isNot(contains('t_sans_offre')),
        reason: 'sans offre, sa fiche n’offre rien à réserver',
      );
      expect(domicile.length, avant.length);
    });

    test('n’en perd aucun qui propose du cours à domicile', () async {
      // L'erreur symétrique : un filtre trop strict viderait la liste sans
      // rien signaler, et une famille conclurait qu'il n'y a personne.
      final c = container();
      addTearDown(c.dispose);

      final tous = await c.read(availableTeachersProvider(null).future);
      final domicile = await c.read(homeTeachersProvider(null).future);
      final offres = await c.read(allTutoringOffersProvider.future);
      final proposent = {for (final offer in offres) offer.teacherId};

      final attendus = [
        for (final t in tous)
          if (proposent.contains(t.profile.teacherId)) t.profile.teacherId,
      ];
      expect(
        [for (final t in domicile) t.profile.teacherId],
        attendus,
        reason: 'même ordre, mêmes professeurs — le classement est conservé',
      );
    });
  });

  group('La fiche du professeur', () {
    final fiche = File(
      'lib/presentation/screens/shared/teacher_public_profile_screen.dart',
    ).readAsStringSync();

    // Ces vérifications lisent la source : la question posée est « qui peut
    // atteindre ce bouton », et monter la fiche avec une session de chaque
    // rôle répondrait plus lentement à la même chose.
    test('ne montre « Contacter » qu’à un établissement', () {
      final barre = fiche.indexOf('StickyActionBar');
      expect(barre, greaterThan(0));

      // La garde doit être juste avant la barre. La chercher dans tout le
      // fichier passerait si elle protégeait n'importe quoi d'autre ; les
      // 200 caractères qui précèdent ne contiennent que le commentaire et
      // la condition.
      expect(
        fiche.substring(barre - 200, barre),
        contains('if (session?.isInstitution ?? false)'),
        reason: 'sans garde, une famille retrouve le bouton de contact',
      );
    });

    test('verrouille la réservation tant que la demande est sans réponse', () {
      expect(fiche.contains('Ce professeur vous répondra bientôt'), isTrue);
      expect(
        fiche.contains('TutoringStatus.sent'),
        isTrue,
        reason:
            'le verrou suit l’état réel de la demande, pas un drapeau local',
      );
      // Désactivé, pas masqué. L'indentation n'entre pas dans le test :
      // `dart format` la réécrit à chaque changement de la ligne au-dessus.
      expect(
        fiche.replaceAll(RegExp(r'\s+'), ' '),
        contains('onPressed: enAttente ? null'),
        reason: 'le bouton reste visible et désactivé, il ne disparaît pas',
      );
    });
  });

  group('Le tableau de bord de la famille', () {
    final accueil = File(
      'lib/presentation/screens/dashboards/parent_dashboard.dart',
    ).readAsStringSync();

    test('nomme le professeur attendu et le dit en bleu', () {
      expect(accueil.contains('Demandes envoyées'), isTrue);
      expect(accueil.contains('En attente de confirmation'), isTrue);
      expect(accueil.contains('demande.offer.teacherName'), isTrue);
      // StatusTone.info est le bleu de la palette (#2563EB) ; success est
      // vert et warning orange — l'attente n'est ni l'un ni l'autre.
      //
      // Le ton est cherché dans ce qui suit immédiatement l'étiquette, et
      // non dans tout le fichier : `StatusTone.info` y apparaît aussi pour
      // la pastille du professeur, et le test passerait sans que
      // l'étiquette soit bleue.
      final etiquette = accueil.indexOf('En attente de confirmation');
      expect(etiquette, greaterThan(0));
      expect(
        accueil.substring(etiquette, etiquette + 120),
        contains('StatusTone.info'),
      );
    });
  });

  group('L’assistant', () {
    final ecran = File(
      'lib/presentation/screens/assistant/assistant_screen.dart',
    ).readAsStringSync();

    test('ne compte plus de crédits', () {
      // Passé du crédit à l'abonnement le 26/09. Le solde en haut de
      // l'écran et la feuille d'achat faisaient surveiller un compteur à
      // quelqu'un qui paie déjà tous les mois.
      expect(ecran.contains('showCreditsSheet'), isFalse);
      expect(ecran.contains('aiBalanceProvider'), isFalse);
      expect(ecran.contains('NeedsCredits'), isFalse);
    });

    test('affiche la formule et demande l’abonnement au geste', () {
      expect(ecran.contains('plan.label'), isTrue);
      expect(ecran.contains('showSubscriptionSheet'), isTrue);
      expect(
        ecran.contains('PaidFeature.assistant'),
        isTrue,
        reason: 'la règle vit dans subscription_rules, pas dans l’écran',
      );
      // La garde est dans `_guard`, par où passent l'envoi, la création de
      // cours et l'amélioration : la brancher sur le seul bouton d'envoi
      // laisserait les deux autres ouvertes.
      expect(
        ecran.replaceAll(RegExp(r'\s+'), ' '),
        contains('if (!await _ouvert()) return;'),
      );
    });

    test('le plan gratuit s’appelle Basic', () {
      final regles = File(
        'lib/domain/usecases/subscription_rules.dart',
      ).readAsStringSync();
      expect(regles.contains("free('FREE', 'Basic', 0)"), isTrue);
    });
  });

  group('Ce qui doit rester atteignable', () {
    final router = File(
      'lib/presentation/router/app_router.dart',
    ).readAsStringSync();
    final profil = File(
      'lib/presentation/screens/dashboards/teacher_profile_page.dart',
    ).readAsStringSync();
    final coquille = File(
      'lib/presentation/screens/institution/institution_shell.dart',
    ).readAsStringSync();
    final promotion = File(
      'lib/presentation/screens/catalog/promotion_form_page.dart',
    ).readAsStringSync();

    test('le catalogue côté famille a enfin une route', () {
      // La constante existait depuis le 21/09 sans route derrière : un lien
      // vers elle renvoyait sur l'accueil sans rien dire.
      expect(router.contains('path: Routes.parentCatalog'), isTrue);
    });

    test('les deux gestes qui font des vues mènent quelque part', () {
      expect(profil.contains('Ajouter une photo de profil'), isTrue);
      expect(profil.contains('Routes.teacherProfileEdit'), isTrue);
      expect(profil.contains('Passer un test de compétence'), isTrue);
      expect(profil.contains('Routes.teacherTests'), isTrue);
      expect(router.contains('path: Routes.teacherTests'), isTrue);
    });

    test('la facturation et le contact se joignent depuis le profil', () {
      expect(profil.contains('Routes.paymentMethods'), isTrue);
      expect(profil.contains('Routes.contact'), isTrue);
      expect(router.contains('path: Routes.contact'), isTrue);
    });

    test('l’établissement a un onglet Promotion', () {
      expect(coquille.contains('Routes.institutionPromotions'), isTrue);
      expect(coquille.contains("label: 'Promotion'"), isTrue);
      expect(router.contains('path: Routes.institutionPromotions'), isTrue);
    });

    test('« votre promotion est en ligne » mène à ses chiffres', () {
      // Le formulaire revenait en arrière : la phrase était le dernier mot
      // de l'application sur ce que la mise en avant rapporte.
      expect(promotion.contains('Votre promotion est en ligne.'), isTrue);
      expect(
        promotion.contains('context.go(Routes.institutionPromotions)'),
        isTrue,
      );
      expect(
        promotion.contains('context.pop();'),
        isFalse,
        reason: 'le retour arrière laissait le directeur sans ses chiffres',
      );
    });

    test('« Faire ma promotion » propose la formule, pas des crédits', () {
      // Signalé le 25/09 : la page montrait encore la feuille d'achat de
      // crédits alors que le produit était passé aux trois formules.
      expect(promotion.contains('showCreditsSheet'), isFalse);
      expect(promotion.contains('PromotionNeedsCredits'), isFalse);
      expect(promotion.contains('showSubscriptionSheet'), isTrue);
      expect(promotion.contains('PromotionNeedsPlan'), isTrue);
    });

    test('le système de crédits n’existe plus nulle part', () {
      // Un retrait a moitié fait est pire que les deux modèles : le solde
      // est caché mais le débit continue, et la fonction s'arrête a zéro
      // pour quelqu'un qui paie, sans que rien ne l'explique.
      for (final chemin in [
        'lib/domain/usecases/credit_rules.dart',
        'lib/presentation/screens/assistant/credits_sheet.dart',
      ]) {
        expect(
          File(chemin).existsSync(),
          isFalse,
          reason: '$chemin devait partir avec les crédits',
        );
      }
      // Et le routage de modèle, lui, reste : ce que coûte un appel ne
      // disparaît pas avec ce qu'on facture, il passe sur notre marge.
      final regles = File(
        'lib/domain/usecases/ai_rules.dart',
      ).readAsStringSync();
      expect(regles.contains('gemini-2.5-flash'), isTrue);
      expect(regles.contains('gemini-3.1-pro'), isTrue);
      expect(regles.contains('cost'), isFalse);
    });

    test('« Espace professeur » ouvre la connexion', () {
      final landing = File(
        'lib/presentation/screens/auth/landing_screen.dart',
      ).readAsStringSync();
      final bouton = landing.indexOf("label: 'Espace professeur'");
      expect(bouton, greaterThan(0));
      final suite = landing.substring(bouton, bouton + 200);
      expect(suite.contains('Routes.login'), isTrue);
      expect(
        suite.contains('Routes.signup'),
        isFalse,
        reason: 'un professeur qui appuie ici a presque toujours un compte',
      );
    });
  });

  /// « Pas de professeur d'université pour un élève de 7ème » (note du 02/10).
  ///
  /// La règle elle-même est éprouvée dans `cycle_match_test.dart`, sur des
  /// données inventées. Ici on éprouve le **chemin des données**, qui est le
  /// vrai risque : si `RefItem.cycles` arrive vide de la base, la règle retient
  /// tout le monde et le filtre ne fait rien — en passant pour un succès.
  group('Le filtre par palier', () {
    test('le cycle du professeur vient réellement de la base', () async {
      final c = container();
      addTearDown(c.dispose);

      final domicile = await c.read(homeTeachersProvider(null).future);
      expect(domicile, isNotEmpty, reason: 'semis sans professeur à domicile');

      final avecCycle = [
        for (final t in domicile)
          if (cyclesOfCandidate(t).isNotEmpty) t,
      ];
      expect(
        avecCycle,
        isNotEmpty,
        reason:
            'aucun professeur ne déclare de cycle : la requête des capacités ne '
            'remonte pas `l.cycle`, et tout filtre par palier retiendrait '
            'silencieusement TOUT LE MONDE',
      );
    });

    test('ne garde que ceux du palier, ou ceux qui n’en déclarent aucun', () {
      // Joué sur chaque cycle réellement présent dans le semis, plutôt que sur
      // un cycle choisi d'avance : le semis change, l'invariant tient.
      final c = container();
      addTearDown(c.dispose);

      return c.read(homeTeachersProvider(null).future).then((domicile) {
        final cycles = {for (final t in domicile) ...cyclesOfCandidate(t)};
        expect(cycles, isNotEmpty);

        for (final cycle in cycles) {
          final gardes = teachersForCycle(
            domicile,
            learnerCycle: cycle,
            cyclesOf: cyclesOfCandidate,
          );
          for (final garde in gardes) {
            final siens = cyclesOfCandidate(garde);
            expect(
              siens.isEmpty || siens.contains(cycle),
              isTrue,
              reason:
                  '${garde.profile.fullName} enseigne ${siens.join('/')} et '
                  'reste proposé pour « $cycle »',
            );
          }
          expect(
            gardes.length,
            lessThanOrEqualTo(domicile.length),
            reason: 'un filtre n’ajoute jamais personne',
          );
        }
      });
    });

    test('sans apprenant connu, la liste n’est pas filtrée', () async {
      /*
       * Le cas le plus facile à casser en voulant bien faire.
       *
       * Sans session, il n'y a pas d'apprenant, donc pas de palier. Un filtre
       * qui se déclencherait quand même rendrait une liste vide, et la famille
       * en conclurait qu'il n'y a aucun professeur dans sa ville — alors que
       * c'est le produit qui ne sait pas encore à qui il parle.
       */
      final c = container();
      addTearDown(c.dispose);

      final domicile = await c.read(homeTeachersProvider(null).future);
      final reservables = await c.read(bookableTeachersProvider(null).future);
      expect(
        reservables.map((t) => t.profile.teacherId),
        domicile.map((t) => t.profile.teacherId),
        reason: 'aucun palier connu : rien ne doit disparaître',
      );
    });
  });
}
