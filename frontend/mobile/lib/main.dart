import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/network/api_client.dart';
import 'core/network/network_status_service.dart';
import 'core/security/secure_store.dart';
import 'core/startup_report.dart';
import 'data/local/database/app_database.dart';
import 'data/local/seed/database_seeder.dart';
import 'data/remote/sync_api.dart';
import 'data/sync/sync_engine.dart';
import 'presentation/app.dart';
import 'presentation/providers/core_providers.dart';

/// Délais maximaux de démarrage.
///
/// Généreux, parce qu'un téléphone d'entrée de gamme sème un référentiel de
/// trente kilo-octets en plusieurs secondes — mais bornés, parce qu'une
/// étape qui dépasse ces délais ne finira pas : elle est bloquée, et
/// l'attendre une minute de plus ne fait qu'ajouter une minute d'écran noir.
const _delaiBase = Duration(seconds: 45);
const _delaiCourt = Duration(seconds: 10);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Les erreurs de rendu partaient dans la console d'un téléphone que
  // personne ne branche. Elles remontent maintenant dans le rapport.
  final problemes = <StartupIssue>[];
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Erreur Flutter : ${details.exceptionAsString()}');
  };

  // Formats de dates et de nombres en francais (§54).
  await runStartupStep(
    'formats de date',
    problemes,
    fatal: false,
    delai: _delaiCourt,
    action: () => initializeDateFormatting('fr'),
  );

  final database = AppDatabase();
  // Referentiel et données de démonstration disponibles des la première
  // ouverture, y compris sans connexion (§41).
  //
  // C'est aussi cette étape qui ouvre la base, donc qui exécute les
  // migrations : sur un téléphone déjà installé, tout le poids du démarrage
  // est ici.
  await runStartupStep(
    'base de données',
    problemes,
    fatal: true,
    delai: _delaiBase,
    action: () => DatabaseSeeder(database).seedIfNeeded(),
  );

  final secureStore = SecureStore();
  // Un identifiant de session sert de repli : le magasin de clés d'Android
  // peut être inutilisable après une restauration de sauvegarde, et cet
  // identifiant ne sert qu'à nommer l'appareil dans la file d'envoi.
  var deviceId = 'appareil-sans-cle';
  await runStartupStep(
    'stockage sécurisé',
    problemes,
    fatal: false,
    delai: _delaiCourt,
    action: () async => deviceId = await secureStore.deviceId(),
  );

  final network = NetworkStatusService();
  // Sans `await` : mesurer l'etat du reseau prend plusieurs secondes sur une
  // connexion lente, et aucun ecran n'attend cette information pour
  // s'afficher.
  //
  // Mais sous rattrapage quand meme : `start()` s'abonne au service de
  // connectivite d'Android, et une exception synchrone de ce cote tuerait
  // `main()` avant `runApp` — c'est-a-dire l'application entiere, pour une
  // information dont aucun ecran n'a besoin pour s'afficher.
  await runStartupStep(
    'état du réseau',
    problemes,
    fatal: false,
    delai: _delaiCourt,
    action: () async => network.start(),
  );

  final dio = buildApiClient(() => secureStore.accessToken);
  final syncEngine = SyncEngine(
    database: database,
    network: network,
    api: SyncApi(dio),
    deviceId: deviceId,
  );
  await runStartupStep(
    'synchronisation',
    problemes,
    fatal: false,
    delai: _delaiCourt,
    action: syncEngine.start,
  );

  // `runApp` est atteint quoi qu'il arrive. Une application qui s'ouvre sur
  // un message d'erreur se raconte au support ; une application qui reste
  // sur le logo du lanceur ne se raconte pas.
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        secureStoreProvider.overrideWithValue(secureStore),
        networkServiceProvider.overrideWithValue(network),
        syncEngineProvider.overrideWithValue(syncEngine),
        dioProvider.overrideWithValue(dio),
      ],
      child: EduqualiApp(startup: StartupReport(problemes)),
    ),
  );
}
