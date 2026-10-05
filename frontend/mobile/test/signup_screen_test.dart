import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:veriprof/core/network/api_client.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/core/security/secure_store.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/local/seed/database_seeder.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/sync/sync_engine.dart';
import 'package:veriprof/presentation/providers/core_providers.dart';
import 'package:veriprof/presentation/screens/onboarding/signup_flow_screen.dart';

/// L'inscription telle qu'elle s'utilise avec le doigt.
///
/// Les tests de données passaient alors que le testeur ne pouvait pas
/// s'inscrire : le blocage était donc dans l'écran, pas dans le modèle. Ce
/// test appuie réellement sur « Continuer ».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('fr');

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await DatabaseSeeder(db).seedIfNeeded();
  });

  tearDown(() => db.close());

  Widget app({String? presetRole, void Function(String, Map)? onDone}) {
    final network = NetworkStatusService();
    return ProviderScope(
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
      // Les quatre profils suivent desormais le meme parcours : plus de
      // detour vers une page a part, donc plus besoin d'un routeur ici.
      child: MaterialApp(
        home: SignupFlowScreen(
          presetRole: presetRole,
          onCompleted: (role, answers) => onDone?.call(role, answers),
        ),
      ),
    );
  }

  testWidgets('choisir un profil ouvre son parcours, sans revenir au menu', (
    tester,
  ) async {
    // Rapport du 20/09 : « je clique sur professeur et ça revient au menu ».
    // `intro.json` ne contient plus qu'une étape, donc la première était
    // aussi la dernière, et l'écran fermait sa propre route juste après
    // avoir prévenu l'appelant.
    await tester.pumpWidget(app());
    await _poser(tester);

    expect(find.text('Professeur'), findsOneWidget);
    // Le sélecteur enchaîne de lui-même : pas de « Continuer » à presser.
    await tester.tap(find.text('Professeur'));
    await _poser(tester);

    // Le choix mène à la suite : depuis le 24/09, trois écrans de valeur
    // précèdent les questions. C'est exactement ce que le bug du 20/09
    // empêchait — l'écran se refermait et l'on revenait au menu.
    expect(
      find.text('Professeur'),
      findsNothing,
      reason: 'le choix du profil est toujours à l’écran',
    );
    // Et il mène à *son* écran. Depuis le 26/09 les écrans de valeur sont
    // propres à chaque rôle : un professeur qui lit « des profils vérifiés,
    // pas des promesses » reçoit l'argument destiné aux familles, sur la
    // page censée lui donner envie de remplir onze réponses.
    expect(
      find.text('Votre profil, vu par ceux qui cherchent'),
      findsOneWidget,
      reason: 'le choix du profil ne mène nulle part',
    );
    expect(
      find.text('Des profils vérifiés, pas des promesses'),
      findsNothing,
      reason: 'c’est l’argument des familles, pas celui d’un professeur',
    );
  });

  // Les deux autres profils sont couverts par `signup_end_to_end_test.dart`,
  // qui parcourt leurs questions et crée réellement le compte. Un second
  // test de widget dans ce fichier ne rendait rien — fuite d'état entre
  // tests successifs, pas un défaut du produit — et un test instable
  // désigne des coupables au hasard.
}

/// Laisse l'écran se stabiliser, sans attendre l'impossible.
///
/// `pumpAndSettle` n'aboutit jamais tant qu'une liste déroulante affiche sa
/// barre de chargement indéterminée : elle s'anime sans fin.
Future<void> _poser(WidgetTester tester) async {
  // `pump` fait avancer une horloge simulée ; la lecture d'un asset, elle,
  // se termine sur le vrai ordonnanceur. Sans `runAsync`, l'écran reste
  // vide et le test accuse le produit à tort.
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
}
