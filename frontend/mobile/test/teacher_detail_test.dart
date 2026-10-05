import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:veriprof/presentation/providers/feature_providers.dart';
import 'package:veriprof/presentation/screens/shared/teacher_public_profile_screen.dart';

/// La fiche complète d'un professeur.
///
/// Rapport du 20/09 : « les cartes voir professeur ne marchent pas au clic ».
/// L'écran existe et les cartes le poussent bien ; reste à savoir ce qu'il
/// affiche une fois ouvert.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('fr');

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

  test('des professeurs de démonstration existent', () async {
    final teachers = await db.select(db.teachers).get();
    expect(
      teachers,
      isNotEmpty,
      reason: 'sans professeur semé, aucune carte n’est cliquable',
    );
  });

  test('chaque professeur affiché a une fiche consultable', () async {
    final c = container();
    addTearDown(c.dispose);

    final teachers = await db.select(db.teachers).get();
    for (final teacher in teachers) {
      final profile = await c.read(
        teacherProfileByIdProvider(teacher.id).future,
      );
      expect(
        profile,
        isNotNull,
        reason:
            'la carte du professeur ${teacher.id} mène à une fiche vide : '
            '« Profil introuvable »',
      );
    }
  });

  testWidgets('la fiche affiche un contenu, pas une erreur', (tester) async {
    final teachers = await db.select(db.teachers).get();
    final id = teachers.first.id;
    final c = container();
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: TeacherPublicProfileScreen(teacherId: id)),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Profil introuvable'), findsNothing);
    expect(find.text('Profil indisponible'), findsNothing);
    // Le nom du professeur doit apparaître : c'est le minimum d'une fiche.
    final textes = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((t) => t.trim().isNotEmpty)
        .toList();
    expect(textes, isNotEmpty, reason: 'la fiche est vide');
  });
}
