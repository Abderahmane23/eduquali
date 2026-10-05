import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:veriprof/core/network/api_client.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/core/security/secure_store.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/local/seed/database_seeder.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/presentation/providers/core_providers.dart';
import 'package:veriprof/presentation/providers/session_providers.dart';
import 'package:veriprof/presentation/screens/dashboards/teacher_profile_page.dart';
import 'package:veriprof/presentation/screens/institution/institution_shell.dart';

/// On doit pouvoir quitter son compte, depuis les trois profils.
///
/// Signalé sur l'APK du 23/09 : « i cannot deconnect from the teacher profil
/// page ». La refonte du profil sur la maquette du 21/09 avait remplacé
/// l'ancien écran — et emporté avec lui le seul bouton de déconnexion de
/// l'espace professeur, alors que les deux autres profils gardaient le leur.
///
/// Ce test est là pour qu'une prochaine refonte ne le reprenne pas : un
/// téléphone se prête, et qui ne peut pas se déconnecter laisse son compte
/// ouvert à la personne suivante.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('fr');

  late AppDatabase db;

  setUp(() async {
    // Sans ce faux magasin, `setSession` attend une reponse du canal natif
    // qui n'existe pas en test : la suite entiere restait bloquee dix
    // minutes par cas avant d'abandonner.
    FlutterSecureStorage.setMockInitialValues({});
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

  /// Ouvre l'ecran de profil d'un role, connecte comme l'application le fait.
  Future<void> ouvrir(
    WidgetTester tester,
    Widget page,
    Future<dynamic> Function(dynamic auth) connexion,
  ) async {
    final c = container();
    addTearDown(c.dispose);

    final session = await connexion(c.read(authRepositoryProvider));
    await c.read(sessionProvider.notifier).setSession(session);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: Scaffold(body: page)),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
  }

  /// « Se deconnecter » quelque part : un libelle, ou l'infobulle d'un
  /// bouton-icone. C'est la sortie qui compte, pas sa forme.
  Finder sortie() => find.byWidgetPredicate(
    (w) =>
        (w is Text && w.data == 'Se déconnecter') ||
        (w is Tooltip && w.message == 'Se déconnecter'),
    description: 'un moyen de se déconnecter',
  );

  testWidgets(
    'le professeur peut quitter son compte',
    timeout: const Timeout(Duration(seconds: 30)),
    (tester) async {
      await ouvrir(
        tester,
        const TeacherProfilePage(),
        (auth) => auth.loginAsDemoTeacher(),
      );
      expect(sortie(), findsOneWidget);
    },
  );

  testWidgets(
    'l’établissement peut quitter son compte',
    timeout: const Timeout(Duration(seconds: 30)),
    (tester) async {
      await ouvrir(
        tester,
        const InstitutionProfileTab(),
        (auth) => auth.loginAsDemoInstitution(),
      );
      expect(
        sortie(),
        findsOneWidget,
        reason: 'aucun moyen de quitter le compte établissement',
      );
    },
  );
}
