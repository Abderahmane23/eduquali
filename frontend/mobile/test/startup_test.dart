import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/data/local/database/app_database.dart';

import 'support/v19_database.dart' as support;
import 'package:veriprof/data/local/seed/database_seeder.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/sync/sync_engine.dart';

/// Le démarrage de `main()`, sur une base posée dans un fichier.
///
/// Signalé le 25/09 : « l'apk ne se lance pas, il montre le logo ». Ce logo
/// est celui du lanceur Android, pas l'écran d'accueil de l'application :
/// `runApp` n'est jamais atteint. Tout ce que `main()` attend avant lui
/// bloque donc l'application entière, sans message et sans issue.
///
/// Ce fichier rejoue cette séquence — ouverture, migration, semis, moteur de
/// synchronisation — dans l'ordre et sur un vrai fichier, parce que les
/// autres tests travaillent en mémoire et ne migrent jamais rien.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('fr');

  late Directory dossier;
  late File fichier;

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('eduquali_demarrage');
    fichier = File('${dossier.path}${Platform.pathSeparator}app.sqlite');
  });

  tearDown(() async {
    if (dossier.existsSync()) await dossier.delete(recursive: true);
  });

  /// Ramène une base neuve à la forme v19.
  ///
  /// La remise en forme vit dans `support/v19_database.dart`. Elle était
  /// recopiée ici et dans `migration_v20_test.dart`, chacune affirmant que le
  /// prix se payait « ici, une fois » : il se payait deux fois, et cette
  /// copie-ci avait pris du retard — elle ne défaisait pas les trois tables de
  /// la v23, si bien que la migration n'en créait aucune.
  Future<void> poserUneBaseV19() => support.poserUneBaseV19(fichier);

  /// La séquence que `main()` exécute avant `runApp`, dans son ordre.
  ///
  /// Les quatre étapes de `main.dart` : les formats de date (posés une fois
  /// pour tout le fichier), l'ouverture de la base — c'est elle qui exécute
  /// les migrations, donc tout le poids du démarrage sur un téléphone déjà
  /// installé —, le semis du référentiel, puis le moteur de synchronisation.
  ///
  /// `runStartupStep` n'est pas rejoué ici : ce fichier éprouve que la
  /// séquence **aboutit**, et les délais de `main()` sont précisément ce qui
  /// masquerait une étape qui ne rend jamais la main. C'est le `timeout` de
  /// chaque test qui tient ce rôle.
  Future<void> demarrer(AppDatabase db) async {
    await DatabaseSeeder(db).seedIfNeeded();

    final network = NetworkStatusService();
    addTearDown(network.dispose);
    final moteur = SyncEngine(
      database: db,
      network: network,
      api: SyncApi(Dio()),
      deviceId: 'appareil-de-test',
    );
    addTearDown(moteur.dispose);
    await moteur.start();
  }

  test('première installation : la séquence complète aboutit', () async {
    final db = AppDatabase.forTesting(NativeDatabase(fichier));
    addTearDown(db.close);

    // Le délai est la vraie assertion : `main()` n'a aucun garde-fou, donc
    // une étape qui ne rend jamais la main laisse l'écran de lancement
    // affiché indéfiniment — ce que voit l'utilisateur.
    await expectLater(
      demarrer(db).timeout(const Duration(seconds: 30)),
      completes,
    );

    // Et le semis a bien eu lieu : sans référentiel, tous les écrans de
    // choix seraient vides.
    expect(await db.select(db.subjects).get(), isNotEmpty);
    expect(await db.select(db.levels).get(), isNotEmpty);
  });

  test('mise à jour depuis la v19 : la séquence complète aboutit', () async {
    await poserUneBaseV19();

    final db = AppDatabase.forTesting(NativeDatabase(fichier));
    addTearDown(db.close);

    await expectLater(
      demarrer(db).timeout(const Duration(seconds: 30)),
      completes,
    );
    expect(await db.select(db.subjects).get(), isNotEmpty);
  });

  test('deuxième lancement : le semis ne recommence pas', () async {
    final premier = AppDatabase.forTesting(NativeDatabase(fichier));
    await demarrer(premier);
    final matieres = (await premier.select(premier.subjects).get()).length;
    await premier.close();

    final second = AppDatabase.forTesting(NativeDatabase(fichier));
    addTearDown(second.close);
    await expectLater(
      demarrer(second).timeout(const Duration(seconds: 30)),
      completes,
    );

    // Un semis rejoué à chaque ouverture allongerait le démarrage à chaque
    // fois, et finirait par dépasser la patience d'un utilisateur sur un
    // téléphone lent.
    expect((await second.select(second.subjects).get()).length, matieres);
  });
}
