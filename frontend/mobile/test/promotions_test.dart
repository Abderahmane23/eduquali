import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_constants.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/repositories/promotions_repository.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/domain/usecases/subscription_rules.dart';

/// Les promotions d'établissement, demandées le 21/09.
///
/// Elles coûtaient 50 crédits ; depuis le 25/09 elles font partie de la
/// formule Master, avec le reste du produit. La règle est vérifiée dans le
/// dépôt et non seulement à l'écran : un contrôle qui ne vit que dans un
/// bouton se contourne dès qu'un second appelant arrive, et c'est cette
/// règle qui décide de ce qui se vend.
void main() {
  late AppDatabase db;
  late PromotionsRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = PromotionsRepository(
      db,
      SyncEngine(
        database: db,
        network: NetworkStatusService(),
        api: SyncApi(Dio()),
        deviceId: 'test',
      ),
    );

    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u_i',
            role: 'INSTITUTION',
            phone: '+224610000001',
          ),
        );
    await db
        .into(db.institutions)
        .insert(
          InstitutionsCompanion.insert(
            id: 'i1',
            name: 'Lycée Excellence',
            type: 'SCHOOL',
            city: 'Conakry',
            userId: const Value('u_i'),
          ),
        );
  });

  tearDown(() => db.close());

  /// Abonne le compte, avec une échéance à venir sauf indication contraire.
  Future<void> abonner(SubscriptionPlan plan, {DateTime? renewsAt}) =>
      (db.update(db.users)..where((t) => t.id.equals('u_i'))).write(
        UsersCompanion(
          plan: Value(plan.code),
          planRenewsAt: Value(
            renewsAt ?? DateTime.now().add(const Duration(days: 20)),
          ),
        ),
      );

  Future<String> unePromo() => repo.publish(
    institutionId: 'i1',
    ownerId: 'u_i',
    title: 'Inscriptions ouvertes',
    mediaPaths: ['cour.jpg', 'visite.mp4'],
  );

  group('Qui peut se mettre en avant', () {
    test('l’audience annoncée n’a pas bougé', () {
      expect(AppConstants.promotionReach, 3000);
    });

    test('sans abonnement, rien ne se met en ligne', () async {
      expect(unePromo, throwsA(isA<PromotionNeedsPlan>()));
      expect(await repo.ofInstitution('i1'), isEmpty);
    });

    test('Pro ne suffit pas : la mise en avant est dans Master', () async {
      // Le contrôle passe par `covers`, donc par le barème, et non par une
      // comparaison écrite ici. Déplacer la fonction d'une formule à
      // l'autre ne doit toucher que `subscription_rules.dart`.
      await abonner(SubscriptionPlan.pro);
      expect(unePromo, throwsA(isA<PromotionNeedsPlan>()));
      expect(await repo.ofInstitution('i1'), isEmpty);
    });

    test('le refus nomme la formule à prendre', () async {
      // L'écran a besoin de la formule, pas d'une phrase : reconnaître le
      // cas au texte du message aurait tenu jusqu'à la première
      // reformulation.
      await abonner(SubscriptionPlan.pro);
      try {
        await unePromo();
        fail('la promotion est passée sans la formule');
      } on PromotionNeedsPlan catch (refus) {
        expect(refus.required, SubscriptionPlan.master);
        expect(refus.required, PaidFeature.promotion.requires);
      }
    });

    test('un abonnement Master expiré ne l’ouvre plus', () async {
      // Le mois payé est fini : le compte redevient Basic. Sans cette
      // vérification, un abonnement souscrit une fois ouvrirait la mise en
      // avant pour toujours.
      await abonner(
        SubscriptionPlan.master,
        renewsAt: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(unePromo, throwsA(isA<PromotionNeedsPlan>()));
    });

    test('avec Master, elle part en ligne avec ses dates', () async {
      await abonner(SubscriptionPlan.master);
      await unePromo();

      final promo = (await repo.ofInstitution('i1')).single;
      expect(promo.isActive, isTrue);
      expect(promo.media, ['cour.jpg', 'visite.mp4']);
      expect(promo.institutionName, 'Lycée Excellence');
      expect(promo.row.startsAt, isNotNull);
      expect(promo.row.endsAt, isNotNull);
    });
  });

  group('Ce qui reste refusé', () {
    setUp(() => abonner(SubscriptionPlan.master));

    test('sans image ni vidéo, elle est refusée', () async {
      // Une mise en avant pour une ligne de texte : il n'y aurait rien à
      // montrer aux familles.
      expect(
        () => repo.publish(
          institutionId: 'i1',
          ownerId: 'u_i',
          title: 'Sans média',
          mediaPaths: const [],
        ),
        throwsA(isA<PromotionException>()),
      );
      expect(await repo.ofInstitution('i1'), isEmpty);
    });

    test('sans titre, elle est refusée', () async {
      expect(
        () => repo.publish(
          institutionId: 'i1',
          ownerId: 'u_i',
          title: '  ',
          mediaPaths: ['a.jpg'],
        ),
        throwsA(isA<PromotionException>()),
      );
      expect(await repo.ofInstitution('i1'), isEmpty);
    });
  });

  group('Sa vie ensuite', () {
    setUp(() => abonner(SubscriptionPlan.master));

    test('les familles ne voient que ce qui est en ligne', () async {
      final id = await unePromo();
      expect(await repo.active(), hasLength(1));

      await repo.end(id);
      expect(await repo.active(), isEmpty);
      // L'établissement, lui, garde la trace de ce qu'il a publié.
      expect(await repo.ofInstitution('i1'), hasLength(1));
    });

    test(
      'les affichages se comptent — c’est ce que la mise en avant fait',
      () async {
        final id = await unePromo();
        await repo.countView(id);
        await repo.countView(id);
        expect((await repo.ofInstitution('i1')).single.row.views, 2);
      },
    );
  });
}
