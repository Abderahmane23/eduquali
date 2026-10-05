import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/data/billing/invoice_pdf.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/repositories/payment_methods_repository.dart';
import 'package:veriprof/data/sync/sync_engine.dart';

/// Moyens de paiement et factures, demandés le 21/09.
///
/// Le point le plus important n'est pas l'écran : c'est qu'**aucun secret**
/// ne soit conservé. Un code de paiement dans une base locale que l'APK
/// transporte de téléphone à téléphone se lirait en quelques minutes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('fr');

  late AppDatabase db;
  late PaymentMethodsRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = PaymentMethodsRepository(
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
            id: 'u1',
            role: 'PARENT',
            phone: '+224620000001',
          ),
        );
  });

  tearDown(() => db.close());

  group('Rien de secret n’est conservé', () {
    test('seuls les quatre derniers chiffres sont écrits', () async {
      await repo.add(
        userId: 'u1',
        kind: PaymentKind.orangeMoney,
        reference: '620 12 34 56',
      );

      final row = await db.select(db.paymentMethods).getSingle();
      expect(row.last4, '3456');
      // Le numéro complet n'apparaît nulle part.
      expect(row.toString(), isNot(contains('6201234')));
    });

    test('la file de synchronisation n’emporte pas le numéro', () async {
      await repo.add(
        userId: 'u1',
        kind: PaymentKind.card,
        reference: '4111111111111111',
      );
      final queued = await db.select(db.syncQueue).getSingle();
      expect(queued.payload, contains('1111'));
      expect(
        queued.payload,
        isNot(contains('4111111111111111')),
        reason: 'le numéro complet part vers le serveur',
      );
    });

    test('un numéro trop court est refusé', () async {
      expect(
        () =>
            repo.add(userId: 'u1', kind: PaymentKind.mtnMomo, reference: '62'),
        throwsA(isA<PaymentMethodException>()),
      );
    });

    test('les espèces n’exigent aucun numéro', () async {
      // Une part des règlements se fait encore de la main à la main.
      await repo.add(userId: 'u1', kind: PaymentKind.cash);
      expect(await repo.of('u1'), hasLength(1));
    });
  });

  group('Le moyen par défaut', () {
    test('le premier enregistré le devient', () async {
      await repo.add(
        userId: 'u1',
        kind: PaymentKind.orangeMoney,
        reference: '620000001',
      );
      expect((await repo.of('u1')).single.isDefault, isTrue);
    });

    test('il n’y en a jamais deux', () async {
      await repo.add(
        userId: 'u1',
        kind: PaymentKind.orangeMoney,
        reference: '620000001',
      );
      await repo.add(
        userId: 'u1',
        kind: PaymentKind.mtnMomo,
        reference: '660000002',
        makeDefault: true,
      );

      final defaults = (await repo.of('u1')).where((m) => m.isDefault);
      expect(defaults, hasLength(1));
      expect(defaults.single.kind, PaymentKind.mtnMomo);
    });

    test('le retirer promeut le suivant', () async {
      // Sinon le compte se retrouve sans aucun moyen par défaut, et l'écran
      // de paiement n'en propose plus.
      final first = await repo.add(
        userId: 'u1',
        kind: PaymentKind.orangeMoney,
        reference: '620000001',
      );
      await repo.add(
        userId: 'u1',
        kind: PaymentKind.mtnMomo,
        reference: '660000002',
      );

      await repo.remove(userId: 'u1', methodId: first);
      final rest = await repo.of('u1');
      expect(rest, hasLength(1));
      expect(rest.single.isDefault, isTrue);
    });
  });

  group('Ce qui s’affiche', () {
    test('« Orange Money · •••• 3456 »', () async {
      await repo.add(
        userId: 'u1',
        kind: PaymentKind.orangeMoney,
        reference: '620123456',
      );
      expect((await repo.of('u1')).single.display, 'Orange Money · •••• 3456');
    });

    test('les espèces s’affichent sans chiffres', () async {
      await repo.add(userId: 'u1', kind: PaymentKind.cash);
      expect((await repo.of('u1')).single.display, 'Espèces');
    });
  });

  group('La facture PDF', () {
    test('elle s’écrit, et porte un vrai PDF', () async {
      final bytes = await InvoicePdf.build(
        accountName: 'Fatoumata Barry',
        subtitle: 'Parent d’élève',
        lines: [
          InvoiceLine(
            label: 'Lycée Excellence',
            date: DateTime(2026, 10, 5),
            amount: 150000,
          ),
          InvoiceLine(
            label: 'Cours de maths',
            date: DateTime(2026, 11, 5),
            amount: 60000,
          ),
        ],
      );

      expect(bytes.length, greaterThan(1000));
      // Un PDF commence par « %PDF ».
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });

    test('une période sans paiement donne quand même un document', () async {
      // Un comptable qui demande les factures doit recevoir une page qui dit
      // « rien », pas une erreur.
      final bytes = await InvoicePdf.build(
        accountName: 'Mamadou Barry',
        lines: const [],
      );
      expect(bytes.length, greaterThan(500));
    });

    test('le nom de fichier porte le mois', () {
      expect(
        InvoicePdf.fileName(DateTime(2026, 9, 22)),
        'factures-2026-09.pdf',
      );
    });
  });
}
