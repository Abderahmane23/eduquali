import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veriprof/data/local/database/app_database.dart';
import 'package:veriprof/data/local/seed/database_seeder.dart';
import 'package:veriprof/data/repositories/catalog_repository.dart';

/// Le référentiel tel qu'il arrive réellement en base.
///
/// Les tests de fichiers lisent le JSON ; celui-ci vérifie le trajet complet
/// — semis, colonnes, requêtes — parce que c'est là que se logent les erreurs
/// qu'aucune relecture de JSON ne montre.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CatalogRepository catalog;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await DatabaseSeeder(db).seedIfNeeded();
    catalog = CatalogRepository(db);
  });

  tearDown(() => db.close());

  test('les classes proposées excluent les en-têtes de cycle', () async {
    // La demande du 19/09 : « le professeur qui a choisi un cycle ne voit que
    // les classes correspondantes ». « Lycée » n'est pas une classe.
    final names = (await catalog.levels()).map((l) => l.name).toList();
    expect(names, isNot(contains('Lycée')));
    expect(names, isNot(contains('Collège')));
    expect(names, isNot(contains('Primaire')));
    expect(names, containsAll(['11ème année', '12ème année', 'Terminale']));
  });

  test('les en-têtes restent disponibles pour une certification', () async {
    // Un test « Mathématiques — Lycée » vise bien le cycle entier : les
    // retirer de la base casserait les certifications existantes.
    final all = await catalog.levels(includeGroupings: true);
    expect(all.map((l) => l.name), contains('Lycée'));
    expect(all.length, greaterThan((await catalog.levels()).length));
  });

  test('le lycée compte exactement trois classes', () async {
    final lycee = (await catalog.levels())
        .where((l) => l.cycles.contains('LYCEE'))
        .map((l) => l.name)
        .toList();
    expect(lycee, ['11ème année', '12ème année', 'Terminale']);
  });

  test('le collège compte exactement quatre années', () async {
    final college = (await catalog.levels())
        .where((l) => l.cycles.contains('COLLEGE'))
        .map((l) => l.name)
        .toList();
    expect(college, ['7ème année', '8ème année', '9ème année', '10ème année']);
  });

  test('les trois profils sont en base, avec leurs matières', () async {
    final filieres = await catalog.filieres();
    expect(filieres, hasLength(3));

    final soc = filieres.firstWhere((f) => f.code == 'SS');
    expect(soc.name, 'Sciences sociales');
    expect(soc.levelIds.split(','), ['lvl_12', 'lvl_terminale']);
    expect(soc.majorSubjectIds.split(','), ['sub_hist', 'sub_geog']);
    expect(soc.subjectIds.split(','), contains('sub_econ'));
    expect(soc.note, isNotEmpty);
  });

  test('les matières du programme sont toutes semées', () async {
    final names = (await catalog.subjects()).map((s) => s.name).toSet();
    // Vingt-quatre jusqu'au 03/10 : l'arabe manquait au referentiel alors que le
    // programme national le liste pour les sept classes du secondaire, et qu'il
    // s'enseigne dans les ecoles franco-arabes. Le controle croise de
    // `sync.mjs` l'a signale en comparant les identifiants cites par le
    // programme a ceux du catalogue.
    expect(names, hasLength(25));
    expect(names, contains('Arabe'));
    expect(
      names,
      containsAll([
        'Philosophie',
        'Éducation civique et morale',
        'Éducation physique et sportive',
        'Biologie',
        'Geologie',
        // Les facultés décrites le 19/09.
        'Médecine',
        'Pharmacie',
        'Génie civil',
        'Télécommunications',
      ]),
    );
  });

  test('chaque matière déclare au moins un cycle', () async {
    // Sans cycle, une matière passe tous les filtres et réapparaît partout.
    for (final subject in await catalog.subjects()) {
      expect(subject.cycles, isNotEmpty, reason: subject.name);
    }
  });

  test('la fiche enfant accepte un profil', () async {
    // La colonne existe et la valeur se relit : une migration ratée se
    // verrait ici.
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u1',
            role: 'PARENT',
            phone: '+224600000001',
          ),
        );
    await db
        .into(db.parents)
        .insert(ParentsCompanion.insert(id: 'p1', userId: 'u1'));
    await db
        .into(db.children)
        .insert(
          ChildrenCompanion.insert(
            id: 'c1',
            parentId: 'p1',
            firstName: 'Fatoumata',
            levelId: const Value('lvl_terminale'),
            filiereId: const Value('fil_exp'),
          ),
        );

    final child = await db.select(db.children).getSingle();
    expect(child.filiereId, 'fil_exp');
  });

  test('les clés étrangères existent enfin, et mordent', () async {
    // Le 19/09, `tables.dart` déclarait 51 `.references(...)` et le schéma
    // généré n'en portait aucune : `drift_dev` 2.31 ne savait plus résoudre
    // un nom de table sous `analyzer` 10, et abandonnait la contrainte en
    // silence. La montée en 2.35 les rétablit toutes.
    final schema = await db
        .customSelect(
          "SELECT name, sql FROM sqlite_master WHERE type = 'table' "
          "AND sql IS NOT NULL",
        )
        .get();
    final avecCle = schema
        .where((r) => r.read<String>('sql').contains('REFERENCES'))
        .length;
    expect(
      avecCle,
      greaterThan(10),
      reason: 'le générateur a de nouveau perdu les clés étrangères',
    );

    // Et elles sont appliquées : un enfant ne peut plus pointer vers un
    // profil qui n'existe pas.
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: 'u2',
            role: 'PARENT',
            phone: '+224600000002',
          ),
        );
    await db
        .into(db.parents)
        .insert(ParentsCompanion.insert(id: 'p2', userId: 'u2'));

    await expectLater(
      db
          .into(db.children)
          .insert(
            ChildrenCompanion.insert(
              id: 'c2',
              parentId: 'p2',
              firstName: 'Ibrahima',
              filiereId: const Value('fil_inexistant'),
            ),
          ),
      throwsA(anything),
    );
  });

  test('un parent inexistant est refusé', () async {
    // La même garantie sur la relation la plus utilisée du schéma.
    await expectLater(
      db
          .into(db.children)
          .insert(
            ChildrenCompanion.insert(
              id: 'c3',
              parentId: 'parent_fantome',
              firstName: 'Mariama',
            ),
          ),
      throwsA(anything),
    );
  });
}
