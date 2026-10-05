import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/constants/app_constants.dart';
import 'package:veriprof/core/constants/app_enums.dart';
import 'package:veriprof/core/network/api_client.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/core/security/secure_store.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/repositories/auth_repository.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/domain/usecases/otp_check.dart';

/// L'application sans serveur.
///
/// Le serveur n'est pas déployé et l'APK circule déjà de téléphone à
/// téléphone. Rien de ce qu'un testeur veut essayer ne doit dépendre de lui :
/// ni l'ouverture de l'application, ni la création d'un compte, ni la
/// publication d'une offre.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('aucune adresse de serveur n’est compilée par défaut', () {
    // Une adresse inventée ferait attendre l'application à chaque démarrage
    // puis toutes les 45 secondes, pour un serveur qui n'existe pas.
    expect(AppConstants.apiBaseUrl, isEmpty);
    expect(AppConstants.hasBackend, isFalse);
  });

  test('un appel réseau échoue tout de suite, et le dit en français', () async {
    final dio = buildApiClient(() async => null);
    final stopwatch = Stopwatch()..start();

    await expectLater(
      dio.get<dynamic>('/jobs'),
      throwsA(
        isA<DioException>().having(
          (e) => e.error,
          'cause',
          isA<BackendUnavailable>(),
        ),
      ),
    );

    // Rejet immédiat : aucune attente de douze secondes sur une adresse vide.
    expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    expect(backendUnavailableMessage, contains('n’est pas encore en ligne'));
  });

  test('mettre le réseau en route ne bloque pas le démarrage', () {
    // `start()` ne rend pas de Future : impossible de l'attendre par
    // inadvertance dans `main()`, ce qui figeait l'écran d'accueil jusqu'à
    // neuf secondes sur une connexion lente.
    final service = NetworkStatusService(probeClient: Dio());
    expect(service.start, isA<void Function()>());
    expect(service.state, NetworkState.noNetwork);
    service.dispose();
  });

  test('sans serveur, la synchronisation reste inerte', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final engine = SyncEngine(
      database: db,
      network: NetworkStatusService(probeClient: Dio()),
      api: SyncApi(buildApiClient(() async => null)),
      deviceId: 'test',
    );

    await engine.enqueue(
      entity: 'teacher',
      entityId: 't1',
      operation: SyncOperation.create,
      payload: const {'city': 'Ratoma'},
    );

    // Aucune exception, aucun appel : l'opération attend son tour dans la
    // file locale et partira le jour où le serveur existera.
    await engine.synchronize();
    final queued = await db.select(db.syncQueue).get();
    expect(queued, hasLength(1));
  });

  // Un vrai code, different du code unique : sans cela les deux cas se
  // confondraient et le test ne prouverait rien.
  OtpOutcome offlineOtp({required bool serverReachable}) => checkOtp(
    entered: AppConstants.offlineOtpCode,
    expected: '987654',
    issuedAt: DateTime.now(),
    now: DateTime.now(),
    validity: AppConstants.otpValidity,
    offlineCodeEnabled: AppConstants.offlineOtpEnabled,
    offlineCode: AppConstants.offlineOtpCode,
    serverReachable: serverReachable,
  );

  test('le code unique ouvre la session quand le serveur est muet', () {
    // Sans serveur, aucun SMS ne part. Refuser le code bloquerait tout
    // testeur dès le premier écran.
    expect(AppConstants.offlineOtpEnabled, isTrue);

    final outcome = offlineOtp(serverReachable: false);
    expect(outcome, OtpOutcome.acceptedOffline);
    expect(outcome.opensSession, isTrue);
  });

  test('serveur joignable, le code unique est refusé', () {
    // Le jour du déploiement, ce code ne doit plus ouvrir aucun compte :
    // c'est la règle la plus sensible de tout le parcours.
    final outcome = offlineOtp(serverReachable: true);
    expect(outcome, OtpOutcome.wrong);
    expect(outcome.opensSession, isFalse);
  });

  test('le dépôt d’authentification sait qu’il travaille hors ligne', () {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repo = AuthRepository(
      db,
      SecureStore(),
      SyncEngine(
        database: db,
        network: NetworkStatusService(probeClient: Dio()),
        api: SyncApi(buildApiClient(() async => null)),
        deviceId: 'test',
      ),
      isServerReachable: () => false,
    );
    expect(repo.offlineOtpApplies, isTrue);
  });
}
