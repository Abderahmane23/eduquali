import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/core/network/network_status_service.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/local/seed/database_seeder.dart';
import 'package:veriprof/data/remote/sync_api.dart';
import 'package:veriprof/data/repositories/tutoring_repository.dart';
import 'package:veriprof/data/sync/sync_engine.dart';

/// Premier lancement sur un téléphone neuf.
///
/// L'APK circule par Bluetooth et Xender : chaque installation part d'une
/// base vide, sans serveur. Ce que le seed n'apporte pas, le testeur ne le
/// voit jamais.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await DatabaseSeeder(db).seedIfNeeded();
  });

  tearDown(() => db.close());

  test('la Terminale est chargée', () async {
    final levels = await db.select(db.levels).get();
    expect(levels.map((l) => l.name), contains('Terminale'));
  });

  test('un parent trouve des professeurs à réserver', () async {
    final repo = TutoringRepository(
      db,
      SyncEngine(
        database: db,
        network: NetworkStatusService(),
        api: SyncApi(Dio()),
        deviceId: 'test',
      ),
    );

    final mamadou = await repo.offersOf('tch_mamadou', onlyActive: true);
    expect(mamadou, isNotEmpty, reason: 'le professeur de démonstration');
    expect(mamadou.first.subjectName, isNotEmpty);
    expect(mamadou.first.levelNames, contains('Terminale'));
    expect(mamadou.first.hourlyRate, 60000);

    // Le nombre vient du catalogue, pas d'un litteral : il a saute de 4 a 30
    // le 02/10, et un test qui fige le chiffre casse a chaque ajout de
    // donnees sans rien apprendre a personne.
    final attendues = catalogue('tutoringServices').length;
    final toutes = await db.select(db.tutoringServices).get();
    expect(toutes, hasLength(attendues));

    // La regle, elle, ne depend pas du nombre : depuis le 02/10 chaque
    // professeur de demonstration propose des cours a domicile. Sans offre,
    // il est invisible cote famille — le filtre du 26/09 ne retient que ceux
    // qui se deplacent — et la moitie de la liste manquerait la ou elle
    // compte le plus.
    final avecOffre = {for (final o in toutes) o.teacherId};
    final professeurs = await db.select(db.teachers).get();
    expect(professeurs, hasLength(catalogue('demoTeachers').length));
    for (final prof in professeurs) {
      expect(
        avecOffre,
        contains(prof.id),
        reason: '${prof.id} ne propose aucun cours a domicile',
      );
    }
  });

  test('relancer le seed ne duplique rien', () async {
    final avant = (await db.select(db.tutoringServices).get()).length;
    await DatabaseSeeder(db).seedIfNeeded();
    expect(await db.select(db.tutoringServices).get(), hasLength(avant));
  });
}

/// Une liste du catalogue de demonstration, lue a la source.
///
/// Les tests comparent a ce fichier plutot qu'a des chiffres recopies : c'est
/// lui qui decide, et un litteral finit toujours par le contredire.
List<dynamic> catalogue(String cle) {
  final brut = File('assets/seed/catalog.json').readAsStringSync();
  return (jsonDecode(brut) as Map<String, dynamic>)[cle] as List<dynamic>;
}
